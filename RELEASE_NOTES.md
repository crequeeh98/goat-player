## 🐐 GOATPlayer v2.1.2

### 🇩🇪 Änderungen & Neuerungen (v2.1.2)
- **TV D-Pad & Dialog-Navigation (Fire TV / Android TV)**:
  - *Fokus-Trapping & Sofort-Fokus*: TV-Fernbedienungsfokus landet beim Öffnen des Update- und Changelog-Modals sofort zuverlässig auf dem Aktionsbutton.
  - *D-Pad Tastensteuerung*: Links/Rechts wechselt direkt zwischen den Aktionsbuttons („Jetzt aktualisieren“ / „Später“), Oben/Unten scrollt den Changelog flüssig.
  - *Button-Layout & Skalierung*: Verhindert das Überlappen von Buttons in das Textfeld auf Fire TV; fester Maßstab (`focusScale: 1.0`) ohne störenden Zoom.
  - *Back-Taste Entkopplung*: Erster Druck auf die Zurück-Taste schließt ausschließlich das Dialog-Modal; erst der nächste Druck öffnet den Beenden-Dialog.
  - *Desktop Live TV*: Sicheres synchrones Bereinigen von Riverpod-Providern beim Schließen des Live TV Screens.
- **Kategorien-Manager Hotfix (v2.1.1)**:
  - *Mobiles Wischen & Scrolling*: Action Bar (`Ausgeblendete verbergen/anzeigen`, `A-Z Zurücksetzen`, `Alle ein-/ausblenden`) auf Mobilgeräten horizontal flüssig scroll- und wischbar.
  - *Fokus-Glow Beseitigung*: Kein nachrückender lila Fokusrahmen auf Touch- und Desktop-Geräten nach dem Ausblenden von Kategorien.
  - *TV D-Pad Stabilität*: Schnelles und unterbrechungsfreies Zappen & Verschieben auf Fire TV / Android TV bleibt uneingeschränkt erhalten.
- **Eigene Listen & Granulare Sync-Bereiche (v2.1)**:
  - Beliebig viele persönliche Listen erstellen, umbenennen und löschen (getrennt nach Live TV, Filme und Serien).
  - Streams direkt über das Kontextmenü (langer Klick auf Mobile, Enter / Options-Taste auf TV) zu eigenen Listen hinzufügen.
  - Granulare Playlist-Sync-Bereiche (Live TV, Filme, Serien getrennt synchronisierbar).
- **Smart TV (v2.0.5)**:
  - Stabile 2.0.5 Version auf Samsung Tizen & LG webOS bleibt aktiv (v2.1 UI Overhaul im Feature-Zweig).

### 🇬🇧 Changes & Improvements (v2.1.2)
- **TV D-Pad & Dialog Navigation (Fire TV / Android TV)**:
  - *Focus Trapping & Immediate Focus*: TV remote focus reliably locks onto action buttons when opening update or changelog modals.
  - *D-Pad Key Mapping*: Left/Right switches between buttons ("Update Now" / "Later"), Up/Down scrolls changelog smoothly.
  - *Button Layout & Sizing*: Prevents buttons from overlapping the changelog container on Fire TV / Android TV; enforced 1:1 scale (`focusScale: 1.0`) without zoom distortion.
  - *Back Key Decoupling*: First back press closes only the modal; second back press brings up the app exit dialog.
  - *Desktop Live TV*: Resolved unmounted Riverpod state error on live screen disposal.
- **Category Manager Hotfix (v2.1.1)**:
  - *Mobile Touch Scrolling*: Horizontally scrollable Action Bar (`Show/Hide Inactive`, `Reset A-Z`, `Bulk Toggle`) for smartphones.
  - *Focus Glow Cleared*: Removed lingering purple focus outline on mobile touch and desktop mouse interactions after hiding categories.
  - *TV D-Pad Navigation*: Preserved seamless auto-focus continuation on Android TV and Fire TV remotes.
- **Custom Playlists & Granular Sync (v2.1)**:
  - Create, rename, and delete custom playlists partitioned across Live TV, Movies, and TV Series.
  - Add streams directly to custom lists via context menu (long press on mobile, Enter / Option key on TV).
  - Granular playlist synchronization scopes per account.
- **Smart TV (v2.0.5)**:
  - Stable 2.0.5 release maintained for Samsung Tizen & LG webOS (v2.1 UI Overhaul on feature branch).
