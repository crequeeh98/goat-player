// smart_tv/js/bootloader.js - Universal OTA Bootloader v2 (Samsung Tizen & LG webOS)
(function() {
  'use strict';

  var BASE_VERSION = '2.1.3';
  var EMBEDDED_VERSION = '2.1.3';
  var OTA_PROTOCOL = 2;
  var LEGACY_OTA_KEY = 'goat_tv_ota_bundle';
  var LS_FALLBACK_META_KEY = 'goat_tv_ota_v2_meta';
  var LS_FALLBACK_FILE_PREFIX = 'goat_tv_ota_v2_file:';
  var CRASH_CANARY_KEY = 'goat_ota_boot_in_progress';
  var IDB_NAME = 'goat_tv_ota_v2';
  var IDB_VERSION = 1;

  var FACTORY_VENDOR_SCRIPTS = [
    'hls.min.js',
    'qrcode.min.js'
  ];

  var FACTORY_APP_SCRIPTS = [
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

  /* __FACTORY_HASHES_START__ */
  var FACTORY_HASHES = {
      "index.html": "ca68ac87f9fcb5f6a909bdfc6a138e035185e7a860d0cfad000c7ab5142b0602",
      "style.css": "d7cfa4a625eb89a09d749ae6375261cabe10c1c03bd6e2ed2350aa53df265b07",
      "hls.min.js": "64425220c46f2a1ed9725fb7f263e88d40c4179d62bd8f6de3e76789085cba87",
      "qrcode.min.js": "c541ef06327885a8415bca8df6071e14189b4855336def4f36db54bde8484f36",
      "icons.js": "fab7b3b102f9a6e38c474ce1f5d24d0003c106b99593badbc26036236cf98742",
      "i18n.js": "aad3a5d0ca83c5fe778d6df71f71ecc22941701db21961502cec5edb3ac65d45",
      "m3u.js": "a5fa8f01c112c2093f6563ce8074f7e60e1fa8cffa855a30b6641de087c06ff3",
      "storage.js": "4be7ec94362f283897a4926a1430455fc43e575bcfa27e816e3da8550d9fbbe8",
      "api.js": "b0cb5d5158116ea79fc35ae8e8e725e485ddb9a0eb146cb5e52f82210e7e8289",
      "sync.js": "5807778284a99bdae9d28b7f9b768b1d78886439b0e5f7fbfb9776960cc4333f",
      "spatial_nav.js": "4f22e47ade4f1bffa8a080ba000e66b16be26da75c11ba3c636f2e218070b941",
      "virtual_list.js": "85ec5eb4fe9fdbf5dc4acb7843f9c5ed5f1058b12c8b744cf3d1543a8f75fded",
      "diagnostics.js": "196ce420664d6c9ba5bf89527b0590cd2a1606356797d672442ce580753889a8",
      "subtitles.js": "c4c2d0933ab91211d1920afebc68bb86208c7ff0386b734b11c191eb275f774d",
      "player.js": "ed30dff468c62ff974653fd45ff376adc3d7d1c03125d73eec00d2655bc34af4",
      "updater.js": "8629e12f7c214f0b0d5badf1b872b4e7d83a1ab42443a76c80ba862903ddd7b9",
      "app.js": "264d201bb2f50b78afb4d1f2e6d8fd45763dac4fd86e6f5504ae454a707c623d",
      "assets/dockIcon.png": "c79649292a6d2d663e0637db0865fd02ddff55095365c33593b451bf1c0c4ba8",
      "assets/head.png": "5edbed44598d653a3a554f55ae04d0a64d79439987645fb14b5d1ba318da5996",
      "assets/icon.png": "342729e50500ad00d308c242042af1763a36910193efbd84a97bcf7c9cf34259",
      "assets/largeIcon.png": "3d7a2a074f41b2604e6646394dc2c29baeafa0fe391dd578d7a04b8b33896caf",
      "assets/logo.png": "4664458b23c273617c74a351b91479187c73cb2c31b3a657ed6b163cdacd85ca",
      "assets/splash.png": "fbe6b4a062e9fcc3be9ad595a572695203e408330fc2e3777ad5e4db780885cc"
  };
  /* __FACTORY_HASHES_END__ */

  var _bootFinished = false;
  var _bootHealthyMarked = false;
  var _activeBootSlot = null;
  var _otaAssetsMap = {};
  var _queuedDomReadyCallbacks = [];
  var _queuedWindowLoadCallbacks = [];
  var _interceptingLifecycleEvents = true;

  // Intercept late DOMContentLoaded / load listeners registered during async IDB boot
  var _origDocAddEventListener = document.addEventListener;
  var _origWinAddEventListener = window.addEventListener;

  document.addEventListener = function(type, listener, options) {
    if (_interceptingLifecycleEvents && type === 'DOMContentLoaded' && typeof listener === 'function') {
      if (document.readyState !== 'loading') {
        _queuedDomReadyCallbacks.push(listener);
        return;
      }
    }
    return _origDocAddEventListener.apply(document, arguments);
  };

  window.addEventListener = function(type, listener, options) {
    if (_interceptingLifecycleEvents && typeof listener === 'function') {
      if (type === 'DOMContentLoaded' && document.readyState !== 'loading') {
        _queuedDomReadyCallbacks.push(listener);
        return;
      }
      if (type === 'load' && document.readyState === 'complete') {
        _queuedWindowLoadCallbacks.push(listener);
        return;
      }
    }
    return _origWinAddEventListener.apply(window, arguments);
  };

  function flushLifecycleCallbacks() {
    _interceptingLifecycleEvents = false;
    var domCbs = _queuedDomReadyCallbacks.slice();
    _queuedDomReadyCallbacks = [];
    for (var i = 0; i < domCbs.length; i++) {
      try { domCbs[i].call(document, { type: 'DOMContentLoaded' }); } catch (e) {
        console.error('[Bootloader] Error in DOMContentLoaded callback:', e);
        throw e;
      }
    }
    var loadCbs = _queuedWindowLoadCallbacks.slice();
    _queuedWindowLoadCallbacks = [];
    for (var j = 0; j < loadCbs.length; j++) {
      try { loadCbs[j].call(window, { type: 'load' }); } catch (e2) {
        console.error('[Bootloader] Error in load callback:', e2);
      }
    }
  }

  // Pure-JS synchronous SHA-256 fallback (for environments where crypto.subtle is unavailable)
  function computeSha256(ascii) {
    function rightRotate(value, amount) {
      return (value >>> amount) | (value << (32 - amount));
    }
    var utf8 = unescape(encodeURIComponent(ascii));
    var mathPow = Math.pow;
    var maxWord = mathPow(2, 32);
    var lengthProperty = 'length';
    var i, j;
    var result = '';
    var words = [];
    var asciiBitLength = utf8[lengthProperty] * 8;
    var hash = computeSha256.h = computeSha256.h || [];
    var k = computeSha256.k = computeSha256.k || [];
    var primeCounter = k[lengthProperty];
    var isComposite = {};
    for (var candidate = 2; primeCounter < 64; candidate++) {
      if (!isComposite[candidate]) {
        for (i = 0; i < 313; i += candidate) {
          isComposite[i] = candidate;
        }
        hash[primeCounter] = (mathPow(candidate, 0.5) * maxWord) | 0;
        k[primeCounter++] = (mathPow(candidate, 1 / 3) * maxWord) | 0;
      }
    }
    utf8 += '\x80';
    while (utf8[lengthProperty] % 64 - 56) utf8 += '\x00';
    for (i = 0; i < utf8[lengthProperty]; i++) {
      j = utf8.charCodeAt(i);
      if (j >> 8) return '';
      words[i >> 2] |= j << ((3 - (i % 4)) * 8);
    }
    words[words[lengthProperty]] = (asciiBitLength / maxWord) | 0;
    words[words[lengthProperty]] = asciiBitLength;
    for (j = 0; j < words[lengthProperty];) {
      var w = words.slice(j, (j += 16));
      var oldHash = hash;
      hash = hash.slice(0, 8);
      for (i = 0; i < 64; i++) {
        var w15 = w[i - 15], w2 = w[i - 2];
        var a = hash[0], e = hash[4];
        var temp1 =
          hash[7] +
          (rightRotate(e, 6) ^ rightRotate(e, 11) ^ rightRotate(e, 25)) +
          ((e & hash[5]) ^ (~e & hash[6])) +
          k[i] +
          (w[i] =
            i < 16
              ? w[i]
              : (w[i - 16] +
                  (rightRotate(w15, 7) ^ rightRotate(w15, 18) ^ (w15 >>> 3)) +
                  w[i - 7] +
                  (rightRotate(w2, 17) ^ rightRotate(w2, 19) ^ (w2 >>> 10))) |
                0);
        var temp2 =
          (rightRotate(a, 2) ^ rightRotate(a, 13) ^ rightRotate(a, 22)) +
          ((a & hash[1]) ^ (a & hash[2]) ^ (hash[1] & hash[2]));
        hash = [(temp1 + temp2) | 0].concat(hash);
        hash[4] = (hash[4] + temp1) | 0;
      }
      for (i = 0; i < 8; i++) {
        hash[i] = (hash[i] + oldHash[i]) | 0;
      }
    }
    for (i = 0; i < 8; i++) {
      for (j = 3; j + 1; j--) {
        var b = (hash[i] >> (j * 8)) & 255;
        result += (b < 16 ? 0 : '') + b.toString(16);
      }
    }
    return result.toLowerCase();
  }

  function computeSha256Bytes(bytes) {
    function rightRotate(value, amount) {
      return (value >>> amount) | (value << (32 - amount));
    }
    var binStr = '';
    for (var idx = 0; idx < bytes.length; idx++) {
      binStr += String.fromCharCode(bytes[idx] & 0xff);
    }
    var mathPow = Math.pow;
    var maxWord = mathPow(2, 32);
    var i, j;
    var result = '';
    var words = [];
    var bitLength = binStr.length * 8;
    var hash = computeSha256.h = computeSha256.h || [];
    var k = computeSha256.k = computeSha256.k || [];
    var primeCounter = k.length;
    var isComposite = {};
    for (var candidate = 2; primeCounter < 64; candidate++) {
      if (!isComposite[candidate]) {
        for (i = 0; i < 313; i += candidate) {
          isComposite[i] = candidate;
        }
        hash[primeCounter] = (mathPow(candidate, 0.5) * maxWord) | 0;
        k[primeCounter++] = (mathPow(candidate, 1 / 3) * maxWord) | 0;
      }
    }
    binStr += '\x80';
    while (binStr.length % 64 - 56) binStr += '\x00';
    for (i = 0; i < binStr.length; i++) {
      j = binStr.charCodeAt(i);
      words[i >> 2] |= j << ((3 - (i % 4)) * 8);
    }
    words[words.length] = (bitLength / maxWord) | 0;
    words[words.length] = bitLength;
    for (j = 0; j < words.length;) {
      var w = words.slice(j, (j += 16));
      var oldHash = hash;
      hash = hash.slice(0, 8);
      for (i = 0; i < 64; i++) {
        var w15 = w[i - 15], w2 = w[i - 2];
        var a = hash[0], e = hash[4];
        var temp1 =
          hash[7] +
          (rightRotate(e, 6) ^ rightRotate(e, 11) ^ rightRotate(e, 25)) +
          ((e & hash[5]) ^ (~e & hash[6])) +
          k[i] +
          (w[i] =
            i < 16
              ? w[i]
              : (w[i - 16] +
                  (rightRotate(w15, 7) ^ rightRotate(w15, 18) ^ (w15 >>> 3)) +
                  w[i - 7] +
                  (rightRotate(w2, 17) ^ rightRotate(w2, 19) ^ (w2 >>> 10))) |
                0);
        var temp2 =
          (rightRotate(a, 2) ^ rightRotate(a, 13) ^ rightRotate(a, 22)) +
          ((a & hash[1]) ^ (a & hash[2]) ^ (hash[1] & hash[2]));
        hash = [(temp1 + temp2) | 0].concat(hash);
        hash[4] = (hash[4] + temp1) | 0;
      }
      for (i = 0; i < 8; i++) {
        hash[i] = (hash[i] + oldHash[i]) | 0;
      }
    }
    for (i = 0; i < 8; i++) {
      for (j = 3; j + 1; j--) {
        var b = (hash[i] >> (j * 8)) & 255;
        result += (b < 16 ? 0 : '') + b.toString(16);
      }
    }
    return result.toLowerCase();
  }

  function computeSha256Async(input, isBinaryBytes, cb) {
    try {
      if (window.crypto && window.crypto.subtle && typeof Uint8Array !== 'undefined') {
        var bufferData = null;
        if (isBinaryBytes && input instanceof Uint8Array) {
          bufferData = input;
        } else if (!isBinaryBytes && typeof TextEncoder !== 'undefined') {
          bufferData = new TextEncoder().encode(String(input));
        }
        if (bufferData) {
          window.crypto.subtle.digest('SHA-256', bufferData).then(function(buf) {
            var hex = '';
            var bytes = new Uint8Array(buf);
            for (var i = 0; i < bytes.length; i++) {
              hex += (bytes[i] < 16 ? '0' : '') + bytes[i].toString(16);
            }
            cb(null, hex.toLowerCase());
          }).catch(function() {
            var syncHash = isBinaryBytes ? computeSha256Bytes(input) : computeSha256(String(input));
            cb(null, syncHash);
          });
          return;
        }
      }
    } catch (_) {}
    try {
      var fallbackHash = isBinaryBytes ? computeSha256Bytes(input) : computeSha256(String(input));
      cb(null, fallbackHash);
    } catch (err) {
      cb(err, null);
    }
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
    } catch (_) {}
    return false;
  }

  // Clean up legacy localStorage OTA bundle from v1 to free ~1 MB quota
  try {
    if (window.localStorage && localStorage.getItem(LEGACY_OTA_KEY)) {
      localStorage.removeItem(LEGACY_OTA_KEY);
    }
  } catch (_) {}

  // =========================================================================
  // In-App Asset Resolver (window.TVAssets)
  // =========================================================================
  window.TVAssets = {
    resolve: function(relPath) {
      if (!relPath || typeof relPath !== 'string') return relPath;
      var clean = relPath.replace(/^\.\//, '').replace(/^\.\.\//, '');
      if (_otaAssetsMap && _otaAssetsMap[clean]) {
        return _otaAssetsMap[clean];
      }
      return relPath;
    },
    register: function(relPath, dataUri) {
      if (!relPath || !dataUri) return;
      var clean = relPath.replace(/^\.\//, '').replace(/^\.\.\//, '');
      _otaAssetsMap[clean] = dataUri;
    },
    applyToDom: function(rootEl) {
      if (!rootEl || !rootEl.querySelectorAll) return;
      var imgs = rootEl.querySelectorAll('img');
      for (var i = 0; i < imgs.length; i++) {
        var img = imgs[i];
        var src = img.getAttribute('src');
        if (src && src.indexOf('assets/') === 0 && _otaAssetsMap[src]) {
          img.setAttribute('src', _otaAssetsMap[src]);
        }
        var onErr = img.getAttribute('onerror');
        if (onErr && onErr.indexOf('assets/logo.png') !== -1 && _otaAssetsMap['assets/logo.png']) {
          img.setAttribute('onerror', "this.src='" + _otaAssetsMap['assets/logo.png'] + "'");
        }
      }
    }
  };

  // =========================================================================
  // Dual-Slot OTA Vault (IndexedDB primary + Compact localStorage fallback)
  // =========================================================================
  var _idbInstance = null;
  var _idbUnavailable = false;

  function openOtaDb(cb) {
    if (_idbInstance) {
      cb(null, _idbInstance);
      return;
    }
    if (_idbUnavailable) {
      cb(new Error('IndexedDB unavailable'), null);
      return;
    }
    try {
      var idbFactory = window.indexedDB || window.webkitIndexedDB || window.mozIndexedDB;
      if (!idbFactory) {
        _idbUnavailable = true;
        cb(new Error('No IndexedDB support'), null);
        return;
      }
      var req = idbFactory.open(IDB_NAME, IDB_VERSION);
      var settled = false;
      var timer = setTimeout(function() {
        if (!settled) {
          settled = true;
          _idbUnavailable = true;
          cb(new Error('IndexedDB open timeout'), null);
        }
      }, 2500);

      req.onupgradeneeded = function(e) {
        var db = e.target.result;
        if (!db.objectStoreNames.contains('meta')) {
          db.createObjectStore('meta', { keyPath: 'id' });
        }
        if (!db.objectStoreNames.contains('files')) {
          db.createObjectStore('files', { keyPath: 'key' });
        }
      };
      req.onsuccess = function(e) {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        _idbInstance = e.target.result;
        cb(null, _idbInstance);
      };
      req.onerror = function(e) {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        _idbUnavailable = true;
        cb(e.target.error || new Error('IndexedDB open failed'), null);
      };
      req.onblocked = function() {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        _idbUnavailable = true;
        cb(new Error('IndexedDB open blocked'), null);
      };
    } catch (err) {
      _idbUnavailable = true;
      cb(err, null);
    }
  }

  function defaultMetaState() {
    return {
      id: 'state',
      activeSlot: null,
      previousSlot: null,
      slots: {}
    };
  }

  function getMetaState(cb) {
    openOtaDb(function(err, db) {
      if (!err && db) {
        try {
          var tx = db.transaction(['meta'], 'readonly');
          var store = tx.objectStore('meta');
          var req = store.get('state');
          req.onsuccess = function() {
            cb(null, req.result || defaultMetaState(), 'idb');
          };
          req.onerror = function() {
            cb(null, defaultMetaState(), 'idb');
          };
          return;
        } catch (_) {}
      }
      // Fallback to localStorage
      try {
        var raw = localStorage.getItem(LS_FALLBACK_META_KEY);
        if (raw) {
          cb(null, JSON.parse(raw), 'ls');
          return;
        }
      } catch (_) {}
      cb(null, defaultMetaState(), 'ls');
    });
  }

  function saveMetaState(state, cb) {
    state.id = 'state';
    openOtaDb(function(err, db) {
      if (!err && db) {
        try {
          var tx = db.transaction(['meta'], 'readwrite');
          var store = tx.objectStore('meta');
          store.put(state);
          tx.oncomplete = function() { if (cb) cb(null); };
          tx.onerror = function(e) { if (cb) cb(e.target.error || new Error('Meta write failed')); };
          return;
        } catch (_) {}
      }
      try {
        localStorage.setItem(LS_FALLBACK_META_KEY, JSON.stringify(state));
        if (cb) cb(null);
      } catch (lsErr) {
        if (cb) cb(lsErr);
      }
    });
  }

  function clearSlotFiles(slot, cb) {
    openOtaDb(function(err, db) {
      if (!err && db) {
        try {
          var tx = db.transaction(['files'], 'readwrite');
          var store = tx.objectStore('files');
          var prefix = slot + ':';
          if (typeof store.openCursor === 'function') {
            var cursorReq = store.openCursor();
            cursorReq.onsuccess = function(e) {
              var cursor = e.target.result;
              if (cursor) {
                if (String(cursor.key).indexOf(prefix) === 0) {
                  cursor.delete();
                }
                cursor.continue();
              }
            };
          }
          tx.oncomplete = function() { if (cb) cb(null); };
          tx.onerror = function() { if (cb) cb(null); };
          return;
        } catch (_) {}
      }
      try {
        var lsPrefix = LS_FALLBACK_FILE_PREFIX + slot + ':';
        var keysToRemove = [];
        for (var i = 0; i < localStorage.length; i++) {
          var k = localStorage.key(i);
          if (k && k.indexOf(lsPrefix) === 0) keysToRemove.push(k);
        }
        for (var j = 0; j < keysToRemove.length; j++) {
          localStorage.removeItem(keysToRemove[j]);
        }
      } catch (_) {}
      if (cb) cb(null);
    });
  }

  function saveFileRecord(slot, record, cb) {
    var item = {
      key: slot + ':' + record.name,
      slot: slot,
      name: record.name,
      sha256: String(record.sha256 || '').toLowerCase(),
      source: record.source || 'ota',
      mime: record.mime || '',
      content: record.source === 'factory' ? null : record.content
    };
    openOtaDb(function(err, db) {
      if (!err && db) {
        try {
          var tx = db.transaction(['files'], 'readwrite');
          var store = tx.objectStore('files');
          store.put(item);
          tx.oncomplete = function() { cb(null); };
          tx.onerror = function(e) { cb(e.target.error || new Error('IDB file write failed for ' + record.name)); };
          return;
        } catch (_) {}
      }
      // Compact localStorage fallback (only stores non-factory files)
      try {
        var lsKey = LS_FALLBACK_FILE_PREFIX + item.key;
        if (item.source === 'factory') {
          localStorage.setItem(lsKey, JSON.stringify({
            key: item.key,
            slot: item.slot,
            name: item.name,
            sha256: item.sha256,
            source: 'factory',
            content: null
          }));
        } else {
          localStorage.setItem(lsKey, JSON.stringify(item));
        }
        cb(null);
      } catch (lsErr) {
        cb(new Error('Storage quota exceeded while saving ' + record.name));
      }
    });
  }

  function getFileRecord(slot, name, cb) {
    var fullKey = slot + ':' + name;
    openOtaDb(function(err, db) {
      if (!err && db) {
        try {
          var tx = db.transaction(['files'], 'readonly');
          var store = tx.objectStore('files');
          var req = store.get(fullKey);
          req.onsuccess = function() { cb(null, req.result || null); };
          req.onerror = function(e) { cb(e.target.error || new Error('Read failed'), null); };
          return;
        } catch (_) {}
      }
      try {
        var raw = localStorage.getItem(LS_FALLBACK_FILE_PREFIX + fullKey);
        cb(null, raw ? JSON.parse(raw) : null);
      } catch (lsErr) {
        cb(lsErr, null);
      }
    });
  }

  function getManifestRequiredEntries(manifest) {
    var list = [];
    if (!manifest) return list;
    if (manifest.html && manifest.html.name && manifest.html.sha256) {
      list.push({ name: manifest.html.name, path: manifest.html.path || 'smart_tv/index.html', sha256: manifest.html.sha256, kind: 'html' });
    }
    var styles = manifest.styles || [{ name: 'style.css', path: 'smart_tv/css/style.css', sha256: manifest.files && manifest.files['style.css'] }];
    for (var i = 0; i < styles.length; i++) {
      if (styles[i] && styles[i].name && styles[i].sha256) {
        list.push({ name: styles[i].name, path: styles[i].path, sha256: styles[i].sha256, kind: 'style' });
      }
    }
    var vendors = manifest.vendorScripts || [];
    for (var v = 0; v < vendors.length; v++) {
      if (vendors[v] && vendors[v].name && vendors[v].sha256) {
        list.push({ name: vendors[v].name, path: vendors[v].path, sha256: vendors[v].sha256, kind: 'vendor' });
      }
    }
    var scripts = manifest.scripts || [];
    if (scripts.length === 0 && manifest.files) {
      for (var s = 0; s < FACTORY_APP_SCRIPTS.length; s++) {
        var sName = FACTORY_APP_SCRIPTS[s];
        if (manifest.files[sName]) {
          list.push({ name: sName, path: 'smart_tv/js/' + sName, sha256: manifest.files[sName], kind: 'script' });
        }
      }
    } else {
      for (var k = 0; k < scripts.length; k++) {
        if (scripts[k] && scripts[k].name && scripts[k].sha256) {
          list.push({ name: scripts[k].name, path: scripts[k].path, sha256: scripts[k].sha256, kind: 'script' });
        }
      }
    }
    var assets = manifest.assets || [];
    for (var a = 0; a < assets.length; a++) {
      if (assets[a] && assets[a].name && assets[a].sha256) {
        list.push({ name: assets[a].name, path: assets[a].path, sha256: assets[a].sha256, mime: assets[a].mime || 'image/png', kind: 'asset' });
      }
    }
    return list;
  }

  var otaVault = {
    getState: getMetaState,
    prepareStagingSlot: function(manifest, cb) {
      getMetaState(function(err, state) {
        var targetSlot = (state && state.activeSlot === 'slot_a') ? 'slot_b' : 'slot_a';
        clearSlotFiles(targetSlot, function() {
          cb(null, targetSlot);
        });
      });
    },
    saveStagingFile: saveFileRecord,
    verifyAndActivateSlot: function(slot, manifest, cb) {
      var entries = getManifestRequiredEntries(manifest);
      if (!entries.length) {
        cb(new Error('Manifest contains no verifiable entries'));
        return;
      }
      var idx = 0;
      function checkNext() {
        if (idx >= entries.length) {
          // All files verified in storage! Switch activeSlot atomically
          getMetaState(function(err, state) {
            state = state || defaultMetaState();
            state.slots = state.slots || {};
            if (state.activeSlot && state.slots[state.activeSlot] && state.slots[state.activeSlot].bootedHealthy) {
              state.previousSlot = state.activeSlot;
            }
            state.slots[slot] = {
              version: manifest.version,
              updatedAt: Date.now(),
              bootedHealthy: false,
              bootAttempts: 0,
              manifest: manifest
            };
            state.activeSlot = slot;
            saveMetaState(state, function(saveErr) {
              if (saveErr) {
                cb(saveErr);
                return;
              }
              // Read back meta state to guarantee pointer persistence
              getMetaState(function(rErr, verifyState) {
                if (rErr || !verifyState || verifyState.activeSlot !== slot) {
                  cb(new Error('Failed to verify active OTA slot persistence'));
                  return;
                }
                cb(null, verifyState);
              });
            });
          });
          return;
        }
        var expected = entries[idx++];
        var expectedHash = String(expected.sha256 || '').toLowerCase();
        getFileRecord(slot, expected.name, function(fErr, rec) {
          if (fErr || !rec) {
            cb(new Error('Post-write check failed: missing ' + expected.name));
            return;
          }
          if (String(rec.sha256 || '').toLowerCase() !== expectedHash) {
            cb(new Error('Post-write hash mismatch for ' + expected.name));
            return;
          }
          if (rec.source !== 'factory' && (!rec.content || typeof rec.content !== 'string')) {
            cb(new Error('Post-write content missing for ' + expected.name));
            return;
          }
          checkNext();
        });
      }
      checkNext();
    },
    rollback: function(reason, cb) {
      console.warn('[Bootloader] Rolling back OTA bundle. Reason:', reason);
      getMetaState(function(err, state) {
        if (!state || !state.activeSlot) {
          if (cb) cb(null);
          return;
        }
        var failedSlot = state.activeSlot;
        var prevSlot = state.previousSlot;
        var prevMeta = (prevSlot && state.slots) ? state.slots[prevSlot] : null;
        if (prevSlot && prevSlot !== failedSlot && prevMeta && prevMeta.bootedHealthy && isNewer(BASE_VERSION, prevMeta.version)) {
          console.warn('[Bootloader] Reverting from ' + failedSlot + ' to last known good slot ' + prevSlot + ' (v' + prevMeta.version + ')');
          state.activeSlot = prevSlot;
          state.previousSlot = null;
          state.slots[prevSlot].bootAttempts = 0;
        } else {
          console.warn('[Bootloader] Reverting to factory v' + BASE_VERSION);
          state.activeSlot = null;
          state.previousSlot = null;
        }
        if (state.slots && state.slots[failedSlot]) {
          delete state.slots[failedSlot];
        }
        saveMetaState(state, function() {
          clearSlotFiles(failedSlot, function() {
            try { sessionStorage.removeItem(CRASH_CANARY_KEY); } catch (_) {}
            if (cb) cb(null);
          });
        });
      });
    },
    clearAll: function(cb) {
      var empty = defaultMetaState();
      saveMetaState(empty, function() {
        clearSlotFiles('slot_a', function() {
          clearSlotFiles('slot_b', function() {
            try { sessionStorage.removeItem(CRASH_CANARY_KEY); } catch (_) {}
            if (cb) cb(null);
          });
        });
      });
    }
  };

  // =========================================================================
  // Sequential Factory Script Loader (works safely post-DOMContentLoaded)
  // =========================================================================
  function loadLocalScriptTag(srcPath, cb) {
    var s = document.createElement('script');
    s.src = srcPath + '?v=' + encodeURIComponent(BASE_VERSION);
    s.async = false;
    s.onload = function() { cb(null); };
    s.onerror = function() { cb(new Error('Failed to load local script: ' + srcPath)); };
    (document.body || document.head || document.documentElement).appendChild(s);
  }

  function loadFactoryScripts() {
    window.__GOAT_TV_VERSION__ = BASE_VERSION;
    window.__GOAT_BOOT_MODE__ = 'factory';
    var allFactory = [];
    for (var i = 0; i < FACTORY_VENDOR_SCRIPTS.length; i++) {
      allFactory.push('js/' + FACTORY_VENDOR_SCRIPTS[i]);
    }
    for (var j = 0; j < FACTORY_APP_SCRIPTS.length; j++) {
      allFactory.push('js/' + FACTORY_APP_SCRIPTS[j]);
    }
    var idx = 0;
    function next() {
      if (idx >= allFactory.length) {
        try {
          flushLifecycleCallbacks();
          _bootFinished = true;
          _bootHealthyMarked = true;
        } catch (e) {
          console.error('[Bootloader] Factory lifecycle callback error:', e);
        }
        return;
      }
      var path = allFactory[idx++];
      loadLocalScriptTag(path, function(err) {
        if (err) console.error('[Bootloader]', err);
        next();
      });
    }
    next();
  }

  // =========================================================================
  // OTA DOM, CSS, Asset & Script Hydration
  // =========================================================================
  function rewriteCssAssetUrls(cssText) {
    if (!cssText) return '';
    return cssText.replace(/url\(\s*(['"]?)(?:\.\.\/|\.\/)?(assets\/[^)'"]+)\1\s*\)/g, function(match, quote, assetPath) {
      var resolved = window.TVAssets.resolve(assetPath);
      var q = quote || "'";
      return 'url(' + q + resolved + q + ')';
    });
  }

  function applyOtaHtml(htmlString) {
    if (!htmlString || typeof DOMParser === 'undefined') return;
    var parser = new DOMParser();
    var doc = parser.parseFromString(htmlString, 'text/html');
    if (!doc || !doc.body) return;

    // 1. Update lang & title
    if (doc.documentElement && doc.documentElement.lang) {
      document.documentElement.lang = doc.documentElement.lang;
    }
    if (doc.title) {
      document.title = doc.title;
    }

    // 2. Remove any <script> tags inside parsed body so bootloader controls script execution order
    var scriptsInBody = doc.body.querySelectorAll('script');
    for (var i = 0; i < scriptsInBody.length; i++) {
      if (scriptsInBody[i].parentNode) {
        scriptsInBody[i].parentNode.removeChild(scriptsInBody[i]);
      }
    }

    // 3. Rewrite in-app <img src="assets/..."> in parsed body before swapping
    window.TVAssets.applyToDom(doc.body);

    // 4. Preserve splash screen progress if currently visible
    var curSplashFill = document.getElementById('splash-progress-fill');
    var curSplashWidth = curSplashFill ? curSplashFill.style.width : '';

    // 5. Swap body DOM & body classes
    if (doc.body && typeof doc.body.className === 'string') {
      document.body.className = doc.body.className;
    }
    document.body.innerHTML = doc.body.innerHTML;

    if (curSplashWidth) {
      var newSplashFill = document.getElementById('splash-progress-fill');
      if (newSplashFill) newSplashFill.style.width = curSplashWidth;
    }
  }

  function verifyRecordIntegrity(rec, expectedHash, isAsset, cb) {
    var exp = String(expectedHash || '').toLowerCase();
    if (!rec || String(rec.sha256 || '').toLowerCase() !== exp) {
      cb(new Error('Stored metadata hash mismatch'));
      return;
    }
    if (rec.source === 'factory') {
      if ((FACTORY_HASHES[rec.name] || '').toLowerCase() === exp) {
        cb(null);
      } else {
        cb(new Error('Factory hash mismatch for ' + rec.name));
      }
      return;
    }
    if (!rec.content || typeof rec.content !== 'string') {
      cb(new Error('Empty OTA content for ' + rec.name));
      return;
    }
    if (isAsset) {
      // Data URI format: data:<mime>;base64,<b64>
      var commaIdx = rec.content.indexOf(',');
      if (commaIdx === -1) {
        cb(new Error('Invalid Data URI for asset ' + rec.name));
        return;
      }
      try {
        var b64 = rec.content.substring(commaIdx + 1);
        var binStr = atob(b64);
        var bytes = new Uint8Array(binStr.length);
        for (var i = 0; i < binStr.length; i++) {
          bytes[i] = binStr.charCodeAt(i);
        }
        computeSha256Async(bytes, true, function(hErr, actualHash) {
          if (hErr || actualHash !== exp) {
            cb(new Error('Asset cryptographic hash mismatch for ' + rec.name));
          } else {
            cb(null);
          }
        });
      } catch (e) {
        cb(e);
      }
      return;
    }
    var normalized = rec.content.replace(/\r\n/g, '\n');
    computeSha256Async(normalized, false, function(hErr, actualHash) {
      if (hErr || actualHash !== exp) {
        cb(new Error('Cryptographic hash mismatch for ' + rec.name));
      } else {
        cb(null);
      }
    });
  }

  function verifyPostBootInvariants() {
    var requiredGlobals = ['TVStorage', 'TVApi', 'SpatialNav', 'TVPlayer', 'TVUpdater', 'TVApp'];
    for (var i = 0; i < requiredGlobals.length; i++) {
      if (!window[requiredGlobals[i]]) {
        throw new Error('Missing global module after boot: ' + requiredGlobals[i]);
      }
    }
    if (!document.getElementById('view-accounts') || !document.getElementById('view-dashboard')) {
      throw new Error('Critical DOM views missing after boot');
    }
  }

  function triggerFatalOtaRollback(reason) {
    console.error('[Bootloader] Fatal OTA failure:', reason);
    otaVault.rollback(reason, function() {
      if (window.location && typeof window.location.reload === 'function') {
        window.location.reload();
      } else {
        loadFactoryScripts();
      }
    });
  }

  function bootOtaSlot(slot, slotMeta, state) {
    var manifest = slotMeta.manifest;
    if (!manifest) {
      triggerFatalOtaRollback('Missing manifest in slot ' + slot);
      return;
    }

    _activeBootSlot = slot;
    window.__GOAT_TV_VERSION__ = slotMeta.version;
    window.__GOAT_BOOT_MODE__ = 'ota';

    // Increment crash canary in sessionStorage and IDB
    var crashCount = 0;
    try {
      crashCount = parseInt(sessionStorage.getItem(CRASH_CANARY_KEY) || '0', 10) || 0;
      sessionStorage.setItem(CRASH_CANARY_KEY, String(crashCount + 1));
    } catch (_) {}

    slotMeta.bootAttempts = (slotMeta.bootAttempts || 0) + 1;
    saveMetaState(state);

    // Attach uncaught error & unhandled rejection guards until boot is marked healthy
    var prevOnError = window.onerror;
    window.onerror = function(msg, url, line) {
      if (!_bootHealthyMarked && url && (url.indexOf('ota/') !== -1 || url.indexOf('eval') !== -1 || !_bootFinished)) {
        triggerFatalOtaRollback('Uncaught runtime error during OTA boot: ' + msg + ' (' + url + ':' + line + ')');
        return true;
      }
      if (typeof prevOnError === 'function') {
        return prevOnError.apply(this, arguments);
      }
      return false;
    };

    var entries = getManifestRequiredEntries(manifest);
    var loadedRecords = {};
    var idx = 0;

    // Phase 1: Load and cryptographically verify every required entry before touching DOM
    function loadAndVerifyNext() {
      if (idx >= entries.length) {
        applyVerifiedBundle();
        return;
      }
      var entry = entries[idx++];
      getFileRecord(slot, entry.name, function(err, rec) {
        if (err || !rec) {
          triggerFatalOtaRollback('Missing file record: ' + entry.name);
          return;
        }
        verifyRecordIntegrity(rec, entry.sha256, entry.kind === 'asset', function(vErr) {
          if (vErr) {
            triggerFatalOtaRollback(vErr.message || String(vErr));
            return;
          }
          loadedRecords[entry.name] = rec;
          loadAndVerifyNext();
        });
      });
    }

    // Phase 2: Hydrate Assets -> CSS -> HTML -> Vendor Scripts -> App Scripts
    function applyVerifiedBundle() {
      try {
        // 1. Register OTA Assets into window.TVAssets
        var assets = manifest.assets || [];
        for (var a = 0; a < assets.length; a++) {
          var aName = assets[a].name;
          var aRec = loadedRecords[aName];
          if (aRec && aRec.source === 'ota' && aRec.content) {
            window.TVAssets.register(aName, aRec.content);
          }
          delete loadedRecords[aName];
        }

        // 2. Inject Stylesheets & Remove Factory CSS to prevent ghost rules
        var styles = manifest.styles || [{ name: 'style.css' }];
        var replacedMainCss = false;
        for (var c = 0; c < styles.length; c++) {
          var sName = styles[c].name;
          var sRec = loadedRecords[sName];
          if (sRec && sRec.source === 'ota' && sRec.content) {
            var styleEl = document.createElement('style');
            styleEl.className = 'goat-ota-style';
            styleEl.setAttribute('data-ota-style', sName);
            styleEl.textContent = rewriteCssAssetUrls(sRec.content.replace(/\r\n/g, '\n'));
            document.head.appendChild(styleEl);
            if (sName === 'style.css') replacedMainCss = true;
            sRec.content = null;
          }
          delete loadedRecords[sName];
        }
        if (replacedMainCss) {
          var factoryLink = document.getElementById('goat-factory-style');
          if (factoryLink) {
            factoryLink.disabled = true;
            if (factoryLink.parentNode) factoryLink.parentNode.removeChild(factoryLink);
          }
        }

        // 3. Swap HTML DOM if index.html was updated via OTA
        if (manifest.html && manifest.html.name) {
          var htmlRec = loadedRecords[manifest.html.name];
          if (htmlRec && htmlRec.source === 'ota' && htmlRec.content) {
            applyOtaHtml(htmlRec.content);
            htmlRec.content = null;
          } else {
            window.TVAssets.applyToDom(document.body);
          }
          delete loadedRecords[manifest.html.name];
        } else {
          window.TVAssets.applyToDom(document.body);
        }

        // 4. Execute Vendor Scripts followed by App Scripts in exact manifest order
        var execQueue = [];
        var vendors = manifest.vendorScripts || [];
        for (var v = 0; v < vendors.length; v++) {
          execQueue.push({ name: vendors[v].name, localPath: 'js/' + vendors[v].name, isVendor: true });
        }
        var appScripts = manifest.scripts || [];
        if (appScripts.length === 0) {
          for (var f = 0; f < FACTORY_APP_SCRIPTS.length; f++) {
            execQueue.push({ name: FACTORY_APP_SCRIPTS[f], localPath: 'js/' + FACTORY_APP_SCRIPTS[f], isVendor: false });
          }
        } else {
          for (var s = 0; s < appScripts.length; s++) {
            execQueue.push({ name: appScripts[s].name, localPath: 'js/' + appScripts[s].name, isVendor: false });
          }
        }

        var qIdx = 0;
        function execNextScript() {
          if (qIdx >= execQueue.length) {
            try {
              flushLifecycleCallbacks();
              verifyPostBootInvariants();
              _bootFinished = true;
              console.log('[Bootloader] OTA Bundle v' + slotMeta.version + ' booted & verified successfully.');
              // Backup health timer in case markBootHealthy wasn't called synchronously
              setTimeout(function() {
                if (_bootFinished && !_bootHealthyMarked) {
                  markBootHealthy();
                }
              }, 2500);
            } catch (postErr) {
              triggerFatalOtaRollback(postErr.message || String(postErr));
            }
            return;
          }

          var item = execQueue[qIdx++];
          var rec = loadedRecords[item.name];
          delete loadedRecords[item.name];

          if (rec && rec.source === 'factory') {
            loadLocalScriptTag(item.localPath, function(loadErr) {
              if (loadErr) {
                triggerFatalOtaRollback(loadErr.message || String(loadErr));
                return;
              }
              execNextScript();
            });
            return;
          }

          if (!rec || typeof rec.content !== 'string') {
            triggerFatalOtaRollback('Missing executable script content for ' + item.name);
            return;
          }

          try {
            var code = rec.content.replace(/\r\n/g, '\n');
            rec.content = null; // Free RAM immediately before evaluation
            (0, window.eval)(code + '\n//# sourceURL=ota/' + item.name);
            code = null;
          } catch (evalErr) {
            triggerFatalOtaRollback('Script execution error in ' + item.name + ': ' + (evalErr.message || String(evalErr)));
            return;
          }

          execNextScript();
        }

        execNextScript();
      } catch (err) {
        triggerFatalOtaRollback(err.message || String(err));
      }
    }

    loadAndVerifyNext();
  }

  function markBootHealthy() {
    if (_bootHealthyMarked) return;
    _bootHealthyMarked = true;
    window.__GOAT_OTA_VERIFIED__ = true;
    try { sessionStorage.removeItem(CRASH_CANARY_KEY); } catch (_) {}
    if (!_activeBootSlot) return;
    getMetaState(function(err, state) {
      if (state && state.slots && state.slots[_activeBootSlot]) {
        state.slots[_activeBootSlot].bootedHealthy = true;
        state.slots[_activeBootSlot].bootAttempts = 0;
        saveMetaState(state);
      }
    });
  }

  function boot() {
    var crashCount = 0;
    try {
      crashCount = parseInt(sessionStorage.getItem(CRASH_CANARY_KEY) || '0', 10) || 0;
    } catch (_) {}

    getMetaState(function(err, state) {
      var activeSlot = state ? state.activeSlot : null;
      var slotMeta = (activeSlot && state && state.slots) ? state.slots[activeSlot] : null;

      if (!activeSlot || !slotMeta || !slotMeta.version) {
        try { sessionStorage.removeItem(CRASH_CANARY_KEY); } catch (_) {}
        loadFactoryScripts();
        return;
      }

      // If native package was updated to >= OTA version, purge obsolete OTA bundle
      if (!isNewer(BASE_VERSION, slotMeta.version)) {
        console.log('[Bootloader] Native v' + BASE_VERSION + ' >= cached OTA v' + slotMeta.version + '. Clearing obsolete OTA.');
        otaVault.clearAll(function() {
          loadFactoryScripts();
        });
        return;
      }

      // Check crash canary & boot attempt counter before booting unverified OTA slot
      if (!slotMeta.bootedHealthy && (crashCount >= 2 || (slotMeta.bootAttempts || 0) >= 2)) {
        otaVault.rollback('Crash canary triggered (' + crashCount + ' session / ' + slotMeta.bootAttempts + ' slot attempts)', function() {
          // Re-run boot after rollback (boots previousSlot if available, else Factory)
          boot();
        });
        return;
      }

      console.log('[Bootloader] Booting OTA Slot ' + activeSlot + ' v' + slotMeta.version + ' (Factory: v' + BASE_VERSION + ')');
      bootOtaSlot(activeSlot, slotMeta, state);
    });
  }

  window.TVBootloader = {
    OTA_PROTOCOL: OTA_PROTOCOL,
    getBaseVersion: function() { return BASE_VERSION; },
    getEmbeddedVersion: function() { return EMBEDDED_VERSION; },
    getActiveVersion: function() { return window.__GOAT_TV_VERSION__ || BASE_VERSION; },
    getBootMode: function() { return window.__GOAT_BOOT_MODE__ || 'factory'; },
    isOtaVerified: function() { return !!window.__GOAT_OTA_VERIFIED__; },
    getFactoryHash: function(name) { return (FACTORY_HASHES && FACTORY_HASHES[name]) ? FACTORY_HASHES[name].toLowerCase() : null; },
    computeSha256: computeSha256,
    computeSha256Bytes: computeSha256Bytes,
    computeSha256Async: computeSha256Async,
    markBootHealthy: markBootHealthy,
    otaVault: otaVault,
    clearOtaBundle: function(cb) {
      otaVault.clearAll(cb);
    }
  };

  boot();
})();
