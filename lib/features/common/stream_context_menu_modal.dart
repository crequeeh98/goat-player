import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/platform_utils.dart';
import '../../core/widgets/tv_focusable.dart';
import '../../main.dart';

class StreamContextMenuModal extends ConsumerStatefulWidget {
  final StreamItem stream;

  const StreamContextMenuModal({
    super.key,
    required this.stream,
  });

  static Future<void> show(BuildContext context, StreamItem stream) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StreamContextMenuModal(stream: stream),
    );
  }

  @override
  ConsumerState<StreamContextMenuModal> createState() => _StreamContextMenuModalState();
}

class _StreamContextMenuModalState extends ConsumerState<StreamContextMenuModal> {
  final TextEditingController _newListController = TextEditingController();
  final FocusNode _newListFocusNode = FocusNode(debugLabel: 'new_list_input');
  bool _isCreatingList = false;

  @override
  void dispose() {
    _newListController.dispose();
    _newListFocusNode.dispose();
    super.dispose();
  }

  void _createAndAddList() async {
    final name = _newListController.text.trim();
    if (name.isEmpty) return;

    final account = ref.read(activeAccountProvider);
    if (account == null) return;

    final customDao = ref.read(customListDaoProvider);
    final listId = await customDao.createList(account.id, name, widget.stream.streamType);
    await customDao.addItemToList(
      listId,
      account.id,
      widget.stream.streamId,
      widget.stream.streamType,
      widget.stream.name,
    );

    if (mounted) {
      _newListController.clear();
      setState(() => _isCreatingList = false);
    }
  }

  void _showRenameListDialog(CustomList list, bool isDe) async {
    final controller = TextEditingController(text: list.name);
    final formKey = GlobalKey<FormState>();

    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161026),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.edit_rounded, color: Color(0xFFB388FF), size: 22),
            const SizedBox(width: 10),
            Text(
              isDe ? 'Liste umbenennen' : 'Rename List',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: isDe ? 'Listenname...' : 'List name...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFB388FF), width: 1.5),
              ),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? (isDe ? 'Name darf nicht leer sein' : 'Name cannot be empty')
                : null,
            onFieldSubmitted: (v) {
              if (formKey.currentState?.validate() == true) {
                Navigator.of(ctx).pop(v.trim());
              }
            },
          ),
        ),
        actions: [
          TvFocusable(
            borderRadius: BorderRadius.circular(8),
            onPressed: () => Navigator.of(ctx).pop(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(isDe ? 'Abbrechen' : 'Cancel', style: const TextStyle(color: Colors.white60)),
            ),
          ),
          TvFocusable(
            borderRadius: BorderRadius.circular(8),
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.of(ctx).pop(controller.text.trim());
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isDe ? 'Speichern' : 'Save',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );

    if (updated != null && updated.isNotEmpty && mounted) {
      await ref.read(customListDaoProvider).renameList(list.id, updated);
      setState(() {});
    }
  }

  void _showDeleteListDialog(CustomList list, bool isDe) async {
    final account = ref.read(activeAccountProvider);
    if (account == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161026),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5), width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
            const SizedBox(width: 10),
            Text(
              isDe ? 'Liste löschen' : 'Delete List',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        content: Text(
          isDe
              ? 'Möchtest du die Liste "${list.name}" wirklich löschen?\nEnthaltene Einträge bleiben erhalten.'
              : 'Do you really want to delete the list "${list.name}"?\nContained streams will not be deleted.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TvFocusable(
            borderRadius: BorderRadius.circular(8),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(isDe ? 'Abbrechen' : 'Cancel', style: const TextStyle(color: Colors.white60)),
            ),
          ),
          TvFocusable(
            borderRadius: BorderRadius.circular(8),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isDe ? 'Löschen' : 'Delete',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(customListDaoProvider).deleteList(list.id);
      await ref.read(categoryPreferenceDaoProvider).deletePreference(account.id, 'custom_list:${list.id}', widget.stream.streamType);
      setState(() {});
    }
  }

  void _showTvListOptions(CustomList list, bool isDe) async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: const Color(0xFF161026),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
        ),
        title: Text(
          list.name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('rename'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.edit_rounded, color: Color(0xFFB388FF), size: 20),
                  const SizedBox(width: 12),
                  Text(isDe ? 'Liste umbenennen' : 'Rename list', style: const TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('delete'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 12),
                  Text(isDe ? 'Liste löschen' : 'Delete list', style: const TextStyle(color: Colors.redAccent, fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (action == 'rename') {
      _showRenameListDialog(list, isDe);
    } else if (action == 'delete') {
      _showDeleteListDialog(list, isDe);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(activeAccountProvider);
    if (account == null) return const SizedBox.shrink();

    final customDao = ref.watch(customListDaoProvider);
    final favDao = ref.watch(favoriteDaoProvider);
    final isDe = Localizations.localeOf(context).languageCode == 'de';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: GoatPlatform.isTv ? 50 : 20,
        vertical: GoatPlatform.isTv ? 30 : 40,
      ),
      child: Container(
        width: 440,
        constraints: const BoxConstraints(maxHeight: 580),
        decoration: BoxDecoration(
          color: const Color(0xFF161026),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 36,
              spreadRadius: 6,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: Stream Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                children: [
                  const Icon(Icons.playlist_add_rounded, color: Color(0xFFB388FF), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.stream.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  TvFocusable(
                    borderRadius: BorderRadius.circular(16),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white70, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white12),

            // Favorites Toggle Row
            StreamBuilder<bool>(
              stream: favDao.isFavorite(account.id, widget.stream.streamId, widget.stream.streamType),
              builder: (context, snapshot) {
                final isFav = snapshot.data ?? false;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: TvFocusable(
                    autofocus: true,
                    borderRadius: BorderRadius.circular(10),
                    onPressed: () => favDao.toggleFavorite(account.id, widget.stream.streamId, widget.stream.streamType),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isFav
                            ? Colors.amber.withValues(alpha: 0.12)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isFav ? Colors.amber.withValues(alpha: 0.5) : Colors.white12,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: isFav ? Colors.amber : Colors.white60,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isFav
                                  ? (isDe ? 'Aus Favoriten entfernen' : 'Remove from Favorites')
                                  : (isDe ? 'Zu Favoriten hinzufügen' : 'Add to Favorites'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isFav ? FontWeight.bold : FontWeight.w500,
                                color: isFav ? Colors.amber : Colors.white,
                              ),
                            ),
                          ),
                          if (isFav)
                            const Icon(Icons.check_rounded, color: Colors.amber, size: 18),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
              child: Text(
                isDe ? 'EIGENE LISTEN' : 'CUSTOM LISTS',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 0.8),
              ),
            ),

            // Custom Lists for this streamType
            Flexible(
              child: StreamBuilder<List<CustomList>>(
                stream: customDao.watchCustomLists(account.id, widget.stream.streamType),
                builder: (context, snapshot) {
                  final lists = snapshot.data ?? [];

                  return FutureBuilder<List<int>>(
                    future: customDao.getListIdsContainingStream(account.id, widget.stream.streamId),
                    builder: (context, idSnap) {
                      final containingListIds = (idSnap.data ?? []).toSet();

                      return ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          for (final list in lists) ...[
                            Builder(
                              builder: (context) {
                                final isInThisList = containingListIds.contains(list.id);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3),
                                  child: TvFocusable(
                                    borderRadius: BorderRadius.circular(10),
                                    onLongPress: GoatPlatform.isTv ? () => _showTvListOptions(list, isDe) : null,
                                    onPressed: () async {
                                      if (isInThisList) {
                                        await customDao.removeItemFromList(list.id, widget.stream.streamId);
                                      } else {
                                        await customDao.addItemToList(
                                          list.id,
                                          account.id,
                                          widget.stream.streamId,
                                          widget.stream.streamType,
                                          widget.stream.name,
                                        );
                                      }
                                      if (mounted) setState(() {});
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isInThisList
                                            ? const Color(0xFF7C3AED).withValues(alpha: 0.18)
                                            : Colors.white.withValues(alpha: 0.04),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isInThisList
                                              ? const Color(0xFFB388FF).withValues(alpha: 0.4)
                                              : Colors.white10,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.playlist_play_rounded,
                                            size: 20,
                                            color: isInThisList ? const Color(0xFFB388FF) : Colors.white60,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              list.name,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: isInThisList ? FontWeight.bold : FontWeight.normal,
                                                color: isInThisList ? Colors.white : Colors.white70,
                                              ),
                                            ),
                                          ),
                                          if (!GoatPlatform.isTv) ...[
                                            IconButton(
                                              icon: const Icon(Icons.edit_rounded, size: 16, color: Color(0xFFB388FF)),
                                              tooltip: isDe ? 'Umbenennen' : 'Rename',
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                              onPressed: () => _showRenameListDialog(list, isDe),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                                              tooltip: isDe ? 'Löschen' : 'Delete',
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                              onPressed: () => _showDeleteListDialog(list, isDe),
                                            ),
                                            const SizedBox(width: 4),
                                          ],
                                          Icon(
                                            isInThisList
                                                ? Icons.check_box_rounded
                                                : Icons.check_box_outline_blank_rounded,
                                            size: 18,
                                            color: isInThisList ? const Color(0xFFB388FF) : Colors.white30,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],

                          if (lists.isEmpty && !_isCreatingList)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                  isDe ? 'Noch keine eigenen Listen erstellt' : 'No custom lists created yet',
                                  style: const TextStyle(fontSize: 12.5, color: Colors.white38),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),

            const Divider(height: 1, color: Colors.white12),

            // Create New List Option
            Padding(
              padding: const EdgeInsets.all(16),
              child: _isCreatingList
                  ? Row(
                      children: [
                        Expanded(
                          child: TextField(
                            focusNode: _newListFocusNode,
                            controller: _newListController,
                            autofocus: true,
                            style: const TextStyle(fontSize: 13, color: Colors.white),
                            decoration: InputDecoration(
                              hintText: isDe ? 'Listenname (z. B. Sport, News)...' : 'List name (e.g. Sports, News)...',
                              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.08),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFFB388FF), width: 1.5),
                              ),
                            ),
                            onSubmitted: (_) => _createAndAddList(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TvFocusable(
                          borderRadius: BorderRadius.circular(10),
                          onPressed: _createAndAddList,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              isDe ? 'Speichern' : 'Save',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    )
                  : TvFocusable(
                      borderRadius: BorderRadius.circular(10),
                      onPressed: () {
                        setState(() => _isCreatingList = true);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            _newListFocusNode.requestFocus();
                            SystemChannels.textInput.invokeMethod('TextInput.show');
                            if (GoatPlatform.isTv) {
                              Future.delayed(const Duration(milliseconds: 300), () {
                                GoatPlatform.focusTvKeyboard();
                              });
                            }
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12, width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_rounded, size: 18, color: Color(0xFFB388FF)),
                            const SizedBox(width: 8),
                            Text(
                              isDe ? 'Neue Liste erstellen...' : 'Create new list...',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFB388FF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
