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

### 🌐 Remote Playlist Manager & QR Sync (Web Portal)
- **Zero-Typing Smart TV Setup**: Add, edit, or delete IPTV playlists on your TV directly from your phone, tablet, or PC browser without tedious on-screen keyboard typing.
- **Hosted Live Web Portal**: Free, instant web portal at [goat-player.vercel.app](https://goat-player.vercel.app) with no backend servers (powered by Supabase Realtime).
- **1-Tap QR Code Pairing**: Scan the pairing QR code displayed in the GOATPlayer TV app to automatically connect in under a second.
- **Virtual Device ID & Expiring PIN**: Unique virtual ID (`GP-XXXX-XXXX`) and 20-minute expiring security PIN with live countdown and one-click copy buttons.
- **Full Playlist Manager**: View all playlists currently configured on the TV, add new accounts, edit server URLs/credentials/names, and delete accounts remotely with automatic local database updates.
- **Smart M3U Link Breakdown**: Paste any raw M3U link with credentials (`http://domain.com/get.php?username=...`), and the portal automatically extracts the server host, username, password, and output format.
- **Real-Time TV Disconnection Detection**: Realtime WebSocket channel + 2.5s polling heartbeat detects when the TV finishes pairing (`Fertig` or TV back button), displays an alert banner with a 1-click reconnect button, and guards against stale actions.
- **Responsive Bilingual UI**: English & German (`EN` / `DE`) localization with an optimized mobile interface.

### 📺 Live TV & EPG
- **Multi-Account Support**: Add and manage multiple Xtream Codes / M3U playlists with ease.
- **Smart Category Browsing**: Searchable category rail with instant search & clear functions.
- **Interactive EPG Timeline**: Real-time Electronic Program Guide with progress bars, program details, and schedules.
- **In-Player Slide-Out EPG & Channel Drawer**: Frosted glass sidebar accessible directly inside the player (both Full-Width and Fullscreen modes). Search channels, inspect logos, and view live show progress bars without exiting the stream.
- **Quick In-Stream Zapping (CH- / CH+)**: Channel flipping buttons and keyboard/remote shortcuts (`ArrowUp` / `ArrowDown` or `PageUp` / `PageDown`) with real-time translucent OSD info banner.
- **Split-Screen & Full-Width Player**: Seamless toggle between category/channel list browsing and full-width playback, with automatic scroll-position restoration on return.
- **Illuminated Channel Selection**: Dynamic glowing border and card container highlight for the active channel; zero-stutter channel tuning in Favorites without stream reloading penalties.
- **Favorites / Favoriten**: Pin and manage your top live channels with instant filtering.
- **Dedicated Volume Controls**: Hover volume slider and quick-mute toggle right next to fullscreen controls.

### 🎬 Movies & Series (VOD)
- **In-Player Slide-Out Episode Drawer**: Frosted glass sidebar with season selectors, episode thumbnails, and active glowing indicator. Quickly browse and change episodes on the fly without exiting cinema playback.
- **Dedicated Episode Badge & Clean Headers**: Dynamic season/episode pill badge (`[S01 E03]`) alongside full episode titles with multiline support (up to 3 lines) to prevent title truncation.
- **Automatic Title Sanitation**: Smart `VodTitleCleaner` strips redundant series name prefixes and cleans country code tags (`DE - `, `EN | `) across all VOD titles.
- **Stream Completion Auto-Play**: Automatically buffers and loads the subsequent episode upon finishing, featuring seamless cross-season rollover.
- **Continue Watching Rail with Progression**: Automatically advances cards to the next episode upon $\ge 95\%$ completion, removes completed series finales and movies, and deduplicates shows to display only the single latest or next episode.
- **Smart Deep-Linking & Per-Episode Watch Progress**: Clicking Continue Watching deep-links to the exact episode in the Series Details modal with primary border highlight and auto-scroll. Every episode card features a persistent SQLite progress bar (red for in-progress, green checkmark for completed).
- **Flexible Sorting (Standard / Added, A-Z, Z-A)**: Real-time sorting by server added date (newest added first using Xtream Unix timestamp metadata), alphabetical A-Z, and reverse Z-A.
- **Unified High-Contrast Category Rails**: Sleek category navigation with vibrant left purple accent indicators and dedicated Watchlist icons.
- **Rich Grid Catalogs**: Responsive poster grids with cover art, genres, ratings, and release years.
- **Watchlist**: Dedicated Watchlist system for both Movies and TV Shows.
- **Global Master Search**: Search across Live TV, Movies, and TV Shows simultaneously with category filtering.
- **Seamless Instant Transition**: Non-blocking `pushReplacement` navigation from modals directly into the cinema player with zero stutter or lag.
- **Clean Account Switch Isolation**: Instant teardown of active playback and stream states when switching accounts to ensure 100% playlist isolation.

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
- **Permanent "Next Episode" Button Overlay**: Dedicated on-screen button in the player control bar next to audio and subtitle menus, with instant `N` hotkey support.
- **State-Preserving Drawer & ESC Handling**: Pressing `ESC` closes the episode or channel drawer gracefully without minimizing or interrupting playback. Minimizing to mini-player strictly retains series metadata and drawer access.
- **Intelligent Audio & Subtitle Language Matcher**: Fuzzy language matching supporting multilingual aliases (`German`, `Deutsch`, `Ger`, `Deu` / `English`, `Englisch`, `Eng`), audio codecs, channels (5.1 / 7.1 surround sound prioritization), and forced subtitles.
- **Per-Media Track Memory**: Remembers preferred audio language and subtitle selections per show and per movie across sessions.
- **Netflix-Style Subtitles**: Refined single subtitle rendering with crisp white text, multi-directional drop shadows, transparent background, and tuned bottom spacing above the control bar.
- **Bilingual Playback Settings**: Configurable global preferred audio and subtitle languages (`Icons.tune`) with dynamic English and German UI localization.
- **Prominent Center Play/Pause HUD**: Large 76px center Play/Pause button in VOD matching the Live TV experience.
- **Keyboard Shortcuts**:
  - `Space`: Play / Pause
  - `Left` / `Right` Arrow: Seek backward / forward 10s
  - `N`: Next episode (Series VOD)
  - `Esc`: Close open drawer / Exit fullscreen

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

### ✅ Polish & In-Stream Navigation (Completed)
- [x] **High-Visibility Selection & Active Highlighting**:
  - Distinct, high-contrast visual styling for the currently selected category in the category rail across Live TV, Movies, and Series.
  - Prominent playing indicator for the currently active channel in the channel list (illuminated border, rich card background, bold high-contrast text).
- [x] **Category & Channel Auto-Scroll Sync**:
  - When switching away to another tab (Movies, Series) or toggling full-width mode, restores the active category (including Favorites) and auto-scrolls the channel list directly to the active channel's position.
- [x] **Master Search Direct Jump**:
  - Selecting a live channel from Master Search reliably initiates playback in the preview player and auto-scrolls down to the exact selected channel.
- [x] **Performance & Concurrency Optimization**:
  - SQLite WAL mode, database indexes, 64MB cache, EPG throttling, and atomic category/stream replacements to eliminate freezes and stutter.

### ✅ Remote Playlist Management Web Portal (Completed)
- [x] **Virtual Device ID & Pairing PIN**:
  - Persistent, unique virtual Device ID (`GP-XXXX-XXXX`) and 20-minute expiring 6-digit PIN with live countdown and refresh option.
  - QR Code generation in the TV app (`add_account_screen.dart`) for 1-tap mobile camera pairing.
  - Copy-to-clipboard buttons for Device ID and PIN in the TV UI.
- [x] **Web Management Portal ([goat-player.vercel.app](https://goat-player.vercel.app))**:
  - Fully responsive, dark-mode web application deployed on Vercel with zero backend footprint (direct Supabase Realtime).
  - Bilingual localization (**English** & **German**) with persistent language switcher.
  - Full remote playlist manager: View all active playlists on the device, Add new playlists, Edit existing credentials, and Delete playlists remotely.
  - **Smart M3U Link Breakdown**: Automatically parses raw M3U URLs (extracting server host, username, password, and output format) into structured Xtream accounts.
  - Mobile-optimized responsive layout: top utility navigation, 2-tier device status banner, and structured playlist card metadata.
- [x] **Real-Time Bidirectional Synchronization & Handshake**:
  - Real-time Supabase WebSocket stream (`postgres_changes`) paired with an active 2.5s polling heartbeat fallback.
  - Awaited disconnection handshake on TV: tapping *"Fertig"* (Done) or pressing TV remote "Back" (`PopScope`) immediately transmits disconnection status.
  - Web portal disconnection state awareness: status badge turns amber, display of a prominent warning banner with 1-click reconnect button, and action guards preventing stale mutations.

### ✅ Phase 1: VOD Series Overhaul (Netflix-Style Experience) - Completed
- [x] **In-Player Episode Navigation & Frosted Drawer**:
  - Slide-out episode drawer with season chips, episode thumbnails, and active glowing indicator.
  - Dedicated season/episode pill badge (`[S01 E03]`) + episode title layout in player header to prevent title truncation.
  - Permanent "Next Episode" button overlay and `N` keyboard shortcut.
  - ESC key integration: closes the drawer gracefully without minimizing playback.
  - Mini-player state retention: preserved series metadata and drawer access when minimizing and restoring player.
- [x] **Stream Completion Auto-Play**:
  - Automatically loads and plays subsequent episodes upon completion, including seamless season rollovers.
- [x] **Audio & Subtitle Preferences & Memory**:
  - Fuzzy language matching supporting multi-lingual aliases, audio codecs, channels (5.1/7.1), and forced subtitles.
  - Remembers user's track selections per series and per movie.
  - Fully localized Playback Settings dialog for configuring global preferred languages.
  - Subtitle visibility enabled by default when subtitle track is selected.
- [x] **Continue Watching Deduplication & Card Progression**:
  - Deduplicates series in Continue Watching so only the latest/next episode appears.
  - Cleans country code prefixes (`DE - `, `EN | `) to ensure clean titles and subtitle labels.
  - Automatically advances cards to the next episode upon completion ($\ge 95\%$), and removes finished series finales / movies.
- [x] **Smart Deep-Linking & Per-Episode Watch Progress**:
  - Clicking Continue Watching deep-links to the exact next episode in the Series Details modal with primary border highlight and auto-scroll.
  - Persistent SQLite watch progress bars on every episode card (in-progress red bar, completed green bar + checkmark).

### 📺 Phase 2: Cross-Platform Expansion (Android, Fire TV, LG, Samsung)
- [ ] **Android TV & Amazon Fire TV Enablement**:
  - Full D-Pad focus traversal across main navigation, category rails, channel grids, and player controls.
  - Standard TV remote button bindings (DPad Center = select/play, Back = return, Play/Pause toggle, Channel Up/Down).
  - Android TV launcher banner, leanback intent configuration, and TV leanback manifest.
- [ ] **Samsung Tizen TV**:
  - Tizen Web app package build with hardware media player compatibility.
- [ ] **LG webOS**:
  - webOS Web App package configuration and hardware decoder integration.
- [ ] **Physical Mobile & Tablet Adaptations**:
  - Touch HUD gestures: swipe left/right for seek, left side for brightness, right side for volume.
  - Automatic landscape lock upon entering cinema playback.

### 📋 Phase 3: Category Management
- [ ] **Hide / Show Categories**:
  - Ability to toggle visibility for unwanted categories (e.g., international language packages, adult content).
- [ ] **Manage & Reorder Categories**:
  - Reorder categories or prioritize them according to user preference.
- [ ] **Persistent Category Filter State**:
  - Store hidden and reordered category states in the local SQLite database per account.

### 🚀 Phase 4: Advanced Media & Cloud Sync (Sync, Multi-View, Catch-Up, Offline Downloads, Custom Categories)
- [ ] **Cross-Device Profile & State Sync**:
  - Synchronize "Continue Watching", Watchlist, and Favorites across devices (Desktop ↔ Mobile ↔ Smart TV).
  - Multi-profile support for family households.
- [ ] **Multi-View / Multi-Screen Player**:
  - Split-screen grid to play 2 or 4 Live TV channels simultaneously (customizable layouts for live sports).
- [ ] **Catch-Up TV (Archive)**:
  - Play past broadcasts directly from the EPG guide for supported Xtream providers.
- [ ] **Offline Downloads**:
  - Download VOD movies and episodes locally for offline viewing during flights or travel.
- [ ] **Custom User Categories**:
  - Create personal custom categories and curated playlists mixing channels and VOD from multiple accounts.

---

## 🔒 License & Copyright
Copyright (c) 2026. All rights reserved. 
This is a proprietary and confidential private software repository. Unauthorized copying, distribution, or modification of this project via any medium is strictly prohibited.
