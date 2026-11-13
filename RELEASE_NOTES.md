## 🐐 GOATPlayer v2.1.3

### 🇩🇪 Änderungen & Neuerungen (v2.1.3)
- **Flutter & Web-Portal (`fix/windows-startup-window`)**:
  - *Windows Start-Fix*: App startet direkt maximiert nach dem ersten gerenderten Frame (`waitUntilFirstFrameRasterized` + entferntes Vorab-Show in `flutter_window.cpp`) ohne kleines Fenster oder White-Screen.
  - *Deutsch als Standard*: Frische Installationen in Flutter und Web-Portal starten standardmäßig auf Deutsch; bestehende Sprach-Einstellungen bleiben erhalten.
  - *TV D-Pad & Navigation (v2.1.2 Basis)*: Fokus-Trapping im Update-/Changelog-Dialog, 1:1 Skalierung, entkoppelte Back-Taste und sauberes Desktop-Live-Cleanup.
- **Smart TV – Samsung Tizen & LG webOS (`feat/v2.1-smart-tv-overhaul`)**:
  - *v2.1 UI/UX Overhaul & webOS 6.5*: Überarbeitete 10-Foot-Oberfläche, scharfe SVG-Vektor-Icons (`window.TVIcons`), kompaktes Account-/Login-Modal und vereinheitlichter Markdown-Changelog.
  - *Kategorien-Manager & Eigene Listen*: Kategorien ausblenden/verschieben, `A-Z Zurücksetzen`, Custom Lists (Live, Filme, Serien), Sender-Verschiebemodus (▲/▼), OK-Halten-Kontextmenü und selektive Sync-Bereiche.
  - *Plattform-Feinschliff*: Deutsch als Standard auf Smart TV, Tizen-Suchfeld (`body.platform-tizen`) drückt Tune-Button nicht mehr über die Trennlinie, und doppelter Haken auf „Fertig“ entfernt.

### 🇬🇧 Changes & Improvements (v2.1.3)
- **Flutter & Web Portal (`fix/windows-startup-window`)**:
  - *Windows Startup Fix*: Launches directly maximized after the first rasterized frame (`waitUntilFirstFrameRasterized`, removed premature native `Show()`) without small-window flash or blank frame.
  - *German Default Language*: Fresh installs across Flutter and the Web Pairing Portal default to German while preserving existing user preferences.
  - *TV D-Pad & Navigation (v2.1.2 base)*: Modal focus trapping, 1:1 button scale, decoupled Back key handling, and clean desktop Live TV provider disposal.
- **Smart TV – Samsung Tizen & LG webOS (`feat/v2.1-smart-tv-overhaul`)**:
  - *v2.1 UI/UX Overhaul & webOS 6.5*: Harmonized 10-foot UI, crisp SVG vector icons (`window.TVIcons`), compact account/login layout, and unified Markdown changelog viewer.
  - *Category Manager & Custom Lists*: Hide/reorder categories, `Reset A-Z`, Custom Lists (Live, Movies, Series), channel move mode (▲/▼), Hold-OK context menu, and selective sync scopes.
  - *Platform Polish*: German default language on Smart TV, Tizen-only category search width constraint next to the tune button (`body.platform-tizen`), and single checkmark on Done button.
