// smart_tv/js/updater.js - In-App OTA Updater for Samsung Tizen & LG webOS
(function() {
  'use strict';

  var APP_VERSION = '2.1.2';
  var CURRENT_VERSION = (window.TVBootloader && window.TVBootloader.getBaseVersion)
    ? window.TVBootloader.getBaseVersion()
    : APP_VERSION;
  var GITHUB_REPO = 'crequeeh98/goat-player';
  var OTA_STORAGE_KEY = 'goat_tv_ota_bundle';

  var _pendingUpdate = null;
  var _cachedReleaseNotes = null;
  var _isUpdating = false;

  var FALLBACK_CHANGELOG_2_1_1 = [
    '### 🇩🇪 Änderungen & Neuerungen (v2.1.1)',
    '- **Komplette Smart TV UI/UX Modernisierung**:',
    '  - *Harmonisierte TV-Typografie*: Einheitliche 10-Foot Schriftgrößen ohne unpassende Sprünge auf 1080p und 4K TVs.',
    '  - *Scharfe Vektor-Icons*: Alle veralteten Emojis durch gestochen scharfe Vektor-SVGs (`window.TVIcons`) ersetzt.',
    '  - *Kompakteres Account- & Login-Design*: 1-Spalten-Layout passt perfekt ohne Scrollen auf jeden Smart TV.',
    '  - *1:1 Flutter Update-Dialog*: Reines Markdown-Changelog mit Sprachfilter, Status-Pill und Schließen-Button.',
    '- **Kategorien-Manager (Live, Filme & Serien)**:',
    '  - *Ausgeblendete verbergen/anzeigen*: Ein-/Ausblenden ungenutzter Kategorien mit D-Pad OK.',
    '  - *Kategorien verschieben*: Mit gelber Taste oder OK gedrückt halten Reihenfolge interaktiv anpassen.',
    '  - *Schnell-Aktionen*: `A-Z Zurücksetzen` und `Alle ein-/ausblenden`.',
    '- **Eigene Listen & Sender-Sortierung**:',
    '  - *Custom Lists*: Beliebig viele eigene Listen erstellen, umbenennen und löschen.',
    '  - *Sender-Verschiebemodus*: Sender in Favoriten und eigenen Listen direkt per D-Pad (▲/▼) neu anordnen.',
    '  - *Stream-Kontextmenü*: OK auf einem Sender oder Poster gedrückt halten für Schnell-Aktionen.',
    '- **Selektive Synchronisation**:',
    '  - Granulare Auswahl der Bereiche (Live TV, Filme, Serien) pro Konto beim Hinzufügen und Bearbeiten.',
    '',
    '---',
    '',
    '### 🇬🇧 Changes & Improvements (v2.1.1)',
    '- **Complete Smart TV UI/UX Modernization**:',
    '  - *Harmonized TV Typography*: Crisp 10-foot scale tailored for 1080p and 4K displays.',
    '  - *Sharp Vector Icons*: Replaced all legacy emojis with crisp SVG vector icons (`window.TVIcons`).',
    '  - *Compact Account & Login Layout*: 1-column layout fitting seamlessly on screen without scrolling.',
    '  - *1:1 Flutter Update Dialog*: Rich Markdown changelog with language filter, status pill and close button.',
    '- **Category Manager (Live, Movies & Series)**:',
    '  - *Show/Hide Inactive*: Toggle category visibility with D-Pad OK.',
    '  - *Reorder Categories*: Hold OK or press Yellow key to interactively move categories.',
    '  - *Quick Actions*: `Reset A-Z` and `Show/Hide All`.',
    '- **Custom Lists & Channel Reordering**:',
    '  - *Custom Lists*: Create, rename, and manage custom playlists for Live TV, Movies, and Series.',
    '  - *Interactive Channel Move Mode*: Reorder channels in Favorites and Custom Lists via D-Pad (▲/▼).',
    '  - *Stream Context Menu*: Hold OK on any channel or poster to open quick actions.',
    '- **Selective Synchronization**:',
    '  - Granular playlist sync scopes (Live TV, Movies, Series) when adding or editing accounts.'
  ].join('\n');

  function getActiveVersion() {
    try {
      if (window.__GOAT_TV_VERSION__) {
        return window.__GOAT_TV_VERSION__;
      }
      if (window.TVBootloader && typeof window.TVBootloader.getActiveVersion === 'function') {
        return window.TVBootloader.getActiveVersion();
      }
      var saved = localStorage.getItem(OTA_STORAGE_KEY);
      if (saved) {
        var otaBundle = JSON.parse(saved);
        if (otaBundle && otaBundle.version) {
          return otaBundle.version;
        }
      }
    } catch (_) {}
    return CURRENT_VERSION;
  }

  function isNewer(current, latest) {
    try {
      var c = String(current || '0.0.0').replace(/^v/, '').split('.').map(function(n) { return parseInt(n, 10) || 0; });
      var l = String(latest || '0.0.0').replace(/^v/, '').split('.').map(function(n) { return parseInt(n, 10) || 0; });
      for (var i = 0; i < 3; i++) {
        var cv = c[i] || 0;
        var lv = l[i] || 0;
        if (lv > cv) return true;
        if (lv < cv) return false;
      }
    } catch (e) {
      console.warn('[TVUpdater] isNewer comparison failed:', e);
    }
    return false;
  }

  function escapeHtml(text) {
    if (!text) return '';
    return String(text)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  function formatInlineMarkdown(text) {
    var escaped = escapeHtml(text);
    // Inline code: `code`
    escaped = escaped.replace(/`([^`]+)`/g, '<code class="changelog-code">$1</code>');
    // Bold: **text**
    escaped = escaped.replace(/\*\*([^*]+)\*\*/g, '<strong style="color:#FFFFFF;font-weight:700;">$1</strong>');
    // Italic: *text*
    escaped = escaped.replace(/\*([^*]+)\*/g, '<em style="color:rgba(255,255,255,0.9);">$1</em>');
    return escaped;
  }

  function extractLocalizedChangelog(rawNotes, isGerman) {
    if (!rawNotes || typeof rawNotes !== 'string') return '';
    var normalized = rawNotes.replace(/\r\n/g, '\n').trim();
    if (!normalized) return '';

    var deRegex = /(?:^|\n)#{1,4}\s*(?:🇩🇪|[🇩][🇪]|.*[Ää]nderungen|.*Neuerungen|.*German|.*Deutsch)/i;
    var enRegex = /(?:^|\n)#{1,4}\s*(?:🇬🇧|[🇬][🇧]|.*Changes|.*English|.*What's new|.*Improvements)/i;

    var deMatch = deRegex.exec(normalized);
    var enMatch = enRegex.exec(normalized);

    var section = '';
    if (deMatch && enMatch) {
      if (isGerman) {
        var startDe = deMatch.index + deMatch[0].length;
        var endDe = enMatch.index > startDe ? enMatch.index : normalized.length;
        section = normalized.substring(startDe, endDe);
      } else {
        var startEn = enMatch.index + enMatch[0].length;
        var nextHeader = /\n---|\n#{1,3}\s+/.exec(normalized.substring(startEn));
        var endEn = nextHeader ? startEn + nextHeader.index : normalized.length;
        section = normalized.substring(startEn, endEn);
      }
    } else if (deMatch && isGerman) {
      var startDeOnly = deMatch.index + deMatch[0].length;
      var nextHDe = /\n---|\n#{1,3}\s+/.exec(normalized.substring(startDeOnly));
      var endDeOnly = nextHDe ? startDeOnly + nextHDe.index : normalized.length;
      section = normalized.substring(startDeOnly, endDeOnly);
    } else if (enMatch && !isGerman) {
      var startEnOnly = enMatch.index + enMatch[0].length;
      var nextHEn = /\n---|\n#{1,3}\s+/.exec(normalized.substring(startEnOnly));
      var endEnOnly = nextHEn ? startEnOnly + nextHEn.index : normalized.length;
      section = normalized.substring(startEnOnly, endEnOnly);
    } else {
      // Split by separator '---' if present
      var parts = normalized.split(/\n---+\n|\n---+\s*$/);
      if (parts.length >= 2) {
        section = isGerman ? parts[0] : parts[1];
      } else {
        section = normalized;
      }
    }

    // Clean leading language header line / markdown markers
    section = section.replace(/^(?:[\r\n\s]|---+|#{1,4}\s*(?:🇩🇪|🇬🇧|🇺🇸|[^\n]*))+/i, '').trim();
    // Also remove any remaining trailing separator
    section = section.replace(/\n---+\s*$/, '').trim();
    return section;
  }

  function renderMarkdownChangelogHtml(rawText) {
    if (!rawText) return '';
    var normalized = String(rawText).replace(/\r\n/g, '\n');
    var lines = normalized.split('\n');
    var html = '';

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      var trimmed = line.trim();
      if (!trimmed) {
        html += '<div class="changelog-space" style="height:6px;"></div>';
        continue;
      }

      // Headers (### or ## or #)
      if (/^#{1,4}\s+/.test(trimmed)) {
        var headerText = trimmed.replace(/^#{1,4}\s+/, '');
        html += '<div class="changelog-h3">' + formatInlineMarkdown(headerText) + '</div>';
        continue;
      }

      // Sub-bullets (indented with 2+ spaces or tab followed by - or *)
      var isSubBullet = /^(\s{2,}|\t)[-*•]\s+/.test(line);
      var isBullet = isSubBullet || /^[-*•]\s+/.test(trimmed);

      if (isBullet) {
        var bulletContent = trimmed.replace(/^[-*•]\s+/, '');
        var rowClass = isSubBullet ? 'changelog-bullet-row changelog-subbullet-row' : 'changelog-bullet-row';
        var dotChar = isSubBullet ? '›' : '•';
        var dotStyle = isSubBullet ? 'color:#B388FF;font-weight:700;margin-right:6px;' : 'color:#9333EA;font-weight:800;margin-right:8px;';
        html += '<div class="' + rowClass + '"><span class="changelog-bullet-dot" style="' + dotStyle + '">' + dotChar + '</span><span class="changelog-bullet-text">' + formatInlineMarkdown(bulletContent) + '</span></div>';
        continue;
      }

      // Normal paragraph
      html += '<div class="changelog-p">' + formatInlineMarkdown(trimmed) + '</div>';
    }

    return html;
  }

  function checkForUpdates() {
    var url = 'https://api.github.com/repos/' + GITHUB_REPO + '/releases/latest';

    return fetch(url, { headers: { 'Accept': 'application/vnd.github.v3+json' } })
      .then(function(res) {
        if (!res.ok) throw new Error('HTTP ' + res.status);
        return res.json();
      })
      .then(function(data) {
        if (!data || !data.tag_name) return null;

        var latestTag = data.tag_name.trim();
        if (!/^v?\d+\.\d+\.\d+(?:[-+][a-zA-Z0-9._-]+)?$/.test(latestTag)) return null;
        if (data.body) {
          _cachedReleaseNotes = data.body;
        }

        // Fetch manifest.json to inspect the Smart TV specific version
        var rawBaseUrl = 'https://raw.githubusercontent.com/' + GITHUB_REPO + '/' + latestTag + '/';
        var manifestUrl = rawBaseUrl + 'smart_tv/manifest.json?t=' + Date.now();

        return fetch(manifestUrl)
          .then(function(mRes) {
            if (mRes.ok) return mRes.json();
            return null;
          })
          .then(function(manifest) {
            var tvVersion = (manifest && manifest.version) ? manifest.version : latestTag.replace(/^v/, '');
            var activeVer = getActiveVersion();

            if (isNewer(activeVer, tvVersion)) {
              _pendingUpdate = {
                version: tvVersion,
                tag: latestTag,
                body: data.body || '',
                assets: data.assets || []
              };
              showUpdateModal(activeVer, tvVersion, _pendingUpdate.body, false);
              return _pendingUpdate;
            }
            return {
              version: tvVersion,
              tag: latestTag,
              body: data.body || '',
              hasUpdate: false
            };
          });
      })
      .catch(function(err) {
        console.log('[TVUpdater] Check skipped / offline:', err.message);
        return null;
      });
  }

  function showUpdateModal(arg1, arg2, arg3, arg4) {
    var currentVer, latestVer, changelog, isUpToDateMode;

    if (typeof arg1 === 'object' && arg1 !== null) {
      currentVer = arg1.currentVersion || getActiveVersion();
      latestVer = arg1.latestVersion || arg1.version || currentVer;
      changelog = arg1.changelog || arg1.releaseNotes || arg1.body || '';
      isUpToDateMode = (typeof arg2 === 'boolean') ? arg2 : (arg1.hasUpdate === false || currentVer === latestVer);
    } else {
      currentVer = arg1 || getActiveVersion();
      latestVer = arg2 || currentVer;
      changelog = arg3 || '';
      isUpToDateMode = (typeof arg4 === 'boolean') ? arg4 : (currentVer === latestVer);
    }

    var modal = document.getElementById('modal-update');
    if (!modal) return;

    var isDe = (window.TVI18n && typeof TVI18n.getLanguage === 'function')
      ? (TVI18n.getLanguage() === 'de')
      : false;

    // 1. Badge Icon
    var badgeIcon = document.getElementById('update-badge-icon');
    if (badgeIcon) {
      if (isUpToDateMode) {
        badgeIcon.innerHTML = (window.TVIcons && window.TVIcons.checkCircle)
          ? window.TVIcons.checkCircle
          : '<svg class="tv-icon-svg" viewBox="0 0 24 24" fill="none" stroke="#34D399" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>';
      } else {
        badgeIcon.innerHTML = (window.TVIcons && window.TVIcons.systemUpdate)
          ? window.TVIcons.systemUpdate
          : '<svg class="tv-icon-svg" viewBox="0 0 24 24" fill="none" stroke="#B388FF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>';
      }
    }

    // 2. Title
    var titleEl = document.getElementById('update-modal-title') || document.getElementById('update-title') || modal.querySelector('.modal-title');
    if (titleEl) {
      titleEl.textContent = isUpToDateMode
        ? (isDe ? 'App ist auf dem neuesten Stand' : 'App is up to date')
        : (isDe ? 'Update verfügbar' : 'Update Available');
    }

    // 3. Version Pill
    var badge = document.getElementById('update-version-pill') || document.getElementById('update-version-badge');
    if (badge) {
      if (isUpToDateMode) {
        badge.textContent = 'v' + currentVer;
        badge.className = 'update-version-badge update-version-badge-current';
      } else {
        badge.textContent = 'v' + currentVer + '  →  v' + latestVer;
        badge.className = 'update-version-badge update-version-badge-new';
      }
    }

    // 4. Description
    var descEl = modal.querySelector('.update-desc');
    if (descEl) {
      descEl.textContent = isUpToDateMode
        ? (isDe ? 'Du nutzt die aktuellste Version von GOATPlayer TV.' : 'You are using the latest version of GOATPlayer TV.')
        : (isDe ? 'Eine neue Version von GOATPlayer TV ist bereit zur Installation.' : 'A new version of GOATPlayer TV is ready to install.');
    }

    // 5. Changelog Box with localized markdown
    var changelogBox = document.getElementById('update-changelog-box');
    if (changelogBox) {
      var rawChangelog = changelog || (isUpToDateMode ? FALLBACK_CHANGELOG_2_1_1 : 'Performance improvements and bug fixes.');
      var localizedNotes = extractLocalizedChangelog(rawChangelog, isDe);
      changelogBox.innerHTML = renderMarkdownChangelogHtml(localizedNotes);
      changelogBox.scrollTop = 0;
    }

    // 6. Progress Row (hidden on open)
    var progressRow = document.getElementById('update-progress-row');
    if (progressRow) progressRow.style.display = 'none';

    // 7. Buttons
    var confirmBtn = document.getElementById('update-now-btn') || document.getElementById('update-confirm-btn');
    var laterBtn = document.getElementById('update-later-btn');

    if (confirmBtn) {
      if (isUpToDateMode) {
        confirmBtn.style.display = 'none';
      } else {
        confirmBtn.style.display = '';
        confirmBtn.disabled = false;
        var confirmText = confirmBtn.querySelector('#update-confirm-text') || confirmBtn.querySelector('span');
        var nowLabel = isDe ? 'Jetzt aktualisieren' : 'Update Now';
        if (confirmText) confirmText.textContent = nowLabel;
        else confirmBtn.textContent = nowLabel;
      }
    }

    if (laterBtn) {
      laterBtn.style.display = '';
      laterBtn.disabled = false;
      var laterLabel = isUpToDateMode
        ? (isDe ? 'Schließen' : 'Close')
        : (isDe ? 'Später' : 'Later');
      var laterSpan = laterBtn.querySelector('#update-later-text') || laterBtn.querySelector('span');
      if (laterSpan) laterSpan.textContent = laterLabel;
      else laterBtn.textContent = laterLabel;
    }

    // 8. Open modal
    if (window.TVApp && typeof window.TVApp.openModal === 'function') {
      window.TVApp.openModal(modal, isUpToDateMode ? laterBtn : confirmBtn);
    } else {
      modal.classList.add('active');
    }

    // 9. Spatial navigation focus
    var nav = window.SpatialNav || window.TVSpatialNav;
    if (nav) {
      if (typeof nav.pushBackHandler === 'function') {
        nav.pushBackHandler(function() {
          closeUpdateModal();
          return true;
        });
      }
      var targetFocus = isUpToDateMode ? laterBtn : (confirmBtn || laterBtn);
      if (targetFocus && typeof nav.setFocus === 'function') {
        nav.setFocus(targetFocus);
        setTimeout(function() {
          if (modal.classList.contains('active')) {
            nav.setFocus(targetFocus);
          }
        }, 120);
      }
    }
  }

  function openChangelogModal() {
    var activeVer = getActiveVersion();

    if (_pendingUpdate && isNewer(activeVer, _pendingUpdate.version)) {
      showUpdateModal(activeVer, _pendingUpdate.version, _pendingUpdate.body, false);
      return;
    }

    // Instant Mode B display using cached release notes or embedded fallback
    var notesToUse = _cachedReleaseNotes || FALLBACK_CHANGELOG_2_1_1;
    showUpdateModal(activeVer, activeVer, notesToUse, true);

    // If we haven't fetched from GitHub yet, check in background
    if (!_cachedReleaseNotes) {
      checkForUpdates().then(function(updateResult) {
        if (updateResult && updateResult.body) {
          _cachedReleaseNotes = updateResult.body;
        }
      }).catch(function(_) {});
    }
  }

  function closeUpdateModal() {
    var modal = document.getElementById('modal-update');
    if (!modal) return;

    var nav = window.SpatialNav || window.TVSpatialNav;
    if (nav && typeof nav.popBackHandler === 'function') {
      nav.popBackHandler();
    }

    if (window.TVApp && typeof window.TVApp.closeModal === 'function') {
      window.TVApp.closeModal(modal);
    } else {
      modal.classList.remove('active');
    }

    var verBadge = document.getElementById('accounts-version-badge');
    if (verBadge && verBadge.offsetParent !== null && nav && typeof nav.setFocus === 'function') {
      nav.setFocus(verBadge);
    } else if (nav && typeof nav.focusFirst === 'function') {
      nav.focusFirst();
    }
  }

  function getSha256(str) {
    if (window.TVBootloader && typeof window.TVBootloader.computeSha256 === 'function') {
      return Promise.resolve(window.TVBootloader.computeSha256(str));
    }
    if (window.crypto && window.crypto.subtle && typeof TextEncoder !== 'undefined') {
      return window.crypto.subtle.digest('SHA-256', new TextEncoder().encode(str))
        .then(function(buf) {
          var hex = '';
          var bytes = new Uint8Array(buf);
          for (var i = 0; i < bytes.length; i++) {
            hex += (bytes[i] < 16 ? '0' : '') + bytes[i].toString(16);
          }
          return hex.toLowerCase();
        });
    }
    return Promise.reject(new Error('No cryptographic SHA-256 engine available'));
  }

  function startOtaUpdate() {
    if (_isUpdating || !_pendingUpdate) return;
    _isUpdating = true;

    var progressRow = document.getElementById('update-progress-row');
    var progressFill = document.getElementById('update-progress-fill');
    var progressText = document.getElementById('update-progress-text');
    var confirmBtn = document.getElementById('update-now-btn') || document.getElementById('update-confirm-btn');
    var confirmText = confirmBtn ? (confirmBtn.querySelector('#update-confirm-text') || confirmBtn.querySelector('span')) : null;

    if (progressRow) progressRow.style.display = 'block';
    if (confirmBtn) confirmBtn.disabled = true;

    var lang = (window.TVI18n && typeof TVI18n.t === 'function') ? TVI18n.t('updating') : 'Updating...';
    if (confirmText) confirmText.textContent = lang;

    var filesToUpdate = [
      { name: 'style.css', path: 'smart_tv/css/style.css' },
      { name: 'icons.js', path: 'smart_tv/js/icons.js' },
      { name: 'i18n.js', path: 'smart_tv/js/i18n.js' },
      { name: 'm3u.js', path: 'smart_tv/js/m3u.js' },
      { name: 'storage.js', path: 'smart_tv/js/storage.js' },
      { name: 'api.js', path: 'smart_tv/js/api.js' },
      { name: 'sync.js', path: 'smart_tv/js/sync.js' },
      { name: 'spatial_nav.js', path: 'smart_tv/js/spatial_nav.js' },
      { name: 'virtual_list.js', path: 'smart_tv/js/virtual_list.js' },
      { name: 'diagnostics.js', path: 'smart_tv/js/diagnostics.js' },
      { name: 'subtitles.js', path: 'smart_tv/js/subtitles.js' },
      { name: 'player.js', path: 'smart_tv/js/player.js' },
      { name: 'updater.js', path: 'smart_tv/js/updater.js' },
      { name: 'app.js', path: 'smart_tv/js/app.js' }
    ];

    var total = filesToUpdate.length;
    var completed = 0;
    var downloadedBundle = {
      version: _pendingUpdate.version,
      updatedAt: Date.now(),
      hashes: {},
      files: {}
    };

    var rawBaseUrl = 'https://raw.githubusercontent.com/' + GITHUB_REPO + '/' + _pendingUpdate.tag + '/';
    var manifestUrl = rawBaseUrl + 'smart_tv/manifest.json?t=' + Date.now();

    if (progressText) progressText.textContent = 'Verifying manifest...';

    fetch(manifestUrl)
      .then(function(res) {
        if (!res.ok) throw new Error('Manifest download failed (HTTP ' + res.status + ')');
        return res.json();
      })
      .then(function(manifest) {
        if (!manifest || !manifest.files) {
          throw new Error('Invalid manifest format');
        }
        downloadedBundle.hashes = manifest.files;

        function fetchNext(index) {
          if (index >= total) {
            finishUpdate(downloadedBundle);
            return;
          }

          var fileInfo = filesToUpdate[index];
          var fileUrl = rawBaseUrl + fileInfo.path + '?t=' + Date.now();
          var expectedHash = (manifest.files[fileInfo.name] || '').toLowerCase();

          if (!expectedHash || expectedHash.length !== 64) {
            throw new Error('Missing expected hash for ' + fileInfo.name);
          }

          fetch(fileUrl)
            .then(function(res) {
              if (!res.ok) throw new Error('Download failed: ' + fileInfo.name);
              return res.text();
            })
            .then(function(content) {
              if (!content || content.length < 50 || (content.length < 100 && content.indexOf('404') !== -1)) {
                throw new Error('Invalid content for ' + fileInfo.name);
              }

              // Normalize CRLF to LF so OS line ending differences never cause hash mismatches
              var normalized = content.replace(/\r\n/g, '\n');

              return getSha256(normalized).then(function(actualHash) {
                if (actualHash !== expectedHash) {
                  throw new Error('Integrity check failed for ' + fileInfo.name + ' (hash mismatch)');
                }
                downloadedBundle.files[fileInfo.name] = normalized;
                completed++;
                var pct = Math.round((completed / total) * 100);
                if (progressFill) progressFill.style.width = pct + '%';
                if (progressText) progressText.textContent = pct + '% (' + fileInfo.name + ')';
                fetchNext(index + 1);
              });
            })
            .catch(function(err) {
              console.error('[TVUpdater] Update failed on ' + fileInfo.name + ':', err);
              if (progressText) {
                progressText.textContent = 'Fehler: ' + err.message;
                progressText.style.color = '#ef4444';
              }
              _isUpdating = false;
              if (confirmBtn) confirmBtn.disabled = false;
              if (confirmText) confirmText.textContent = 'Erneut versuchen';
            });
        }

        fetchNext(0);
      })
      .catch(function(err) {
        console.error('[TVUpdater] Manifest verification failed:', err);
        if (progressText) {
          progressText.textContent = 'Fehler: ' + err.message;
          progressText.style.color = '#ef4444';
        }
        _isUpdating = false;
        if (confirmBtn) confirmBtn.disabled = false;
        if (confirmText) confirmText.textContent = 'Erneut versuchen';
      });
  }

  function finishUpdate(bundle) {
    try {
      localStorage.setItem(OTA_STORAGE_KEY, JSON.stringify(bundle));
      var successMsg = (window.TVI18n && typeof TVI18n.t === 'function')
        ? TVI18n.t('update_success')
        : 'Update completed! Reloading...';

      var progressText = document.getElementById('update-progress-text');
      if (progressText) {
        progressText.textContent = successMsg;
        progressText.style.color = '#22c55e';
      }

      setTimeout(function() {
        window.location.reload();
      }, 1200);
    } catch (e) {
      console.error('[TVUpdater] Failed to store update bundle:', e);
      _isUpdating = false;
    }
  }

  function applyCachedOtaBundle() {
    // If the dynamic bootloader is active, the OTA bundle was already booted before updater.js
    if (window.TVBootloader) return;

    try {
      var saved = localStorage.getItem(OTA_STORAGE_KEY);
      if (!saved) return;

      var bundle = JSON.parse(saved);
      if (!bundle || !bundle.version || !isNewer(CURRENT_VERSION, bundle.version)) {
        localStorage.removeItem(OTA_STORAGE_KEY);
        return;
      }

      if (!bundle.files) return;

      if (bundle.files['style.css']) {
        var styleEl = document.getElementById('goat-ota-style') || document.createElement('style');
        styleEl.id = 'goat-ota-style';
        styleEl.textContent = bundle.files['style.css'];
        document.head.appendChild(styleEl);
      }
    } catch (e) {
      console.warn('[TVUpdater] Error applying cached bundle, reverting to factory:', e);
      localStorage.removeItem(OTA_STORAGE_KEY);
    }
  }

  function init() {
    applyCachedOtaBundle();

    var closeBtn = document.getElementById('update-close-btn');
    var laterBtn = document.getElementById('update-later-btn');
    var confirmBtn = document.getElementById('update-now-btn') || document.getElementById('update-confirm-btn');

    if (closeBtn) closeBtn.addEventListener('click', closeUpdateModal);
    if (laterBtn) laterBtn.addEventListener('click', closeUpdateModal);
    if (confirmBtn) confirmBtn.addEventListener('click', startOtaUpdate);

    // Auto-bind #accounts-version-badge to open changelog modal
    var verBadge = document.getElementById('accounts-version-badge');
    if (verBadge) {
      verBadge.addEventListener('click', function() {
        openChangelogModal();
      });
    }

    // Run update check in background 5s after boot (after splash and screen settle)
    setTimeout(checkForUpdates, 5000);
  }

  window.TVUpdater = {
    init: init,
    checkForUpdates: checkForUpdates,
    openChangelogModal: openChangelogModal,
    showUpdateModal: showUpdateModal,
    extractLocalizedChangelog: extractLocalizedChangelog,
    renderMarkdownChangelogHtml: renderMarkdownChangelogHtml,
    getVersion: getActiveVersion,
    getActiveVersion: getActiveVersion,
    APP_VERSION: APP_VERSION,
    FALLBACK_CHANGELOG_2_1_1: FALLBACK_CHANGELOG_2_1_1
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
