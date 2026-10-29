# 🤖 AGENTS.md — AI Agent Master Operational Guide

> **Welcome, Agent!** This document is your primary entry point for understanding, navigating, developing, debugging, and packaging the **GOATPlayer** project. Read this thoroughly before making changes.

---

## 📌 Project Overview & Philosophy

**GOATPlayer** is an ultra-fast, premium IPTV client tailored for cross-platform operation:
1. **Flutter Application (`lib/`)**: Targets **Android Mobile / Tablets** (`arm64-v8a`), **Android TV / Amazon Fire TV** (`armeabi-v7a`), **Windows Desktop**, **macOS**, and **Linux**. Built with Flutter, Dart, Drift (SQLite WAL), and `media_kit` (`libmpv`).
2. **Smart TV Web Application (`smart_tv/`)**: Targets **Samsung Tizen (2018+)** and **LG webOS (4.0+)**. Built with zero-dependency Vanilla JS/CSS for blistering speed on low-power TV chips (ARM Cortex-A53/A7) where heavy web frameworks stutter.
3. **Web Pairing Portal (`portal/` & [goat-player.vercel.app](https://goat-player.vercel.app))**: Zero-typing remote playlist manager using Supabase Realtime with client-side **Zero-Knowledge AES-GCM encryption** for instant QR/PIN pairing with TVs.

### Core Philosophy
- **Speed First**: Sub-second channel zapping, instant focus response (<70ms), 60 FPS scrolling even with 20,000+ streams.
- **Native Aspect Ratio**: Never stretch video by default. Always preserve original aspect ratio (`object-fit: contain` / `BoxFit.contain`) unless explicitly overridden.
- **Dual-Stack Alignment**: Features and bug fixes in one stack must be mirrored or accounted for in the other where applicable.
- **Zero-Knowledge Security**: TV credentials and server URLs must never be stored in plaintext on third-party cloud brokers.

---

## 📂 Repository Structure

```
d:/Projects/iptv-player/
├── lib/                             # Flutter Application (Dart)
│   ├── core/                        # Core system services & shared utilities
│   │   ├── database/                # Drift SQLite database (tables, DAOs, migrations)
│   │   │   ├── daos/                # StreamDao, AccountDao, EpgDao, PlaybackProgressDao
│   │   │   └── app_database.dart    # AppDatabase schema definition
│   │   ├── network/                 # Xtream Codes API client
│   │   ├── player/                  # Video player engine abstraction
│   │   │   ├── engine/              # MediaKitPlayerEngine (libmpv hardware decoding)
│   │   │   ├── widgets/             # Mini-player, mobile gestures, controls
│   │   │   └── player_service.dart  # Playback state, track selection, resume
│   │   ├── remote_sync/             # Supabase Realtime pairing client with AES-GCM
│   │   ├── utils/                   # M3U isolate parser, title cleaner, string utils
│   │   ├── updater/                 # AppUpdaterService, multi-platform updater dialog
│   │   └── widgets/                 # TvRemoteScope, TvFocusable, tv_text_field
│   ├── features/                    # Feature modules
│   │   ├── account/                 # Playlist management, QR/PIN pairing
│   │   ├── dashboard/               # Home dashboard, Continue Watching rail
│   │   ├── live_tv/                 # Live channel grid, EPG drawer, preview player
│   │   │   └── widgets/             # tv_smart_iptv_overlays.dart, custom_live_controls
│   │   ├── vod_movies/              # Movie grid, categories, detail modal, player
│   │   ├── vod_series/              # Series grid, episode drawer, auto-play, modal
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
│       ├── m3u.js                   # Client-side M3U/M3U8 playlist parser
│       ├── subtitles.js             # WebVTT/SRT subtitle parser & renderer
│       ├── sync.js                  # Supabase Realtime pairing client with Web Crypto AES-GCM
│       ├── diagnostics.js           # Media diagnostics, stream prober, error reporter
│       ├── i18n.js                  # TV internationalization (EN, DE)
│       └── virtual_list.js          # High-performance DOM recycling list
│
├── portal/                          # Web Pairing Portal (https://goat-player.vercel.app)
│   └── index.html                   # Zero-Knowledge remote playlist management portal
│
├── tool/                            # Packaging & Automation scripts
│   ├── package_smart_tv_tizen.ps1   # Builds signed .wgt for Samsung Tizen
│   └── package_smart_tv_webos.ps1   # Builds .ipk for LG webOS
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
rtk flutter test

# Verify Dart code analysis
rtk flutter analyze

# Build Android APK for Phone / Modern TV (arm64-v8a)
rtk flutter build apk --release --target-platform android-arm64 --split-per-abi

# Build Android APK for Amazon Fire TV / Older Stick (armeabi-v7a)
rtk flutter build apk --release --target-platform android-arm --split-per-abi

# Build Windows Desktop executable
rtk flutter build windows --release
```

### 2. Smart TV Packaging (Samsung Tizen & LG webOS)
```powershell
# Check JavaScript syntax on TV codebase
rtk node -c smart_tv/js/storage.js smart_tv/js/player.js smart_tv/js/app.js smart_tv/js/spatial_nav.js

# Build Signed Samsung Tizen W3C Package (.wgt)
# Output: build/smart_tv_out/com.goatplayer.tv.signed.wgt
powershell -ExecutionPolicy Bypass -File .\tool\package_smart_tv_tizen.ps1

# Build LG webOS Package (.ipk)
# Output: build/smart_tv_out/com.goatplayer.tv_2.0.0_all.ipk
powershell -ExecutionPolicy Bypass -File .\tool\package_smart_tv_webos.ps1
```

### 3. Deploying to Physical Smart TVs

#### Samsung Tizen TV (via SDB CLI)
```powershell
# 1. Connect to TV over local network
& "C:\Users\crequ\.tizen-extension-platform\server\sdktools\data\tools\sdb.exe" connect <TV_IP_ADDRESS>

# 2. Install signed widget
& "C:\Users\crequ\.tizen-extension-platform\server\sdktools\data\tools\sdb.exe" install "D:\Projects\iptv-player\build\smart_tv_out\com.goatplayer.tv.signed.wgt"
```

#### LG webOS TV (via ares-cli / Dev Manager)
```powershell
# 1. Install via ares-install
ares-install -d <DEVICE_NAME> "D:\Projects\iptv-player\build\smart_tv_out\com.goatplayer.tv_2.0.0_all.ipk"
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
- On Samsung Tizen TV, HTML5 `<video>.duration` often returns `Infinity`, `NaN`, or `1` during streaming. Rely on metadata and the MP4 container prober (`TVContainerProber.parseMp4` reading the `mvhd` atom).

### 2. Video Aspect Ratio Discipline
- **Rule**: Never use `object-fit: fill` on VOD video elements without user request.
- Video must use `object-fit: contain` / `BoxFit.contain` to preserve the provider's native resolution and aspect ratio (eliminating stretched picture on TVs).

### 3. Remote Control Key Mapping (D-Pad & Back Key)
- **webOS Back Key**: `keyCode: 461`
- **Samsung Tizen Back Key**: `keyCode: 10009` (or `Escape`)
- **D-Pad Direction Keys**: `ArrowUp (38)`, `ArrowDown (40)`, `ArrowLeft (37)`, `ArrowRight (39)`, `Enter (13)`.
- **TV Media Keys**: `MediaPlay (415 / 19)`, `MediaPause (19)`, `MediaPlayPause (10252)`, `MediaFastForward (417)`, `MediaRewind (412)`, `MediaStop (413)`.
- **Color Keys**: `ColorF0Red (403)`, `ColorF1Green (404)`, `ColorF2Yellow (405)`, `ColorF3Blue (406)`.
- In `smart_tv/js/spatial_nav.js` and `lib/core/widgets/tv_remote_scope.dart`, Back-key precedence is strictly prioritized:
  1. Close open modal, drawer, or search overlay.
  2. If video player is in fullscreen, minimize or exit playback.
  3. If on Dashboard, show exit confirmation dialog.

### 4. Amazon Fire OS Sideload Display vs Projectivy Launcher
- On Amazon Fire TV, Fire OS places all sideloaded apps into a fixed gray 16:9 card containing a centered **1:1 square icon slot** (`fitXY`).
- Projectivy Launcher, however, is a standard Android Leanback launcher displaying full **16:9 cards** using `@drawable/banner_3d`.
- To look optimal in both:
  - Use seamless 16:9 banners in `@drawable/banner_3d` for Projectivy.
  - Use rounded 1:1 square icons in `res/mipmap-television-*` for Fire OS icon queries.
  - Never place a 16:9 bitmap directly into `ic_launcher`, as Fire OS will squish it horizontally into the 1:1 slot.

### 5. Smart TV Sandboxed LocalStorage
- When running as an installed widget (`file://` protocol), some Tizen TVs disable `window.localStorage` or throw `SecurityError`.
- `smart_tv/js/storage.js` wraps all storage access with an automatic in-memory fallback store (`_memStore`).
- Always use `window.TVStorage` API methods (`saveProgress`, `getProgress`, `getContinueWatching`, `toggleFavorite`, `isFavorite`). Never call raw `localStorage` directly in TV views.
