# 🗺️ GOATPlayer Project Roadmap

This document outlines the planned development phases, feature requirements, and architectural milestones for **GOATPlayer**.

---

## ✅ Polish & In-Stream Navigation (Completed)

### 🎯 Live TV Active Indicator & Auto-Scroll Tracking
- [x] **High-Visibility Selection & Active Highlighting**:
  - Distinct, high-contrast visual styling for the currently selected category in the category rail across Live TV, Movies, and Series.
  - Prominent playing indicator for the currently active channel in the channel list (illuminated border, rich card background, bold high-contrast text).
- [x] **Category & Channel Auto-Scroll Sync**:
  - When switching away to another tab (Movies, Series) or toggling full-width mode, restores the active category (including Favorites) and auto-scrolls the channel list directly to the active channel's position.
- [x] **Master Search Direct Jump**:
  - Selecting a live channel from Master Search reliably initiates playback in the preview player and auto-scrolls down to the exact selected channel.
- [x] **Performance & Concurrency Optimization**:
  - SQLite WAL mode, database indexes, 64MB cache, EPG throttling, and atomic category/stream replacements to eliminate freezes and stutter.

---

## 📋 Phase 1: Category Management
- [ ] **Hide / Show Categories**:
  - Ability to hide unwanted categories (e.g., international language packages, adult content).
- [ ] **Manage & Reorder Categories**:
  - Reorder categories or group them according to user preference.
- [ ] **Persistent Category Filter State**:
  - Store hidden categories in the local database per account.

---

## 🎬 Phase 2: Complete VOD Series Overhaul (Netflix-Style Experience)
- [ ] **In-Player Episode Navigation**:
  - "Next Episode" button overlay upon episode completion / credits.
  - In-player slide-out Episode Drawer to switch episodes without leaving playback.
- [ ] **Audio & Subtitle Track Memory**:
  - Remember the user's preferred audio language and subtitle settings across episodes and movies.
  - Restore last-used audio/subtitle tracks when continuing watching.
- [ ] **Continue Watching Deduplication**:
  - Prevent multiple episode cards of the same show from cluttering Continue Watching.
  - Only show the latest in-progress or next episode for each series.
- [ ] **Smart Season & Episode Modal Deep-Linking**:
  - When opening a show from Continue Watching, automatically select and expand the relevant season and episode instead of resetting to Season 1 / Episode 1.
- [ ] **Per-Episode Watch Progress Indicators**:
  - Visual progress bar on every individual episode card in the Series Details modal, not just in Continue Watching.

---

## 🌐 Phase 3: Remote Playlist Management (Web Portal)
- [ ] **Virtual Device ID / MAC Address Generation**:
  - Display a unique virtual hardware/device ID in settings for easy identification.
- [ ] **Web Management Portal**:
  - Lightweight web portal where users can input their Device ID from a smartphone or computer browser.
  - Remotely add, update, and manage Xtream Codes or M3U playlists without typing on a TV remote or virtual keyboard.
- [ ] **Instant Cloud Sync**:
  - Push updated playlist configurations from the web portal directly to the client application.

---

## 📺 Phase 4: TV & Cross-Platform Expansion
- [ ] **Android TV & Amazon Fire TV Remote Navigation**:
  - Full D-Pad focus engine with directional navigation rings and remote-friendly focus states across all screens.
  - Physical remote shortcuts for channel zapping, guide toggling, and menu access.
- [ ] **Smart TV Ecosystems**:
  - **Samsung Tizen TV**: Dedicated web/WASM packaging.
  - **LG webOS**: webOS app package with hardware-accelerated playback.
- [ ] **Mobile & Tablet Releases**:
  - Android APK optimization and iOS / Apple TV packaging.

---

## 🚀 Phase 5: Advanced Media & Power Features (Deferred)
- [ ] **Multi-View / Multi-Screen Player**:
  - Split-screen grid to play 2 or 4 Live TV channels simultaneously (customizable layouts for live sports).
- [ ] **Catch-Up TV (Archive)**:
  - Play past broadcasts directly from the EPG guide for supported Xtream providers.
- [ ] **Offline Downloads**:
  - Download VOD movies and episodes locally for offline viewing.
- [ ] **Custom User Categories**:
  - Create custom user playlists and grouped channels.
