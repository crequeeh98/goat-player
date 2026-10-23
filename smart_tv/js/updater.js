// smart_tv/js/updater.js - In-App OTA Updater for Samsung Tizen & LG webOS
(function() {
  'use strict';

  var CURRENT_VERSION = '1.2.4';
  var GITHUB_REPO = 'crequeeh98/goat-player';
  var OTA_STORAGE_KEY = 'goat_tv_ota_bundle';

  var _pendingUpdate = null;
  var _isUpdating = false;

  function getActiveVersion() {
    try {
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
      var c = current.replace(/^v/, '').split('.').map(function(n) { return parseInt(n, 10) || 0; });
      var l = latest.replace(/^v/, '').split('.').map(function(n) { return parseInt(n, 10) || 0; });
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

  function checkForUpdates() {
    var url = 'https://api.github.com/repos/' + GITHUB_REPO + '/releases/latest';

    fetch(url, { headers: { 'Accept': 'application/vnd.github.v3+json' } })
      .then(function(res) {
        if (!res.ok) throw new Error('HTTP ' + res.status);
        return res.json();
      })
      .then(function(data) {
        if (!data || !data.tag_name) return;

        var latestTag = data.tag_name.trim();
        var latestVer = latestTag.replace(/^v/, '');

        var activeVer = getActiveVersion();

        if (isNewer(activeVer, latestVer)) {
          _pendingUpdate = {
            version: latestVer,
            tag: latestTag,
            body: data.body || '',
            assets: data.assets || []
          };
          showUpdateModal(activeVer, latestVer, _pendingUpdate.body);
        }
      })
      .catch(function(err) {
        console.log('[TVUpdater] Check skipped / offline:', err.message);
      });
  }

  function showUpdateModal(currentVer, latestVer, changelog) {
    var modal = document.getElementById('modal-update');
    if (!modal) return;

    var badge = document.getElementById('update-version-badge');
    if (badge) {
      badge.textContent = 'v' + currentVer + ' → v' + latestVer;
    }

    var changelogBox = document.getElementById('update-changelog-box');
    if (changelogBox) {
      changelogBox.textContent = changelog || 'Performance improvements and bug fixes.';
    }

    var progressRow = document.getElementById('update-progress-row');
    if (progressRow) progressRow.style.display = 'none';

    var confirmBtn = document.getElementById('update-confirm-btn');
    if (confirmBtn) {
      confirmBtn.disabled = false;
      var lang = (window.TVI18n && typeof TVI18n.t === 'function') ? TVI18n.t('update_now') : 'Update Now';
      var confirmText = document.getElementById('update-confirm-text');
      if (confirmText) confirmText.textContent = lang;
    }

    if (window.TVApp && typeof window.TVApp.openModal === 'function') {
      window.TVApp.openModal(modal, confirmBtn);
    } else {
      modal.classList.add('active');
    }

    var nav = window.SpatialNav || window.TVSpatialNav;
    if (nav) {
      if (typeof nav.pushBackHandler === 'function') {
        nav.pushBackHandler(function() {
          closeUpdateModal();
          return true;
        });
      }
      if (confirmBtn && typeof nav.setFocus === 'function') {
        nav.setFocus(confirmBtn);
        setTimeout(function() {
          if (modal.classList.contains('active')) {
            nav.setFocus(confirmBtn);
          }
        }, 120);
      }
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
      if (nav && typeof nav.focusFirst === 'function') nav.focusFirst();
    }
  }

  function startOtaUpdate() {
    if (_isUpdating || !_pendingUpdate) return;
    _isUpdating = true;

    var progressRow = document.getElementById('update-progress-row');
    var progressFill = document.getElementById('update-progress-fill');
    var progressText = document.getElementById('update-progress-text');
    var confirmBtn = document.getElementById('update-confirm-btn');
    var confirmText = document.getElementById('update-confirm-text');

    if (progressRow) progressRow.style.display = 'block';
    if (confirmBtn) confirmBtn.disabled = true;

    var lang = (window.TVI18n && typeof TVI18n.t === 'function') ? TVI18n.t('updating') : 'Updating...';
    if (confirmText) confirmText.textContent = lang;

    var filesToUpdate = [
      { name: 'app.js', path: 'smart_tv/js/app.js' },
      { name: 'player.js', path: 'smart_tv/js/player.js' },
      { name: 'spatial_nav.js', path: 'smart_tv/js/spatial_nav.js' },
      { name: 'subtitles.js', path: 'smart_tv/js/subtitles.js' },
      { name: 'style.css', path: 'smart_tv/css/style.css' }
    ];

    var total = filesToUpdate.length;
    var completed = 0;
    var downloadedBundle = {
      version: _pendingUpdate.version,
      updatedAt: Date.now(),
      files: {}
    };

    var rawBaseUrl = 'https://raw.githubusercontent.com/' + GITHUB_REPO + '/' + _pendingUpdate.tag + '/';

    function fetchNext(index) {
      if (index >= total) {
        finishUpdate(downloadedBundle);
        return;
      }

      var fileInfo = filesToUpdate[index];
      var fileUrl = rawBaseUrl + fileInfo.path + '?t=' + Date.now();

      fetch(fileUrl)
        .then(function(res) {
          if (!res.ok) throw new Error('File download failed: ' + fileInfo.name);
          return res.text();
        })
        .then(function(content) {
          if (!content || content.indexOf('404: Not Found') !== -1 || content.length < 50) {
            throw new Error('Invalid content for ' + fileInfo.name);
          }
          downloadedBundle.files[fileInfo.name] = content;
          completed++;
          var pct = Math.round((completed / total) * 100);
          if (progressFill) progressFill.style.width = pct + '%';
          if (progressText) progressText.textContent = pct + '%';
          fetchNext(index + 1);
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
    try {
      var saved = localStorage.getItem(OTA_STORAGE_KEY);
      if (!saved) return;

      var bundle = JSON.parse(saved);
      if (!bundle || !bundle.version || !isNewer(CURRENT_VERSION, bundle.version)) {
        localStorage.removeItem(OTA_STORAGE_KEY);
        return;
      }

      if (!bundle.files) return;

      // Dynamically inject updated CSS if present
      if (bundle.files['style.css']) {
        var styleEl = document.createElement('style');
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
    var confirmBtn = document.getElementById('update-confirm-btn');

    if (closeBtn) closeBtn.addEventListener('click', closeUpdateModal);
    if (laterBtn) laterBtn.addEventListener('click', closeUpdateModal);
    if (confirmBtn) confirmBtn.addEventListener('click', startOtaUpdate);

    // Run update check in background 5s after boot (after splash and screen settle)
    setTimeout(checkForUpdates, 5000);
  }

  window.TVUpdater = {
    init: init,
    checkForUpdates: checkForUpdates,
    getVersion: getActiveVersion
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
