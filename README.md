# 🐐 GOATPlayer

<div align="center">

**The Ultimate Modern, High-Performance IPTV & VOD Player**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Android%20%7C%20iOS%20%7C%20SmartTV-blue)](#-roadmap-v2--beyond)
[![Repository](https://img.shields.io/badge/Repo-Private-red)](https://github.com)
[![Release](https://img.shields.io/badge/Release-v1.1.0-purple)](https://github.com)

</div>

---

## 🌟 Overview

**GOATPlayer** is a sleek, modern desktop & cross-platform IPTV application built from the ground up with **Flutter**, **Drift (SQLite)**, and **MediaKit (`libmpv`)**. Designed for speed, smooth playback, and an intuitive user experience, it effortlessly handles massive Xtream Codes / M3U playlists, live channel guides (EPG), movies, and TV series.

---

## ✨ Current Features

### 📺 Live TV & EPG
- **Multi-Account Support**: Add and manage multiple Xtream Codes / M3U playlists with ease.
- **Smart Category Browsing**: Searchable category rail with instant search & clear functions.
- **Interactive EPG Timeline**: Real-time Electronic Program Guide with progress bars, program details, and schedules.
- **In-Player Slide-Out EPG & Channel Drawer**: Frosted glass sidebar accessible directly inside the player (both Full-Width and Fullscreen modes). Search channels, inspect logos, and view live show progress bars without exiting the stream.
- **Quick In-Stream Zapping (CH- / CH+)**: Channel flipping buttons and keyboard/remote shortcuts (`ArrowUp` / `ArrowDown` or `PageUp` / `PageDown`) with real-time translucent OSD info banner.
- **Split-Screen & Full-Width Player**: Seamless toggle between category/channel list browsing and full-width playback.
- **Favorites / Favoriten**: Pin and manage your top live channels with instant filtering.
- **Dedicated Volume Controls**: Hover volume slider and quick-mute toggle right next to fullscreen controls.

### 🎬 Movies & Series (VOD)
- **Rich Grid Catalogs**: Responsive poster grids with cover art, genres, ratings, and release years.
- **Watchlist**: Dedicated Watchlist system for both Movies and TV Shows.
- **Continue Watching Rail**: Automatic playback resume tracking with persistent progress indicators.
- **Series Season & Episode Browser**: Clean episode modal breakdown with episode thumbnails, synopsis, and quick launch.
- **Global Master Search**: Search across Live TV, Movies, and TV Shows simultaneously with category filtering.
- **Seamless Instant Transition**: Non-blocking `pushReplacement` navigation from modals directly into the cinema player with zero stutter or lag.

### 🪟 Picture-in-Picture (Floating Mini-Player)
- **Universal Multi-Tasking**: Seamlessly browse movies, series, or settings while Live TV or VOD streams keep playing in the corner.
- **Smooth Drag & Reposition**: Click-and-drag the floating player anywhere across your screen.
- **Native OS Border Resizing**: Interactive diagonal resize grip zones with system cursor (`resizeUpLeft`) and double-tap cycle presets (Small, Medium, Large).
- **Rich Mini-Player Controls**:
  - **Center Play/Pause Button**: Instant playback control.
  - **Interactive Seek Scrubber (VOD)**: Drag or tap along the seek bar to jump directly to any timestamp.
  - **Live Runtime Display**: Formatted timestamp indicator (`00:15:30 / 01:42:00`).
  - **Expandable Volume Slider**: Smoothly slides out on hover with tap-to-mute and mouse-wheel support for both Live TV and VOD.
  - **One-Click Fullscreen Restore**: Instantly return to the full-size player with smooth state preservation.
- **Mobile Mini-Bar**: Bottom dock mini-player for mobile devices with quick play/pause and close controls.

### ⚡ Player Engine & Cinema Experience
- **Powered by `libmpv` (MediaKit)**: Hardware-accelerated decoding for HLS (`.m3u8`), MPEG-TS (`.ts`), MKV, MP4, and exotic IPTV stream formats.
- **Zero-Ghost-Frame Architecture**: Multi-buffered Direct3D protection eliminates the split-second flash of previous streams on channel or movie switches.
- **Frame-Perfect Audio/Video Synchronization**: Silent buffering pipeline guarantees audio and video reveal in 100% lockstep synchrony.
- **State-Preserving Minimization**: Pausing or playing before minimizing strictly retains its state in the mini-player without accidental play/pause toggles.
- **Prominent Center Play/Pause HUD**: Large 76px center Play/Pause button in VOD matching the Live TV experience.
- **Audio & Subtitle Track Selector**: Switch audio language and subtitle tracks on the fly.
- **Keyboard Shortcuts**:
  - `Space`: Play / Pause
  - `Left` / `Right` Arrow: Seek backward / forward 10s
  - `Esc`: Instant exit fullscreen

### 🌍 Localization & UI
- **English & German Support**: Dynamic in-app language switcher (`English` / `Deutsch`) with complete translations for player controls and mini-player.
- **Dark Modern Aesthetic**: Deep purple / slate dark mode with pixel-perfect borders and polished layout.

---

## 🛠️ Tech Stack & Architecture

- **Framework**: [Flutter](https://flutter.dev) (3.24+)
- **State Management**: [Riverpod 2.x](https://riverpod.dev)
- **Local Database & Cache**: [Drift (SQLite)](https://drift.simonbinder.eu/) + Isolate Parsing
- **Media Engine**: [MediaKit](https://github.com/media-kit/media-kit) (`libmpv` native backend)
- **HTTP & Networking**: [Dio](https://pub.dev/packages/dio) with retry & timeout policies
- **Localization**: Flutter `intl` (`.arb` based)
- **Window Management**: `window_manager` for desktop sizing, maximization, and multi-display handling

---

## 🚀 Getting Started & Building

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.24+ recommended)
- [Visual Studio 2022](https://visualstudio.microsoft.com/) with **"Desktop development with C++"** workload (for Windows builds)

### 1. Clone the repository
```bash
git clone https://github.com/YOUR_USERNAME/goat-player.git
cd goat-player
```

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Generate Database & Localization Code (if needed)
```bash
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
```

### 4. Run in Development
```bash
flutter run -d windows
```

### 5. Build Release Executable (Windows)
```bash
flutter build windows
```
The compiled output will be located in:
`build\windows\x64\runner\Release\`

---

## 🗺️ Roadmap & Planned Features

### ⚡ Priority 1: In-Player EPG List & Quick-Zapping (Completed)
- [x] **In-Player Slide-Out EPG & Channel List Drawer**:
  - Transparent frosted sidebar overlay accessible directly inside the Live TV player (both Full-Width and Fullscreen).
  - Search channels, view logos, and inspect real-time EPG program schedules with live progress bars without leaving the stream.
  - 1-click instant channel tuning directly from the drawer.
- [x] **Quick In-Stream Zapping**:
  - In-player Channel Up (`CH +`) / Channel Down (`CH -`) buttons.
  - Keyboard & Remote shortcuts (`PageUp` / `PageDown` or `ArrowUp` / `ArrowDown`) to flip channels instantly.
  - Sleek translucent On-Screen Display (OSD) banner showing channel logo, name, number, and current live show info on each zap.

### 📋 Phase 1: Smart TV & Remote Experience
- [ ] **Android TV & Amazon Fire TV Remote (D-Pad) Navigation**:
  - D-Pad focus traversal on category lists, channel guides, and VOD cards.
  - Remote channel flipping (Channel Up / Down) with instant in-stream zapping.
  - Transparent slide-out quick-channel drawer while video plays in the background.
- [ ] **Physical Android Phone & Tablet Optimization**:
  - Touch HUD gestures: swipe left/right for seek, swipe left side for brightness, swipe right side for volume.
  - Automatic landscape lock upon entering cinema mode.
  - Adaptive touch controls for mobile screens.

### 🌐 Phase 2: Remote Playlist Management & Cloud Sync
- [ ] **Web-Based Playlist Portal via MAC Address**:
  - Assign a unique device MAC address / Virtual ID to each GOATPlayer installation.
  - Web management portal where users can upload and manage Xtream / M3U playlists remotely from any browser.
  - Instant automatic sync to the client device without manual typing on TV remotes.
- [ ] **Cloud Profile & Watch Progress Sync**:
  - Synchronize "Continue Watching", Watchlist, and Favorites across devices (Desktop $\leftrightarrow$ Mobile $\leftrightarrow$ TV).

### 🎛️ Phase 3: Advanced Media & Organization
- [ ] **Category Management**:
  - Hide/show unwanted categories (e.g. international packages, adult content).
  - Drag-and-drop category reordering with custom folder organization.
- [ ] **Multi-Screen / Multi-View**:
  - Watch 2 or 4 Live TV channels simultaneously in a customizable grid (ideal for live sports).
- [ ] **Catch-Up TV (Archive)**:
  - Play past broadcasts directly from the EPG timeline for supported Xtream providers.
- [ ] **Offline Downloads (Mobile & Desktop)**:
  - Download VOD movies and episodes for offline viewing on flights or travel.

### 📺 Phase 4: Smart TV Platform Expansion
- [ ] **Samsung Tizen TV App** (Tizen Web / WebAssembly player engine).
- [ ] **LG webOS App** (webOS Web App with hardware decoders).
- [ ] **Apple TV & iOS** (TestFlight & App Store release).

---

## 🔒 License & Copyright
Copyright (c) 2026. All rights reserved. 
This is a proprietary and confidential private software repository. Unauthorized copying, distribution, or modification of this project via any medium is strictly prohibited.
