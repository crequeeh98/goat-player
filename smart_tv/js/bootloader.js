// smart_tv/js/bootloader.js - Dynamic OTA Bootloader for Samsung Tizen & LG webOS
(function() {
  'use strict';

  var BASE_VERSION = '2.0.5';
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

  // Fast pure-JS SHA-256 implementation (works synchronously in all TV runtimes without external dependencies)
  function computeSha256(ascii) {
    if (!ascii || typeof ascii !== 'string') return '';
    function r(v, a) { return (v >>> a) | (v << (32 - a)); }
    var m = Math.pow, maxW = m(2, 32), i, j, res = '', words = [];
    var hash = [], k = [], pc = 0, isC = {};
    for (var c = 2; pc < 64; c++) {
      if (!isC[c]) {
        for (i = 0; i < 313; i += c) isC[i] = c;
        hash[pc] = (m(c, 0.5) * maxW) | 0;
        k[pc++] = (m(c, 1 / 3) * maxW) | 0;
      }
    }
    hash = hash.slice(0, 8);
    var utf8 = [];
    for (i = 0; i < ascii.length; i++) {
      var code = ascii.charCodeAt(i);
      if (code < 0x80) utf8.push(code);
      else if (code < 0x800) utf8.push(0xc0 | (code >> 6), 0x80 | (code & 0x3f));
      else if (code < 0xd800 || code >= 0xe000) utf8.push(0xe0 | (code >> 12), 0x80 | ((code >> 6) & 0x3f), 0x80 | (code & 0x3f));
      else {
        i++;
        code = 0x10000 + (((code & 0x3ff) << 10) | (ascii.charCodeAt(i) & 0x3ff));
        utf8.push(0xf0 | (code >> 18), 0x80 | ((code >> 12) & 0x3f), 0x80 | ((code >> 6) & 0x3f), 0x80 | (code & 0x3f));
      }
    }
    var bitLen = utf8.length * 8;
    utf8.push(0x80);
    while ((utf8.length % 64) !== 56) utf8.push(0);
    for (i = 0; i < 4; i++) utf8.push(0);
    utf8.push((bitLen >>> 24) & 0xff, (bitLen >>> 16) & 0xff, (bitLen >>> 8) & 0xff, bitLen & 0xff);
    for (i = 0; i < utf8.length; i += 4) {
      words.push((utf8[i] << 24) | (utf8[i + 1] << 16) | (utf8[i + 2] << 8) | utf8[i + 3]);
    }
    for (j = 0; j < words.length;) {
      var w = words.slice(j, j += 16), o = hash.slice(0);
      for (i = 0; i < 64; i++) {
        if (i >= 16) {
          var s0 = r(w[i - 15], 7) ^ r(w[i - 15], 18) ^ (w[i - 15] >>> 3);
          var s1 = r(w[i - 2], 17) ^ r(w[i - 2], 19) ^ (w[i - 2] >>> 10);
          w[i] = (w[i - 16] + s0 + w[i - 7] + s1) | 0;
        }
        var ch = (hash[4] & hash[5]) ^ (~hash[4] & hash[6]);
        var maj = (hash[0] & hash[1]) ^ (hash[0] & hash[2]) ^ (hash[1] & hash[2]);
        var t1 = (hash[7] + (r(hash[4], 6) ^ r(hash[4], 11) ^ r(hash[4], 25)) + ch + k[i] + w[i]) | 0;
        var t2 = ((r(hash[0], 2) ^ r(hash[0], 13) ^ r(hash[0], 22)) + maj) | 0;
        hash = [(t1 + t2) | 0, hash[0], hash[1], hash[2], (hash[3] + t1) | 0, hash[4], hash[5], hash[6]];
      }
      for (i = 0; i < 8; i++) hash[i] = (hash[i] + o[i]) | 0;
    }
    for (i = 0; i < 8; i++) {
      for (j = 3; j >= 0; j--) {
        var b = (hash[i] >> (j * 8)) & 255;
        res += ((b < 16) ? '0' : '') + b.toString(16);
      }
    }
    return res.toLowerCase();
  }

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
      if (!bundle || !bundle.version || !bundle.files || !bundle.hashes) return null;

      // Discard OTA bundle if factory/package version is newer or equal
      if (!isNewer(BASE_VERSION, bundle.version)) {
        console.log('[Bootloader] Factory version (' + BASE_VERSION + ') >= OTA version (' + bundle.version + '), clearing OTA cache');
        localStorage.removeItem(OTA_STORAGE_KEY);
        return null;
      }

      // Check critical files and integrity hashes
      for (var i = 0; i < APP_SCRIPTS.length; i++) {
        var sName = APP_SCRIPTS[i];
        if (!bundle.files[sName] || typeof bundle.hashes[sName] !== 'string' || bundle.hashes[sName].length !== 64) {
          console.warn('[Bootloader] Incomplete or unsigned OTA bundle detected, discarding');
          localStorage.removeItem(OTA_STORAGE_KEY);
          return null;
        }
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
      // 1. Inject updated CSS if present in bundle (with integrity check)
      if (bundle.files['style.css']) {
        var cssContent = (bundle.files['style.css'] || '').replace(/\r\n/g, '\n');
        if (bundle.hashes && bundle.hashes['style.css']) {
          var expectedCssHash = bundle.hashes['style.css'].toLowerCase();
          var actualCssHash = computeSha256(cssContent);
          if (actualCssHash !== expectedCssHash) {
            console.error('[Bootloader] CSS integrity violation! Expected ' + expectedCssHash + ', got ' + actualCssHash);
            throw new Error('Integrity violation for style.css');
          }
        }
        var styleEl = document.createElement('style');
        styleEl.id = 'goat-ota-style';
        styleEl.textContent = cssContent;
        document.head.appendChild(styleEl);
      }

      // 2. Synchronously execute application scripts in dependency order after verifying cryptographic SHA-256
      for (var i = 0; i < APP_SCRIPTS.length; i++) {
        var scriptName = APP_SCRIPTS[i];
        var scriptCode = (bundle.files[scriptName] || '').replace(/\r\n/g, '\n');
        var expectedHash = (bundle.hashes[scriptName] || '').toLowerCase();

        if (typeof scriptCode !== 'string' || !expectedHash || computeSha256(scriptCode) !== expectedHash) {
          console.error('[Bootloader] Hash mismatch for ' + scriptName + '! Aborting OTA boot.');
          throw new Error('Integrity violation for ' + scriptName);
        }

        // Indirect eval evaluates in global window scope and throws synchronously on syntax/runtime errors
        (0, window.eval)(scriptCode + '\n//# sourceURL=ota/' + scriptName);
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
      if (window.location && typeof window.location.reload === 'function') {
        window.location.reload();
      }
    }
  }

  window.TVBootloader = {
    getBaseVersion: function() { return BASE_VERSION; },
    getActiveVersion: function() { return window.__GOAT_TV_VERSION__ || BASE_VERSION; },
    computeSha256: computeSha256,
    clearOtaBundle: function() {
      try { localStorage.removeItem(OTA_STORAGE_KEY); } catch (_) {}
    }
  };

  boot();
})();
