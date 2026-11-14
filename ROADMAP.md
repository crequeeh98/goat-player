# 🗺️ GOATPlayer Roadmap

Current Release: **`v2.1.4`** (Flutter Desktop/Mobile/Fire TV, Web Pairing Portal, Samsung Tizen & LG webOS Smart TV)

---

## ⚡ Phase 1: Performance & Storage Optimizations

### Smart TV (`smart_tv/`)
- [x] **A1 — Incremental Category Rendering & Clean Tab-Reset (`app.js` / `spatial_nav.js`)**: Render categories in 60-item batches (`CATEGORY_BATCH_SIZE = 60`) with viewport focus pruning so 1,000+ categories never freeze low-RAM TVs; preserve classic full tab-reset (to top / Favorites) on tab switch while keeping explicit Master Search jump scrolling.
- [x] **A2 — Fast Sorting (`api.js` / `app.js`)**: Replace repeated `localeCompare` + `.toLowerCase().trim()` inside `sortAlpha` (`smart_tv/js/api.js`) and `_sortVodList` (`smart_tv/js/app.js`) with precomputed sort keys (`_sortName`, `_addedTs`) and cached `_sortedStreamCache` comparisons.
- [x] **A3 — Slim Snapshots for Lists (`app.js` / `storage.js`)**: Store slim stream metadata snapshots (`goat_snap_*`) with batch writes for Favorites & Custom Lists so opening top lists avoids fetching 20k+ full streams; eliminate unnecessary `_allAccount*Streams = null` cache invalidation thrashing; cache parsed M3U playlists in `_m3uParsedCache`.
- [x] **A4 — Lightweight CSS Rules (`css/style.css`)**: Replace `transition: all 0.15s ease` and heavy `box-shadow` focus glows with targeted, compositor-friendly CSS properties on low-power TV GPUs.
- [x] **B1 + B3 — IndexedDB SWR Cache & Manual Sync Modal**: IndexedDB Stale-While-Revalidate (SWR) cache (`TVIdbCache`, guarding out oversized `*_streams_all` & arrays > 6,000 items) paired with a redesigned conditional **Playlist & EPG Sync** modal (`Aktualisieren` / `Refresh`, scope toggles, persistent `HH:MM` cache/sync timestamps, Cache Clear).
- [x] **B2 — EPG Short-TTL Cache, Dynamic Ticker & Dashboard EPG Timeline**: In-memory Short-EPG cache (4 min TTL) + `AbortController` viewport fetching, timezone-accurate active program matching, live 30s minute-ticker (`noch XX min` / progress bar & auto-rollover in channel list, bottom-right EPG timeline, drawer, OSD & infobar), and search jump `scrollToIndex`.
- [x] **Quickfix — Portal Upload `expDate` Check (`app.js`)**: Ensure newly synced portal Xtream accounts immediately fetch & persist `expDate` instead of falling back to "Unlimited" on first render.
- [x] **Quickfix — Device-Side Connectivity & Auth Validation (`app.js` / `sync.js`)**: On Portal `add` and Portal `edit` (when `serverUrl` or `username`/`password` changed), verify server reachability + login/M3U validity directly on the TV (`authenticate` / `authenticateM3u`, without fetching categories/streams) and surface errors in the pairing UI (manual add/edit already checks).

### Flutter (`lib/`)
- [x] **F1 — SQLite FTS5 Stream Search**: Upgrade `StreamDao.watchStreamsByQuery()` (`lib/core/database/daos/stream_dao.dart:43-53`) from `lower().like('%query%')` full-table scans to SQLite FTS5 full-text search.
- [x] **F2 — Paged Category Queries**: Add SQL `LIMIT`/`OFFSET` paging to `StreamDao.watchStreamsByCategory()` (`lib/core/database/daos/stream_dao.dart:17-22`) for ultra-large categories.
- [x] **F3 — Incremental Delta Upsert Sync**: Replace `replaceStreamsByType()` delete-all + re-insert (`lib/core/database/daos/stream_dao.dart:64-74`) with incremental delta upserts.
- [x] **F4 — Category Sync Cooldown**: Add an in-memory 10-minute cooldown for category-click syncs (`syncLiveStreams` / `VodSyncHelper.syncCategoryStreams`), always bypassing when DB count for that category is 0 or during manual `PlaylistSyncModal` / `force: true` syncs.
- [x] **F5 — Android TV Viewport Short-EPG & Live Minute Ticker (`desktop_live_screen.dart` / `mobile_live_view.dart`)**: Debounced viewport calculation on `desktop_live_screen.dart` to throttled-fetch `ensureShortEpg()` (max 2–3 concurrent) for visible TV channel rows, plus right-aligned `noch XX min` / `XX min left` & 30s live minute-ticker across desktop/TV and mobile (`mobile_live_view.dart`) channel lists.
- [x] **Quickfix — Account Expiration Date Badge (`account_list_screen.dart` / DB)**: Persist & display Xtream `expDate` directly on account cards (parity with Smart TV).
- [x] **Quickfix — Device-Side Connectivity & Auth Validation (`add_account_screen.dart` / `remote_sync_service.dart`)**: Check server reachability + Xtream auth / M3U validity (connection/auth only, no categories/streams) on manual Add, manual Edit (only when URL or username/password changed), Portal `add`, and Portal `edit` (only when URL or username/password changed).

---

## 🔄 Phase 2: Smart TV OTA Full-Parity (Zero Re-Install)
- [x] **Dynamic DOM & Manifest v2 Bootloader (`bootloader.js` / `updater.js` / `generate_tv_manifest.js`)**: Schema v2 auto-discovery manifest (`html`, `styles`, `vendorScripts`, `scripts`, `assets`) with embedded `FACTORY_HASHES` delta-skipping, full `index.html` DOM body swap, ghost-free CSS replacement with relative `url()` rewriting, `new Function()` JS syntax pre-check, post-write read-back verification, post-boot global/DOM invariant checks, and deterministic `DOMContentLoaded`/`load` callback flushing.
- [x] **In-App Assets, Per-File IndexedDB Vault & Dual-Slot A/B Rollback (`goat_tv_ota_v2`)**: Per-file IndexedDB storage (`slot_a` / `slot_b` with compact `localStorage` fallback and automatic v1 `goat_tv_ota_bundle` cleanup), binary SHA-256 verified Data-URI asset resolution (`window.TVAssets`), immediate heap release after write/eval for low-RAM TVs, and automatic rollback to last healthy OTA slot (`markBootHealthy()`) before falling back to factory.
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
