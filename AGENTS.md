# 🤖 AGENTS.md — AI Agent Master Operational Guide

> **Welcome, Agent!** This document is your primary entry point for understanding, navigating, developing, debugging, and packaging the **GOATPlayer** project. Read this thoroughly before making changes.

---

## 📌 Project Overview & Philosophy

**GOATPlayer** is an ultra-fast, premium IPTV client tailored for dual-stack operation:
1. **Flutter Application**: Targets Android Mobile, Android TV / Amazon Fire TV, Windows Desktop, macOS, and Linux. Built with Flutter, Dart, Drift (SQLite), and `media_kit` (`libmpv`).
2. **Smart TV Web Application (`smart_tv/`)**: Targets **Samsung Tizen** (2018+) and **LG webOS** (4.0+). Built with zero-dependency Vanilla JS/CSS for blistering speed on low-power TV chips (ARM Cortex-A53/A7) where heavy web frameworks stutter.
3. **Web Pairing Portal ([goat-player.vercel.app](https://goat-player.vercel.app))**: Zero-typing remote playlist manager using Supabase Realtime for instant QR/PIN pairing with TVs.

### Core Philosophy
- **Speed First**: Sub-second channel zapping, instant focus response (<70ms), 60 FPS scrolling even with 20,000+ streams.
- **Native Aspect Ratio**: Never stretch video by default. Always preserve original aspect ratio (`object-fit: contain`) unless explicitly overridden.
- **Dual-Stack Alignment**: Features and bug fixes in one stack must be mirrored or accounted for in the other where applicable.
- **Fail-Safe Playback**: Multi-tier video playback fallback (Native -> HLS -> TS -> Container extension fallback).

---

## 📂 Repository Structure

```
d:/Projects/iptv-player/
├── lib/                             # Flutter Application (Dart)
│   ├── core/                        # Core system services & shared utilities
│   │   ├── database/                # Drift SQLite database (tables, DAOs, migrations)
│   │   │   ├── daos/                # StreamDao, AccountDao, EpgDao, PlaybackDao
│   │   │   └── app_database.dart    # AppDatabase schema definition
│   │   ├── network/                 # Xtream Codes API client, M3U parser
│   │   ├── player/                  # Video player engine abstraction
│   │   │   ├── engine/              # MediaKitPlayerEngine (libmpv hardware decoding)
│   │   │   ├── widgets/             # Mini-player, mobile gestures, controls
│   │   │   └── player_service.dart  # Playback state, track selection, resume
│   │   └── widgets/                 # TvRemoteScope, TvFocusable, shared UI
│   ├── features/                    # Feature modules
│   │   ├── account/                 # Playlist management, QR/PIN pairing
│   │   ├── dashboard/               # Home dashboard, Continue Watching rail
│   │   ├── live_tv/                 # Live channel grid, EPG drawer, preview player
│   │   ├── vod_movies/              # Movie grid, categories, detail modal
│   │   ├── vod_series/              # Series grid, episode drawer, auto-play
│   │   └── settings/                # Playback settings, track preferences, i18n
│   ├── l10n/                        # Localization files (app_en.arb, app_de.arb)
│   └── main.dart                    # Application entry point & service initialization
│
├── smart_tv/                        # Smart TV Web Application (Samsung Tizen & LG webOS)
│   ├── index.html                   # TV root layout, modals, drawers, HUD
│   ├── config.xml                   # Samsung Tizen W3C widget manifest
│   ├── appinfo.json                 # LG webOS application manifest
│   ├── css/
│   │   └── style.css                # Dark mode TV styling, glowing D-Pad focus indicators
│   └── js/
│       ├── app.js                   # Main TV UI controller, virtual lists, routing
│       ├── player.js                # TV player, aspect ratio, HUD, watchdog, prober
│       ├── spatial_nav.js           # 4-way D-Pad focus traversal & remote key mapper
│       ├── storage.js               # LocalStorage manager with in-memory sandbox fallback
│       ├── api.js                   # Xtream Codes API client & playlist URL builder
│       ├── subtitles.js             # WebVTT/SRT subtitle parser & renderer
│       ├── sync.js                  # Supabase Realtime pairing client for TV
│       ├── diagnostics.js           # Media diagnostics, stream prober, error reporter
│       ├── i18n.js                  # TV internationalization (EN, DE)
│       └── virtual_list.js          # High-performance DOM recycling list
│
├── tool/                            # Automation & Packaging scripts
│   ├── package_smart_tv_tizen.ps1   # Builds signed .wgt for Samsung Tizen
│   ├── package_smart_tv_webos.ps1   # Builds .ipk for LG webOS
│   ├── package_tizen.ps1            # Flutter Web Tizen packager
│   └── package_webos.ps1            # Flutter Web webOS packager
│
├── AGENTS.md                        # Master AI agent instructions
├── ARCHITECTURE.md                  # Dual-stack system architecture
├── DATABASE.md                      # Drift SQLite schema & Smart TV storage docs
└── ROADMAP.md                       # Roadmap, milestones & prioritized backlog
```

---

## 🛠️ Build, Test & Packaging Commands

Always run these commands from the repository root (`d:\Projects\iptv-player`).

### 1. Flutter Testing & Compilation
```powershell
# Run Flutter unit & widget tests
flutter test

# Verify Dart code analysis
flutter analyze

# Build Android APK (Mobile & Fire TV)
flutter build apk --release

# Build Windows Desktop executable
flutter build windows --release
```

### 2. Smart TV Packaging (Samsung Tizen & LG webOS)
```powershell
# Check JavaScript syntax on TV codebase
node -c smart_tv/js/storage.js smart_tv/js/player.js smart_tv/js/app.js smart_tv/js/spatial_nav.js

# Build Signed Samsung Tizen W3C Package (.wgt)
# Output: build/smart_tv_out/com.goatplayer.tv.signed.wgt
powershell -ExecutionPolicy Bypass -File .\tool\package_smart_tv_tizen.ps1

# Build LG webOS Package (.ipk)
# Output: build/smart_tv_out/com.goatplayer.tv_1.2.0_all.ipk
powershell -ExecutionPolicy Bypass -File .\tool\package_smart_tv_webos.ps1
```

### 3. Deploying to Physical Smart TVs

#### Samsung Tizen TV (via SDB CLI)
```powershell
# 1. Connect to TV over local network
& "C:\Users\crequ\.tizen-extension-platform\server\sdktools\data\tools\sdb.exe" connect <TV_IP_ADDRESS>

# 2. Install signed widget
& "C:\Users\crequ\.tizen-extension-platform\server\sdktools\data\tools\sdb.exe" install "D:\Projects\iptv-player\build\smart_tv_out\com.goatplayer.tv.signed.wgt"

# 3. View debug logs (filter by GOATPlayer or TVPlayer)
& "C:\Users\crequ\.tizen-extension-platform\server\sdktools\data\tools\sdb.exe" dlog | Select-String "TVPlayer"
```

#### LG webOS TV (via ares-cli / Dev Manager)
```powershell
# 1. Install via ares-install
ares-install -d <DEVICE_NAME> "D:\Projects\iptv-player\build\smart_tv_out\com.goatplayer.tv_1.2.0_all.ipk"

# 2. Or drag & drop the .ipk into LG webOS Dev Manager UI
```

---

## 🚨 Critical Agent Rules & Gotchas

### 1. The IPTV Duration Quirk (Crucial)
- In Xtream Codes IPTV, stream durations are **NOT** reliably returned as integer seconds.
- Durations can appear as:
  - Human strings in `info.runtime`: `"98 min"`, `"1h 38m"`, `"90 mins"`
  - Timestamps: `"01:38:00"` or `"98:00"`
  - Root fields: `stream.duration_secs`, `stream.duration`, `stream.runtime`
  - Sub-objects: `info.movie_data.duration`, `info.movie_data.runtime`
- **Rule**: ALWAYS use `parseDurationSecs()` and `extractDurationFromInfo()` in `smart_tv/js/storage.js`. Never write custom regex or assume durations are integers.
- On Samsung Tizen TV, HTML5 `<video>.duration` often returns `Infinity`, `NaN`, or `1` during streaming. We rely on metadata and the MP4 container prober (`TVContainerProber.parseMp4` reading the `mvhd` atom).

### 2. Video Aspect Ratio Discipline
- **Rule**: Never use `object-fit: fill` on VOD video elements without user request.
- Video must use `object-fit: contain` to preserve the provider's native resolution and aspect ratio (eliminating stretched picture on Samsung/LG TVs).

### 3. Remote Control Key Mapping (D-Pad & Back Key)
- **webOS Back Key**: `keyCode: 461`
- **Samsung Tizen Back Key**: `keyCode: 10009` (or `Escape`)
- **D-Pad Direction Keys**: `ArrowUp (38)`, `ArrowDown (40)`, `ArrowLeft (37)`, `ArrowRight (39)`, `Enter (13)`.
- **TV Media Keys**: `MediaPlay (415 / 19)`, `MediaPause (19)`, `MediaPlayPause (10252)`, `MediaFastForward (417)`, `MediaRewind (412)`, `MediaStop (413)`.
- **Color Keys**: `ColorF0Red (403)`, `ColorF1Green (404)`, `ColorF2Yellow (405)`, `ColorF3Blue (406)`.
- In `smart_tv/js/spatial_nav.js`, Back key precedence is strictly prioritized:
  1. Close open modal or drawer.
  2. If video player is in fullscreen, minimize or exit fullscreen.
  3. If on Dashboard, show exit confirmation dialog.

### 4. Smart TV Sandboxed LocalStorage
- When running as an installed widget (`file://` protocol), some Tizen TVs disable `window.localStorage` or throw SecurityError.
- `smart_tv/js/storage.js` wraps all storage access with an automatic in-memory fallback store (`_memStore`).
- Always use `window.TVStorage` API methods (`saveProgress`, `getProgress`, `getContinueWatching`, `toggleFavorite`, `isFavorite`). Never call raw `localStorage` directly in TV views.

### 5. Memory & Performance on Low-End TVs
- Smart TVs have limited RAM (often 1GB to 1.5GB total, with web sandbox restricted to ~300MB).
- Never render 10,000 DOM elements at once.
- The Smart TV app uses `VirtualList` (`smart_tv/js/virtual_list.js`) for Live TV channels and pagination/lazy chunking for VOD grids.
- Always clean up image error handlers (`onerror="this.style.display='none';"`) and avoid memory leaks in event listeners.
