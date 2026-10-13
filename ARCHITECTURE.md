# 🏛️ ARCHITECTURE.md — GOATPlayer System Architecture

GOATPlayer uses a purposeful dual-stack architecture to deliver native performance across modern desktop/mobile OSes while maintaining near-instant responsiveness on low-powered Smart TV platforms.

---

## 1. High-Level Architecture Diagram

```
                                  +---------------------------------------+
                                  |   Web Pairing Portal (Vercel)         |
                                  |   https://goat-player.vercel.app      |
                                  +-------------------+-------------------+
                                                      |
                                             Supabase Realtime
                                                      |
                         +----------------------------+----------------------------+
                         |                                                         |
                         v                                                         v
        +-----------------------------------+                     +-----------------------------------+
        |       FLUTTER CLIENT              |                     |      SMART TV CLIENT (Vanilla)    |
        |  Android TV, Fire TV, Mobile, Win |                     |    Samsung Tizen & LG webOS       |
        +-----------------------------------+                     +-----------------------------------+
        | - Presentation: Flutter Widgets   |                     | - Presentation: Vanilla HTML5/CSS |
        | - Remote: TvRemoteScope, TvFocus  |                     | - Remote: spatial_nav.js          |
        | - Engine: media_kit (libmpv)      |                     | - Engine: HTML5 Video + Hls.js    |
        | - Database: Drift (SQLite WAL)    |                     | - Storage: storage.js (Sandboxed) |
        | - Network: Dio + Xtream Client    |                     | - Network: Native fetch() API     |
        +-----------------+-----------------+                     +-----------------+-----------------+
                          |                                                         |
                          +----------------------------+----------------------------+
                                                       |
                                                       v
                                     +-----------------------------------+
                                     |    IPTV Server (Xtream Codes)     |
                                     |  Live Streams, VOD, Series, EPG   |
                                     +-----------------------------------+
```

---

## 2. Platform Implementations

### 2.1 Native Flutter Stack (`lib/`)
- **Framework**: Flutter 3.x / Dart.
- **Platforms**: Android Mobile, Android TV, Fire TV, Windows, macOS, Linux.
- **Media Engine**: `media_kit` powered by `libmpv`. Provides direct hardware-accelerated video decoding (Direct3D on Windows, MediaCodec on Android), multi-audio track selection, and external subtitle parsing.
- **Database**: `drift` with SQLite compiled using WAL mode. Enables smooth reads during heavy background updates.
- **Remote Navigation**: `TvRemoteScope` manages global TV remote Back button routing, while `TvFocusable` provides glowing borders and auto-scrolls lists.

### 2.2 Smart TV Web Stack (`smart_tv/`)
- **Philosophy**: Zero external frameworks. Pure Vanilla JavaScript (ES5/ES6 compatible) and CSS.
- **Target OS**:
  - **Samsung Tizen**: 2018+ (Tizen 4.0 - 8.0), packaged as W3C Widget (`.wgt`).
  - **LG webOS**: 2018+ (webOS 4.0 - 24), packaged as webOS IPK (`.ipk`).
- **Core Modules**:
  1. `spatial_nav.js`: 4-way D-Pad focus traversal engine with spatial distance calculation, modal focus trapping, and remote key handling.
  2. `player.js`: Media manager handling native HTML5 video playback, aspect ratio normalization, HUD state, seek watchdogs, and stream fallback.
  3. `storage.js`: Sandboxed storage engine with in-memory fallback, safe duration parsing (`parseDurationSecs`), and Continue Watching management.
  4. `api.js`: Xtream Codes API consumer with memory caching.
  5. `subtitles.js`: Client-side SRT/WebVTT subtitle parser and hardware-rendered subtitle overlay.
  6. `virtual_list.js`: High-performance DOM recycling list ensuring smooth scrolling with 10,000+ live channels.

---

## 3. Video Pipeline & Fail-Safe Architecture

IPTV streams vary wildly in container format, audio encoding, and header structures. GOATPlayer uses a 4-tier resilient playback pipeline:

```
[Play Stream Request]
        |
        v
1. Native Video Element (Hardware Decoded)
        |
        +---> [Success] ---> Render Video in Native Aspect Ratio
        |
        +---> [Fails / Times Out (>4.5s)]
                    |
                    v
            2. Hls.js Media Engine (HLS Fallback)
                    |
                    +---> [Success] ---> Playback Resumes
                    |
                    +---> [Fails]
                                |
                                v
                        3. Raw MPEG-TS Fallback (.ts)
                                |
                                +---> [Success] ---> Playback Resumes
                                |
                                +---> [Fails]
                                            |
                                            v
                                    4. Alternative Container Extension (e.g. mkv -> mp4)
```

### In-Stream MP4 / MKV Container Header Prober (`TVContainerProber`)
To resolve audio tracks, subtitle tracks, and exact duration on Smart TVs where the video element fails to report them:
1. Performs an HTTP Range request for the first 64KB - 512KB of the file.
2. Demuxes the MP4 `mvhd` and `trak` atoms (or MKV EBML tracks) in pure JavaScript.
3. Extracts track languages, codecs, and container duration without downloading the full video.
