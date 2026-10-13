# 🗄️ DATABASE.md — GOATPlayer Database Architecture

GOATPlayer utilizes a dual-database architecture designed for maximum performance, offline reliability, and platform suitability across native Flutter clients and Smart TV web engines.

---

## 1. Flutter Client Database: Drift (SQLite)

The native Flutter application uses **Drift** (type-safe SQLite ORM) located in `lib/core/database/`.

### 1.1 Core Tables Schema

#### 1. `accounts` (`AccountsTable`)
Stores configured IPTV provider connections.
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | Text | Primary Key | Unique UUID |
| `name` | Text | Not Null | Display name |
| `server_url` | Text | Not Null | Base IPTV provider URL (normalized) |
| `username` | Text | Not Null | Xtream username |
| `password` | Text | Not Null | Xtream password |
| `is_active` | Bool | Default false | Currently active account |
| `expires_at` | DateTime | Nullable | Subscription expiry date |
| `created_at` | DateTime | Not Null | Creation timestamp |

#### 2. `stream_categories` (`StreamCategoriesTable`)
Categorizes Live TV, Movies, and Series.
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | Text | Primary Key | Composite key (`${account_id}_${category_id}`) |
| `account_id` | Text | Foreign Key (`accounts.id`) | Owner account |
| `category_id` | Text | Not Null | Provider category ID |
| `category_name`| Text | Not Null | Category display name |
| `category_type`| Text | Not Null | `'live'`, `'movie'`, or `'series'` |
| `is_hidden` | Bool | Default false | User hidden status |
| `sort_order` | Int | Default 0 | Custom display order |

#### 3. `live_streams` (`LiveStreamsTable`)
Live TV channels cached per account.
| Column | Type | Constraints | Description |
|---|---|---|---|
| `stream_id` | Int | Not Null | Provider stream ID |
| `account_id` | Text | Foreign Key (`accounts.id`) | Owner account |
| `name` | Text | Not Null | Channel name |
| `stream_icon`| Text | Nullable | Channel logo URL |
| `epg_channel_id`| Text | Nullable | EPG mapping channel ID |
| `category_id`| Text | Not Null | Provider category ID |
| `tv_archive` | Int | Default 0 | Catch-up archive support (days) |
| **Primary Key**| (`account_id`, `stream_id`) | Composite | Unique per account |

#### 4. `vod_streams` (`VodStreamsTable`)
Movies cached per account.
| Column | Type | Constraints | Description |
|---|---|---|---|
| `stream_id` | Int | Not Null | Provider movie ID |
| `account_id` | Text | Foreign Key (`accounts.id`) | Owner account |
| `name` | Text | Not Null | Movie title |
| `stream_icon`| Text | Nullable | Poster image URL |
| `rating` | Real | Nullable | Rating (e.g. 7.8) |
| `category_id`| Text | Not Null | Category ID |
| `container_extension`| Text | Default 'mp4' | Container format (`mp4`, `mkv`, `avi`) |
| `added` | DateTime | Nullable | Date added |
| **Primary Key**| (`account_id`, `stream_id`) | Composite | Unique per account |

#### 5. `series` (`SeriesTable`)
VOD Series cached per account.
| Column | Type | Constraints | Description |
|---|---|---|---|
| `series_id` | Int | Not Null | Provider series ID |
| `account_id` | Text | Foreign Key (`accounts.id`) | Owner account |
| `name` | Text | Not Null | Series title |
| `cover` | Text | Nullable | Poster image URL |
| `rating` | Real | Nullable | Rating (e.g. 8.4) |
| `category_id`| Text | Not Null | Category ID |
| `last_modified`| DateTime | Nullable | Last update timestamp |
| **Primary Key**| (`account_id`, `series_id`) | Composite | Unique per account |

#### 6. `epg_programs` (`EpgProgramsTable`)
Electronic Program Guide schedule.
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | Text | Primary Key | Composite key |
| `channel_id`| Text | Not Null | EPG channel ID (Indexed) |
| `title` | Text | Not Null | Program title |
| `start_time`| DateTime | Not Null | Start timestamp (Indexed) |
| `end_time` | DateTime | Not Null | End timestamp (Indexed) |
| `description`| Text | Nullable | Program plot / synopsis |

#### 7. `playback_progress` (`PlaybackProgressTable`)
Tracks Continue Watching and resume points for Movies and Series episodes.
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | Text | Primary Key | Composite (`${account_id}_${stream_id}`) |
| `account_id` | Text | Foreign Key | Owner account |
| `stream_id` | Text | Not Null | Movie or Episode stream ID |
| `series_id` | Text | Nullable | Parent series ID (null for movies) |
| `type` | Text | Not Null | `'movie'` or `'series'` |
| `title` | Text | Not Null | Title |
| `series_name`| Text | Nullable | Series title |
| `season` | Int | Nullable | Season number |
| `episode` | Int | Nullable | Episode number |
| `position` | Int | Not Null | Last watched position (seconds) |
| `duration` | Int | Not Null | Total duration (seconds) |
| `is_completed`| Bool | Default false | Flagged true if watched >= 95% |
| `updated_at` | DateTime | Not Null | Timestamp for sorting |

#### 8. `favorites` (`FavoritesTable`)
User bookmarked channels, movies, and series.
| Column | Type | Constraints | Description |
|---|---|---|---|
| `account_id` | Text | Foreign Key | Owner account |
| `stream_id` | Text | Not Null | Target stream / series ID |
| `type` | Text | Not Null | `'live'`, `'movie'`, or `'series'` |
| `created_at`| DateTime | Not Null | Timestamp |
| **Primary Key**| (`account_id`, `stream_id`, `type`) | Composite | Unique bookmark |

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
| `goat_accounts` | JSON Array | Array of account objects (`id`, `name`, `serverUrl`, `username`, `password`) |
| `goat_active_acc` | String | ID of currently selected account |
| `goat_prog_${accId}_${streamId}` | JSON Object | Individual stream progress record |
| `goat_cw_${accId}` | JSON Array | Continue Watching rail items (LRU sorted, capped at 100) |
| `goat_favs_${accId}` | JSON Object | Favorites mapping: `{ live: [], movie: [], series: [] }` |
| `goat_device_id` | String | Unique Virtual Device ID (e.g. `GP-8832-1940`) |
| `goat_settings` | JSON Object | Subtitle/audio track preferences, language, buffer settings |

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
