## 🐐 GOATPlayer v2.1.0

### 🇩🇪 Änderungen & Neuerungen (v2.1.0)
- **Eigene Listen (Custom Playlists)**:
  - Beliebig viele persönliche Listen erstellen, umbenennen und löschen (getrennt nach Live TV, Filme und Serien).
  - Streams direkt über das Kontextmenü (langer Klick auf Mobile, Enter / Options-Taste auf TV) zu eigenen Listen hinzufügen.
  - Nahtlose Wiederherstellung von Streams bei Verschiebung der Provider-IDs über den Sendernamen.
- **Kategorien-Manager & Sortierung**:
  - Kategorien per Drag-and-Drop (oder Fernbedienung) individuell anordnen.
  - Ungewünschte Kategorien ausblenden / einblenden oder alphabetisch zurücksetzen.
  - Automatische Erkennung neuer Provider-Kategorien mit dezentem "NEW"-Badge bis zum ersten Öffnen.
- **Granulare Playlist-Sync-Bereiche**:
  - Für jede Playlist separat einstellbar, ob Live TV, Filme und/oder Serien synchronisiert werden sollen.
- **Smart TV Wartungs-Patch (v2.0.5)**:
  - *Pairing-Fix*: Erhalt von Xtream-Zugangsdaten beim Bearbeiten von Playlist-Namen im Web-Portal.
  - *Samsung Tizen Branding*: Gestochen scharfes 512×512 Icon im Samsung Tizen Home-Menü und App-Grid.
  - *Toast-Sichtbarkeit*: Meldungs-Banner schweben jetzt zuverlässig über allen Modals.
  - *Entkoppelter TV-Updater*: Unabhängige Versionierung über `manifest.json`.
- **Web-Portal (goat-player.vercel.app)**:
  - Zero-Knowledge Verschlüsselungs-Fixes bei Playlist-Edits und zuverlässige Feedback-Meldungen.

### 🇬🇧 Changes & Improvements (v2.1.0)
- **Custom Playlists**:
  - Create, rename, and delete custom playlists partitioned across Live TV, Movies, and TV Series.
  - Add streams directly to custom lists via context menu (long press on mobile, Enter / Option key on TV).
  - Robust stream recovery matching stream titles if provider IDs change.
- **Category Manager & Custom Ordering**:
  - Reorder categories via drag-and-drop or D-Pad navigation.
  - Hide/unhide categories or reset to alphabetical order.
  - Automatic detection of new categories with a subtle "NEW" badge until browsed.
- **Granular Playlist Sync Scopes**:
  - Selectively enable or disable synchronization for Live TV, Movies, or Series per account.
- **Smart TV Maintenance Patch (v2.0.5)**:
  - *Pairing Fix*: Preserves Xtream credentials when renaming playlists in the Web Portal.
  - *Samsung Tizen Branding*: Ultra-sharp 512×512 textless icon on Samsung 4K panels.
  - *Toast Visibility*: Toast notifications now render with elevated z-index above all dialogs.
  - *Decoupled OTA Updater*: Version comparison driven directly by `smart_tv/manifest.json`.
- **Web Portal (goat-player.vercel.app)**:
  - Zero-Knowledge pairing encryption hardening and reliable update feedback.
