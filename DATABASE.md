# 🗄️ DATABASE.md — GOATPlayer Database Architecture

GOATPlayer utilizes a dual-database architecture designed for maximum performance, offline reliability, and platform suitability across native Flutter clients and Smart TV web engines.

---

## 1. Flutter Client Database: Drift (SQLite)

The native Flutter application uses **Drift** (type-safe SQLite ORM) located in `lib/core/database/`.

### 1.1 Core Tables Schema

#### 1. `Accounts` (`Accounts` Table)
Stores configured IPTV provider connections (Xtream Codes & M3U).
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | Int | Primary Key, Auto-Increment | Unique account ID |
| `playlistName` | Text | Nullable | User-friendly playlist display name |
| `serverUrl` | Text | Not Null | Base IPTV provider URL or M3U URL |
| `username` | Text | Not Null | Xtream username or empty for direct M3U |
| `password` | Text | Not Null | Xtream password or empty for direct M3U |
| `isTrial` | Bool | Default false | Trial account indicator |
| `maxConnections` | Int | Nullable | Maximum allowed concurrent connections |
| `expDate` | Int | Nullable | Subscription expiry timestamp (Unix) |
| `createdAt` | DateTime | Default `currentDateAndTime` | Account creation timestamp |

#### 2. `Categories` (`Categories` Table)
Categorizes Live TV, Movies, and Series.
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | Int | Primary Key, Auto-Increment | Unique category row ID |
| `accountId` | Int | Foreign Key (`Accounts.id`) | Owner account |
| `categoryId` | Text | Not Null | Provider or parsed category ID |
| `name` | Text | Not Null | Category display name |
| `type` | Text | Not Null | `'live'`, `'movie'`, or `'series'` |

#### 3. `Streams` (`Streams` Table)
Unified stream items table caching channels, movies, and series.
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | Int | Primary Key, Auto-Increment | Unique stream row ID |
| `accountId` | Int | Foreign Key (`Accounts.id`) | Owner account |
| `categoryId` | Text | Not Null | Category ID |
| `streamId` | Text | Not Null | Provider stream ID |
| `epgChannelId` | Text | Nullable | EPG mapping channel ID |
| `name` | Text | Not Null | Stream / title name |
| `streamType` | Text | Not Null | `'live'`, `'movie'`, or `'series'` |
| `streamIcon` | Text | Nullable | Stream icon or cover poster URL |
| `url` | Text | Nullable | Direct playback URL (constructed or M3U) |
| `added` | Int | Nullable | Unix timestamp added (for VOD sorting) |

#### 4. `EpgPrograms` (`EpgPrograms` Table)
Electronic Program Guide schedule.
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | Int | Primary Key, Auto-Increment | Unique program row ID |
| `accountId` | Int | Foreign Key (`Accounts.id`) | Owner account |
| `channelId` | Text | Not Null | Stream ID matching live channel |
| `title` | Text | Not Null | Program title |
| `description` | Text | Nullable | Program synopsis / plot |
| `startTime` | DateTime | Not Null | Broadcast start time |
| `stopTime` | DateTime | Not Null | Broadcast stop time |

#### 5. `Favorites` (`Favorites` Table)
User bookmarked channels, movies, and series.
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | Int | Primary Key, Auto-Increment | Unique favorite row ID |
| `accountId` | Int | Foreign Key (`Accounts.id`) | Owner account |
| `streamId` | Text | Not Null | Target stream ID |
| `streamType` | Text | Not Null | `'live'`, `'movie'`, or `'series'` |
| `addedAt` | DateTime | Default `currentDateAndTime` | Timestamp added |
| **Unique Key** | (`accountId`, `streamId`, `streamType`) | Composite | Prevents duplicate bookmarks |

#### 6. `PlaybackProgress` (`PlaybackProgress` Table)
Tracks Continue Watching and resume points for Movies and Series episodes.
| Column | Type | Constraints | Description |
|---|---|---|---|
| `streamId` | Text | Primary Key | Movie or Episode stream ID |
| `streamType` | Text | Not Null | `'movie'` or `'series'` |
| `seriesId` | Text | Nullable | Parent series ID (null for movies) |
| `title` | Text | Not Null | Title of movie or episode |
| `coverUrl` | Text | Nullable | Poster URL |
| `position` | Int | Not Null | Last watched position (seconds) |
| `duration` | Int | Not Null | Total duration (seconds) |
| `season` | Int | Nullable | Season number |
| `episode` | Int | Nullable | Episode number |
| `episodeTitle` | Text | Nullable | Specific episode title |
| `isCompleted` | Bool | Default false | Flagged true if watched >= 95% |
| `updatedAt` | DateTime | Default `currentDateAndTime` | Timestamp for sorting |

### 1.2 Performance & Optimization Settings
- **WAL Mode (Write-Ahead Logging)**: Enabled at initialization to allow concurrent background EPG/stream updates without blocking UI reads.
- **Synchronous = NORMAL**: Reduces disk write latency on flash storage (Android TV / Fire TV sticks).
- **Cache Size = -64000**: Allocates 64MB memory cache for instant queries.
- **Indexes**:
  - `idx_live_acc_cat`: `ON live_streams(account_id, category_id)`
  - `idx_vod_acc_cat`: `ON vod_streams(account_id, category_id)`
  - `idx_epg_chan_time`: `ON epg_programs(channel_id, start_time, end_time)`

---

## 2. Smart TV Client Storage (`smart_tv/js/storage.js`)

On Samsung Tizen and LG webOS, data is stored in `localStorage` with automatic in-memory fallback (`_memStore`) if `file://` sandboxing restricts disk access.

### 2.1 Storage Key Registry

| Storage Key | Format | Description |
|---|---|---|
| `goat_accounts` | JSON Array | Array of account objects (`id`, `name`, `serverUrl`, `username`, `password`, `type`: `'xtream'` \| `'m3u'`) |
| `goat_active_acc` | String | ID of currently selected account |
| `goat_prog_${accId}_${streamId}` | JSON Object | Individual stream progress record |
| `goat_cw_${accId}` | JSON Array | Continue Watching rail items (LRU sorted, capped at 100) |
| `goat_favs_${accId}` | JSON Object | Favorites mapping: `{ live: [], movie: [], series: [] }` |
| `goat_device_id` | String | Unique Virtual Device ID (e.g. `GP-8832-1940`) |
| `goat_settings` | JSON Object | Audio/subtitle track preferences (`audio_pref`, `sub_pref`: `'deu'`, `'eng'`, `'auto'`), app language (`lang`: `'de'`, `'en'`) |

### 2.2 Continue Watching Item Schema
```json
{
  "streamId": "184920",
  "seriesId": "4810",
  "type": "series",
  "title": "Chapter One: The Vanishing",
  "seriesName": "Stranger Things",
  "season": 1,
  "episode": 1,
  "posterUrl": "http://provider.com/images/poster.jpg",
  "containerExtension": "mp4",
  "position": 1240,
  "duration": 2980,
  "isCompleted": false,
  "updatedAt": 1726402800000
}
```

---

## 3. Cloud Synchronization: Supabase Realtime

The remote web manager portal communicates with devices via Supabase Realtime.
- **Pairing Table (`device_pairings`)**:
  - `device_id`: `GP-XXXX-XXXX`
  - `pin`: 6-digit numeric string (20-minute expiry)
  - `accounts_payload`: Encrypted JSON string of IPTV credentials
  - `status`: `'waiting'`, `'connected'`, `'completed'`
