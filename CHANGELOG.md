# 📝 Changelog

All notable changes to the **GOATPlayer** project will be documented in this file.

---

## [2.1.1] - 2026-11-12

### 🇩🇪 Änderungen & Optimierungen
- **Kategorien-Manager Hotfix**:
  - *Mobiles Wischen & Scrolling*: Action Bar (`Ausgeblendete verbergen/anzeigen`, `A-Z Zurücksetzen`, `Alle ein-/ausblenden`) auf Mobilgeräten horizontal flüssig scroll- und wischbar.
  - *Fokus-Glow Beseitigung*: Kein nachrückender lila Fokusrahmen auf Touch- und Desktop-Geräten nach dem Ausblenden von Kategorien.
  - *TV D-Pad Stabilität*: Schnelles und unterbrechungsfreies Zappen & Verschieben auf Fire TV / Android TV bleibt uneingeschränkt erhalten.
- **Modernisiertes Update-Modal & Changelog-Viewer**:
  - *Automatischer Sprachfilter*: Zeigt auf deutschen Geräten exklusiv deutsche Release-Notes und auf englischen Geräten englische Texte.
  - *Rich Markdown Rendering*: Kompakte Bullets, `Code-Badges`, **Fettschrift** und *Kursivschrift* auf einen Blick ohne unnötiges Scrollen.
  - *Changelog jederzeit abrufbar*: Klick auf die Versions-Badge öffnet die Neuerungen; bei aktuellem Stand mit grünem Bestätigungshaken und reinem „Schließen“-Button.
  - *Responsive Dialogmaße*: 620px breite TV-Darstellung und D-Pad Autofokus.
  - *Windows Fast-Path*: Sofortiges Anzeigen ohne blockierende 404-Netzwerkanfragen sowie Schutz vor Mehrfachklicks (Debounce).

### 🇬🇧 Changes & Optimizations
- **Category Manager Hotfix**:
  - *Mobile Touch Scrolling*: Horizontally scrollable Action Bar (`Show/Hide Inactive`, `Reset A-Z`, `Bulk Toggle`) for smartphones.
  - *Focus Glow Cleared*: Removed lingering purple focus outline on mobile touch and desktop mouse interactions after hiding categories.
  - *TV D-Pad Navigation*: Preserved seamless auto-focus continuation on Android TV and Fire TV remotes.
- **Modernized Update Dialog & Changelog Viewer**:
  - *Automated Language Filter*: Displays German notes on German systems and English notes on English systems without bilingual clutter.
  - *Rich Markdown Formatting*: Dense bullet points, `code tags`, **bold** and *italic* styling fitting on a single screen without scrolling.
  - *Changelog on Demand*: Clicking the version badge displays the release notes; shows verified checkmark with "Close" button when up-to-date.
  - *Responsive TV Dialog*: 620px wide layout for television screens with D-Pad autofocus.
  - *Windows Fast-Path*: Instant changelog display without blocking 404 queries and debounced version click handling.

---

## [2.1.0] - 2026-11-07

### 🇩🇪 Änderungen & Neuerungen
- **Eigene Listen (Custom Playlists)**:
  - Beliebig viele persönliche Listen erstellen, umbenennen und löschen (getrennt nach Live TV, Filme und Serien).
  - Streams direkt über das Kontextmenü (langer Klick auf Mobile, Enter / Options-Taste auf TV) zu eigenen Listen hinzufügen.
  - Nahtlose Wiederherstellung von Streams bei Verschiebung der Provider-IDs über den Sendernamen.
- **Kategorien-Manager & Sortierung**:
  - Kategorien per Drag-and-Drop (oder Fernbedienung) individuell anordnen.
  - Ungewünschte Kategorien ausblenden / einblenden oder alphabetisch zurücksetzen.
  - Automatische Erkennung neuer Provider-Kategorien mit dezentem NEW-Badge bis zum ersten Öffnen.
- **Granulare Playlist-Sync-Bereiche**:
  - Für jede Playlist separat einstellbar, ob Live TV, Filme und/oder Serien synchronisiert werden sollen.
- **Smart TV Wartungs-Patch (v2.0.5)**:
  - *Pairing-Fix*: Erhalt von Xtream-Zugangsdaten beim Bearbeiten von Playlist-Namen im Web-Portal.
  - *Samsung Tizen Branding*: Gestochen scharfes 512×512 Icon im Samsung Tizen Home-Menü und App-Grid.
  - *Toast-Sichtbarkeit*: Meldungs-Banner schweben jetzt zuverlässig über allen Modals.
  - *Entkoppelter TV-Updater*: Unabhängige Versionierung über `manifest.json`.
- **Web-Portal (goat-player.vercel.app)**:
  - Zero-Knowledge Verschlüsselungs-Fixes bei Playlist-Edits und zuverlässige Feedback-Meldungen.

### 🇬🇧 Changes & Improvements
- **Custom Playlists**:
  - Create, rename, and delete custom playlists partitioned across Live TV, Movies, and TV Series.
  - Add streams directly to custom lists via context menu (long press on mobile, Enter / Option key on TV).
  - Robust stream recovery matching stream titles if provider IDs change.
- **Category Manager & Custom Ordering**:
  - Reorder categories via drag-and-drop or D-Pad navigation.
  - Hide/unhide categories or reset to alphabetical order.
  - Automatic detection of new categories with a subtle NEW badge until browsed.
- **Granular Playlist Sync Scopes**:
  - Selectively enable or disable synchronization for Live TV, Movies, or Series per account.
- **Smart TV Maintenance Patch (v2.0.5)**:
  - *Pairing Fix*: Preserves Xtream credentials when renaming playlists in the Web Portal.
  - *Samsung Tizen Branding*: Ultra-sharp 512×512 textless icon on Samsung 4K panels.
  - *Toast Visibility*: Toast notifications now render with elevated z-index above all dialogs.
  - *Decoupled OTA Updater*: Version comparison driven directly by `smart_tv/manifest.json`.
- **Web Portal (goat-player.vercel.app)**:
  - Zero-Knowledge pairing encryption hardening and reliable update feedback.

---

## [2.0.4] - 2026-11-03

### 🇩🇪 Änderungen & Optimierungen
- **Sicherheits- & Hardening-Suite**:
  - *Zero-Knowledge Remote Pairing*: Ende-zu-Ende AES-256-GCM Verschlüsselung bei QR-/PIN-Kopplung (PBKDF2 Schlüsselableitung). Playlisten und Zugangsdaten liegen auf Cloud-Brokern zu keinem Zeitpunkt im Klartext vor.
  - *Passwort-Verschlüsselung at Rest*: Zugangsdaten in lokaler SQLite (Flutter) und LocalStorage (Smart TV) per AES-GCM geschützt. Nahtlose automatische Migration aller bestehenden Accounts.
  - *Smart TV OTA Code-Integrität*: Dynamischer Bootloader validiert Code vor Ausführung strikt per kryptografischem SHA-256 Hash.
  - *Schutz vor Credential-Leaks in Logs*: Automatische Maskierung von Passwörtern und Parametern bei Netzwerk- und Verbindungsfehlern.
  - *Android Backup-Schutz*: Deaktiviertes OS-Backup (`allowBackup="false"`) verhindert Extraktion von Nutzerdaten über ADB.
  - *Berechtigungs-Minimalismus*: Unnötige System-Privilegien und Berechtigungen auf Tizen (`config.xml`) und webOS (`appinfo.json`) bereinigt.
  - *Automatischer Session-Cleanup*: Abgelaufene Kopplungssitzungen werden nach 10 Minuten serverseitig automatisch gelöscht.
- **UI, Lokalisierung & Modernisierung**:
  - *Playlist-Aktualisieren Dialog*: Vollständig 1:1 auf Deutsch und Englisch übersetzt (relative Zeitstempel, Statusanzeigen, Buttons).
  - *Moderne Dialog-Icons*: Wiedergabe-Einstellungen modernisiert mit abgerundeten Material-Icons für Audiospur, Untertitel und Fertig-Aktion.
  - *Aktive Versionsanzeige*: Laufende App-Version wird nun direkt auf der Account-Übersicht auf allen Plattformen angezeigt.

### 🇬🇧 Changes & Optimizations
- **Security & Hardening Suite**:
  - *Zero-Knowledge Remote Pairing*: End-to-end AES-256-GCM encryption for QR/PIN TV pairing. Credentials and playlist URLs are never stored in plaintext on third-party cloud brokers.
  - *Password Encryption at Rest*: Secret credentials encrypted with AES-GCM across SQLite (Flutter) and LocalStorage (Smart TV) with zero-breakage migration.
  - *Smart TV OTA Code Integrity*: Dynamic bootloader validates cached script integrity via SHA-256 before script injection.
  - *Credential Masking in Error Logs*: Passwords and sensitive parameters are stripped and masked in network error messages.
  - *Android Backup Hardening*: Explicitly disabled OS backup (`allowBackup="false"`) prevents extracting credentials via ADB backup.
  - *Privilege Minimization*: Stripped unused system permissions from Samsung Tizen (`config.xml`) and LG webOS (`appinfo.json`).
  - *Automated Session Cleanup*: Database trigger purges expired pairing sessions (>10 min) automatically.
- **UI, Localization & Modernization**:
  - *Playlist Sync Modal*: Complete 1:1 localization in English and German (relative timestamps, status states, action buttons).
  - *Modernized Dialog Icons*: Playback settings dialog updated with sleek rounded Material icons for audio, subtitles, and done buttons.
  - *Active Version Badge*: Displays active running version on the Account management screen across all platforms.

---

## [2.0.3] - 2026-11-02

### 🇩🇪 Änderungen & Optimierungen
- **Dynamischer Smart-TV OTA Bootloader (Samsung Tizen & LG webOS)**:
  - *Vollwertige In-App-Updates ohne Neuinstallation*: Neuer Code wird beim Start direkt aus dem Speicher dynamisch gebootet.
  - *Fail-Safe & Auto-Rollback*: Fängt Startfehler automatisch ab und stellt bei Problemen die stabilen Originaldateien ohne Abstürze wieder her.

### 🇬🇧 Changes & Optimizations
- **Dynamic Smart TV OTA Bootloader (Samsung Tizen & LG webOS)**:
  - *Full in-app updates without reinstallation*: Updated code is booted dynamically from cache on startup.
  - *Fail-safe & auto-rollback*: Automatically intercepts boot errors and restores factory files without crash loops.

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
