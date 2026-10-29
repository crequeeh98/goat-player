# 🐐 GOATPlayer

<div align="center">

**The Ultimate Modern, High-Performance IPTV & Cinema VOD Player**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Android%20%7C%20FireTV%20%7C%20Tizen%20%7C%20webOS-blue)](#-device-installation-guides)
[![Repository](https://img.shields.io/badge/Repo-GitHub-blue)](https://github.com/crequeeh98/goat-player)
[![Release](https://img.shields.io/badge/Release-v2.0.0-purple)](https://github.com/crequeeh98/goat-player/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

</div>

---

## 🌟 Overview

**GOATPlayer** is an ultra-fast, premium IPTV and VOD streaming application engineered for dual-stack operation across desktop, mobile, and television ecosystems:

1. **Native Flutter Application (`lib/`)**: Built for **Windows Desktop**, **Android Phones / Tablets**, **Android TV / Google TV**, and **Amazon Fire TV**. Powered by **Drift (SQLite WAL)** and **`media_kit` (`libmpv`)** for direct hardware-accelerated video decoding.
2. **Smart TV Web Application (`smart_tv/`)**: Built for **Samsung Tizen (2018+)** and **LG webOS (4.0+)** using zero-dependency Vanilla JavaScript and CSS for blistering speed and instant focus response (<70ms) on low-power TV chipsets.
3. **Web Pairing Portal ([goat-player.vercel.app](https://goat-player.vercel.app))**: Zero-typing remote playlist manager featuring client-side **Zero-Knowledge AES-GCM encryption** for instantaneous QR code and PIN pairing.

---

## ✨ Features

### 🌐 Remote Pairing Portal & Zero-Knowledge Cloud Sync
- **Zero-Typing Smart TV Setup**: Add, edit, test, or remove IPTV playlists on your TV from your phone, tablet, or PC browser without tedious on-screen keyboard typing.
- **Client-Side Zero-Knowledge Encryption**: All server credentials and playlist URLs are encrypted via AES-GCM (256-bit) using keys derived directly from the TV's pairing PIN. The cloud relay never sees plaintext credentials.
- **1-Tap QR Code Pairing**: Scan the pairing QR code on the TV screen to automatically link in under a second.
- **Smart M3U Link Breakdown**: Paste raw M3U URLs (`http://server:port/get.php?username=...`), and the portal automatically extracts the host, username, password, and output format.
- **Real-Time Disconnection Guard**: WebSocket heartbeat monitoring alerts you when the TV exits pairing mode, preventing orphaned edits.

### 📺 Live TV & Smart IPTV Overlays
- **Sub-Second Channel Zapping**: Instantaneous stream tuning on native Flutter and Smart TV web engines.
- **Dual-Drawer Leanback Navigation**:
  - **Category Drawer (`ArrowLeft`)**: Instant category browsing with stream count badges.
  - **Channel Drawer (`Enter`)**: Live channel guide featuring current airing show, schedule times, and live progress bars.
- **Zapping OSD Infobar**: Clean lower-third HUD showing resolution badges (4K, FHD, HD), audio codecs, current program, and next upcoming program.
- **Interactive EPG Timeline**: Real-time Electronic Program Guide with timeline scrubbing and schedule details.
- **Illuminated Focus Indicators**: Dynamic glowing borders and cards designed for optimal readability at couch distance.

### 🎬 Cinema VOD (Movies & Series)
- **Netflix-Style Series Drawer**: Slide-out episode navigation drawer with season chips, episode thumbnails, and active glowing indicators.
- **Auto-Play Next Episode**: Smooth continuous playback across episodes, including automatic cross-season rollovers.
- **Intelligent Continue Watching Rail**:
  - Automatically deduplicates series, displaying only the single latest or next episode.
  - Advances cards to the next episode upon $\ge 95\%$ completion.
  - Safely purges finished movies and series finales.
- **Native Aspect Ratio Letterboxing**: Enforces `object-fit: contain` / `BoxFit.contain` by default, eliminating stretched picture on 16:9 and 21:9 television panels.
- **Universal Duration Extraction**: Robust parsing of irregular IPTV duration formats (`"98 min"`, `"1h 38m"`, `"01:30:00"`) and direct MP4 `mvhd` atom demuxing.

### 🔊 Audio & Subtitle Engine
- **Multi-Track Audio Switching**: Seamless switching between audio language tracks with codec, channel layout, and bitrate details.
- **Synchronized Subtitle Overlay**: On-demand WebVTT/SRT cue fetching, caching, and synchronized rendering (`TVSubtitles`).
- **Language Preference Matching**: Automatic pre-selection of preferred audio and subtitle languages (Deutsch, English, Auto).

---

## 📱 Device Installation Guides

Before you begin, download the appropriate package for your device from the official [GitHub Releases](https://github.com/crequeeh98/goat-player/releases).

### 📦 Android Architecture Matrix (Which APK do I need?)

| Package Name | Architecture | Target Devices |
|---|---|---|
| `app-arm64-v8a-release.apk` | 64-bit ARM | Modern Android smartphones (e.g. Xiaomi, Samsung Galaxy, Pixel), tablets, and modern TV boxes (Nvidia Shield TV Pro). |
| `app-armeabi-v7a-release.apk` | 32-bit ARM | **Amazon Fire TV Sticks** (Lite, 4K, 4K Max), Fire TV Cube, and compact Android TV sticks (Mi TV Stick, Chromecast HD). |
| `app-release.apk` (Universal) | Fat APK (Both) | Works on **all** Android & Fire OS devices without needing to know the architecture. |

---

### 1. 🪟 Windows Desktop (10 / 11)
1. Download `goat_player_windows_x64.zip` from [Releases](https://github.com/crequeeh98/goat-player/releases).
2. Extract the ZIP archive to your preferred directory (e.g. `C:\Tools\GOATPlayer`).
3. Run `goat_player.exe` to launch.

---

### 2. 📱 Android Phone & Tablet
1. Download `app-arm64-v8a-release.apk` directly to your phone.
2. Tap the downloaded file in your browser or file manager.
3. If prompted, grant permission to "Install unknown apps" in Android Settings.
4. Tap **Install** and launch GOATPlayer from your app drawer.

---

### 3. 📺 Amazon Fire TV & Fire TV Stick
Pick whichever installation path is most convenient for you:

#### Weg A: Via Android-Smartphone (Am einfachsten — Easy Fire Tools)
1. Install the free app **Easy Fire Tools** from the Google Play Store on your Android phone.
2. On your Fire TV: Go to **Settings** -> **My Fire TV** -> **Developer Options** and enable **ADB Debugging**.
3. In Easy Fire Tools on your phone, connect to your Fire TV over the local Wi-Fi, select the downloaded `app-armeabi-v7a-release.apk` (or GOATPlayer installed on your phone), and tap Install.

#### Weg B: Via Fire TV "Downloader" App
1. Install **Downloader** from the Amazon Appstore.
2. In Fire TV Settings: **My Fire TV** -> **Developer Options** -> **Install unknown apps** -> Enable for **Downloader**.
3. Open Downloader, select the **Browser** tab, navigate to:
   ```
   https://github.com/crequeeh98/goat-player/releases
   ```
4. Scroll to the latest release assets, click on `app-armeabi-v7a-release.apk`, and Downloader will automatically download and start the installation dialog.

#### Weg C: Via PC (ADB Sideload)
1. In Fire TV Settings: Enable **ADB Debugging**.
2. Open PowerShell on your PC and run:
   ```powershell
   adb connect <FIRE_TV_IP_ADDRESS>:5555
   adb install -r app-armeabi-v7a-release.apk
   ```

*GOATPlayer will automatically appear in **Meine Apps und Sender** with native 1:1 rounded icons and on **Projectivy Launcher** with borderless 16:9 3D banners.*

---

### 4. 📺 Android TV & Google TV (Sony, Philips, TCL, Nvidia Shield)
1. Download `app-arm64-v8a-release.apk` (or `app-armeabi-v7a-release.apk` for 32-bit sticks).
2. Transfer the APK to your TV using a USB flash drive or the free **Send Files to TV** app.
3. Open a file manager on your TV (e.g. File Commander) and click the APK to install.

---

### 5. 📺 LG Smart TV (webOS 4.0+)
1. Download `com.goatplayer.tv_1.2.7_all.ipk` from [Releases](https://github.com/crequeeh98/goat-player/releases) to your computer.
2. Install the **Developer Mode** app from the LG Content Store on your TV, launch it, log in with your free LG Developer account, and turn **Dev Mode Status** to **ON** (note the TV IP and Passphrase).
3. **Easiest Installation (1-Click GUI via PC/Mac)**:
   - Download and open the free open-source [webOS Dev Manager](https://github.com/webosbrew/dev-manager-desktop) on your computer.
   - Click **Add Device**, enter the TV IP and Passphrase.
   - Click **Install App**, select `com.goatplayer.tv_1.2.7_all.ipk`.
4. **Alternative via CLI (`ares-cli`)**:
   ```powershell
   ares-install -d <DEVICE_NAME> com.goatplayer.tv_1.2.7_all.ipk
   ```

*GOATPlayer includes full 16:9 LG webOS Dock banner support (`dockIcon.png`).*

---

### 6. 📺 Samsung Smart TV (Tizen OS 2018+)

> [!NOTE]
> Samsung Tizen's security model does not allow direct USB-sideloading. Installing third-party W3C widgets requires developer authorization matching the TV's hardware identifier (DUID).

1. Download `com.goatplayer.tv.signed.wgt` from [Releases](https://github.com/crequeeh98/goat-player/releases) to your computer.
2. Enable Developer Mode on your Samsung TV:
   - Open **Apps** on your TV.
   - Enter `1`, `2`, `3`, `4`, `5` using the remote number keys.
   - Toggle Developer Mode to **ON**, enter your computer's local IP, and reboot the TV (hold Power button until the Samsung logo appears).
3. Connect and install using the Samsung Tizen SDK CLI:
   ```powershell
   # Connect to your TV over local network
   sdb connect <TV_IP_ADDRESS>

   # Install signed W3C widget
   sdb install com.goatplayer.tv.signed.wgt
   ```
*(Alternative for Samsung TV without SDK setup: Open the Samsung TV Web Browser and navigate to the hosted Web Player).*

---

## 🛠️ Building from Source

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.13+)
- [Node.js](https://nodejs.org) (for Smart TV packaging tools)
- [PowerShell](https://microsoft.com/powershell) (Windows)

### 1. Build Flutter Desktop & Mobile
```powershell
# Get packages
flutter pub get

# Run test suite
flutter test

# Build Android APK (arm64-v8a)
flutter build apk --release --target-platform android-arm64 --split-per-abi

# Build Android TV / Fire TV APK (armeabi-v7a)
flutter build apk --release --target-platform android-arm --split-per-abi

# Build Universal Android APK (fat APK for all architectures)
flutter build apk --release

# Build Windows Desktop Release
flutter build windows --release
```

### 2. Package Smart TV (Tizen & webOS)
```powershell
# Package signed Samsung Tizen widget (.wgt)
powershell -ExecutionPolicy Bypass -File .\tool\package_smart_tv_tizen.ps1

# Package LG webOS package (.ipk)
powershell -ExecutionPolicy Bypass -File .\tool\package_smart_tv_webos.ps1
```

---

## 📄 License & Copyright

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for details.

Copyright (c) 2026 **Alexandros Panagiotidis**. All rights reserved.
