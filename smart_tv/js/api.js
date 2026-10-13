// Xtream Codes API Client with In-Memory Caching, A-Z Sorting & Base64 EPG Decoding
(function() {
  var _cache = {};

  function normalizeUrl(url) {
    if (!url) return '';
    var trimmed = url.trim();
    if (!/^https?:\/\//i.test(trimmed)) {
      trimmed = 'http://' + trimmed;
    }
    return trimmed.replace(/\/+$/, '');
  }

  function sortAlpha(array, key) {
    return (array || []).slice().sort(function(a, b) {
      var nameA = (a[key] || '').toLowerCase().trim();
      var nameB = (b[key] || '').toLowerCase().trim();
      return nameA.localeCompare(nameB);
    });
  }

  function parseAddedTimestamp(val) {
    if (!val) return 0;
    if (typeof val === 'number') return isNaN(val) ? 0 : val;
    if (typeof val === 'string') {
      var str = val.trim();
      if (/^\d+$/.test(str)) {
        var num = parseInt(str, 10);
        return str.length >= 12 ? Math.floor(num / 1000) : num;
      }
      var isoStr = str.replace(' ', 'T');
      var parsedMs = Date.parse(isoStr);
      if (!isNaN(parsedMs)) return Math.floor(parsedMs / 1000);
      var fallbackMs = Date.parse(str);
      if (!isNaN(fallbackMs)) return Math.floor(fallbackMs / 1000);
    }
    return 0;
  }

  function sortVod(array, mode) {
    var items = (array || []).slice();
    if (mode === 'asc') {
      return items.sort(function(a, b) {
        return (a.name || '').toLowerCase().trim().localeCompare((b.name || '').toLowerCase().trim());
      });
    } else if (mode === 'desc') {
      return items.sort(function(a, b) {
        return (b.name || '').toLowerCase().trim().localeCompare((a.name || '').toLowerCase().trim());
      });
    } else {
      // Default: newly added first
      return items.sort(function(a, b) {
        var addedA = parseAddedTimestamp(a.added || a.last_modified);
        var addedB = parseAddedTimestamp(b.added || b.last_modified);
        if (addedA !== addedB) return addedB - addedA;
        return (a.name || '').toLowerCase().trim().localeCompare((b.name || '').toLowerCase().trim());
      });
    }
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

    loadM3uData: function(account) {
      if (!account || account.type !== 'm3u') return Promise.reject(new Error('Not an M3U account'));
      var cached = window.TVStorage ? window.TVStorage.getM3uData(account.id) : null;
      if (cached && cached.streams && cached.streams.length > 0) {
        return Promise.resolve(cached);
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
    getLiveCategories: function(account) {
      var cacheKey = account.id + '_live_cats';
      if (_cache[cacheKey]) return Promise.resolve(_cache[cacheKey]);

      if (account && account.type === 'm3u') {
        return window.TVApi.loadM3uData(account).then(function(data) {
          var cats = data.categories || [];
          _cache[cacheKey] = cats;
          return cats;
        });
      }

      var base = normalizeUrl(account.serverUrl);
      var url = base + '/player_api.php?username=' + encodeURIComponent(account.username) +
                '&password=' + encodeURIComponent(account.password) + '&action=get_live_categories';

      return fetch(url, { method: 'GET', cache: 'no-store' })
        .then(function(res) {
          if (!res.ok) throw new Error('Failed to fetch live categories');
          return res.json();
        })
        .then(function(data) {
          var list = Array.isArray(data) ? sortAlpha(data, 'category_name') : [];
          _cache[cacheKey] = list;
          return list;
        });
    },

    getLiveStreams: function(account, categoryId) {
      var cacheKey = account.id + '_live_streams_' + (categoryId || 'all');
      if (_cache[cacheKey]) return Promise.resolve(_cache[cacheKey]);

      if (account && account.type === 'm3u') {
        return window.TVApi.loadM3uData(account).then(function(data) {
          var streams = data.streams || [];
          var filtered = (!categoryId || categoryId === 'all')
            ? streams
            : streams.filter(function(s) { return s.category_id === categoryId; });
          _cache[cacheKey] = filtered;
          return filtered;
        });
      }

      var base = normalizeUrl(account.serverUrl);
      var catParam = (categoryId && categoryId !== 'all' && categoryId !== 'favorites') ? '&category_id=' + encodeURIComponent(categoryId) : '';
      var url = base + '/player_api.php?username=' + encodeURIComponent(account.username) +
                '&password=' + encodeURIComponent(account.password) + '&action=get_live_streams' + catParam;

      return fetch(url, { method: 'GET', cache: 'no-store' })
        .then(function(res) {
          if (!res.ok) throw new Error('Failed to fetch live streams');
          return res.json();
        })
        .then(function(data) {
          var list = Array.isArray(data) ? sortAlpha(data, 'name') : [];
          _cache[cacheKey] = list;
          return list;
        });
    },

    getShortEpg: function(account, streamId) {
      if (!streamId) return Promise.resolve([]);
      var base = normalizeUrl(account.serverUrl);
      var url = base + '/player_api.php?username=' + encodeURIComponent(account.username) +
                '&password=' + encodeURIComponent(account.password) + '&action=get_short_epg&stream_id=' + encodeURIComponent(streamId);

      return fetch(url, { method: 'GET', cache: 'no-store' })
        .then(function(res) {
          if (!res.ok) return [];
          return res.json();
        })
        .then(function(data) {
          if (data && Array.isArray(data.epg_listings)) {
            return data.epg_listings.map(function(item) {
              return {
                id: item.id,
                title: decodeBase64(item.title),
                description: decodeBase64(item.description),
                start: item.start,
                end: item.end,
                start_timestamp: item.start_timestamp,
                stop_timestamp: item.stop_timestamp
              };
            });
          }
          return [];
        })
        .catch(function() {
          return [];
        });
    },

    // 2. VOD MOVIES
    getVodCategories: function(account) {
      if (account && account.type === 'm3u') return Promise.resolve([]);
      var cacheKey = account.id + '_vod_cats';
      if (_cache[cacheKey]) return Promise.resolve(_cache[cacheKey]);

      var base = normalizeUrl(account.serverUrl);
      var url = base + '/player_api.php?username=' + encodeURIComponent(account.username) +
                '&password=' + encodeURIComponent(account.password) + '&action=get_vod_categories';

      return fetch(url, { method: 'GET', cache: 'no-store' })
        .then(function(res) {
          if (!res.ok) throw new Error('Failed to fetch VOD categories');
          return res.json();
        })
        .then(function(data) {
          var list = Array.isArray(data) ? sortAlpha(data, 'category_name') : [];
          _cache[cacheKey] = list;
          return list;
        });
    },

    getVodStreams: function(account, categoryId, sortMode) {
      if (account && account.type === 'm3u') return Promise.resolve([]);
      var base = normalizeUrl(account.serverUrl);
      var catParam = (categoryId && categoryId !== 'all' && categoryId !== 'favorites') ? '&category_id=' + encodeURIComponent(categoryId) : '';
      var url = base + '/player_api.php?username=' + encodeURIComponent(account.username) +
                '&password=' + encodeURIComponent(account.password) + '&action=get_vod_streams' + catParam;

      return fetch(url, { method: 'GET', cache: 'no-store' })
        .then(function(res) {
          if (!res.ok) throw new Error('Failed to fetch VOD streams');
          return res.json();
        })
        .then(function(data) {
          var list = Array.isArray(data) ? data : [];
          return sortVod(list, sortMode || 'default');
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
    getSeriesCategories: function(account) {
      if (account && account.type === 'm3u') return Promise.resolve([]);
      var cacheKey = account.id + '_series_cats';
      if (_cache[cacheKey]) return Promise.resolve(_cache[cacheKey]);

      var base = normalizeUrl(account.serverUrl);
      var url = base + '/player_api.php?username=' + encodeURIComponent(account.username) +
                '&password=' + encodeURIComponent(account.password) + '&action=get_series_categories';

      return fetch(url, { method: 'GET', cache: 'no-store' })
        .then(function(res) {
          if (!res.ok) throw new Error('Failed to fetch series categories');
          return res.json();
        })
        .then(function(data) {
          var list = Array.isArray(data) ? sortAlpha(data, 'category_name') : [];
          _cache[cacheKey] = list;
          return list;
        });
    },

    getSeries: function(account, categoryId, sortMode) {
      if (account && account.type === 'm3u') return Promise.resolve([]);
      var base = normalizeUrl(account.serverUrl);
      var catParam = (categoryId && categoryId !== 'all' && categoryId !== 'favorites') ? '&category_id=' + encodeURIComponent(categoryId) : '';
      var url = base + '/player_api.php?username=' + encodeURIComponent(account.username) +
                '&password=' + encodeURIComponent(account.password) + '&action=get_series' + catParam;

      return fetch(url, { method: 'GET', cache: 'no-store' })
        .then(function(res) {
          if (!res.ok) throw new Error('Failed to fetch series');
          return res.json();
        })
        .then(function(data) {
          var list = Array.isArray(data) ? data : [];
          return sortVod(list, sortMode || 'default');
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

    clearCache: function(accountId) {
      if (accountId) {
        Object.keys(_cache).forEach(function(k) {
          if (k.indexOf(accountId) === 0) {
            delete _cache[k];
          }
        });
      } else {
        _cache = {};
      }
    }
  };
})();
