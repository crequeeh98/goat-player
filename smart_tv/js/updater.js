// smart_tv/js/updater.js - Universal In-App OTA Updater v2 for Samsung Tizen & LG webOS
(function() {
  'use strict';

  var APP_VERSION = '2.1.3';
  var CURRENT_VERSION = (window.TVBootloader && window.TVBootloader.getBaseVersion)
    ? window.TVBootloader.getBaseVersion()
    : APP_VERSION;
  var GITHUB_REPO = 'crequeeh98/goat-player';

  var _pendingUpdate = null;
  var _cachedReleaseNotes = null;
  var _isUpdating = false;

  var FALLBACK_CHANGELOG = [
    '### 🇩🇪 Änderungen & Neuerungen (v2.1.3)',
    '- **Smart TV UI/UX Overhaul & webOS 6.5 Kompatibilität**:',
    '  - *Moderne 10-Foot Oberfläche*: Scharfe SVG-Vektor-Icons (`window.TVIcons`), kompaktes 1-Spalten Account-/Login-Layout und D-Pad-optimierter Markdown-Changelog.',
    '  - *Tizen & Finish*: Deutsch als Standardsprache bei Neuinstallation, sauberes Suchfeld-Layout vor dem Tune-Button auf Samsung Tizen und einzelner Haken im „Fertig“-Button.',
    '- **Kategorien-Manager & Eigene Listen**:',
    '  - *Kategorien*: Ein-/Ausblenden per OK, Sortieren via Gelb/OK-Halten sowie `A-Z Zurücksetzen` und `Alle ein-/ausblenden`.',
    '  - *Custom Lists & Sender-Sortierung*: Eigene Listen (Live, Filme, Serien), Sender-Verschiebemodus (▲/▼), Kontextmenü per OK-Halten und selektive Sync-Bereiche.',
    '',
    '---',
    '',
    '### 🇬🇧 Changes & Improvements (v2.1.3)',
    '- **Smart TV UI/UX Overhaul & webOS 6.5 Compatibility**:',
    '  - *Modern 10-Foot Interface*: Crisp SVG vector icons (`window.TVIcons`), compact 1-column account/login layout, and D-Pad-ready Markdown changelog viewer.',
    '  - *Tizen & Polish*: German default UI language on fresh installs, constrained category search width next to the tune button on Samsung Tizen, and single checkmark on the Done button.',
    '- **Category Manager & Custom Lists**:',
    '  - *Categories*: Toggle visibility with OK, reorder via Yellow/Hold-OK, plus `Reset A-Z` and `Show/Hide All`.',
    '  - *Custom Lists & Channel Reordering*: Personal playlists (Live, Movies, Series), channel move mode (▲/▼), Hold-OK context menu, and selective sync scopes.'
  ].join('\n');

  function getActiveVersion() {
    try {
      if (window.__GOAT_TV_VERSION__) {
        return window.__GOAT_TV_VERSION__;
      }
      if (window.TVBootloader && typeof window.TVBootloader.getActiveVersion === 'function') {
        return window.TVBootloader.getActiveVersion();
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
    escaped = escaped.replace(/`([^`]+)`/g, '<code class="changelog-code">$1</code>');
    escaped = escaped.replace(/\*\*([^*]+)\*\*/g, '<strong style="color:#FFFFFF;font-weight:700;">$1</strong>');
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
      var parts = normalized.split(/\n---+\n|\n---+\s*$/);
      if (parts.length >= 2) {
        section = isGerman ? parts[0] : parts[1];
      } else {
        section = normalized;
      }
    }

    section = section.replace(/^(?:[\r\n\s]|---+|#{1,4}\s*(?:🇩🇪|🇬🇧|🇺🇸|[^\n]*))+/i, '').trim();
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

      if (/^#{1,4}\s+/.test(trimmed)) {
        var headerText = trimmed.replace(/^#{1,4}\s+/, '');
        html += '<div class="changelog-h3">' + formatInlineMarkdown(headerText) + '</div>';
        continue;
      }

      var isSubBullet = /^(\s{2,}|\t)[-*•]\s+/.test(line);
      var isBullet = isSubBullet || /^[-*•]\s+/.test(trimmed);

      if (isBullet) {
        var bulletContent = trimmed.replace(/^[-*•]\s+/, '');
        var rowClass = isSubBullet ? 'changelog-bullet-row changelog-subbullet-row' : 'changelog-bullet-row';
        html += '<div class="' + rowClass + '"><span class="changelog-bullet-dot"></span><span class="changelog-bullet-text">' + formatInlineMarkdown(bulletContent) + '</span></div>';
        continue;
      }

      html += '<div class="changelog-p">' + formatInlineMarkdown(trimmed) + '</div>';
    }

    return html;
  }

  function resolveUpdateFromManifest(manifest, latestTag, releaseBody, customBaseUrl) {
    if (!manifest || !manifest.version) return null;
    var tvVersion = String(manifest.version).replace(/^v/, '');
    var tag = latestTag || manifest.tag || ('v' + tvVersion);
    var activeVer = getActiveVersion();
    var currentProtocol = (window.TVBootloader && window.TVBootloader.OTA_PROTOCOL) ? window.TVBootloader.OTA_PROTOCOL : 1;
    var minProtocol = manifest.minBootloaderProtocol || 1;
    var requiresNative = minProtocol > currentProtocol;

    var baseUrl = customBaseUrl || ('https://raw.githubusercontent.com/' + GITHUB_REPO + '/' + tag + '/');

    if (isNewer(activeVer, tvVersion)) {
      _pendingUpdate = {
        version: tvVersion,
        tag: tag,
        baseUrl: baseUrl,
        manifest: manifest,
        requiresNativePackage: requiresNative,
        body: releaseBody || manifest.releaseNotes || ''
      };
      showUpdateModal(activeVer, tvVersion, _pendingUpdate.body, false);
      return _pendingUpdate;
    }
    return {
      version: tvVersion,
      tag: tag,
      body: releaseBody || '',
      hasUpdate: false
    };
  }

  function checkForUpdates(customBaseUrl) {
    var overrideBase = customBaseUrl || window.__GOAT_OTA_BASE_URL__ || null;
    if (overrideBase) {
      if (overrideBase.charAt(overrideBase.length - 1) !== '/') overrideBase += '/';
      var customManifestUrl = overrideBase + 'smart_tv/manifest.json?t=' + Date.now();
      return fetch(customManifestUrl)
        .then(function(r) {
          if (!r.ok) throw new Error('HTTP ' + r.status);
          return r.json();
        })
        .then(function(manifest) {
          return resolveUpdateFromManifest(manifest, manifest && manifest.tag, manifest && manifest.releaseNotes, overrideBase);
        })
        .catch(function(err) {
          console.warn('[TVUpdater] Custom OTA check failed:', err.message);
          return null;
        });
    }

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

        var rawBaseUrl = 'https://raw.githubusercontent.com/' + GITHUB_REPO + '/' + latestTag + '/';
        var manifestUrl = rawBaseUrl + 'smart_tv/manifest.json?t=' + Date.now();

        return fetch(manifestUrl)
          .then(function(mRes) {
            if (mRes.ok) return mRes.json();
            return null;
          })
          .then(function(manifest) {
            if (!manifest) {
              manifest = { version: latestTag.replace(/^v/, ''), tag: latestTag };
            }
            return resolveUpdateFromManifest(manifest, latestTag, data.body || '', rawBaseUrl);
          });
      })
      .catch(function(err) {
        // Fallback directly to raw main manifest if GitHub API is rate-limited (HTTP 403/429)
        var fallbackManifestUrl = 'https://raw.githubusercontent.com/' + GITHUB_REPO + '/main/smart_tv/manifest.json?t=' + Date.now();
        return fetch(fallbackManifestUrl)
          .then(function(fRes) {
            if (!fRes.ok) throw err;
            return fRes.json();
          })
          .then(function(manifest) {
            if (!manifest || !manifest.version) return null;
            var tag = manifest.tag || ('v' + String(manifest.version).replace(/^v/, ''));
            var rawBaseUrl = 'https://raw.githubusercontent.com/' + GITHUB_REPO + '/' + tag + '/';
            return resolveUpdateFromManifest(manifest, tag, manifest.releaseNotes || '', rawBaseUrl);
          })
          .catch(function() {
            console.log('[TVUpdater] Check skipped / offline:', err.message);
            return null;
          });
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

    var requiresNative = !isUpToDateMode && _pendingUpdate && _pendingUpdate.requiresNativePackage;

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
      if (isUpToDateMode) {
        descEl.textContent = isDe ? 'Du nutzt die aktuellste Version von GOATPlayer TV.' : 'You are using the latest version of GOATPlayer TV.';
      } else if (requiresNative) {
        descEl.textContent = isDe
          ? 'Dieses System-Update erfordert einmalig eine Paket-Neuinstallation (.ipk / .wgt).'
          : 'This system update requires a one-time package installation (.ipk / .wgt).';
      } else {
        descEl.textContent = isDe ? 'Eine neue Version von GOATPlayer TV ist bereit zur Installation.' : 'A new version of GOATPlayer TV is ready to install.';
      }
    }

    // 5. Changelog Box with localized markdown
    var changelogBox = document.getElementById('update-changelog-box');
    if (changelogBox) {
      var rawChangelog = changelog || (isUpToDateMode ? FALLBACK_CHANGELOG : 'Performance improvements and bug fixes.');
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
      if (isUpToDateMode || requiresNative) {
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
      var laterLabel = (isUpToDateMode || requiresNative)
        ? (isDe ? 'Schließen' : 'Close')
        : (isDe ? 'Später' : 'Later');
      var laterSpan = laterBtn.querySelector('#update-later-text') || laterBtn.querySelector('span');
      if (laterSpan) laterSpan.textContent = laterLabel;
      else laterBtn.textContent = laterLabel;
    }

    // 8. Open modal
    if (window.TVApp && typeof window.TVApp.openModal === 'function') {
      window.TVApp.openModal(modal, (isUpToDateMode || requiresNative) ? laterBtn : confirmBtn);
    } else {
      modal.classList.add('active');
    }

    // 9. Spatial navigation focus
    var nav = window.SpatialNav || window.TVSpatialNav;
    if (nav) {
      if (typeof nav.pushBackHandler === 'function') {
        if (!modal._updateBackHandler) {
          modal._updateBackHandler = function() {
            if (modal && modal.classList.contains('active')) {
              closeUpdateModal();
              return true;
            }
            return false;
          };
        }
        if (typeof nav.removeBackHandler === 'function') {
          nav.removeBackHandler(modal._updateBackHandler);
        }
        nav.pushBackHandler(modal._updateBackHandler);
      }
      var targetFocus = (isUpToDateMode || requiresNative) ? laterBtn : (confirmBtn || laterBtn);
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

    var notesToUse = _cachedReleaseNotes || FALLBACK_CHANGELOG;
    showUpdateModal(activeVer, activeVer, notesToUse, true);

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
    if (nav && modal._updateBackHandler && typeof nav.removeBackHandler === 'function') {
      nav.removeBackHandler(modal._updateBackHandler);
    } else if (nav && typeof nav.popBackHandler === 'function') {
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

  function computeSha256Promise(input, isBinaryBytes) {
    return new Promise(function(resolve, reject) {
      if (window.TVBootloader && typeof window.TVBootloader.computeSha256Async === 'function') {
        window.TVBootloader.computeSha256Async(input, !!isBinaryBytes, function(err, hash) {
          if (err || !hash) reject(err || new Error('SHA-256 computation failed'));
          else resolve(hash.toLowerCase());
        });
        return;
      }
      if (!isBinaryBytes && window.crypto && window.crypto.subtle && typeof TextEncoder !== 'undefined') {
        window.crypto.subtle.digest('SHA-256', new TextEncoder().encode(String(input)))
          .then(function(buf) {
            var hex = '';
            var bytes = new Uint8Array(buf);
            for (var i = 0; i < bytes.length; i++) {
              hex += (bytes[i] < 16 ? '0' : '') + bytes[i].toString(16);
            }
            resolve(hex.toLowerCase());
          })
          .catch(reject);
        return;
      }
      if (!isBinaryBytes && window.TVBootloader && typeof window.TVBootloader.computeSha256 === 'function') {
        resolve(window.TVBootloader.computeSha256(String(input)));
        return;
      }
      reject(new Error('No cryptographic SHA-256 engine available'));
    });
  }

  function bytesToBase64DataUri(bytes, mimeType) {
    var binary = '';
    var chunkSize = 8192;
    for (var i = 0; i < bytes.length; i += chunkSize) {
      var slice = bytes.subarray(i, Math.min(i + chunkSize, bytes.length));
      binary += String.fromCharCode.apply(null, slice);
    }
    return 'data:' + (mimeType || 'image/png') + ';base64,' + btoa(binary);
  }

  function buildDownloadPlanFromManifest(manifest) {
    var plan = [];
    if (!manifest) return plan;

    if (manifest.html && manifest.html.name && manifest.html.sha256) {
      plan.push({
        name: manifest.html.name,
        path: manifest.html.path || 'smart_tv/index.html',
        sha256: manifest.html.sha256,
        kind: 'html'
      });
    }

    var styles = manifest.styles || [];
    if (styles.length === 0 && manifest.files && manifest.files['style.css']) {
      styles = [{ name: 'style.css', path: 'smart_tv/css/style.css', sha256: manifest.files['style.css'] }];
    }
    for (var i = 0; i < styles.length; i++) {
      if (styles[i] && styles[i].name && styles[i].sha256) {
        plan.push({
          name: styles[i].name,
          path: styles[i].path || ('smart_tv/css/' + styles[i].name),
          sha256: styles[i].sha256,
          kind: 'style'
        });
      }
    }

    var vendors = manifest.vendorScripts || [];
    for (var v = 0; v < vendors.length; v++) {
      if (vendors[v] && vendors[v].name && vendors[v].sha256) {
        plan.push({
          name: vendors[v].name,
          path: vendors[v].path || ('smart_tv/js/' + vendors[v].name),
          sha256: vendors[v].sha256,
          kind: 'vendor'
        });
      }
    }

    var scripts = manifest.scripts || [];
    if (scripts.length === 0 && manifest.files) {
      var legacyNames = [
        'icons.js', 'i18n.js', 'm3u.js', 'storage.js', 'api.js',
        'sync.js', 'spatial_nav.js', 'virtual_list.js', 'diagnostics.js',
        'subtitles.js', 'player.js', 'updater.js', 'app.js'
      ];
      for (var l = 0; l < legacyNames.length; l++) {
        var ln = legacyNames[l];
        if (manifest.files[ln]) {
          plan.push({
            name: ln,
            path: 'smart_tv/js/' + ln,
            sha256: manifest.files[ln],
            kind: 'script'
          });
        }
      }
    } else {
      for (var s = 0; s < scripts.length; s++) {
        if (scripts[s] && scripts[s].name && scripts[s].sha256) {
          plan.push({
            name: scripts[s].name,
            path: scripts[s].path || ('smart_tv/js/' + scripts[s].name),
            sha256: scripts[s].sha256,
            kind: 'script'
          });
        }
      }
    }

    var assets = manifest.assets || [];
    for (var a = 0; a < assets.length; a++) {
      if (assets[a] && assets[a].name && assets[a].sha256) {
        plan.push({
          name: assets[a].name,
          path: assets[a].path || ('smart_tv/' + assets[a].name),
          sha256: assets[a].sha256,
          mime: assets[a].mime || 'image/png',
          kind: 'asset'
        });
      }
    }

    return plan;
  }

  function validateJsSyntax(code, fileName) {
    try {
      // Dry-compile without executing to catch syntax errors before saving
      new Function(code);
    } catch (syntaxErr) {
      throw new Error('Syntax error in ' + fileName + ': ' + (syntaxErr.message || String(syntaxErr)));
    }
  }

  function startOtaUpdate() {
    if (_isUpdating || !_pendingUpdate) return;
    if (!window.TVBootloader || !window.TVBootloader.otaVault) {
      console.error('[TVUpdater] TVBootloader.otaVault not available');
      return;
    }
    _isUpdating = true;

    var progressRow = document.getElementById('update-progress-row');
    var progressFill = document.getElementById('update-progress-fill');
    var progressText = document.getElementById('update-progress-text');
    var confirmBtn = document.getElementById('update-now-btn') || document.getElementById('update-confirm-btn');
    var confirmText = confirmBtn ? (confirmBtn.querySelector('#update-confirm-text') || confirmBtn.querySelector('span')) : null;
    var isDe = (window.TVI18n && typeof TVI18n.getLanguage === 'function') ? (TVI18n.getLanguage() === 'de') : false;

    if (progressRow) progressRow.style.display = 'block';
    if (progressFill) progressFill.style.width = '2%';
    if (progressText) {
      progressText.style.color = '';
      progressText.textContent = isDe ? 'Manifest wird geprüft...' : 'Verifying manifest...';
    }
    if (confirmBtn) confirmBtn.disabled = true;

    var lang = (window.TVI18n && typeof TVI18n.t === 'function') ? TVI18n.t('updating') : (isDe ? 'Aktualisiere...' : 'Updating...');
    if (confirmText) confirmText.textContent = lang;

    var rawBaseUrl = _pendingUpdate.baseUrl || ('https://raw.githubusercontent.com/' + GITHUB_REPO + '/' + _pendingUpdate.tag + '/');
    var manifestUrl = rawBaseUrl + 'smart_tv/manifest.json?t=' + Date.now();

    function handleUpdateFailure(err) {
      console.error('[TVUpdater] OTA update failed:', err);
      if (progressText) {
        progressText.textContent = (isDe ? 'Fehler: ' : 'Error: ') + (err && err.message ? err.message : String(err));
        progressText.style.color = '#ef4444';
      }
      _isUpdating = false;
      if (confirmBtn) confirmBtn.disabled = false;
      if (confirmText) confirmText.textContent = isDe ? 'Erneut versuchen' : 'Retry';
    }

    fetch(manifestUrl)
      .then(function(res) {
        if (!res.ok) throw new Error('Manifest download failed (HTTP ' + res.status + ')');
        return res.json();
      })
      .then(function(manifest) {
        var filesToUpdate = buildDownloadPlanFromManifest(manifest);
        if (!filesToUpdate.length) {
          throw new Error('Invalid or empty manifest');
        }

        var vault = window.TVBootloader.otaVault;
        vault.prepareStagingSlot(manifest, function(prepErr, stagingSlot) {
          if (prepErr || !stagingSlot) {
            handleUpdateFailure(prepErr || new Error('Failed to prepare staging slot'));
            return;
          }

          var total = filesToUpdate.length;
          var completed = 0;

          function stepProgress(fileName, skipped) {
            completed++;
            var pct = Math.min(95, Math.round((completed / total) * 95));
            if (progressFill) progressFill.style.width = pct + '%';
            if (progressText) {
              progressText.textContent = pct + '% (' + fileName + (skipped ? ' ✓' : '') + ')';
            }
          }

          function fetchAndStageNext(index) {
            if (index >= total) {
              if (progressText) {
                progressText.textContent = isDe ? 'Installation wird überprüft...' : 'Verifying installation...';
              }
              vault.verifyAndActivateSlot(stagingSlot, manifest, function(actErr) {
                if (actErr) {
                  handleUpdateFailure(actErr);
                  return;
                }
                if (progressFill) progressFill.style.width = '100%';
                var successMsg = (window.TVI18n && typeof TVI18n.t === 'function')
                  ? TVI18n.t('update_success')
                  : (isDe ? 'Update erfolgreich! Neustart...' : 'Update completed! Reloading...');
                if (progressText) {
                  progressText.textContent = successMsg;
                  progressText.style.color = '#22c55e';
                }
                setTimeout(function() {
                  window.location.reload();
                }, 1000);
              });
              return;
            }

            var fileInfo = filesToUpdate[index];
            var expectedHash = String(fileInfo.sha256 || '').toLowerCase();
            if (!expectedHash || expectedHash.length !== 64) {
              handleUpdateFailure(new Error('Missing expected SHA-256 for ' + fileInfo.name));
              return;
            }

            // Delta check: if factory file on disk already has the exact same SHA-256, reference factory directly
            var factoryHash = (window.TVBootloader && typeof window.TVBootloader.getFactoryHash === 'function')
              ? window.TVBootloader.getFactoryHash(fileInfo.name)
              : null;

            if (factoryHash && factoryHash === expectedHash) {
              vault.saveStagingFile(stagingSlot, {
                name: fileInfo.name,
                sha256: expectedHash,
                source: 'factory',
                mime: fileInfo.mime || '',
                content: null
              }, function(saveErr) {
                if (saveErr) {
                  handleUpdateFailure(saveErr);
                  return;
                }
                stepProgress(fileInfo.name, true);
                fetchAndStageNext(index + 1);
              });
              return;
            }

            var fileUrl = rawBaseUrl + fileInfo.path + '?t=' + Date.now();

            if (fileInfo.kind === 'asset') {
              fetch(fileUrl)
                .then(function(res) {
                  if (!res.ok) throw new Error('Asset download failed: ' + fileInfo.name);
                  return res.arrayBuffer();
                })
                .then(function(buf) {
                  var bytes = new Uint8Array(buf);
                  if (!bytes || bytes.length < 16) {
                    throw new Error('Invalid binary asset: ' + fileInfo.name);
                  }
                  return computeSha256Promise(bytes, true).then(function(actualHash) {
                    if (actualHash !== expectedHash) {
                      throw new Error('Integrity check failed for ' + fileInfo.name + ' (hash mismatch)');
                    }
                    var dataUri = bytesToBase64DataUri(bytes, fileInfo.mime || 'image/png');
                    bytes = null;
                    return new Promise(function(resolve, reject) {
                      vault.saveStagingFile(stagingSlot, {
                        name: fileInfo.name,
                        sha256: actualHash,
                        source: 'ota',
                        mime: fileInfo.mime || 'image/png',
                        content: dataUri
                      }, function(err) {
                        dataUri = null;
                        if (err) reject(err);
                        else resolve();
                      });
                    });
                  });
                })
                .then(function() {
                  stepProgress(fileInfo.name, false);
                  fetchAndStageNext(index + 1);
                })
                .catch(handleUpdateFailure);
              return;
            }

            // Text file (html, style, vendor, script)
            fetch(fileUrl)
              .then(function(res) {
                if (!res.ok) throw new Error('Download failed: ' + fileInfo.name);
                return res.text();
              })
              .then(function(content) {
                if (!content || content.length < 20) {
                  throw new Error('Invalid content for ' + fileInfo.name);
                }
                var normalized = content.replace(/\r\n/g, '\n');
                content = null;

                return computeSha256Promise(normalized, false).then(function(actualHash) {
                  if (actualHash !== expectedHash) {
                    throw new Error('Integrity check failed for ' + fileInfo.name + ' (hash mismatch)');
                  }
                  if (fileInfo.kind === 'script' || fileInfo.kind === 'vendor') {
                    validateJsSyntax(normalized, fileInfo.name);
                  }
                  return new Promise(function(resolve, reject) {
                    vault.saveStagingFile(stagingSlot, {
                      name: fileInfo.name,
                      sha256: actualHash,
                      source: 'ota',
                      content: normalized
                    }, function(err) {
                      normalized = null; // Free RAM immediately after write
                      if (err) reject(err);
                      else resolve();
                    });
                  });
                });
              })
              .then(function() {
                stepProgress(fileInfo.name, false);
                fetchAndStageNext(index + 1);
              })
              .catch(handleUpdateFailure);
          }

          fetchAndStageNext(0);
        });
      })
      .catch(handleUpdateFailure);
  }

  function init() {
    var closeBtn = document.getElementById('update-close-btn');
    var laterBtn = document.getElementById('update-later-btn');
    var confirmBtn = document.getElementById('update-now-btn') || document.getElementById('update-confirm-btn');

    if (closeBtn) closeBtn.addEventListener('click', closeUpdateModal);
    if (laterBtn) laterBtn.addEventListener('click', closeUpdateModal);
    if (confirmBtn) confirmBtn.addEventListener('click', startOtaUpdate);

    var verBadge = document.getElementById('accounts-version-badge');
    if (verBadge) {
      verBadge.addEventListener('click', function() {
        openChangelogModal();
      });
    }

    setTimeout(function() {
      checkForUpdates();
    }, 5000);
  }

  window.TVUpdater = {
    init: init,
    checkForUpdates: checkForUpdates,
    startOtaUpdate: startOtaUpdate,
    openChangelogModal: openChangelogModal,
    showUpdateModal: showUpdateModal,
    extractLocalizedChangelog: extractLocalizedChangelog,
    renderMarkdownChangelogHtml: renderMarkdownChangelogHtml,
    getVersion: getActiveVersion,
    getActiveVersion: getActiveVersion,
    APP_VERSION: APP_VERSION,
    FALLBACK_CHANGELOG: FALLBACK_CHANGELOG
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
