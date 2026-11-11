## 🐐 GOATPlayer v2.1.1

### 🇩🇪 Änderungen & Neuerungen (v2.1.1)
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
- **Eigene Listen & Granulare Sync-Bereiche (v2.1)**:
  - Beliebig viele persönliche Listen erstellen, umbenennen und löschen (getrennt nach Live TV, Filme und Serien).
  - Streams direkt über das Kontextmenü (langer Klick auf Mobile, Enter / Options-Taste auf TV) zu eigenen Listen hinzufügen.
  - Granulare Playlist-Sync-Bereiche (Live TV, Filme, Serien getrennt synchronisierbar).
- **Smart TV Wartungs-Patch (v2.0.5)**:
  - *Pairing-Fix*: Erhalt von Xtream-Zugangsdaten beim Bearbeiten von Playlist-Namen im Web-Portal.
  - *Samsung Tizen Branding*: Gestochen scharfes 512×512 Icon im Samsung Tizen Home-Menü und App-Grid.
  - *Toast-Sichtbarkeit*: Meldungs-Banner schweben jetzt zuverlässig über allen Modals.
  - *Entkoppelter TV-Updater*: Unabhängige Versionierung über `manifest.json`.

### 🇬🇧 Changes & Improvements (v2.1.1)
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
- **Custom Playlists & Granular Sync (v2.1)**:
  - Create, rename, and delete custom playlists partitioned across Live TV, Movies, and TV Series.
  - Add streams directly to custom lists via context menu (long press on mobile, Enter / Option key on TV).
  - Granular playlist synchronization scopes per account.
- **Smart TV Maintenance Patch (v2.0.5)**:
  - *Pairing Fix*: Preserves Xtream credentials when renaming playlists in the Web Portal.
  - *Samsung Tizen Branding*: Ultra-sharp 512×512 textless icon on Samsung 4K panels.
  - *Toast Visibility*: Toast notifications now render with elevated z-index above all dialogs.
  - *Decoupled OTA Updater*: Version comparison driven directly by `smart_tv/manifest.json`.
