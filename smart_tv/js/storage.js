// Storage Manager with in-memory fallback for file:// Smart TV sandboxes
(function() {
  var _memStore = {};
  var _hasNativeStorage = false;

  try {
    window.localStorage.setItem('__tv_test__', '1');
    window.localStorage.removeItem('__tv_test__');
    _hasNativeStorage = true;
  } catch(e) {
    _hasNativeStorage = false;
  }

  function getItem(key) {
    if (_hasNativeStorage) {
      try { return window.localStorage.getItem(key); } catch(e){}
    }
    return _memStore.hasOwnProperty(key) ? _memStore[key] : null;
  }

  function setItem(key, val) {
    if (_hasNativeStorage) {
      try { window.localStorage.setItem(key, String(val)); return; } catch(e){}
    }
    _memStore[key] = String(val);
  }

  function removeItem(key) {
    if (_hasNativeStorage) {
      try { window.localStorage.removeItem(key); return; } catch(e){}
    }
    delete _memStore[key];
  }

  function parseDurationSecs(raw) {
    if (raw === null || raw === undefined || raw === '') return 0;
    if (typeof raw === 'number') {
      if (isNaN(raw) || !isFinite(raw) || raw <= 10) return 0;
      return (raw < 360) ? Math.floor(raw * 60) : Math.floor(raw);
    }
    var str = String(raw).trim().toLowerCase();
    if (!str || str === '0' || str === 'null' || str === 'undefined') return 0;

    // "1h 45m" or "1h45m" or "1 h 45 min" or "2h"
    var hmMatch = str.match(/^(\d+)\s*h(?:ours?|rs?)?(?:\s*(\d+)\s*(?:m|mins?|minutes?)?)?$/);
    if (hmMatch) {
      var hours = parseInt(hmMatch[1], 10) || 0;
      var mins = parseInt(hmMatch[2], 10) || 0;
      return (hours * 3600) + (mins * 60);
    }

    // "90 min" or "90 mins" or "90m" or "90 minutes"
    var minMatch = str.match(/^(\d+)\s*(?:min|mins|minutes|m)$/);
    if (minMatch) {
      var mOnly = parseInt(minMatch[1], 10) || 0;
      return mOnly * 60;
    }

    // "HH:MM:SS" (e.g. "01:30:00")
    var timeMatch = str.match(/^(\d{1,2}):(\d{2}):(\d{2})$/);
    if (timeMatch) {
      var h = parseInt(timeMatch[1], 10) || 0;
      var m = parseInt(timeMatch[2], 10) || 0;
      var s = parseInt(timeMatch[3], 10) || 0;
      return (h * 3600) + (m * 60) + s;
    }

    // "HH:MM" or "MM:SS" (e.g. "01:30" or "90:00")
    var shortMatch = str.match(/^(\d{1,3}):(\d{2})$/);
    if (shortMatch) {
      var part1 = parseInt(shortMatch[1], 10) || 0;
      var part2 = parseInt(shortMatch[2], 10) || 0;
      if (part1 <= 10) {
        return (part1 * 3600) + (part2 * 60);
      } else {
        return (part1 * 60) + part2;
      }
    }

    // Numeric string (e.g. "5400" or "90" or "5400.0")
    if (/^\d+(\.\d+)?$/.test(str)) {
      var num = parseFloat(str);
      if (isNaN(num) || !isFinite(num) || num <= 10) return 0;
      return (num < 360) ? Math.floor(num * 60) : Math.floor(num);
    }
    return 0;
  }

  function extractDurationFromInfo(info) {
    if (!info) return 0;
    var candidates = [];
    if (info.info) {
      candidates.push(info.info.duration_secs);
      candidates.push(info.info.duration);
      candidates.push(info.info.runtime);
      candidates.push(info.info.episode_run_time);
      candidates.push(info.info.movie_duration);
    }
    if (info.movie_data) {
      candidates.push(info.movie_data.duration_secs);
      candidates.push(info.movie_data.duration);
      candidates.push(info.movie_data.runtime);
      candidates.push(info.movie_data.episode_run_time);
    }
    candidates.push(info.duration_secs);
    candidates.push(info.duration);
    candidates.push(info.runtime);
    candidates.push(info.episode_run_time);

    for (var i = 0; i < candidates.length; i++) {
      var val = candidates[i];
      if (val !== undefined && val !== null && val !== '' && val !== 0 && val !== '0') {
        var parsed = parseDurationSecs(val);
        if (parsed > 100) return parsed;
      }
    }
    return 0;
  }

  window.parseDurationSecs = parseDurationSecs;
  window.extractDurationFromInfo = extractDurationFromInfo;

  // Device-bound At-Rest Encryption Vault (SEC-04)
  var VAULT_PREFIX = 'enc:v1:';

  function getDeviceKey() {
    var salt = getItem('goat_vault_salt');
    if (!salt) {
      salt = 'salt_' + Date.now() + '_' + Math.random().toString(36).substr(2, 12);
      setItem('goat_vault_salt', salt);
    }
    return salt;
  }

  function hashStr(str) {
    if (window.TVBootloader && typeof window.TVBootloader.computeSha256 === 'function') {
      return window.TVBootloader.computeSha256(str);
    }
    // Lightweight fast synchronous hash fallback
    var h1 = 0xdeadbeef, h2 = 0x41c6ce57;
    for (var i = 0; i < str.length; i++) {
      var ch = str.charCodeAt(i);
      h1 = Math.imul(h1 ^ ch, 2654435761);
      h2 = Math.imul(h2 ^ ch, 1597334677);
    }
    h1 = Math.imul(h1 ^ (h1 >>> 16), 2246822507) ^ Math.imul(h2 ^ (h2 >>> 13), 3266489909);
    h2 = Math.imul(h2 ^ (h2 >>> 16), 2246822507) ^ Math.imul(h1 ^ (h1 >>> 13), 3266489909);
    var p1 = (h1 >>> 0).toString(16);
    var p2 = (h2 >>> 0).toString(16);
    while (p1.length < 8) p1 = '0' + p1;
    while (p2.length < 8) p2 = '0' + p2;
    return p1 + p2 + p1 + p2;
  }

  function encryptSecret(plain) {
    if (!plain || typeof plain !== 'string' || plain.indexOf(VAULT_PREFIX) === 0) return plain;
    try {
      var iv = Math.random().toString(36).substr(2, 8);
      var key = hashStr(getDeviceKey() + ':' + iv);
      var res = '';
      for (var i = 0; i < plain.length; i++) {
        var code = plain.charCodeAt(i) ^ parseInt(key.substr((i * 2) % (key.length - 2), 2), 16);
        res += (code < 16 ? '0' : '') + code.toString(16);
      }
      return VAULT_PREFIX + iv + ':' + res;
    } catch (_) {
      return plain;
    }
  }

  function decryptSecret(cipher) {
    if (!cipher || typeof cipher !== 'string' || cipher.indexOf(VAULT_PREFIX) !== 0) {
      return cipher; // Legacy plaintext account - zero breakage
    }
    try {
      var parts = cipher.substring(VAULT_PREFIX.length).split(':');
      if (parts.length !== 2) return cipher;
      var iv = parts[0];
      var hex = parts[1];
      var key = hashStr(getDeviceKey() + ':' + iv);
      var plain = '';
      for (var i = 0; i < hex.length; i += 2) {
        var code = parseInt(hex.substr(i, 2), 16) ^ parseInt(key.substr(i % (key.length - 2), 2), 16);
        plain += String.fromCharCode(code);
      }
      return plain;
    } catch (_) {
      return cipher;
    }
  }

  window.TVStorage = {
    parseDurationSecs: parseDurationSecs,
    extractDurationFromInfo: extractDurationFromInfo,
    // Accounts Management
    getAccounts: function() {
      try {
        var raw = getItem('goat_accounts');
        if (!raw) return [];
        var accounts = JSON.parse(raw);
        if (!Array.isArray(accounts)) return [];
        var hasPlaintext = false;
        var decrypted = accounts.map(function(acc) {
          if (!acc) return acc;
          var clone = Object.assign({}, acc);
          clone.syncLiveTv = clone.syncLiveTv !== false;
          clone.syncMovies = clone.syncMovies !== false;
          clone.syncSeries = clone.syncSeries !== false;
          if (clone.password) {
            if (clone.password.indexOf(VAULT_PREFIX) === 0) {
              clone.password = decryptSecret(clone.password);
            } else {
              hasPlaintext = true; // Legacy account detected
            }
          }
          if (clone.type === 'm3u' && clone.username && clone.username.trim().length > 0 && clone.serverUrl && clone.serverUrl.indexOf('.m3u') === -1) {
            delete clone.type;
          }
          return clone;
        });

        // Silently upgrade legacy accounts in localStorage
        if (hasPlaintext) {
          try {
            var reEncrypted = accounts.map(function(a) {
              if (!a) return a;
              var c = Object.assign({}, a);
              if (c.password && c.password.indexOf(VAULT_PREFIX) !== 0) {
                c.password = encryptSecret(c.password);
              }
              return c;
            });
            setItem('goat_accounts', JSON.stringify(reEncrypted));
          } catch (_) {}
        }

        return decrypted;
      } catch(e) {
        return [];
      }
    },
    saveAccount: function(acc) {
      var accounts = this.getAccounts();
      if (!acc.id) acc.id = 'acc_' + Date.now() + '_' + Math.floor(Math.random() * 100000);
      acc.syncLiveTv = acc.syncLiveTv !== false;
      acc.syncMovies = acc.syncMovies !== false;
      acc.syncSeries = acc.syncSeries !== false;
      if (acc.username && String(acc.username).trim().length > 0 && acc.serverUrl && acc.serverUrl.indexOf('.m3u') === -1) {
        delete acc.type;
      }
      var strId = String(acc.id);
      var idx = accounts.findIndex(function(a) { return String(a.id) === strId; });
      if (idx >= 0) {
        accounts[idx] = Object.assign({}, accounts[idx], acc);
      } else {
        accounts.push(acc);
      }

      var encryptedList = accounts.map(function(a) {
        var c = Object.assign({}, a);
        if (c.password) {
          c.password = encryptSecret(c.password);
        }
        return c;
      });
      setItem('goat_accounts', JSON.stringify(encryptedList));
      return accounts[idx >= 0 ? idx : accounts.length - 1];
    },
    updateAccountInfo: function(id, info) {
      if (!id || !info) return null;
      var strId = String(id);
      var accounts = this.getAccounts();
      var acc = accounts.find(function(a) { return String(a.id) === strId; });
      if (acc) {
        if (info.exp_date !== undefined) acc.expDate = info.exp_date;
        if (info.expDate !== undefined) acc.expDate = info.expDate;
        if (info.max_connections !== undefined) acc.maxConnections = info.max_connections;
        if (info.maxConnections !== undefined) acc.maxConnections = info.maxConnections;
        if (info.active_cons !== undefined) acc.activeConnections = info.active_cons;
        if (info.activeConnections !== undefined) acc.activeConnections = info.activeConnections;
        if (info.status !== undefined) acc.status = info.status;

        var encryptedList = accounts.map(function(a) {
          var c = Object.assign({}, a);
          if (c.password) {
            c.password = encryptSecret(c.password);
          }
          return c;
        });
        setItem('goat_accounts', JSON.stringify(encryptedList));
        return acc;
      }
      return null;
    },
    updateSyncScopes: function(id, scopes) {
      if (!id || !scopes) return null;
      var strId = String(id);
      var accounts = this.getAccounts();
      var acc = accounts.find(function(a) { return String(a.id) === strId; });
      if (acc) {
        if (scopes.syncLiveTv !== undefined) acc.syncLiveTv = !!scopes.syncLiveTv;
        if (scopes.syncMovies !== undefined) acc.syncMovies = !!scopes.syncMovies;
        if (scopes.syncSeries !== undefined) acc.syncSeries = !!scopes.syncSeries;

        var encryptedList = accounts.map(function(a) {
          var c = Object.assign({}, a);
          if (c.password) {
            c.password = encryptSecret(c.password);
          }
          return c;
        });
        setItem('goat_accounts', JSON.stringify(encryptedList));
        return acc;
      }
      return null;
    },
    deleteAccount: function(id) {
      if (!id) return;
      var strId = String(id);
      var accounts = this.getAccounts().filter(function(a) { return String(a.id) !== strId; });
      var encryptedList = accounts.map(function(a) {
        var c = Object.assign({}, a);
        if (c.password) {
          c.password = encryptSecret(c.password);
        }
        return c;
      });
      setItem('goat_accounts', JSON.stringify(encryptedList));
      if (this.getActiveAccountId() && String(this.getActiveAccountId()) === strId) {
        this.setActiveAccountId(null);
      }
      removeItem('goat_favs_' + strId + '_live');
      removeItem('goat_favs_' + strId + '_movie');
      removeItem('goat_favs_' + strId + '_series');
      removeItem('goat_cat_prefs_' + strId + '_live');
      removeItem('goat_cat_prefs_' + strId + '_movie');
      removeItem('goat_cat_prefs_' + strId + '_series');
      removeItem('goat_custom_lists_' + strId + '_live');
      removeItem('goat_custom_lists_' + strId + '_movie');
      removeItem('goat_custom_lists_' + strId + '_series');
      removeItem('goat_m3u_' + strId);
    },
    saveM3uData: function(accId, data) {
      if (!accId || !data) return;
      var strId = String(accId);
      var jsonStr = JSON.stringify(data);
      setItem('goat_m3u_' + strId, jsonStr);
      _memStore['goat_m3u_' + strId] = jsonStr;
    },
    getM3uData: function(accId) {
      if (!accId) return null;
      var strId = String(accId);
      try {
        var raw = getItem('goat_m3u_' + strId);
        return raw ? JSON.parse(raw) : null;
      } catch(e) {
        return null;
      }
    },
    deleteM3uData: function(accId) {
      if (!accId) return;
      var strId = String(accId);
      removeItem('goat_m3u_' + strId);
      delete _memStore['goat_m3u_' + strId];
    },
    getActiveAccountId: function() {
      return getItem('goat_active_account_id');
    },
    setActiveAccountId: function(id) {
      if (id) {
        setItem('goat_active_account_id', String(id));
      } else {
        removeItem('goat_active_account_id');
      }
    },
    getActiveAccount: function() {
      var id = this.getActiveAccountId();
      var accounts = this.getAccounts();
      if (id) {
        var strId = String(id);
        var found = accounts.find(function(a) { return String(a.id) === strId; });
        if (found) return found;
      }
      return null;
    },

    // Favorites & Watchlists (type: 'live' | 'movie' | 'series')
    getFavorites: function(accId, type) {
      if (!accId) return [];
      var t = type || 'live';
      try {
        var raw = getItem('goat_favs_' + accId + '_' + t);
        return raw ? JSON.parse(raw) : [];
      } catch(e) {
        return [];
      }
    },
    isFavorite: function(accId, streamId, type) {
      if (!accId || !streamId) return false;
      var favs = this.getFavorites(accId, type);
      return favs.indexOf(String(streamId)) >= 0;
    },
    toggleFavorite: function(accId, streamId, type) {
      if (!accId || !streamId) return false;
      var t = type || 'live';
      var favs = this.getFavorites(accId, t);
      var idx = favs.indexOf(String(streamId));
      if (idx >= 0) {
        favs.splice(idx, 1);
      } else {
        favs.push(String(streamId));
      }
      setItem('goat_favs_' + accId + '_' + t, JSON.stringify(favs));
      return favs.indexOf(String(streamId)) >= 0;
    },

    // Category Preferences & Ordering (type: 'live' | 'movie' | 'series')
    getCategoryPrefs: function(accId, type) {
      if (!accId) return { order: [], hidden: [], newIds: [] };
      var t = type || 'live';
      try {
        var raw = getItem('goat_cat_prefs_' + accId + '_' + t);
        if (!raw) return { order: [], hidden: [], newIds: [] };
        var p = JSON.parse(raw);
        return {
          order: Array.isArray(p.order) ? p.order : [],
          hidden: Array.isArray(p.hidden) ? p.hidden : [],
          newIds: Array.isArray(p.newIds) ? p.newIds : []
        };
      } catch(e) {
        return { order: [], hidden: [], newIds: [] };
      }
    },
    saveCategoryPrefs: function(accId, type, prefs) {
      if (!accId) return;
      var t = type || 'live';
      var data = {
        order: (prefs && Array.isArray(prefs.order)) ? prefs.order : [],
        hidden: (prefs && Array.isArray(prefs.hidden)) ? prefs.hidden : [],
        newIds: (prefs && Array.isArray(prefs.newIds)) ? prefs.newIds : []
      };
      setItem('goat_cat_prefs_' + accId + '_' + t, JSON.stringify(data));
    },
    markCategoryViewed: function(accId, type, categoryId) {
      if (!accId || !categoryId) return;
      var prefs = this.getCategoryPrefs(accId, type);
      var idx = prefs.newIds.indexOf(String(categoryId));
      if (idx >= 0) {
        prefs.newIds.splice(idx, 1);
        this.saveCategoryPrefs(accId, type, prefs);
      }
    },
    setCategoryVisibility: function(accId, type, categoryId, isVisible) {
      if (!accId || !categoryId) return;
      var strCat = String(categoryId);
      var prefs = this.getCategoryPrefs(accId, type);
      var idx = prefs.hidden.indexOf(strCat);
      if (isVisible) {
        if (idx >= 0) prefs.hidden.splice(idx, 1);
      } else {
        if (idx < 0) prefs.hidden.push(strCat);
      }
      this.saveCategoryPrefs(accId, type, prefs);
    },
    reorderCategories: function(accId, type, newOrder) {
      if (!accId || !Array.isArray(newOrder)) return;
      var prefs = this.getCategoryPrefs(accId, type);
      prefs.order = newOrder.map(String);
      this.saveCategoryPrefs(accId, type, prefs);
    },
    resetCategorySortOrder: function(accId, type, categories) {
      if (!accId || !Array.isArray(categories)) return;
      var prefs = this.getCategoryPrefs(accId, type);
      var sorted = categories.slice().sort(function(a, b) {
        var na = (a.category_name || a.name || '').toLowerCase();
        var nb = (b.category_name || b.name || '').toLowerCase();
        return na.localeCompare(nb);
      });
      prefs.order = sorted.map(function(c) { return String(c.category_id || c.categoryId); });
      this.saveCategoryPrefs(accId, type, prefs);
    },
    unhideAllCategories: function(accId, type) {
      if (!accId) return;
      var prefs = this.getCategoryPrefs(accId, type);
      prefs.hidden = [];
      this.saveCategoryPrefs(accId, type, prefs);
    },
    syncCategoriesWithPrefs: function(accId, type, categories) {
      if (!accId || !Array.isArray(categories)) return categories || [];
      var prefs = this.getCategoryPrefs(accId, type);
      var catIdMap = {};
      categories.forEach(function(c) {
        var id = String(c.category_id || c.categoryId);
        catIdMap[id] = c;
      });

      var isFirstInit = prefs.order.length === 0;
      if (isFirstInit) {
        // Initial sync: alphabetize default order
        var sorted = categories.slice().sort(function(a, b) {
          var na = (a.category_name || a.name || '').toLowerCase();
          var nb = (b.category_name || b.name || '').toLowerCase();
          return na.localeCompare(nb);
        });
        prefs.order = sorted.map(function(c) { return String(c.category_id || c.categoryId); });
        prefs.newIds = [];
        this.saveCategoryPrefs(accId, type, prefs);
      } else {
        // Detect new incoming categories
        var hasNew = false;
        categories.forEach(function(c) {
          var id = String(c.category_id || c.categoryId);
          if (prefs.order.indexOf(id) === -1) {
            prefs.order.push(id);
            if (prefs.newIds.indexOf(id) === -1) {
              prefs.newIds.push(id);
            }
            hasNew = true;
          }
        });
        if (hasNew) {
          this.saveCategoryPrefs(accId, type, prefs);
        }
      }

      // Build ordered, visible list
      var result = [];
      prefs.order.forEach(function(id) {
        if (prefs.hidden.indexOf(id) === -1 && catIdMap[id]) {
          var clone = Object.assign({}, catIdMap[id]);
          clone.isNew = prefs.newIds.indexOf(id) >= 0;
          result.push(clone);
        }
      });
      return result;
    },

    // Custom Lists (type: 'live' | 'movie' | 'series')
    getCustomLists: function(accId, type) {
      if (!accId) return [];
      var t = type || 'live';
      try {
        var raw = getItem('goat_custom_lists_' + accId + '_' + t);
        return raw ? JSON.parse(raw) : [];
      } catch(e) {
        return [];
      }
    },
    createCustomList: function(accId, name, type) {
      if (!accId || !name) return null;
      var t = type || 'live';
      var lists = this.getCustomLists(accId, t);
      var newList = {
        id: 'cl_' + Date.now() + '_' + Math.floor(Math.random() * 10000),
        name: name.trim(),
        type: t,
        createdAt: Date.now()
      };
      lists.push(newList);
      setItem('goat_custom_lists_' + accId + '_' + t, JSON.stringify(lists));
      return newList;
    },
    deleteCustomList: function(accId, listId, type) {
      if (!accId || !listId) return;
      var t = type || 'live';
      var lists = this.getCustomLists(accId, t);
      lists = lists.filter(function(l) { return String(l.id) !== String(listId); });
      setItem('goat_custom_lists_' + accId + '_' + t, JSON.stringify(lists));
      removeItem('goat_custom_items_' + accId + '_' + listId);
    },
    renameCustomList: function(accId, listId, newName, type) {
      if (!accId || !listId || !newName) return;
      var t = type || 'live';
      var lists = this.getCustomLists(accId, t);
      var item = lists.find(function(l) { return String(l.id) === String(listId); });
      if (item) {
        item.name = newName.trim();
        setItem('goat_custom_lists_' + accId + '_' + t, JSON.stringify(lists));
      }
    },
    getCustomListItems: function(accId, listId) {
      if (!accId || !listId) return [];
      try {
        var raw = getItem('goat_custom_items_' + accId + '_' + listId);
        return raw ? JSON.parse(raw) : [];
      } catch(e) {
        return [];
      }
    },
    isStreamInCustomList: function(accId, listId, streamId) {
      if (!accId || !listId || !streamId) return false;
      var items = this.getCustomListItems(accId, listId);
      var strId = String(streamId);
      return items.some(function(it) { return String(it.streamId) === strId; });
    },
    addStreamToCustomList: function(accId, listId, stream) {
      if (!accId || !listId || !stream) return false;
      var items = this.getCustomListItems(accId, listId);
      var streamId = String(stream.stream_id || stream.streamId || stream.series_id || stream.seriesId);
      if (!streamId) return false;
      var exists = items.some(function(it) { return String(it.streamId) === streamId; });
      if (exists) return false;

      var streamName = stream.name || stream.title || ('Stream ' + streamId);
      var streamIcon = stream.stream_icon || stream.streamIcon || stream.cover || '';
      items.push({
        streamId: streamId,
        streamName: streamName,
        streamIcon: streamIcon,
        addedAt: Date.now()
      });
      setItem('goat_custom_items_' + accId + '_' + listId, JSON.stringify(items));
      return true;
    },
    removeStreamFromCustomList: function(accId, listId, streamId) {
      if (!accId || !listId || !streamId) return false;
      var items = this.getCustomListItems(accId, listId);
      var strId = String(streamId);
      var initLen = items.length;
      items = items.filter(function(it) { return String(it.streamId) !== strId; });
      if (items.length !== initLen) {
        setItem('goat_custom_items_' + accId + '_' + listId, JSON.stringify(items));
        return true;
      }
      return false;
    },

    // Playback Settings & Preferences
    getPreferences: function() {
      return {
        audioLanguage: getItem('goat_pref_audio') || 'original',
        subtitleLanguage: getItem('goat_pref_sub') || 'off',
        uiLanguage: getItem('goat_pref_ui_lang') || 'en'
      };
    },
    setPreference: function(key, val) {
      if (key === 'audio' || key === 'audioLanguage') setItem('goat_pref_audio', val);
      if (key === 'subtitle' || key === 'subtitleLanguage') setItem('goat_pref_sub', val);
      if (key === 'uiLanguage') setItem('goat_pref_ui_lang', val);
    },

    // Per-Media Track Memory (series or movie ID)
    getMediaAudioChoice: function(mediaId) {
      if (!mediaId) return null;
      return getItem('goat_pref_media_audio_' + mediaId);
    },
    setMediaAudioChoice: function(mediaId, choice) {
      if (!mediaId) return;
      if (choice) {
        setItem('goat_pref_media_audio_' + mediaId, choice);
      } else {
        removeItem('goat_pref_media_audio_' + mediaId);
      }
    },
    getMediaSubtitleChoice: function(mediaId) {
      if (!mediaId) return null;
      return getItem('goat_pref_media_sub_' + mediaId);
    },
    setMediaSubtitleChoice: function(mediaId, choice) {
      if (!mediaId) return;
      if (choice) {
        setItem('goat_pref_media_sub_' + mediaId, choice);
      } else {
        removeItem('goat_pref_media_sub_' + mediaId);
      }
    },

    // Resume Progress & Continue Watching System
    getProgress: function(accId, streamId) {
      if (!accId || !streamId) return null;
      try {
        var raw = getItem('goat_prog_' + accId + '_' + streamId);
        if (!raw) return null;
        var item = JSON.parse(raw);
        if (item) {
          if (item.duration !== undefined) {
            item.duration = parseDurationSecs(item.duration);
          }
          if (item.duration > 0 && (item.duration < 100 || item.duration <= item.position)) {
            item.duration = 0;
          }
          if (item.duration > 30 && (item.position / item.duration) < 0.92) {
            item.isCompleted = false;
          }
        }
        return item;
      } catch(e) {
        return null;
      }
    },
    saveProgress: function(accId, streamIdOrData, pos, dur) {
      if (!accId) return;
      var item;
      if (typeof streamIdOrData === 'object' && streamIdOrData !== null) {
        item = Object.assign({}, streamIdOrData);
      } else {
        item = {
          streamId: String(streamIdOrData),
          position: Math.floor(pos || 0),
          duration: parseDurationSecs(dur),
          updatedAt: Date.now()
        };
      }
      if (!item.streamId) return;
      item.containerExtension = item.containerExtension || item.container_extension || (typeof streamIdOrData === 'object' && (streamIdOrData.containerExtension || streamIdOrData.container_extension)) || 'mp4';
      item.position = Math.floor(item.position || 0);
      item.duration = parseDurationSecs(item.duration);
      if (item.duration > 0 && item.duration < 100) {
        item.duration = 0;
      }
      item.updatedAt = item.updatedAt || Date.now();

      // If duration is missing/0, attempt to preserve existing known duration
      if (!item.duration || item.duration <= 0) {
        try {
          var existingRaw = getItem('goat_prog_' + accId + '_' + item.streamId);
          if (existingRaw) {
            var exObj = JSON.parse(existingRaw);
            if (exObj && exObj.duration) {
              var pDur = parseDurationSecs(exObj.duration);
              if (pDur >= 100) {
                item.duration = pDur;
              }
            }
          }
        } catch(e){}
      }

      if (item.duration > 30 && (item.position / item.duration) < 0.92) {
        item.isCompleted = false;
      }
      item.isCompleted = !!item.isCompleted || (item.duration > 30 && (item.position / item.duration) >= 0.95);

      // Save individual progress record
      setItem('goat_prog_' + accId + '_' + item.streamId, JSON.stringify(item));

      // Update global Continue Watching list for this account
      var rawList = getItem('goat_cw_' + accId);
      var list = [];
      try { list = rawList ? JSON.parse(rawList) : []; } catch(e){ list = []; }
      var idx = list.findIndex(function(x) { return String(x.streamId) === String(item.streamId); });
      if (idx >= 0) {
        list[idx] = Object.assign({}, list[idx], item);
      } else {
        list.unshift(item);
      }
      if (list.length > 100) list = list.slice(0, 100);
      setItem('goat_cw_' + accId, JSON.stringify(list));
      return item;
    },
    markCompleted: function(accId, streamId) {
      if (!accId || !streamId) return;
      var existing = this.getProgress(accId, streamId);
      if (existing) {
        existing.isCompleted = true;
        existing.position = existing.duration;
        existing.updatedAt = Date.now();
        this.saveProgress(accId, existing);
      }
    },
    getContinueWatching: function(accId, type) {
      if (!accId) return [];
      var rawList = getItem('goat_cw_' + accId);
      var list = [];
      try { list = rawList ? JSON.parse(rawList) : []; } catch(e){ list = []; }
      if (!Array.isArray(list)) return [];

      if (type === 'movie') {
        return list.filter(function(item) {
          if (item.type !== 'movie') return false;
          item.duration = parseDurationSecs(item.duration);
          if (item.duration > 0 && (item.duration < 100 || item.duration <= item.position)) {
            item.duration = 0;
          }
          if (item.duration > 30 && (item.position / item.duration) < 0.92) {
            item.isCompleted = false;
          }
          var isComp = item.isCompleted || (item.duration > 30 && (item.position / item.duration) >= 0.95);
          return !isComp && item.position >= 3;
        }).sort(function(a, b) {
          return (b.updatedAt || 0) - (a.updatedAt || 0);
        });
      }

      if (type === 'series') {
        var seriesItems = list.filter(function(item) {
          if (item.type !== 'series') return false;
          item.duration = parseDurationSecs(item.duration);
          if (item.duration > 0 && (item.duration < 100 || item.duration <= item.position)) {
            item.duration = 0;
          }
          if (item.duration > 30 && (item.position / item.duration) < 0.92) {
            item.isCompleted = false;
          }
          return item.position >= 3 || item.isCompleted;
        });

        var grouped = {};
        seriesItems.forEach(function(item) {
          var key = String(item.seriesId || item.streamId);
          if (!grouped[key]) {
            grouped[key] = item;
          } else {
            var existing = grouped[key];
            var existScore = (existing.season || 1) * 1000 + (existing.episode || 1);
            var itemScore = (item.season || 1) * 1000 + (item.episode || 1);
            if (itemScore > existScore || (itemScore === existScore && (item.updatedAt || 0) > (existing.updatedAt || 0))) {
              grouped[key] = item;
            }
          }
        });

        var result = [];
        Object.keys(grouped).forEach(function(k) {
          var item = Object.assign({}, grouped[k]);
          item.duration = parseDurationSecs(item.duration);
          if (item.duration > 0 && (item.duration < 100 || item.duration <= item.position)) {
            item.duration = 0;
          }
          if (item.duration > 30 && (item.position / item.duration) < 0.92) {
            item.isCompleted = false;
          }
          var isComp = item.isCompleted || (item.duration > 30 && (item.position / item.duration) >= 0.95);
          if (isComp) {
            if (item.isFinale) {
              return; // Completed series finale removed from rail
            }
            item.isAdvanced = true;
            item.isCompleted = false;
            if (item.nextSeason) {
              item.season = parseInt(item.nextSeason, 10);
              item.episode = parseInt(item.nextEpisodeNum, 10) || 1;
            } else {
              item.episode = (item.episode || 1) + 1;
            }
            item.position = 0;
            item.title = item.nextEpisodeTitle || ('Episode ' + item.episode);
            if (item.nextStreamId) item.streamId = item.nextStreamId;
          } else {
            item.isAdvanced = false;
          }
          result.push(item);
        });

        return result.sort(function(a, b) {
          return (b.updatedAt || 0) - (a.updatedAt || 0);
        });
      }

      return [];
    },
    deleteProgress: function(accId, streamId) {
      if (!accId || !streamId) return;
      removeItem('goat_prog_' + accId + '_' + streamId);
      var rawList = getItem('goat_cw_' + accId);
      if (rawList) {
        try {
          var list = JSON.parse(rawList);
          list = list.filter(function(x) { return String(x.streamId) !== String(streamId); });
          setItem('goat_cw_' + accId, JSON.stringify(list));
        } catch(e){}
      }
    }
  };
})();
