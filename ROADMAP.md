# 🗺️ GOATPlayer Roadmap

Current Release: **`v2.1.3`** (Flutter Desktop/Mobile/Fire TV, Web Pairing Portal, Samsung Tizen & LG webOS Smart TV)

---

## ⚡ Phase 1: Performance & Storage Optimizations

### Smart TV (`smart_tv/`)
- [ ] **A1 — Category DOM Caching (`app.js`)**: Dirty-flag / cache rendered category DOM per tab (`_catsDirty.live/movie/series`) instead of rebuilding `listEl.innerHTML` and re-parsing `localStorage` preferences on every `switchTab()`.
- [ ] **A2 — Fast Sorting (`api.js` / `app.js`)**: Replace repeated `localeCompare` + `.toLowerCase().trim()` inside `sortAlpha` (`smart_tv/js/api.js`) and `_sortVodList` (`smart_tv/js/app.js`) with precomputed sort keys and fast `<` / `>` comparisons (or cached `Intl.Collator`).
- [ ] **A3 — Slim Snapshots for Lists (`app.js` / `storage.js`)**: Store slim stream metadata snapshots for Favorites & Custom Lists so opening top lists avoids fetching 20k+ full streams; eliminate unnecessary `_allAccount*Streams = null` cache invalidation thrashing.
- [ ] **A4 — Lightweight CSS Rules (`css/style.css`)**: Replace `transition: all 0.15s ease` and heavy `box-shadow` focus glows with targeted, compositor-friendly CSS properties on low-power TV GPUs.
- [ ] **B1 + B3 — IndexedDB SWR Cache & Manual Sync Modal**: IndexedDB Stale-While-Revalidate (SWR) cache for categories, streams, and search index paired with a manual Sync & Cache modal / refresh control (parity with Flutter `PlaylistSyncModal`).
- [ ] **B2 — EPG Short-TTL Cache, Paging & Dashboard EPG Timeline**: In-memory EPG cache with 3–5 min TTL + `AbortController` / throttled paging in the channel menu, plus live-channel current program & progress timeline directly on dashboard channel rows (parity with Flutter).
- [ ] **Quickfix — Portal Upload `expDate` & `channelCount` (`app.js`)**: Ensure newly synced portal Xtream accounts immediately fetch & persist `expDate` instead of falling back to "Unlimited", and persist `channelCount` for portal-uploaded M3U playlists after background parse.
- [ ] **Quickfix — Device-Side Connectivity & Auth Validation (`app.js` / `sync.js`)**: On Portal `add` and Portal `edit` (when `serverUrl` or `username`/`password` changed), verify server reachability + login/M3U validity directly on the TV (`authenticate` / `authenticateM3u`, without fetching categories/streams) and surface errors in the pairing UI (manual add/edit already checks).

### Flutter (`lib/`)
- [ ] **F1 — SQLite FTS5 Stream Search**: Upgrade `StreamDao.watchStreamsByQuery()` (`lib/core/database/daos/stream_dao.dart:43-53`) from `lower().like('%query%')` full-table scans to SQLite FTS5 full-text search.
- [ ] **F2 — Paged Category Queries**: Add SQL `LIMIT`/`OFFSET` paging to `StreamDao.watchStreamsByCategory()` (`lib/core/database/daos/stream_dao.dart:17-22`) for ultra-large categories.
- [ ] **F3 — Incremental Delta Upsert Sync**: Replace `replaceStreamsByType()` delete-all + re-insert (`lib/core/database/daos/stream_dao.dart:64-74`) with incremental delta upserts.
- [ ] **Quickfix — Account Expiration Date Badge (`account_list_screen.dart` / DB)**: Persist & display Xtream `expDate` (and M3U channel count) directly on account cards (parity with Smart TV).
- [ ] **Quickfix — Device-Side Connectivity & Auth Validation (`add_account_screen.dart` / `remote_sync_service.dart`)**: Check server reachability + Xtream auth / M3U validity (connection/auth only, no categories/streams) on manual Add, manual Edit (only when URL or username/password changed), Portal `add`, and Portal `edit` (only when URL or username/password changed).

---

## 🔄 Phase 2: Smart TV OTA Full-Parity (Zero Re-Install)
- [ ] **Dynamic DOM & Manifest Bootloader**: Support dynamic JS DOM creation / `index.html` body swap and dynamic script loading from `manifest.json` inside `bootloader.js` / `updater.js` so new modals, buttons, and UI layouts ship via In-App OTA without reinstalling `.ipk`/`.wgt`.
- [ ] **In-App Assets & Storage Headroom**: Deliver in-app logos/icons as SVG or cached data-URIs and add IndexedDB OTA bundle fallback beyond the ~5 MB `localStorage` limit.
- *(Note: TV OS launcher icon, app title, OS-reported package version, and system privileges remain fixed at the `.ipk`/`.wgt` package layer.)*

---

## ☁️ Phase 3: Cross-Device Cloud Sync & Backup
- [ ] **Unified Cross-Device Sync Architecture**: Sync user state cleanly across Flutter (Windows, Android, Fire TV), Smart TV (Tizen, webOS), and Web Portal:
  - Favorites & Continue Watching / Watchlist progress
  - Playlists & Account configurations (zero-knowledge encrypted)
  - Custom Lists, Category ordering, and hidden/visible visibility preferences

---

## 🧪 Phase 4: Future Exploration (If Viable / Permitted)
- [ ] **Catch-Up / Archive Playback**: Xtream Codes catch-up stream support with EPG timeline scrubbing.
- [ ] **Offline VOD Downloads**: Local movie/episode caching on supported Flutter targets (Android / Desktop).
- [ ] **Multi-View Playback**: Simultaneous multi-stream layout where provider connection limits and hardware decoders allow.
