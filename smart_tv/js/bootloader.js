// smart_tv/js/bootloader.js - Dynamic OTA Bootloader for Samsung Tizen & LG webOS
(function() {
  'use strict';

  var BASE_VERSION = '2.0.3';
  var OTA_STORAGE_KEY = 'goat_tv_ota_bundle';
  var CRASH_CANARY_KEY = 'goat_ota_boot_in_progress';

  var APP_SCRIPTS = [
    'icons.js',
    'i18n.js',
    'm3u.js',
    'storage.js',
    'api.js',
    'sync.js',
    'spatial_nav.js',
    'virtual_list.js',
    'diagnostics.js',
    'subtitles.js',
    'player.js',
    'updater.js',
    'app.js'
  ];

  function isNewer(current, latest) {
    try {
      var c = (current || '0.0.0').replace(/^v/, '').split('.').map(function(n) { return parseInt(n, 10) || 0; });
      var l = (latest || '0.0.0').replace(/^v/, '').split('.').map(function(n) { return parseInt(n, 10) || 0; });
      for (var i = 0; i < 3; i++) {
        var cv = c[i] || 0;
        var lv = l[i] || 0;
        if (lv > cv) return true;
        if (lv < cv) return false;
      }
    } catch (_) {}
    return false;
  }

  function getCachedBundle() {
    try {
      var raw = localStorage.getItem(OTA_STORAGE_KEY);
      if (!raw) return null;
      var bundle = JSON.parse(raw);
      if (!bundle || !bundle.version || !bundle.files) return null;

      // Discard OTA bundle if factory/package version is newer or equal
      if (!isNewer(BASE_VERSION, bundle.version)) {
        console.log('[Bootloader] Factory version (' + BASE_VERSION + ') >= OTA version (' + bundle.version + '), clearing OTA cache');
        localStorage.removeItem(OTA_STORAGE_KEY);
        return null;
      }

      // Check critical files
      if (!bundle.files['app.js'] || !bundle.files['player.js'] || !bundle.files['spatial_nav.js']) {
        console.warn('[Bootloader] Incomplete OTA bundle detected, discarding');
        localStorage.removeItem(OTA_STORAGE_KEY);
        return null;
      }

      return bundle;
    } catch (e) {
      console.warn('[Bootloader] Error reading OTA bundle:', e);
      try { localStorage.removeItem(OTA_STORAGE_KEY); } catch (_) {}
      return null;
    }
  }

  function loadFactoryScripts() {
    for (var i = 0; i < APP_SCRIPTS.length; i++) {
      var name = APP_SCRIPTS[i];
      document.write('<script src="js/' + name + '?v=' + BASE_VERSION + '"><\/script>');
    }
  }

  function boot() {
    var crashCount = 0;
    try {
      crashCount = parseInt(sessionStorage.getItem(CRASH_CANARY_KEY) || '0', 10);
    } catch (_) {}

    if (crashCount >= 2) {
      console.error('[Bootloader] Crash loop detected (' + crashCount + ' crashes). Rolling back to factory files!');
      try {
        localStorage.removeItem(OTA_STORAGE_KEY);
        sessionStorage.removeItem(CRASH_CANARY_KEY);
      } catch (_) {}
      window.__GOAT_TV_VERSION__ = BASE_VERSION;
      loadFactoryScripts();
      return;
    }

    var bundle = getCachedBundle();
    if (!bundle) {
      window.__GOAT_TV_VERSION__ = BASE_VERSION;
      try { sessionStorage.removeItem(CRASH_CANARY_KEY); } catch (_) {}
      loadFactoryScripts();
      return;
    }

    console.log('[Bootloader] Booting OTA Bundle v' + bundle.version + ' (Factory: v' + BASE_VERSION + ')');
    window.__GOAT_TV_VERSION__ = bundle.version;

    try {
      sessionStorage.setItem(CRASH_CANARY_KEY, String(crashCount + 1));
    } catch (_) {}

    // Catch asynchronous errors in OTA scripts during boot
    var prevOnError = window.onerror;
    window.onerror = function(msg, url, line) {
      if (url && (url.indexOf('ota/') !== -1 || url.indexOf('eval') !== -1)) {
        console.error('[Bootloader] Uncaught error in OTA script:', msg, url, line);
        try {
          localStorage.removeItem(OTA_STORAGE_KEY);
        } catch (_) {}
      }
      if (typeof prevOnError === 'function') {
        return prevOnError.apply(this, arguments);
      }
      return false;
    };

    try {
      // 1. Inject updated CSS if present in bundle
      if (bundle.files['style.css']) {
        var styleEl = document.createElement('style');
        styleEl.id = 'goat-ota-style';
        styleEl.textContent = bundle.files['style.css'];
        document.head.appendChild(styleEl);
      }

      // 2. Synchronously execute application scripts in dependency order in global scope
      for (var i = 0; i < APP_SCRIPTS.length; i++) {
        var scriptName = APP_SCRIPTS[i];
        var scriptCode = bundle.files[scriptName];
        if (scriptCode) {
          // Indirect eval evaluates in global window scope and throws synchronously on syntax/runtime errors
          (0, window.eval)(scriptCode + '\n//# sourceURL=ota/' + scriptName);
        } else {
          // Fallback for missing individual file
          document.write('<script src="js/' + scriptName + '?v=' + BASE_VERSION + '"><\/script>');
        }
      }

      // Clear crash canary after boot stabilizes
      setTimeout(function() {
        try { sessionStorage.removeItem(CRASH_CANARY_KEY); } catch (_) {}
      }, 3500);

    } catch (err) {
      console.error('[Bootloader] Fatal error executing OTA bundle:', err);
      try {
        localStorage.removeItem(OTA_STORAGE_KEY);
        sessionStorage.removeItem(CRASH_CANARY_KEY);
      } catch (_) {}
      window.location.reload();
    }
  }

  window.TVBootloader = {
    getBaseVersion: function() { return BASE_VERSION; },
    getActiveVersion: function() { return window.__GOAT_TV_VERSION__ || BASE_VERSION; },
    clearOtaBundle: function() {
      try { localStorage.removeItem(OTA_STORAGE_KEY); } catch (_) {}
    }
  };

  boot();
})();
