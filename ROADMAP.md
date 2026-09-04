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

## ✅ Phase 1: VOD Series Overhaul (Netflix-Style Experience) - Completed
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
