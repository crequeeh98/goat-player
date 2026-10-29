# 🗄️ DATABASE.md — GOATPlayer Database Architecture

GOATPlayer uses a high-performance dual-database architecture tailored to its target platforms:
1. **Flutter Native Client (Desktop & Android)**: Powered by **Drift** (SQLite with Write-Ahead Logging).
2. **Smart TV Web Application (Samsung Tizen & LG webOS)**: Powered by a sandboxed, fault-tolerant key-value engine with in-memory fallback.

---

## 1. Flutter Client Database: Drift (SQLite)

Located in `lib/core/database/`, Drift provides compile-time type safety, asynchronous query streams, and isolate-based background transactions.

### 1.1 Core Tables Schema

#### 1. `Accounts` Table (`lib/core/database/tables.dart`)
Stores IPTV provider credentials and playlist configurations.
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | Int | Primary Key, Auto-Increment | Unique account ID |
| `playlistName` | Text | Nullable | User-friendly display label |
| `serverUrl` | Text | Not Null | IPTV server base URL or direct M3U URL |
| `username` | Text | Not Null | Xtream username or empty for direct M3U |
| `password` | Text | Not Null | Xtream password or empty for direct M3U |
| `isTrial` | Bool | Default `false` | Trial account indicator |
| `maxConnections` | Int | Nullable | Maximum allowed concurrent streams |
| `expDate` | Int | Nullable | Subscription expiration Unix timestamp |
| `createdAt` | DateTime | Default `currentDateAndTime` | Account creation timestamp |

#### 2. `Categories` Table
Stores stream categories partitioned by type and account.
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | Int | Primary Key, Auto-Increment | Internal row ID |
| `accountId` | Int | Foreign Key (`Accounts.id`) | Owning account ID |
| `categoryId` | Text | Not Null | Provider category ID or M3U group name |
| `name` | Text | Not Null | Category display name |
| `type` | Text | Not Null | Category type: `'live'`, `'movie'`, or `'series'` |

#### 3. `Streams` Table
Unified table indexing Live TV channels, VOD movies, and series episodes.
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | Int | Primary Key, Auto-Increment | Internal row ID |
| `accountId` | Int | Foreign Key (`Accounts.id`) | Owning account ID |
| `categoryId` | Text | Not Null | Category ID mapping |
| `streamId` | Text | Not Null | Provider stream ID or episode ID |
| `parentStreamId` | Text | Nullable | Parent series stream ID (for TV episodes) |
| `epgChannelId` | Text | Nullable | XMLTV channel ID mapping for EPG |
| `name` | Text | Not Null | Cleaned stream or episode title |
| `streamType` | Text | Not Null | `'live'`, `'movie'`, or `'series'` |
| `streamIcon` | Text | Nullable | Poster or channel logo URL |
| `url` | Text | Nullable | Direct playback URL (constructed or M3U) |
| `added` | Int | Nullable | Timestamp added (for sorting newest VODs) |

#### 4. `EpgPrograms` Table
Stores Electronic Program Guide schedule entries.
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | Int | Primary Key, Auto-Increment | Internal row ID |
| `accountId` | Int | Foreign Key (`Accounts.id`) | Owning account ID |
| `channelId` | Text | Not Null | Mapping to `Streams.epgChannelId` |
| `title` | Text | Not Null | Program title |
| `description` | Text | Nullable | Synopsis or episode description |
| `startTime` | DateTime | Not Null | Program start time (UTC) |
| `endTime` | DateTime | Not Null | Program end time (UTC) |

#### 5. `PlaybackProgress` Table
Maintains granular playback state, watch history, and episode completion.
| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | Int | Primary Key, Auto-Increment | Internal row ID |
| `accountId` | Int | Foreign Key (`Accounts.id`) | Owning account ID |
| `streamId` | Text | Not Null | Stream ID or episode ID |
| `seriesId` | Text | Nullable | Parent series ID (if episode) |
| `positionSecs` | Int | Not Null | Current playback position in seconds |
| `durationSecs` | Int | Not Null | Total duration in seconds |
| `isCompleted` | Bool | Default `false` | True when position $\ge 95\%$ of duration |
| `lastWatched` | DateTime | Default `currentDateAndTime` | Timestamp of last playback |

---

### 1.2 Data Access Objects (DAOs)

1. **`StreamDao` (`lib/core/database/daos/stream_dao.dart`)**:
   - Manages batch stream ingestion via SQLite transactions.
   - Implements fast indexed queries by `accountId`, `categoryId`, and `streamType`.
   - Handles global search queries with prefix and substring matching.
2. **`AccountDao` (`lib/core/database/daos/account_dao.dart`)**:
   - Manages account creation, credential updates, and playlist deletion with cascading cleanup.
3. **`EpgDao` (`lib/core/database/daos/epg_dao.dart`)**:
   - Queries currently airing and upcoming programs for channel lists and OSD infobars.
   - Calculates real-time program progress percentages.
4. **`PlaybackProgressDao` (`lib/core/database/daos/playback_progress_dao.dart`)**:
   - Powers the **Continue Watching Rail**:
     - Automatically deduplicates series, displaying only the single latest or next episode.
     - Automatically advances to the next episode when the previous episode reaches $\ge 95\%$ completion.
     - Safely evicts finished movies and series finales.

---

## 2. Smart TV Web Application Storage (`smart_tv/js/storage.js`)

On low-powered Smart TVs (Samsung Tizen & LG webOS), the application uses an abstracted key-value store with sandbox-safe fallbacks.

### 2.1 Schema & Keys

| Key | Storage Target | Description |
|---|---|---|
| `goat_accounts` | JSON Array | Array of configured IPTV accounts |
| `goat_active_account` | String | ID of currently selected active account |
| `goat_favs_<accountId>` | JSON Array | Array of pinned favorite stream IDs |
| `goat_progress_<accountId>` | JSON Object | Map of `streamId` to progress objects `{ position, duration, completed, lastWatched }` |
| `goat_settings` | JSON Object | Audio/subtitle language preferences and UI settings |

### 2.2 Sandboxed In-Memory Fallback

When running as an installed W3C widget (`file://` protocol) on select Samsung Tizen firmware, accessing `window.localStorage` throws a `SecurityError`. `TVStorage` intercepts this condition and seamlessly routes all read/write operations to an in-memory dictionary (`_memStore`), ensuring that video playback and UI navigation remain uninterrupted.
