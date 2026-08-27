# 🐐 GOATPlayer

<div align="center">

**The Ultimate Modern, High-Performance IPTV & VOD Player**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Android%20%7C%20iOS%20%7C%20SmartTV-blue)](#-roadmap-v2--beyond)
[![Repository](https://img.shields.io/badge/Repo-Private-red)](https://github.com)
[![Release](https://img.shields.io/badge/Release-v1.0.0-purple)](https://github.com)

</div>

---

## 🌟 Overview

**GOATPlayer** is a sleek, modern desktop & cross-platform IPTV application built from the ground up with **Flutter**, **Drift (SQLite)**, and **MediaKit (`libmpv`)**. Designed for speed, smooth playback, and an intuitive user experience, it effortlessly handles massive Xtream Codes / M3U playlists, live channel guides (EPG), movies, and TV series.

---

## ✨ Features (v1.0.0)

### 📺 Live TV & EPG
- **Multi-Account Support**: Add and manage multiple Xtream Codes / M3U playlists with ease.
- **Smart Category Browsing**: Searchable category rail with instant search & clear functions.
- **Interactive EPG Timeline**: Real-time Electronic Program Guide with progress bars, program details, and schedules.
- **Instant Preview & Full-Width Player**: Smooth channel switching and full-width playback.
- **Favorites / Favoriten**: Pin and manage your top live channels.

### 🎬 Movies & Series (VOD)
- **Rich Grid Catalogs**: Responsive poster grids with cover art, genres, ratings, and release years.
- **Watchlist**: Dedicated Watchlist system for both Movies and TV Shows.
- **Continue Watching Rail**: Automatic playback resume tracking with persistent progress indicators.
- **Series Season & Episode Browser**: Clean episode modal breakdown with episode thumbnails, synopsis, and quick launch.
- **Global Master Search**: Search across Live TV, Movies, and TV Shows simultaneously with category filtering.

### ⚡ Player Engine & Controls
- **Powered by `libmpv` (MediaKit)**: Hardware-accelerated decoding for HLS (`.m3u8`), MPEG-TS (`.ts`), MKV, MP4, and exotic IPTV stream formats.
- **Audio & Subtitle Track Selector**: Switch audio language and subtitle tracks on the fly.
- **Fullscreen & Shortcut Controls**:
  - `Space`: Play / Pause
  - `Left` / `Right` Arrow: Seek backward / forward 10s
  - `Esc`: Instant exit fullscreen
  - Custom Volume and Position Indicator controls

### 🌍 Localization & UI
- **English & German Support**: Dynamic in-app language switcher (`English` / `Deutsch`).
- **Dark Modern Aesthetic**: Deep purple / slate dark mode with pixel-perfect borders and polished layout.

---

## 🛠️ Tech Stack & Architecture

- **Framework**: [Flutter](https://flutter.dev)
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

## 🗺️ Roadmap (V2 & Beyond)

- [ ] **Category Management**: Hide/show unwanted categories and drag-and-drop category reordering.
- [ ] **Live TV Quick-Zapping**: In-stream channel switcher (Channel Up/Down) with transparent slide-out EPG drawer.
- [ ] **Custom Folders**: Create personalized groups (e.g. *Sports, News, 4K*) across multiple provider playlists.
- [ ] **Multi-Platform Deployment**:
  - [ ] Android Phone & Tablet
  - [ ] Amazon Fire TV / Android TV (D-Pad Remote Focus Navigation)
  - [ ] Samsung Tizen TV & LG webOS Player Abstraction
  - [ ] macOS & iOS / iPadOS

---

## 🔒 License & Copyright
Copyright (c) 2026. All rights reserved. 
This is a proprietary and confidential private software repository. Unauthorized copying, distribution, or modification of this project via any medium is strictly prohibited.
