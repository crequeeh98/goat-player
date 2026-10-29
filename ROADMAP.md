# 🗺️ GOATPlayer Project Roadmap & Prioritized Backlog

This document outlines the development history, architectural milestones, and prioritized execution phases for **GOATPlayer**.

---

## 🏆 Current Release: v2.0.0 (Unified Cross-Platform IPTV & Smart TV)

All core goals of Milestone v1 and Milestone v2 are **100% completed, tested, and verified** across Windows Desktop, Android Phone, Android TV, Amazon Fire TV, LG webOS, and Samsung Tizen.

---

## ✅ Completed Milestones

### 1. Dual-Stack Core & Live TV Engine (v1.0 - v1.2)
- [x] **Sub-Second Channel Zapping**: Instant stream switching on native Flutter (`media_kit` / `libmpv`) and Smart TV (`HTML5 Video` / `Hls.js`).
- [x] **In-Stream Live EPG Drawer**: Translucent slide-out channel guide with active channel highlighting and schedule timeline.
- [x] **Channel & Category Auto-Scroll**: Switching categories or tabs keeps active channel focused and in view.
- [x] **SQLite WAL Mode & Multi-threading**: Zero UI stutter during 20,000+ channel playlist synchronization in Drift.
- [x] **Dual-Stack M3U Parsers**: High-performance streaming parser for Flutter (`m3u_isolate_parser.dart`) and Smart TV (`m3u.js`).
- [x] **Universal Tag Extraction**: `#EXTINF`, `tvg-id`, `tvg-name`, `tvg-logo`, `group-title`, and `#EXTM3U` EPG endpoints.

### 2. Premium Cinema VOD Experience (Movies & Series)
- [x] **Netflix-Style Series Drawer**: Slide-out episode navigation drawer with season chips and thumbnail previews.
- [x] **Auto-Play Next Episode**: Smooth transition to subsequent episodes upon finishing, including cross-season rollovers.
- [x] **Smart Continue Watching Rail**:
  - Deduplicated series cards advancing to the next episode automatically.
  - Accurate progress bars reflecting percentage watched.
  - Safe removal of completed movies and series finales ($\ge 95\%$ watched).
- [x] **Native Aspect Ratio Preservation**: Enforced native aspect ratio letterboxing (`contain`) across Samsung Tizen, LG webOS, and Flutter players (eliminating stretched video).
- [x] **Comprehensive IPTV Duration Parsing**: Robust handling of irregular IPTV duration formats (`"98 min"`, `"1h 38m"`, `"01:30:00"`) and container `mvhd` header demuxing fallback.

### 3. Remote Web Pairing Portal & Zero-Knowledge Cloud Sync
- [x] **Zero-Typing Smart TV Setup**: QR code and 6-digit PIN pairing via [goat-player.vercel.app](https://goat-player.vercel.app).
- [x] **Zero-Knowledge Client-Side Encryption**: AES-GCM 256-bit payload encryption where credentials and playlist URLs are encrypted on the browser and decrypted exclusively on the TV via paired PIN keys (Supabase server never sees raw credentials).
- [x] **Bidirectional Playlist Management**: Add, edit, test, and remove Xtream and M3U playlists from phone/browser to TV in real time via Supabase Realtime.
- [x] **Duplicate Prevention & Optimistic UX**: Realtime acknowledgment queue preventing double-card creation or orphaned records.
- [x] **Smart M3U Breakdown**: Auto-parsing of raw provider URLs into server, username, password, and output format.
- [x] **Live Disconnection Guard**: Heartbeat monitoring detecting when the user leaves pairing mode on the TV.

### 4. Smart TV Web Application (Samsung Tizen & LG webOS)
- [x] **Zero-Framework Vanilla JS Engine**: Sub-70ms focus response and 60 FPS scrolling on low-power TV chips (ARM Cortex-A53).
- [x] **Samsung Tizen Packaging (.wgt)**: Production signed W3C widget builds via `tool/package_smart_tv_tizen.ps1`.
- [x] **LG webOS Packaging (.ipk)**: Clean one-command packaging via `tool/package_smart_tv_webos.ps1`.
- [x] **LG webOS Dock Tile Integration**: Seamless 16:9 full-bleed banner (`dockIcon.png` `408x230`), rounded 1:1 `largeIcon.png` (`130x130`), and `icon.png` (`80x80`).
- [x] **Remote Red Button (🔴) Controls**: Instant search clearing and Continue Watching card removal with focus preservation on TV D-Pads.
- [x] **Multi-Audio Track Switching**: Native audio track switching with provider codec and channel info (`TVContainerProber` / HTML5 AudioTracks).
- [x] **Synced Subtitle Cue Rendering**: On-demand WebVTT/SRT cue fetching, caching, and synchronized screen overlay (`subtitles.js`).
- [x] **Language Matching & Preferences**: Automatic selection of preferred audio and subtitle languages (Deutsch, English, Auto).
- [x] **2D Spatial Navigation**: Natural 3-column 2D grid traversal in Preferences modal and boundary-aware left-exit navigation from VOD grids back to category menus.

### 5. Flutter Android Ecosystem & TV Mode (v2.0)
- [x] **Smart IPTV Dual-Drawer Overlays**: Dedicated Leanback overlay architecture (`tv_smart_iptv_overlays.dart`) featuring:
  - Slide-out Group/Category Drawer on `ArrowLeft` / `Enter`.
  - Channel list with live show name, time, and progress bar.
  - Zapping OSD Infobar with resolution badge, audio codec, and next program preview.
- [x] **Leanback Spatial Navigation (`TvFocusable` & `TvRemoteScope`)**:
  - Boundary-aware D-Pad traversal with custom glowing indicators.
  - Remote Back-key routing prioritizing Modals -> Drawers -> Player Exit -> Dashboard.
  - On-screen TV keyboard support with dedicated focus navigation (`tv_text_field.dart`).
- [x] **Mobile Phone & Tablet Mode**:
  - Touch-optimized live TV screen with collapsible drawer (`mobile_live_view.dart`).
  - Vertical swipe gestures for screen brightness (left side) and volume (right side) (`mobile_gesture_detector.dart`).
  - Double-tap seek gestures and floating mini-player.
  - High-resolution borderless 3D app icon (`res/mipmap-mdpi` through `mipmap-xxxhdpi`).
- [x] **Amazon Fire TV & Projectivy Launcher Branding**:
  - Seamless 16:9 3D banner (`@drawable/banner_3d` in `320x180` to `1280x720`) perfectly fitting Projectivy Launcher and Android TV Leanback slots.
  - Television-specific rounded 1:1 3D mipmaps (`res/mipmap-television-*`) fitting Amazon Fire OS standard sideload cards without horizontal squishing.
  - Clean borderless 3D splash logo (`drawable/splash_logo.png`).

---

## 🌟 Milestone v3: Cloud Ecosystem, Advanced Playback & iOS (Upcoming)

### Phase 1: Cloud & Playlist Enhancements
- [ ] **Custom Cloud Playlist Sync**: Synchronize user-created "Favorites" and category visibility across devices via Supabase.
- [ ] **EPG XMLTV Fallback Source**: Allow users to specify secondary external XMLTV EPG URLs for channels missing provider EPG data.
- [ ] **Catch-Up / Archive Playback**: Support Xtream Codes catch-up streams with timeline-scrubbing EPG history.

### Phase 2: Player & Video Architecture
- [ ] **Picture-in-Picture (PiP)**: Android Native PiP and Windows Floating Overlay for multitasking during Live TV.
- [ ] **Dynamic Subtitle Offset / Delay Slider**: Real-time microsecond subtitle synchronization adjustment in the playback settings dialog.
- [ ] **Auto Frame-Rate (AFR) Matching**: Switch TV display refresh rate (24Hz, 50Hz, 60Hz) to match stream FPS on Android TV and Fire TV devices.

### Phase 3: Apple Ecosystem & Packaging
- [ ] **iOS & iPadOS Native Target**: Native iOS build with hardware acceleration via AVPlayer/VLCKit backend.
- [ ] **Apple TV (tvOS) Evaluation**: Porting Flutter/Swift UI to tvOS with Siri Remote navigation.
