import 'package:drift/drift.dart';

@DataClassName('Account')
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get playlistName => text().nullable()();
  TextColumn get serverUrl => text()();
  TextColumn get username => text()();
  TextColumn get password => text()();
  BoolColumn get isTrial => boolean().withDefault(const Constant(false))();
  IntColumn get maxConnections => integer().nullable()();
  IntColumn get expDate => integer().nullable()(); // Unix timestamp
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Category')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  TextColumn get categoryId => text()(); // String ID from API
  TextColumn get name => text()();
  TextColumn get type => text()(); // 'live', 'movie', 'series'
}

@DataClassName('StreamItem')
class Streams extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  TextColumn get categoryId => text()();
  TextColumn get streamId => text()(); // Stream ID from API
  TextColumn get epgChannelId => text().nullable()(); // EPG Channel ID for matching
  TextColumn get name => text()();
  TextColumn get streamType => text()(); // 'live', 'movie', 'series'
  TextColumn get streamIcon => text().nullable()();
  TextColumn get url => text().nullable()(); // Built from server_url/type/username/password/streamId
  IntColumn get added => integer().nullable()(); // Unix timestamp from API (for VOD sorting)
}

@DataClassName('EpgProgram')
class EpgPrograms extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  TextColumn get channelId => text()(); // Matches streamId of live streams
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get stopTime => dateTime()();
}

@DataClassName('Favorite')
class Favorites extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  TextColumn get streamId => text()(); // The stream ID
  TextColumn get streamType => text()(); // 'live', 'movie', 'series'
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [{accountId, streamId, streamType}];
}

@DataClassName('PlaybackProgressItem')
class PlaybackProgress extends Table {
  TextColumn get streamId => text()(); // The API stream ID (movie ID or episode ID)
  TextColumn get streamType => text()(); // 'movie' or 'series'
  TextColumn get seriesId => text().nullable()(); // If episode, the parent series ID
  TextColumn get title => text()(); // Title of movie or episode
  TextColumn get coverUrl => text().nullable()(); // Poster URL
  IntColumn get position => integer()(); // Position in seconds
  IntColumn get duration => integer()(); // Duration in seconds
  IntColumn get season => integer().nullable()(); // Season number
  IntColumn get episode => integer().nullable()(); // Episode number
  TextColumn get episodeTitle => text().nullable()(); // Specific episode title
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {streamId};
}
