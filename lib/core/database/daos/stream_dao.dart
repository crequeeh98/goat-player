import 'dart:async';

import 'package:drift/drift.dart';
import '../tables.dart';
import '../app_database.dart';

part 'stream_dao.g.dart';

@DriftAccessor(tables: [Streams, Favorites])
class StreamDao extends DatabaseAccessor<AppDatabase> with _$StreamDaoMixin {
  StreamDao(AppDatabase db) : super(db);

  static const int _batchChunkSize = 500;
  static final RegExp _ftsSpecialChars = RegExp(r'''["'*()+^\-:{}~\[\]\\/]''');
  static const Set<String> _ftsOperators = {'AND', 'OR', 'NOT', 'NEAR'};
  Future<void> _writeQueue = Future<void>.value();

  Future<T> _enqueueWrite<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _writeQueue = _writeQueue.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<void> insertStreams(List<StreamsCompanion> streamList) {
    return _enqueueWrite(() async {
      await batch((batch) {
        batch.insertAll(streams, streamList, mode: InsertMode.insertOrReplace);
      });
    });
  }

  Stream<List<StreamItem>> watchStreamsByCategory(
    int accountId,
    String categoryId, {
    int? limit,
    int offset = 0,
  }) {
    final query = select(streams)
      ..where((s) => s.accountId.equals(accountId) & s.categoryId.equals(categoryId))
      ..orderBy([(s) => OrderingTerm(expression: s.name)]);
    if (limit != null && limit > 0) {
      query.limit(limit, offset: offset);
    }
    return query.watch().map(_deduplicateByStreamId);
  }

  Future<List<StreamItem>> getStreamsByCategoryPage(
    int accountId,
    String categoryId, {
    required int limit,
    int offset = 0,
  }) async {
    final rows = await (select(streams)
          ..where((s) => s.accountId.equals(accountId) & s.categoryId.equals(categoryId))
          ..orderBy([(s) => OrderingTerm(expression: s.name)])
          ..limit(limit, offset: offset))
        .get();
    return _deduplicateByStreamId(rows);
  }

  Future<int> countStreamsByCategory(int accountId, String categoryId) async {
    final countExp = streams.id.count();
    final query = selectOnly(streams)
      ..addColumns([countExp])
      ..where(streams.accountId.equals(accountId) & streams.categoryId.equals(categoryId));
    final result = await query.map((row) => row.read(countExp)).getSingle();
    return result ?? 0;
  }

  Stream<List<StreamItem>> watchFavoriteStreams(int accountId, String streamType) {
    final query = select(streams).join([
      innerJoin(
        favorites,
        favorites.streamId.equalsExp(streams.streamId) &
            favorites.streamType.equalsExp(streams.streamType) &
            favorites.accountId.equalsExp(streams.accountId),
      ),
    ])
      ..where(streams.accountId.equals(accountId) & streams.streamType.equals(streamType))
      ..orderBy([OrderingTerm.asc(favorites.sortOrder), OrderingTerm.desc(favorites.addedAt)]);

    return query.watch().map((rows) {
      final list = rows.map((row) => row.readTable(streams)).toList();
      return _deduplicateByStreamId(list);
    });
  }

  List<StreamItem> _deduplicateByStreamId(List<StreamItem> list) {
    final seen = <String>{};
    return list.where((item) => seen.add(item.streamId)).toList();
  }

  String _buildFtsPrefixQuery(String trimmed) {
    final tokens = trimmed
        .split(RegExp(r'\s+'))
        .map((w) => w.replaceAll(_ftsSpecialChars, '').trim())
        .where((w) => w.isNotEmpty && !_ftsOperators.contains(w.toUpperCase()))
        .map((w) => '"$w"*')
        .toList();
    return tokens.join(' ');
  }

  Stream<List<StreamItem>> _watchStreamsByLike(
    int accountId,
    String streamType,
    String trimmedQuery,
  ) {
    final cleanQuery = '%${trimmedQuery.toLowerCase()}%';
    return (select(streams)
          ..where((s) =>
              s.accountId.equals(accountId) &
              s.streamType.equals(streamType) &
              s.name.lower().like(cleanQuery))
          ..orderBy([(s) => OrderingTerm(expression: s.name)]))
        .watch()
        .map(_deduplicateByStreamId);
  }

  Stream<List<StreamItem>> watchStreamsByQuery(
    int accountId,
    String streamType,
    String query,
  ) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return Stream.value(const <StreamItem>[]);
    }

    final ftsQuery = _buildFtsPrefixQuery(trimmed);
    if (ftsQuery.isEmpty) {
      return _watchStreamsByLike(accountId, streamType, trimmed);
    }

    return Stream<List<StreamItem>>.multi((controller) {
      StreamSubscription<List<StreamItem>>? sub;
      var fellBack = false;

      void startLikeFallback() {
        if (fellBack || controller.isClosed) return;
        fellBack = true;
        sub?.cancel();
        sub = _watchStreamsByLike(accountId, streamType, trimmed).listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
      }

      try {
        final ftsStream = customSelect(
          'SELECT s.* FROM streams s '
          'JOIN streams_fts f ON s.id = f.rowid '
          'WHERE s.account_id = ? AND s.stream_type = ? AND streams_fts MATCH ? '
          'ORDER BY s.name ASC',
          variables: [
            Variable.withInt(accountId),
            Variable.withString(streamType),
            Variable.withString(ftsQuery),
          ],
          readsFrom: {streams},
        ).watch().asyncMap((rows) async {
          final items = await Future.wait(rows.map(streams.mapFromRow));
          return _deduplicateByStreamId(items);
        });

        sub = ftsStream.listen(
          controller.add,
          onError: (Object _, StackTrace _) => startLikeFallback(),
          onDone: () {
            if (!fellBack) controller.close();
          },
        );
      } catch (_) {
        startLikeFallback();
      }

      controller.onCancel = () => sub?.cancel();
    });
  }

  Future<int> countStreamsByType(int accountId, String streamType) async {
    final countExp = streams.id.count();
    final query = selectOnly(streams)
      ..addColumns([countExp])
      ..where(streams.accountId.equals(accountId) & streams.streamType.equals(streamType));
    final result = await query.map((row) => row.read(countExp)).getSingle();
    return result ?? 0;
  }

  Future<void> replaceStreamsByType(
    int accountId,
    String streamType,
    List<StreamsCompanion> streamList,
  ) {
    return _enqueueWrite(() async {
      await transaction(() async {
        final existingRows = await (select(streams)
              ..where((s) => s.accountId.equals(accountId) & s.streamType.equals(streamType)))
            .get();

        final existingByKey = <String, StreamItem>{};
        final staleIds = <int>[];
        for (final row in existingRows) {
          final key = '${row.streamId}|${row.categoryId}';
          if (existingByKey.containsKey(key)) {
            staleIds.add(row.id);
          } else {
            existingByKey[key] = row;
          }
        }

        final toInsert = <StreamsCompanion>[];
        final toUpdate = <StreamsCompanion>[];
        final seenIncomingKeys = <String>{};

        for (final incoming in streamList) {
          final incomingStreamId = incoming.streamId.present ? incoming.streamId.value : '';
          final incomingCategoryId = incoming.categoryId.present ? incoming.categoryId.value : '';
          final key = '$incomingStreamId|$incomingCategoryId';
          if (!seenIncomingKeys.add(key)) continue;

          final existing = existingByKey.remove(key);
          if (existing == null) {
            toInsert.add(incoming);
            continue;
          }

          final newName = incoming.name.present ? incoming.name.value : existing.name;
          final newIcon = incoming.streamIcon.present ? incoming.streamIcon.value : null;
          final newEpg = incoming.epgChannelId.present ? incoming.epgChannelId.value : null;
          final newUrl = incoming.url.present ? incoming.url.value : null;
          final newAdded = incoming.added.present ? incoming.added.value : null;

          final changed = newName != existing.name ||
              newIcon != existing.streamIcon ||
              newEpg != existing.epgChannelId ||
              newUrl != existing.url ||
              newAdded != existing.added;

          if (changed) {
            toUpdate.add(StreamsCompanion(
              id: Value(existing.id),
              accountId: Value(accountId),
              categoryId: Value(incomingCategoryId),
              streamId: Value(incomingStreamId),
              epgChannelId: Value(newEpg),
              name: Value(newName),
              streamType: Value(streamType),
              streamIcon: Value(newIcon),
              url: Value(newUrl),
              added: Value(newAdded),
            ));
          }
        }

        for (final remaining in existingByKey.values) {
          staleIds.add(remaining.id);
        }

        final mutationCount = staleIds.length + toInsert.length + toUpdate.length;
        if (mutationCount == 0) return;

        await _runWithBulkFtsIfLarge(mutationCount, () async {
          for (var i = 0; i < staleIds.length; i += _batchChunkSize) {
            final end = (i + _batchChunkSize < staleIds.length) ? i + _batchChunkSize : staleIds.length;
            final chunk = staleIds.sublist(i, end);
            await (delete(streams)..where((s) => s.id.isIn(chunk))).go();
          }
          for (var i = 0; i < toInsert.length; i += _batchChunkSize) {
            final end = (i + _batchChunkSize < toInsert.length) ? i + _batchChunkSize : toInsert.length;
            await batch((batch) {
              batch.insertAll(streams, toInsert.sublist(i, end), mode: InsertMode.insertOrReplace);
            });
          }
          for (var i = 0; i < toUpdate.length; i += _batchChunkSize) {
            final end = (i + _batchChunkSize < toUpdate.length) ? i + _batchChunkSize : toUpdate.length;
            await batch((batch) {
              batch.replaceAll(streams, toUpdate.sublist(i, end));
            });
          }
        });
      });
    });
  }

  Future<void> _runWithBulkFtsIfLarge(
    int mutatedRows,
    Future<void> Function() body,
  ) async {
    const bulkFtsThreshold = 500;
    if (mutatedRows <= bulkFtsThreshold) {
      await body();
      return;
    }

    final hasFtsTable = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type='table' AND name='streams_fts' LIMIT 1",
    ).getSingleOrNull();
    if (hasFtsTable == null) {
      await body();
      return;
    }

    await db.dropStreamsFtsTriggers();
    try {
      await body();
    } finally {
      await db.installStreamsFtsTriggers();
      await db.rebuildStreamsFts();
    }
  }

  Future<void> clearStreamsByType(int accountId, String streamType) {
    return _enqueueWrite(
      () => (delete(streams)..where((s) => s.accountId.equals(accountId) & s.streamType.equals(streamType))).go(),
    );
  }

  Future<void> clearStreamsByCategory(int accountId, String categoryId) {
    return _enqueueWrite(
      () => (delete(streams)..where((s) => s.accountId.equals(accountId) & s.categoryId.equals(categoryId))).go(),
    );
  }

  Future<void> clearAllStreams(int accountId) {
    return _enqueueWrite(
      () => (delete(streams)..where((s) => s.accountId.equals(accountId))).go(),
    );
  }

  Future<void> replaceStreamsByCategory(int accountId, String categoryId, List<StreamsCompanion> streamList) {
    return _enqueueWrite(() async {
      final dedupedList = <StreamsCompanion>[];
      final seenStreamIds = <String>{};
      for (final item in streamList) {
        final sid = item.streamId.present ? item.streamId.value : '';
        if (sid.isEmpty || seenStreamIds.add(sid)) {
          dedupedList.add(item);
        }
      }
      await transaction(() async {
        final existingCount = await countStreamsByCategory(accountId, categoryId);
        await _runWithBulkFtsIfLarge(existingCount + dedupedList.length, () async {
          await (delete(streams)..where((s) => s.accountId.equals(accountId) & s.categoryId.equals(categoryId))).go();
          for (var i = 0; i < dedupedList.length; i += _batchChunkSize) {
            final end = (i + _batchChunkSize < dedupedList.length) ? i + _batchChunkSize : dedupedList.length;
            await batch((batch) {
              batch.insertAll(streams, dedupedList.sublist(i, end), mode: InsertMode.insertOrReplace);
            });
          }
        });
      });
    });
  }
}
