# 🗺️ GOATPlayer Project Roadmap & Prioritized Backlog

This document outlines the development history, architectural milestones, and prioritized execution phases for **GOATPlayer**.

---

## ✅ Completed Milestones (v1.x)

### 1. Dual-Stack Core & Live TV Engine
- [x] **Sub-Second Channel Zapping**: Instant stream switching on native Flutter (`media_kit` / `libmpv`) and Smart TV (`HTML5 Video` / `Hls.js`).
- [x] **In-Stream Live EPG Drawer**: Translucent slide-out channel guide with active channel highlighting and schedule timeline.
- [x] **Channel & Category Auto-Scroll**: Switching categories or tabs keeps active channel focused and in view.
- [x] **SQLite WAL Mode & Multi-threading**: Zero UI stutter during 20,000+ channel playlist synchronization in Drift.

### 2. Premium VOD Experience (Movies & Series)
- [x] **Netflix-Style Series Drawer**: Slide-out episode navigation drawer with season chips and thumbnail previews.
- [x] **Auto-Play Next Episode**: Smooth transition to subsequent episodes upon finishing, including season rollovers.
- [x] **Smart Continue Watching Rail**:
  - Deduplicated series cards advancing to the next episode automatically.
  - Accurate progress bars reflecting percentage watched.
  - Safe removal of completed movies and series finales.
- [x] **Aspect Ratio Normalization**: Enforced native aspect ratio letterboxing (`contain`) across Samsung Tizen, LG webOS, and Flutter players.
- [x] **Comprehensive IPTV Duration Parsing**: Robust handling of irregular IPTV duration formats (`"98 min"`, `"1h 38m"`, `"01:30:00"`) and container `mvhd` header demuxing fallback.

### 3. Remote Web Portal & Cloud Sync
- [x] **Zero-Typing Smart TV Setup**: QR code and 6-digit PIN pairing via [goat-player.vercel.app](https://goat-player.vercel.app).
- [x] **Bidirectional Playlist Management**: Add, edit, test, and remove Xtream and M3U playlists from phone/browser to TV in real time via Supabase Realtime.

### 4. Smart TV Production Release
- [x] **Samsung Tizen Packaging (.wgt)**: Production signed W3C widget builds via `tool/package_smart_tv_tizen.ps1`.
- [x] **LG webOS Packaging (.ipk)**: One-command packaging via `tool/package_smart_tv_webos.ps1`.
- [x] **Remote Red Button (🔴) Controls**: Instant search clearing and Continue Watching card removal with focus preservation on TV D-Pads.

### 5. Universal M3U / M3U8 Playlist Support
- [x] **Dual-Stack M3U Parsers**: High-performance streaming parser for Flutter (`m3u_isolate_parser.dart`) and Smart TV (`m3u.js`).
- [x] **Rich Tag & Metadata Demuxing**: Robust extraction of `#EXTINF`, `tvg-id`, `tvg-name`, `tvg-logo`, `group-title`, and `#EXTM3U` EPG endpoints.
- [x] **Direct Remote Import**: Instant M3U/M3U8 link import and breakdown via web pairing portal with eager TV caching.

### 6. Smart TV In-Stream Audio/Subtitles & Spatial Navigation
- [x] **Multi-Audio Track Switching**: Native audio track switching with provider codec and channel info (`TVContainerProber` / HTML5 AudioTracks).
- [x] **Synced Subtitle Cue Rendering**: On-demand WebVTT/SRT cue fetching, caching, and synchronized screen overlay (`subtitles.js`).
- [x] **Language Matching & Preferences**: Automatic selection of preferred audio and subtitle languages (Deutsch, English, Auto).
- [x] **2D Spatial Navigation**: Natural 3-column 2D grid traversal in Preferences modal and boundary-aware left-exit navigation from VOD grids back to category menus.

---

## 🚀 Milestone v2: Android Ecosystem, Automated Delivery & Category Management

### Phase 1: Android UI, Controls & Form Factors (Mobile, Android TV, Fire TV)
Finish UI fixes and controls across all Android APK targets (phones, tablets, Android TV, and Amazon Fire TV).

- [ ] **VOD Player Controls & Alignment with Windows App**:
  - Bring VOD playback controls on Android in line with the Windows Flutter app (aspect ratio selector, audio track selection, and subtitle track picker).
  - Polished Movies and Series tabs, detail modals, and episode drawer.
- [ ] **Phone Orientation & Layout**:
  - Auto-rotate and lock to landscape mode on phones when entering fullscreen player, restoring portrait upon exit.
  - Clean mobile layout and navigation for phone portrait mode.
- [ ] **Android TV & Fire TV Integration**:
  - Android TV / Fire TV Leanback launcher intent and high-resolution banner asset (`banner.png`).
  - D-Pad focus navigation and TV remote Back button routing verification.

---

### Phase 2: Automated Multi-Platform CI/CD & In-App Update Pipeline
Ensures every commit and release is automatically compiled into ready-to-run packages, and devices notify users when updates are available.

- [ ] **GitHub Actions Automated Build Matrix**:
  - Triggered on git tag / release pushes.
  - **Android**: Compiles universal release APK (`app-release.apk`) and split per-ABI APKs (`arm64-v8a`, `armeabi-v7a`, `x86_64`).
  - **Samsung Tizen**: Runs `tool/package_smart_tv_tizen.ps1` to build signed `com.goatplayer.tv.signed.wgt`.
  - **LG webOS**: Runs `tool/package_smart_tv_webos.ps1` to generate `com.goatplayer.tv_x.x.x_all.ipk`.
  - **Windows Desktop**: Compiles release executable installer / zip package.
- [ ] **In-App Update Checker & Notification**:
  - Lightweight version check against GitHub Releases API (`/releases/latest`) on startup (with 24-hour cache).
  - Clean update modal informing user of a new version with release notes.
  - Direct APK download and Android PackageInstaller prompt on Mobile / Fire TV / Android TV.
  - Direct download links and installation guidance for Smart TV and Desktop users.

---

### Phase 3: Category Management & Reordering (v2 Completion)
Empowers users to declutter massive IPTV playlists (often containing 500+ categories and bouquets).

- [ ] **Category Visibility Management**:
  - Dedicated Category Manager screen in Settings for Live TV, Movies, and Series.
  - Batch toggle visibility (show/hide) for unwanted categories (international bouquets, adult content, etc.).
  - Hidden categories are excluded from tabs, grids, and searches for a cleaner experience and reduced memory usage.
- [ ] **Drag & Drop Category & Channel Reordering**:
  - **Touch & Mouse**: Intuitive drag-and-drop reordering of categories and channels within categories.
  - **TV Remote (D-Pad)**: Dedicated "Move Up" / "Move Down" action mode for TV remotes.
  - Persist custom category sort orders in Drift SQLite (`sort_order` column) and Smart TV `localStorage`.
- [ ] **Parental Control PIN**:
  - 4-digit PIN lock option for hidden or adult categories.
  - PIN prompt before unhiding categories or playing restricted streams.

*(🎉 **Milestone v2 Complete** upon finishing Phase 3)*

---

## 🌟 Milestone v3: Advanced Features, Custom Lists & iOS

### 1. Smart TV & Mobile Deep UI & Performance Tuning
- Virtualized poster grids for VOD Movies and Series on Smart TVs to eliminate DOM thrashing on low-memory (1GB RAM) TVs.
- Smooth hardware-accelerated animations and memory lifecycle management during prolonged streaming sessions.
- Reduced initial cold-start footprint across low-power Smart TVs (Tizen 4.0+, webOS 4.0+) and entry-level Android devices.

### 2. Custom User-Created Lists & Group Drag/Drop
- Create custom named lists beyond standard Favorites (e.g. "Premier League Matchday", "Family Movie Night", "Kids TV").
- Add channels, movies, and series across different provider categories into custom lists.
- Drag-and-drop reordering within custom lists on both mobile touch and TV remote D-Pad.

### 3. Apple iOS / iPhone Build (Flutter for iOS)
- Enable iOS target in Flutter codebase (`ios/` configuration, CocoaPods, runner setup).
- Free iOS deployment support: Xcode project archive, unsigned IPA generation for sideloading (AltStore, Sideloadly, TrollStore), and TestFlight readiness.
- iOS-specific adaptations: iPhone notch / Dynamic Island safe areas, native swipe gestures, PiP (Picture-in-Picture) using AVPlayer/media_kit, and AirPlay casting.

### 4. Selective Feature Toggling in Settings (Performance Profiles)
- Settings toggle to disable **Live TV** or **VOD (Movies/Series)** entirely based on user needs.
- If a user only watches Live TV, Movies & Series syncing and indexing are completely skipped—dramatically speeding up playlist synchronization and reducing database storage.
- If a user only watches Movies & Series, Live TV channels and EPG background parsers are deactivated.

### 5. Advanced Media Features: Offline Downloads, Multi-View & Catch-Up TV
- **Offline VOD Downloads (Mobile & Desktop)**:
  - Background downloader for VOD movies and series episodes with pause/resume support.
  - Local playback engine with resume tracking for offline travel and flights.
- **Multi-View / Multi-Screen Live Player**:
  - 2-screen, 3-screen, and 4-screen grid player for watching multiple live sporting events simultaneously.
  - Instant audio focus toggle between active screens via tap or D-Pad.
- **Catch-Up TV (Archive)**:
  - Integration with Xtream Codes catch-up API for channels with `tv_archive: 1`.
  - Past broadcast timeline guide with time-shifted playback and seekable scrubber.
