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

## 🌐 Phase 1: Remote Playlist Management (Web Portal)
- [ ] **Virtual Device ID / MAC Address Generation**:
  - Generate and display a persistent, unique virtual Device ID (or virtual MAC) on the device settings screen.
- [ ] **Web Management Portal**:
  - Web portal enabling users to enter their Device ID from a smartphone or computer browser.
  - Remotely enter and manage Xtream Codes or M3U playlist credentials without typing on a TV remote or on-screen keyboard.
- [ ] **Instant Cloud Sync**:
  - Securely fetch and synchronize updated playlist configurations from the portal to the client application.

---

## 📺 Phase 2: TV & Cross-Platform Expansion (Core Functionality)
> *Focus: High-level enablement to get apps running on TV platforms without over-complicating.*
- [ ] **Android TV & Amazon Fire TV Enablement**:
  - Basic D-Pad focus traversal across main navigation, category rails, channel grids, and player controls.
  - Standard TV remote button bindings (DPad Center = select/play, Back = return, Play/Pause toggle).
  - Android TV launcher banner and leanback intent configuration.
- [ ] **Smart TV Web/WASM Foundation**:
  - **Samsung Tizen TV**: Web app package build with media playback compatibility.
  - **LG webOS**: Basic webOS package configuration.
- [ ] **Mobile & Tablet Adaptations**:
  - Clean touch responsive layout support.

---

## 📋 Phase 3: Category Management
- [ ] **Hide / Show Categories**:
  - Ability to hide unwanted categories (e.g., international language packages, adult content).
- [ ] **Manage & Reorder Categories**:
  - Reorder categories or group them according to user preference.
- [ ] **Persistent Category Filter State**:
  - Store hidden categories in the local database per account.

---

## 🎬 Phase 4: Complete VOD Series Overhaul (Netflix-Style Experience)
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

## 🚀 Phase 5: Advanced Media & Power Features (Deferred)
- [ ] **Multi-View / Multi-Screen Player**:
  - Split-screen grid to play 2 or 4 Live TV channels simultaneously (customizable layouts for live sports).
- [ ] **Catch-Up TV (Archive)**:
  - Play past broadcasts directly from the EPG guide for supported Xtream providers.
- [ ] **Offline Downloads**:
  - Download VOD movies and episodes locally for offline viewing.
- [ ] **Custom User Categories**:
  - Create custom user playlists and grouped channels.
