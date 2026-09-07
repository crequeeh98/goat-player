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
        var addedA = parseInt(a.added, 10) || 0;
        var addedB = parseInt(b.added, 10) || 0;
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

    getAccountInfo: function(account) {
      if (!account || !account.serverUrl || !account.username || !account.password) {
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
      var base = normalizeUrl(account.serverUrl);
      var ext = useHls ? 'm3u8' : 'ts';
      return base + '/live/' + encodeURIComponent(account.username) + '/' + encodeURIComponent(account.password) + '/' + streamId + '.' + ext;
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
