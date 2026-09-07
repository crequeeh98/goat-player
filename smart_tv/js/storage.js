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

  window.TVStorage = {
    // Accounts Management
    getAccounts: function() {
      try {
        var raw = getItem('goat_accounts');
        return raw ? JSON.parse(raw) : [];
      } catch(e) {
        return [];
      }
    },
    saveAccount: function(acc) {
      var accounts = this.getAccounts();
      if (!acc.id) acc.id = 'acc_' + Date.now() + '_' + Math.floor(Math.random() * 100000);
      var strId = String(acc.id);
      var idx = accounts.findIndex(function(a) { return String(a.id) === strId; });
      if (idx >= 0) {
        accounts[idx] = Object.assign({}, accounts[idx], acc);
      } else {
        accounts.push(acc);
      }
      setItem('goat_accounts', JSON.stringify(accounts));
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
        setItem('goat_accounts', JSON.stringify(accounts));
        return acc;
      }
      return null;
    },
    deleteAccount: function(id) {
      if (!id) return;
      var strId = String(id);
      var accounts = this.getAccounts().filter(function(a) { return String(a.id) !== strId; });
      setItem('goat_accounts', JSON.stringify(accounts));
      if (this.getActiveAccountId() && String(this.getActiveAccountId()) === strId) {
        this.setActiveAccountId(null);
      }
      removeItem('goat_favs_' + strId + '_live');
      removeItem('goat_favs_' + strId + '_movie');
      removeItem('goat_favs_' + strId + '_series');
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
        return raw ? JSON.parse(raw) : null;
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
          duration: Math.floor(dur || 0),
          updatedAt: Date.now()
        };
      }
      if (!item.streamId) return;
      item.containerExtension = item.containerExtension || item.container_extension || (typeof streamIdOrData === 'object' && (streamIdOrData.containerExtension || streamIdOrData.container_extension)) || 'mp4';
      item.position = Math.floor(item.position || 0);
      item.duration = Math.floor(item.duration || 0);
      item.updatedAt = item.updatedAt || Date.now();
      item.isCompleted = item.isCompleted || (item.duration > 0 && (item.position / item.duration) >= 0.95);

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
          var isComp = item.isCompleted || (item.duration > 0 && (item.position / item.duration) >= 0.95);
          return !isComp && item.position >= 3;
        }).sort(function(a, b) {
          return (b.updatedAt || 0) - (a.updatedAt || 0);
        });
      }

      if (type === 'series') {
        var seriesItems = list.filter(function(item) {
          return item.type === 'series' && (item.position >= 3 || item.isCompleted);
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
          var isComp = item.isCompleted || (item.duration > 0 && (item.position / item.duration) >= 0.95);
          if (isComp) {
            if (item.isFinale) {
              return; // Completed series finale removed from rail
            }
            item.isAdvanced = true;
            item.episode = (item.episode || 1) + 1;
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
