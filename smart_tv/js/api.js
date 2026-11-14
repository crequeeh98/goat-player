// Xtream Codes API Client with RAM + IndexedDB SWR Caching, Fast Sorting & Short-TTL EPG
(function() {
  var _cache = {};
  var MAX_STREAM_CACHE = 8;
  var _streamCacheKeys = [];
  var _streamCache = {};
  var _sortedStreamCache = {};
  var _inFlight = {};
  var _epgCache = {};
  var _epgInFlight = {};
  var EPG_TTL_MS = 240000; // 4 minutes
  var SWR_TTL_DEFAULT_MS = 30 * 60 * 1000; // 30 minutes
  var SWR_TTL_CALLBACK_MS = 5 * 60 * 1000; // 5 minutes when onRevalidate is provided
  var IDB_MAX_ARRAY_LEN = 6000;

  function invalidateSortedKey(key) {
    var prefix = key + '::';
    Object.keys(_sortedStreamCache).forEach(function(sk) {
      if (sk.indexOf(prefix) === 0) delete _sortedStreamCache[sk];
    });
  }

  function putStreamCache(key, data) {
    invalidateSortedKey(key);
    var idx = _streamCacheKeys.indexOf(key);
    if (idx !== -1) {
      _streamCacheKeys.splice(idx, 1);
    } else if (_streamCacheKeys.length >= MAX_STREAM_CACHE) {
      var oldest = _streamCacheKeys.shift();
      delete _streamCache[oldest];
      invalidateSortedKey(oldest);
    }
    _streamCacheKeys.push(key);
    _streamCache[key] = data;
  }

  function getStreamCache(key) {
    var idx = _streamCacheKeys.indexOf(key);
    if (idx === -1) return null;
    _streamCacheKeys.splice(idx, 1);
    _streamCacheKeys.push(key);
    return _streamCache[key];
  }

  function putCatCache(key, data) {
    _cache[key] = data;
  }

  function getCatCache(key) {
    return _cache[key] || null;
  }

  function isOversizedForIdb(key, data) {
    if (key && /_streams_all$/.test(key)) return true;
    if (Array.isArray(data) && data.length > IDB_MAX_ARRAY_LEN) return true;
    return false;
  }

  function idbGet(key) {
    if (key && /_streams_all$/.test(key)) return Promise.resolve(null);
    if (window.TVIdbCache && typeof window.TVIdbCache.get === 'function') {
      return window.TVIdbCache.get(key);
    }
    return Promise.resolve(null);
  }

  function idbSet(key, data) {
    if (isOversizedForIdb(key, data)) return Promise.resolve();
    if (window.TVIdbCache && typeof window.TVIdbCache.set === 'function') {
      return window.TVIdbCache.set(key, data);
    }
    return Promise.resolve();
  }

  function swrFetch(cacheKey, options, getRamFn, setRamFn, networkFn, transformFn) {
    var force = !!(options && options.force);
    var onRevalidate = (options && typeof options.onRevalidate === 'function') ? options.onRevalidate : null;
    var ttl = onRevalidate ? SWR_TTL_CALLBACK_MS : SWR_TTL_DEFAULT_MS;
    var finish = function(raw) {
      return transformFn ? transformFn(raw) : raw;
    };

    function runNetworkAndCache(forceNew) {
      if (!forceNew && _inFlight[cacheKey]) {
        return _inFlight[cacheKey];
      }
      var p = networkFn().then(function(fresh) {
        setRamFn(cacheKey, fresh);
        idbSet(cacheKey, fresh);
        if (_inFlight[cacheKey] === p) delete _inFlight[cacheKey];
        return fresh;
      }, function(err) {
        if (_inFlight[cacheKey] === p) delete _inFlight[cacheKey];
        throw err;
      });
      _inFlight[cacheKey] = p;
      return p;
    }

    if (!force) {
      var ramHit = getRamFn(cacheKey);
      if (ramHit) {
        return Promise.resolve(finish(ramHit));
      }

      return idbGet(cacheKey).then(function(cached) {
        if (cached && cached.data !== undefined && cached.data !== null) {
          setRamFn(cacheKey, cached.data);
          var age = Date.now() - (cached.updatedAt || 0);
          if (age > ttl) {
            runNetworkAndCache(false).then(function(fresh) {
              if (onRevalidate) {
                try { onRevalidate(finish(fresh)); } catch (_) {}
              }
            }).catch(function() {});
          }
          return finish(cached.data);
        }

        return runNetworkAndCache(false).then(finish);
      });
    }

    return runNetworkAndCache(true).then(finish);
  }

  function normalizeUrl(url) {
    if (!url) return '';
    var trimmed = url.trim();
    if (!/^https?:\/\//i.test(trimmed)) {
      trimmed = 'http://' + trimmed;
    }
    return trimmed.replace(/\/+$/, '');
  }

  function sortAlpha(array, key) {
    if (!array || array.length === 0) return [];
    var items = array.slice();
    for (var i = 0; i < items.length; i++) {
      var it = items[i];
      if (it) it._sortName = (it[key] || '').toLowerCase().trim();
    }
    items.sort(function(a, b) {
      var na = a ? a._sortName : '';
      var nb = b ? b._sortName : '';
      return na < nb ? -1 : (na > nb ? 1 : 0);
    });
    return items;
  }

  function parseAddedTimestamp(val) {
    if (!val) return 0;
    if (typeof val === 'number') return isNaN(val) ? 0 : val;
    if (typeof val === 'string') {
      var str = val.trim();
      var len = str.length;
      if (!len) return 0;
      var allDigits = true;
      for (var i = 0; i < len; i++) {
        var c = str.charCodeAt(i);
        if (c < 48 || c > 57) { allDigits = false; break; }
      }
      if (allDigits) {
        var num = parseInt(str, 10);
        return len >= 12 ? Math.floor(num / 1000) : num;
      }
      var isoStr = str.indexOf(' ') !== -1 ? str.replace(' ', 'T') : str;
      var parsedMs = Date.parse(isoStr);
      if (!isNaN(parsedMs)) return Math.floor(parsedMs / 1000);
    }
    return 0;
  }

  function getVodSorted(cacheKey, array, mode) {
    var m = mode || 'default';
    var sk = cacheKey + '::' + m;
    if (_sortedStreamCache[sk] && _sortedStreamCache[sk].raw === array) {
      return _sortedStreamCache[sk].sorted;
    }
    var sorted = sortVod(array, m);
    _sortedStreamCache[sk] = { raw: array, sorted: sorted };
    return sorted;
  }

  function sortVod(array, mode) {
    if (!array || array.length === 0) return [];
    var items = array.slice();
    for (var i = 0; i < items.length; i++) {
      var it = items[i];
      if (!it) continue;
      if (it._sortName === undefined) {
        it._sortName = (it.name || '').toLowerCase().trim();
      }
      if (mode !== 'asc' && mode !== 'desc' && it._addedTs === undefined) {
        it._addedTs = parseAddedTimestamp(it.added || it.last_modified);
      }
    }
    if (mode === 'asc') {
      items.sort(function(a, b) {
        var na = a ? a._sortName : '';
        var nb = b ? b._sortName : '';
        return na < nb ? -1 : (na > nb ? 1 : 0);
      });
    } else if (mode === 'desc') {
      items.sort(function(a, b) {
        var na = a ? a._sortName : '';
        var nb = b ? b._sortName : '';
        return nb < na ? -1 : (nb > na ? 1 : 0);
      });
    } else {
      // Default: newly added first
      items.sort(function(a, b) {
        var addedA = a ? (a._addedTs || 0) : 0;
        var addedB = b ? (b._addedTs || 0) : 0;
        if (addedA !== addedB) return addedB - addedA;
        var na = a ? a._sortName : '';
        var nb = b ? b._sortName : '';
        return na < nb ? -1 : (na > nb ? 1 : 0);
      });
    }
    return items;
  }

  // Base64 UTF-8 Decoder for Xtream Codes EPG
  function decodeBase64(str) {
    if (!str || typeof str !== 'string') return '';
    var trimmed = str.trim();
    // If not a valid Base64 string, return plain text
    if (!/^[A-Za-z0-9+/=]+$/.test(trimmed) || trimmed.length % 4 !== 0) {
      return trimmed;
    }
    try {
      var binary = atob(trimmed);
      var bytes = new Uint8Array(binary.length);
      for (var i = 0; i < binary.length; i++) {
        bytes[i] = binary.charCodeAt(i);
      }
      return new TextDecoder('utf-8').decode(bytes);
    } catch(e) {
      try { return atob(trimmed); } catch(err) { return trimmed; }
    }
  }

  window.TVApi = {
    normalizeUrl: normalizeUrl,
    decodeBase64: decodeBase64,
    parseAddedTimestamp: parseAddedTimestamp,
    fastSortAlpha: sortAlpha,
    fastSortVod: sortVod,

    authenticate: function(serverUrl, username, password) {
      var base = normalizeUrl(serverUrl);
      var url = base + '/player_api.php?username=' + encodeURIComponent(username) + '&password=' + encodeURIComponent(password);
      
      return fetch(url, { method: 'GET', cache: 'no-store' })
        .then(function(res) {
          if (!res.ok) throw new Error('HTTP status ' + res.status);
          return res.json();
        })
        .then(function(data) {
          if (data && data.user_info && data.user_info.auth === 1) {
            return {
              success: true,
              userInfo: data.user_info,
              serverInfo: data.server_info
            };
          } else {
            var msg = (data && data.user_info && data.user_info.message) ? data.user_info.message : 'Invalid credentials';
            throw new Error(msg);
          }
        });
    },

    authenticateM3u: function(m3uUrl, playlistName) {
      var trimmed = (m3uUrl || '').trim();
      if (!trimmed) return Promise.reject(new Error('M3U URL is required'));
      return fetch(trimmed, { method: 'GET', cache: 'no-store' })
        .then(function(res) {
          if (!res.ok) throw new Error('HTTP status ' + res.status);
          return res.text();
        })
        .then(function(text) {
          if (text.indexOf('#EXTM3U') === -1 && text.indexOf('#EXTINF') === -1) {
            throw new Error('Invalid M3U playlist format');
          }
          var parsed = window.TVM3U ? window.TVM3U.parse(text) : null;
          if (!parsed || !parsed.streams || parsed.streams.length === 0) {
            throw new Error('No playable streams found in M3U playlist');
          }
          return {
            success: true,
            parsed: parsed,
            streamCount: parsed.streams.length,
            categoryCount: parsed.categories.length
          };
        });
    },

    loadM3uData: function(account, force) {
      if (!account || account.type !== 'm3u') return Promise.reject(new Error('Not an M3U account'));
      if (!force) {
        var cached = window.TVStorage ? window.TVStorage.getM3uData(account.id) : null;
        if (cached && cached.streams && cached.streams.length > 0) {
          return Promise.resolve(cached);
        }
      }
      return fetch(account.serverUrl, { method: 'GET', cache: 'no-store' })
        .then(function(res) {
          if (!res.ok) throw new Error('HTTP status ' + res.status);
          return res.text();
        })
        .then(function(text) {
          var parsed = window.TVM3U ? window.TVM3U.parse(text) : { categories: [], streams: [] };
          if (window.TVStorage) {
            window.TVStorage.saveM3uData(account.id, parsed);
          }
          return parsed;
        });
    },

    getAccountInfo: function(account) {
      if (!account) {
        return Promise.reject(new Error('Invalid account details'));
      }
      if (account.type === 'm3u') {
        return Promise.resolve({
          username: account.name || 'M3U Playlist',
          status: 'Active',
          exp_date: null,
          max_connections: null,
          active_cons: null
        });
      }
      if (!account.serverUrl || !account.username || !account.password) {
        return Promise.reject(new Error('Invalid account details'));
      }
      var base = normalizeUrl(account.serverUrl);
      var url = base + '/player_api.php?username=' + encodeURIComponent(account.username) +
                '&password=' + encodeURIComponent(account.password);

      return fetch(url, { method: 'GET', cache: 'no-store' })
        .then(function(res) {
          if (!res.ok) throw new Error('HTTP status ' + res.status);
          return res.json();
        })
        .then(function(data) {
          if (data && data.user_info && data.user_info.auth === 1) {
            return data.user_info;
          }
          throw new Error('Failed to retrieve account info');
        });
    },

    // 1. LIVE TV
    getLiveCategories: function(account, options) {
      var cacheKey = account.id + '_live_cats';
      if (account && account.type === 'm3u') {
        var forceM3u = !!(options && options.force);
        if (!forceM3u && _cache[cacheKey]) return Promise.resolve(_cache[cacheKey]);
        return window.TVApi.loadM3uData(account, forceM3u).then(function(data) {
          var cats = data.categories || [];
          _cache[cacheKey] = cats;
          return cats;
        });
      }

      var base = normalizeUrl(account.serverUrl);
      var url = base + '/player_api.php?username=' + encodeURIComponent(account.username) +
                '&password=' + encodeURIComponent(account.password) + '&action=get_live_categories';

      return swrFetch(cacheKey, options, getCatCache, putCatCache, function() {
        return fetch(url, { method: 'GET', cache: 'no-store' })
          .then(function(res) {
            if (!res.ok) throw new Error('Failed to fetch live categories');
            return res.json();
          })
          .then(function(data) {
            return Array.isArray(data) ? sortAlpha(data, 'category_name') : [];
          });
      });
    },

    getLiveStreams: function(account, categoryId, options) {
      var cacheKey = account.id + '_live_streams_' + (categoryId || 'all');
      if (account && account.type === 'm3u') {
        var forceM3u = !!(options && options.force);
        if (!forceM3u) {
          var m3uCached = getStreamCache(cacheKey);
          if (m3uCached) return Promise.resolve(m3uCached);
        }
        return window.TVApi.loadM3uData(account, forceM3u).then(function(data) {
          var streams = data.streams || [];
          var filtered = (!categoryId || categoryId === 'all')
            ? streams
            : streams.filter(function(s) { return s.category_id === categoryId; });
          putStreamCache(cacheKey, filtered);
          return filtered;
        });
      }

      var base = normalizeUrl(account.serverUrl);
      var catParam = (categoryId && categoryId !== 'all' && categoryId !== 'favorites') ? '&category_id=' + encodeURIComponent(categoryId) : '';
      var url = base + '/player_api.php?username=' + encodeURIComponent(account.username) +
                '&password=' + encodeURIComponent(account.password) + '&action=get_live_streams' + catParam;

      return swrFetch(cacheKey, options, getStreamCache, putStreamCache, function() {
        return fetch(url, { method: 'GET', cache: 'no-store' })
          .then(function(res) {
            if (!res.ok) throw new Error('Failed to fetch live streams');
            return res.json();
          })
          .then(function(data) {
            return Array.isArray(data) ? sortAlpha(data, 'name') : [];
          });
      });
    },

    getCachedShortEpg: function(account, streamId) {
      if (!account || !account.id || !streamId) return null;
      var key = account.id + '_' + streamId;
      var entry = _epgCache[key];
      if (!entry) return null;
      if ((Date.now() - entry.ts) >= EPG_TTL_MS) {
        delete _epgCache[key];
        return null;
      }
      return entry.data;
    },

    getShortEpg: function(account, streamId, options) {
      if (!account || account.type === 'm3u' || !streamId || !account.serverUrl || !account.username || !account.password) {
        return Promise.resolve([]);
      }
      var signal = (options && options.signal) ? options.signal : null;
      var force = !!(options && options.force);
      if (signal && signal.aborted) {
        return Promise.resolve([]);
      }

      var key = account.id + '_' + streamId;
      if (!force) {
        var fresh = this.getCachedShortEpg(account, streamId);
        if (fresh !== null) return Promise.resolve(fresh);
      }

      var entry = (!force && _epgInFlight[key]) ? _epgInFlight[key] : null;
      if (!entry) {
        var base = normalizeUrl(account.serverUrl);
        var url = base + '/player_api.php?username=' + encodeURIComponent(account.username) +
                  '&password=' + encodeURIComponent(account.password) + '&action=get_short_epg&stream_id=' + encodeURIComponent(streamId);
        var ctrl = (typeof AbortController === 'function') ? new AbortController() : null;
        var fetchOpts = { method: 'GET', cache: 'no-store' };
        if (ctrl) {
          fetchOpts.signal = ctrl.signal;
        } else if (signal) {
          fetchOpts.signal = signal;
        }

        entry = { controller: ctrl, waiters: 0, promise: null };
        entry.promise = fetch(url, fetchOpts)
          .then(function(res) {
            if (!res.ok) return null;
            return res.json();
          })
          .then(function(data) {
            if (data === null) return [];
            var listings = [];
            if (data && Array.isArray(data.epg_listings)) {
              listings = data.epg_listings.map(function(item) {
                return {
                  id: item.id,
                  title: decodeBase64(item.title),
                  description: decodeBase64(item.description),
                  start: item.start,
                  end: item.end,
                  start_timestamp: item.start_timestamp,
                  stop_timestamp: item.stop_timestamp,
                  now_playing: item.now_playing
                };
              });
            }
            _epgCache[key] = { data: listings, ts: Date.now() };
            return listings;
          })
          .catch(function() {
            return [];
          })
          .then(function(res) {
            if (_epgInFlight[key] === entry) delete _epgInFlight[key];
            return res;
          });
        _epgInFlight[key] = entry;
      }

      entry.waiters++;
      if (!signal) {
        return entry.promise;
      }

      return new Promise(function(resolve) {
        var settled = false;
        function onAbort() {
          if (settled) return;
          settled = true;
          entry.waiters--;
          if (entry.waiters <= 0 && entry.controller) {
            try { entry.controller.abort(); } catch (_) {}
          }
          resolve([]);
        }
        signal.addEventListener('abort', onAbort, { once: true });
        entry.promise.then(function(listings) {
          if (settled) return;
          settled = true;
          try { signal.removeEventListener('abort', onAbort); } catch (_) {}
          resolve(listings);
        });
      });
    },

    // 2. VOD MOVIES
    getVodCategories: function(account, options) {
      if (account && account.type === 'm3u') return Promise.resolve([]);
      var cacheKey = account.id + '_vod_cats';
      var base = normalizeUrl(account.serverUrl);
      var url = base + '/player_api.php?username=' + encodeURIComponent(account.username) +
                '&password=' + encodeURIComponent(account.password) + '&action=get_vod_categories';

      return swrFetch(cacheKey, options, getCatCache, putCatCache, function() {
        return fetch(url, { method: 'GET', cache: 'no-store' })
          .then(function(res) {
            if (!res.ok) throw new Error('Failed to fetch VOD categories');
            return res.json();
          })
          .then(function(data) {
            return Array.isArray(data) ? sortAlpha(data, 'category_name') : [];
          });
      });
    },

    getVodStreams: function(account, categoryId, sortMode, options) {
      if (account && account.type === 'm3u') return Promise.resolve([]);
      var cacheKey = account.id + '_vod_streams_' + (categoryId || 'all');
      var base = normalizeUrl(account.serverUrl);
      var catParam = (categoryId && categoryId !== 'all' && categoryId !== 'favorites') ? '&category_id=' + encodeURIComponent(categoryId) : '';
      var url = base + '/player_api.php?username=' + encodeURIComponent(account.username) +
                '&password=' + encodeURIComponent(account.password) + '&action=get_vod_streams' + catParam;

      return swrFetch(cacheKey, options, getStreamCache, putStreamCache, function() {
        return fetch(url, { method: 'GET', cache: 'no-store' })
          .then(function(res) {
            if (!res.ok) throw new Error('Failed to fetch VOD streams');
            return res.json();
          })
          .then(function(data) {
            return Array.isArray(data) ? data : [];
          });
      }, function(rawList) {
        return getVodSorted(cacheKey, rawList, sortMode || 'default');
      });
    },

    getVodInfo: function(account, vodId) {
      if (account && account.type === 'm3u') return Promise.reject(new Error('VOD not supported on M3U'));
      var base = normalizeUrl(account.serverUrl);
      var url = base + '/player_api.php?username=' + encodeURIComponent(account.username) +
                '&password=' + encodeURIComponent(account.password) + '&action=get_vod_info&vod_id=' + encodeURIComponent(vodId);

      return fetch(url, { method: 'GET', cache: 'no-store' })
        .then(function(res) {
          if (!res.ok) throw new Error('Failed to fetch VOD info');
          return res.json();
        });
    },

    // 3. SERIES
    getSeriesCategories: function(account, options) {
      if (account && account.type === 'm3u') return Promise.resolve([]);
      var cacheKey = account.id + '_series_cats';
      var base = normalizeUrl(account.serverUrl);
      var url = base + '/player_api.php?username=' + encodeURIComponent(account.username) +
                '&password=' + encodeURIComponent(account.password) + '&action=get_series_categories';

      return swrFetch(cacheKey, options, getCatCache, putCatCache, function() {
        return fetch(url, { method: 'GET', cache: 'no-store' })
          .then(function(res) {
            if (!res.ok) throw new Error('Failed to fetch series categories');
            return res.json();
          })
          .then(function(data) {
            return Array.isArray(data) ? sortAlpha(data, 'category_name') : [];
          });
      });
    },

    getSeries: function(account, categoryId, sortMode, options) {
      if (account && account.type === 'm3u') return Promise.resolve([]);
      var cacheKey = account.id + '_series_streams_' + (categoryId || 'all');
      var base = normalizeUrl(account.serverUrl);
      var catParam = (categoryId && categoryId !== 'all' && categoryId !== 'favorites') ? '&category_id=' + encodeURIComponent(categoryId) : '';
      var url = base + '/player_api.php?username=' + encodeURIComponent(account.username) +
                '&password=' + encodeURIComponent(account.password) + '&action=get_series' + catParam;

      return swrFetch(cacheKey, options, getStreamCache, putStreamCache, function() {
        return fetch(url, { method: 'GET', cache: 'no-store' })
          .then(function(res) {
            if (!res.ok) throw new Error('Failed to fetch series');
            return res.json();
          })
          .then(function(data) {
            return Array.isArray(data) ? data : [];
          });
      }, function(rawList) {
        return getVodSorted(cacheKey, rawList, sortMode || 'default');
      });
    },

    getSeriesInfo: function(account, seriesId) {
      if (account && account.type === 'm3u') return Promise.reject(new Error('Series not supported on M3U'));
      var base = normalizeUrl(account.serverUrl);
      var url = base + '/player_api.php?username=' + encodeURIComponent(account.username) +
                '&password=' + encodeURIComponent(account.password) + '&action=get_series_info&series_id=' + encodeURIComponent(seriesId);

      return fetch(url, { method: 'GET', cache: 'no-store' })
        .then(function(res) {
          if (!res.ok) throw new Error('Failed to fetch series info');
          return res.json();
        });
    },

    // 4. URL GENERATORS
    getLiveStreamUrl: function(account, streamId, useHls) {
      if (account && account.type === 'm3u') {
        var m3uData = window.TVStorage ? window.TVStorage.getM3uData(account.id) : null;
        if (m3uData && m3uData.streams) {
          var strId = String(streamId);
          var found = m3uData.streams.find(function(s) {
            return String(s.stream_id) === strId;
          });
          if (found && found.url) return found.url;
        }
      }
      var base = normalizeUrl(account ? account.serverUrl : '');
      var ext = useHls ? 'm3u8' : 'ts';
      return base + '/live/' + encodeURIComponent(account ? account.username : '') + '/' + encodeURIComponent(account ? account.password : '') + '/' + streamId + '.' + ext;
    },

    getVodStreamUrl: function(account, streamId, ext) {
      var base = normalizeUrl(account.serverUrl);
      var extension = ext || 'mp4';
      return base + '/movie/' + encodeURIComponent(account.username) + '/' + encodeURIComponent(account.password) + '/' + streamId + '.' + extension;
    },

    getSeriesStreamUrl: function(account, streamId, ext) {
      var base = normalizeUrl(account.serverUrl);
      var extension = ext || 'mp4';
      return base + '/series/' + encodeURIComponent(account.username) + '/' + encodeURIComponent(account.password) + '/' + streamId + '.' + extension;
    },

    clearCache: function(accountId, scope) {
      var normalizedScope = scope === 'movies' ? 'vod' : scope;
      if (accountId) {
        var accPrefix = String(accountId) + '_';
        if (!normalizedScope || normalizedScope === 'live' || normalizedScope === 'vod' || normalizedScope === 'series') {
          var scopePrefix = normalizedScope ? (accPrefix + normalizedScope + '_') : accPrefix;
          Object.keys(_cache).forEach(function(k) {
            if (k.indexOf(scopePrefix) === 0) {
              delete _cache[k];
            }
          });
          _streamCacheKeys = _streamCacheKeys.filter(function(k) {
            if (k.indexOf(scopePrefix) === 0) {
              delete _streamCache[k];
              invalidateSortedKey(k);
              return false;
            }
            return true;
          });
          Object.keys(_inFlight).forEach(function(k) {
            if (k.indexOf(scopePrefix) === 0) {
              delete _inFlight[k];
            }
          });
          if (window.TVIdbCache) {
            if (normalizedScope && typeof window.TVIdbCache.clearPrefix === 'function') {
              window.TVIdbCache.clearPrefix(scopePrefix);
            } else if (!normalizedScope && typeof window.TVIdbCache.clearAccount === 'function') {
              window.TVIdbCache.clearAccount(accountId);
            }
          }
        }
        if (!normalizedScope || normalizedScope === 'epg') {
          Object.keys(_epgCache).forEach(function(k) {
            if (k.indexOf(accPrefix) === 0) {
              delete _epgCache[k];
            }
          });
          Object.keys(_epgInFlight).forEach(function(k) {
            if (k.indexOf(accPrefix) === 0) {
              delete _epgInFlight[k];
            }
          });
        }
      } else {
        _cache = {};
        _streamCache = {};
        _streamCacheKeys = [];
        _sortedStreamCache = {};
        _inFlight = {};
        _epgCache = {};
        _epgInFlight = {};
        if (window.TVIdbCache && typeof window.TVIdbCache.clearPrefix === 'function') {
          window.TVIdbCache.clearPrefix('');
        }
      }
    }
  };
})();
