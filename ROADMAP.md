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

## ✅ Remote Playlist Management Web Portal (Completed)

### 🌐 Zero-Typing Smart TV Setup & Cloud Sync
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

---

## 🎬 Phase 1: VOD Series Overhaul (Netflix-Style Experience)
- [ ] **In-Player Episode Navigation**:
  - "Next Episode" button overlay upon episode completion / credits countdown.
  - In-player slide-out Episode Drawer to quickly switch episodes without leaving active playback.
- [ ] **Audio & Subtitle Track Memory**:
  - Remember user's preferred audio language and subtitle settings across episodes and movies.
  - Automatically restore last-used audio/subtitle tracks when continuing watching.
- [ ] **Continue Watching Deduplication**:
  - Prevent multiple episode cards of the same show from cluttering Continue Watching.
  - Only show the single latest in-progress or next up episode for each series.
- [ ] **Smart Season & Episode Modal Deep-Linking**:
  - When opening a show from Continue Watching, automatically select and expand the relevant season and episode instead of resetting to Season 1 / Episode 1.
- [ ] **Per-Episode Watch Progress Indicators**:
  - Visual progress bar on every individual episode card in the Series Details modal, matching Continue Watching.

---

## 📺 Phase 2: Cross-Platform Expansion (Android, Fire TV, LG, Samsung)
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

---

## 📋 Phase 3: Category Management
- [ ] **Hide / Show Categories**:
  - Ability to toggle visibility for unwanted categories (e.g., international language packages, adult content).
- [ ] **Manage & Reorder Categories**:
  - Reorder categories or prioritize them according to user preference.
- [ ] **Persistent Category Filter State**:
  - Store hidden and reordered category states in the local SQLite database per account.

---

## 🚀 Phase 4: Advanced Media & Cloud Sync (Sync, Multi-View, Catch-Up, Offline Downloads, Custom Categories)
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
