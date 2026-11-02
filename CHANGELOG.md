# 📝 Changelog

All notable changes to the **GOATPlayer** project will be documented in this file.

---

## [2.0.2] - 2026-11-02

### 🇩🇪 Änderungen & Optimierungen
- **7 TV RAM- & Performance-Optimierungen**:
  - *On-Demand Short-EPG*: Kein RAM-Vollabgleich beim Start; lädt on-demand ~10 Sendungen via `get_short_epg` (15 Min TTL).
  - *Virtual DOM Recycling*: Smart TV DOM-Knoten auf max. 30 Elemente begrenzt; Flutter Viewport-Caching optimiert.
  - *Lazy VOD Sync*: Serien- und Filmdetails laden erst beim Öffnen des Modals.
  - *XMLTV Isolate-Streaming*: Streaming großer EPG-Dateien in Chunks verhindert 150+ MB Heap-Spikes.
  - *Poster Image Memory Caching*: Thumbnail-Downscaling (`memCacheWidth`), Disk-Caching und Max 60 Heap-Decoder.
  - *Continue Watching Capping*: Verlauf und Abspielfortschritte auf 50 VOD-Einträge gecappt.
  - *Automatischer EPG-Prune*: Löscht abgelaufene EPG-Sendungen (>24h alt) beim App-Start aus SQLite.
- **2 Sicherheits- & Updater-Härtungen**:
  - *Smart TV DOM XSS Härtung*: Alle dynamischen EPG-/Metadaten-Renderings nutzen strikt `textContent` oder HTML-Sanitization statt unsicherem `innerHTML`.
  - *Auto-Updater Integritätsprüfung*: HTTPS-GitHub-Restriktion, Path-Traversal-Schutz und SHA-256 Checksummenabgleich gegen `SHA256SUMS`.
- **EPG & Info HUD Angleichung (Flutter)**:
  - *EPG Timezone-Fix*: Korrektes lokales Broadcast-String-Parsing verhindert 1h-UTC-Fehlversatz des Xtream-PHP-Servers ("JETZT" bleibt erhalten und verschwindet nicht mehr beim Zappen/Klicken).
  - *Windows Kanalliste*: Sendungstitel und lila Fortschrittsbalken (`LinearProgressIndicator`) unter Sendernamen auf Desktop aktiviert.
  - *Info HUD Parität*: Windows nutzt nun im Vollbild das lange, lila Smart-IPTV Info HUD (wie Fire TV); Preview-Modus bleibt sauber ohne HUD.
  - *Player Schließen-Button*: Folgt nun exakt der erprobten `ESC`-Logik (beendet Vollbild sauber zurück zur Vorschau, kein Dashboard-Sprung).
  - *Fire TV Navigation & EPG-Schrift*: Reibungslose D-Pad-Navigation zurück zu Kategorien; EPG-Programmplan-Schriftgröße dezent verkleinert.
- **Smart TV Brand Icons**:
  - Textlose 1:1 Markenkachel für Samsung Tizen und LG webOS.
  - Harmonisches LG webOS Dock-Banner ohne Textabdrücke.

### 🇬🇧 Changes & Optimizations
- **7 TV RAM & Performance Optimizations**:
  - *On-Demand Short EPG*: TV no longer downloads full EPG upfront; fetches ~10 shows via `get_short_epg` (15m TTL).
  - *Virtual DOM Recycling*: Smart TV DOM capped at 30 recycled elements; Flutter viewport caching fine-tuned.
  - *Lazy VOD Sync*: Series/movie details load on-demand when opening detail modal.
  - *XMLTV Isolate Streaming*: Chunked streaming parser prevents 150+ MB heap spikes.
  - *Poster Memory Caching*: Strict thumbnail downscaling (`memCacheWidth`), disk caching, and max 60 heap decoders.
  - *Continue Watching Capping*: History & playback progress capped at 50 VOD items.
  - *Auto EPG Pruning*: Prunes expired EPG listings (>24h old) from SQLite on launch.
- **2 Security & Updater Hardening Fixes**:
  - *Smart TV DOM XSS Hardening*: All dynamic EPG and metadata rendering uses `textContent` or HTML sanitization.
  - *Auto-Updater Integrity Check*: Enforces HTTPS GitHub domains, blocks path traversal, and validates SHA-256 against `SHA256SUMS`.
- **EPG & Info HUD Cross-Platform Parity (Flutter)**:
  - *EPG Timezone Fix*: Local broadcast string parsing prevents Xtream Codes PHP 1-hour UTC offset bug ("NOW" remains visible).
  - *Windows Channel List*: Added live show title and purple `LinearProgressIndicator` under channel names.
  - *Info HUD Parity*: Windows fullscreen playback now displays the full purple Smart-IPTV Info HUD (matching Fire TV); preview mode remains clean.
  - *Player Close Button*: Top-left Back button now mirrors `ESC` key behavior (exits fullscreen cleanly to preview without jumping to dashboard).
  - *Fire TV Navigation & EPG Typography*: Restored smooth D-Pad navigation to category column; subtly reduced EPG schedule font sizes for TV viewing.
- **Smart TV Brand Icons**:
  - Textless 1:1 brand tile for Samsung Tizen and LG webOS.
  - Seamless LG webOS dock banner.

---

## [2.0.1] - 2026-10-30

### 🇩🇪 Änderungen & Fixes
- **Kategoriesuche & Tastatur-Fokus**: Behebt das unerwünschte Schließen der TV-Tastatur und den Fokusverlust beim Löschen des Suchtextes in Kanälen, Filmen und Serien.
- **Live TV EPG & Menü Back-Navigation**: Das Drücken der Zurück-Taste im Vollbild-EPG oder Kanal-/Kategoriemenü kehrt zur vorherigen Ansicht zurück, statt das Vollbild komplett zum Dashboard zu verlassen.
- **Serien-Player Episoden-Drawer Back-Navigation**: Das Schließen des Episoden-Drawers via Zurück-Taste beendet nicht mehr den gesamten Videoplayer.
- **Film- & Seriensuche Poster-Navigation**: Direkte D-Pad-Navigation (`Pfeil rechts` / `Pfeil runter`) von der Kategorieliste bzw. Suche zu den gefundenen Film- und Serienpostern wiederhergestellt.

### 🇬🇧 Changes & Fixes
- **Category Search & Keyboard Focus**: Fixed premature TV keyboard dismissal and focus disruption when clearing/deleting search text across live channels, movies, and series.
- **Live TV Fullscreen EPG & Menu Back Navigation**: Pressing Back inside fullscreen EPG schedule or channel/category menus now returns to the prior menu layer instead of exiting fullscreen to the dashboard.
- **Series Player Episode Drawer Back Navigation**: Closing the in-player episode drawer via Back key no longer closes the active video playback.
- **VOD Search Poster D-Pad Traversal**: Restored direct D-Pad navigation (`Arrow Right` / `Arrow Down`) from category rails and search inputs to matching movie and series posters.

---

## [2.0.0] - 2026-10-29

### 🇩🇪 Meilenstein-Release
- **Multi-Plattform Core**: Vollständige Unterstützung für Android TV / Fire TV, Android Mobile, Windows Desktop, Samsung Tizen und LG webOS.
- **Smart-IPTV Overlay System**: Zapping Infobar, paginiertes Kanalmenü, Kategorieauswahl und EPG Timeline.
- **Zero-Knowledge Pairing**: Supabase Realtime Pairing Portal mit clientseitiger AES-GCM Verschlüsselung.
- **MediaKit Video Engine**: Hardware-dekodierte libmpv-Wiedergabe mit HLS/TS-Support und nativer Aspect-Ratio Wahrung.
