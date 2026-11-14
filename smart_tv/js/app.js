// GOATPlayer Smart TV - Complete Application Controller (Windows Recreation)
(function() {
  // Comprehensive Smart TV Platform Polyfills (webOS 3+, Tizen 3+, older Chromium)
  if (!String.prototype.padStart) {
    String.prototype.padStart = function(targetLength, padString) {
      targetLength = targetLength >> 0;
      var str = String(this);
      padString = String(padString !== undefined ? padString : ' ');
      if (str.length >= targetLength) return str;
      targetLength = targetLength - str.length;
      while (padString.length < targetLength) {
        padString += padString;
      }
      return padString.slice(0, targetLength) + str;
    };
  }
  if (!String.prototype.padEnd) {
    String.prototype.padEnd = function(targetLength, padString) {
      targetLength = targetLength >> 0;
      var str = String(this);
      padString = String(padString !== undefined ? padString : ' ');
      if (str.length >= targetLength) return str;
      targetLength = targetLength - str.length;
      while (padString.length < targetLength) {
        padString += padString;
      }
      return str + padString.slice(0, targetLength);
    };
  }
  if (!String.prototype.startsWith) {
    String.prototype.startsWith = function(search, pos) {
      return this.substr(!pos || pos < 0 ? 0 : +pos, search.length) === search;
    };
  }
  if (!String.prototype.endsWith) {
    String.prototype.endsWith = function(search, this_len) {
      if (this_len === undefined || this_len > this.length) this_len = this.length;
      return this.substring(this_len - search.length, this_len) === search;
    };
  }
  if (!String.prototype.includes) {
    String.prototype.includes = function(search, start) {
      if (typeof start !== 'number') start = 0;
      if (start + search.length > this.length) return false;
      return this.indexOf(search, start) !== -1;
    };
  }
  if (!Array.prototype.find) {
    Array.prototype.find = function(predicate) {
      if (this == null) throw new TypeError('Array.prototype.find called on null or undefined');
      if (typeof predicate !== 'function') throw new TypeError('predicate must be a function');
      var list = Object(this);
      var length = list.length >>> 0;
      var thisArg = arguments[1];
      for (var i = 0; i < length; i++) {
        var value = list[i];
        if (predicate.call(thisArg, value, i, list)) return value;
      }
      return undefined;
    };
  }
  if (!Array.prototype.findIndex) {
    Array.prototype.findIndex = function(predicate) {
      if (this == null) throw new TypeError('Array.prototype.findIndex called on null or undefined');
      if (typeof predicate !== 'function') throw new TypeError('predicate must be a function');
      var list = Object(this);
      var length = list.length >>> 0;
      var thisArg = arguments[1];
      for (var i = 0; i < length; i++) {
        if (predicate.call(thisArg, list[i], i, list)) return i;
      }
      return -1;
    };
  }
  if (!Array.prototype.includes) {
    Array.prototype.includes = function(searchElement, fromIndex) {
      if (this == null) throw new TypeError('Array.prototype.includes called on null or undefined');
      var O = Object(this);
      var len = parseInt(O.length, 10) || 0;
      if (len === 0) return false;
      var n = parseInt(fromIndex, 10) || 0;
      var k = n >= 0 ? n : Math.max(0, len + n);
      while (k < len) {
        if (searchElement === O[k] || (searchElement !== searchElement && O[k] !== O[k])) return true;
        k++;
      }
      return false;
    };
  }
  if (typeof Object.assign !== 'function') {
    Object.assign = function(target) {
      if (target == null) throw new TypeError('Cannot convert undefined or null to object');
      var to = Object(target);
      for (var index = 1; index < arguments.length; index++) {
        var nextSource = arguments[index];
        if (nextSource != null) {
          for (var nextKey in nextSource) {
            if (Object.prototype.hasOwnProperty.call(nextSource, nextKey)) {
              to[nextKey] = nextSource[nextKey];
            }
          }
        }
      }
      return to;
    };
  }

  function escapeHtml(val) {
    if (val === null || val === undefined) return '';
    return String(val)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  function sanitizeRawUrl(url) {
    if (!url) return '';
    var s = String(url).trim();
    if (!s) return '';
    if (/^(javascript|vbscript|file):/i.test(s)) return '';
    if (/^data:/i.test(s) && !/^data:image\//i.test(s)) return '';
    return s;
  }

  function sanitizeImgUrl(url) {
    return escapeHtml(sanitizeRawUrl(url));
  }

  var _activeAccount = null;
  var _currentTab = 'live'; // 'live' | 'movies' | 'series'
  var _lastMediaSourceCard = null; // Track opened movie or series for focus restoration on back
  var _catsDirty = { live: true, movie: true, series: true, accountId: null };

  function markCategoriesDirty(type) {
    if (!type || type === 'all') {
      _catsDirty.live = true;
      _catsDirty.movie = true;
      _catsDirty.series = true;
    } else {
      var t = (type === 'movies') ? 'movie' : type;
      _catsDirty[t] = true;
    }
  }

  var _dashboardEpgTimer = null;
  var _dashboardEpgAbortController = null;
  var _dashboardEpgGen = 0;
  var _channelMenuAbortController = null;
  var _channelMenuEpgGen = 0;
  
  // Live TV State
  var _liveCategories = [];
  var _selectedLiveCategory = null;
  var _liveStreams = [];
  window._liveStreams = _liveStreams;
  var _selectedLiveStream = null;
  var _virtualList = null;

  // Movies State
  var _movieCategories = [];
  var _selectedMovieCategory = null;
  var _movieStreams = [];
  var _movieFilteredList = [];
  var _movieSortMode = 'default'; // 'default' | 'asc' | 'desc'
  var _movieSearchQuery = '';
  var _movieSearchDebounce = null;

  // Series State
  var _seriesCategories = [];
  var _selectedSeriesCategory = null;
  var _seriesList = [];
  var _seriesFilteredList = [];
  var _seriesSortMode = 'default';
  var _seriesSearchQuery = '';
  var _seriesSearchDebounce = null;
  var _currentSeriesDetails = null;
  var _currentSeriesSeason = '1';

  // Master Search State
  var _searchTab = 'live';
  var _allAccountLiveStreams = null;
  var _allAccountVodStreams = null;
  var _allAccountSeriesStreams = null;
  var _fetchingMasterLivePromise = null;
  var _fetchingMasterMoviesPromise = null;
  var _fetchingMasterSeriesPromise = null;

  // Player & Sync
  var _player = null;
  var _remoteSession = null;
  var _remoteTimer = null;
  var _qrCodeInstance = null;
  var _connectionPollTimer = null;
  var _lastAddedAccount = null;

  // Modal Focus Management (Restores previous focus on modal close)
  var _lastFocusedBeforeModal = null;

  // =========================================================
  // CREATIVE SPLASH SCREEN CONTROLLER (3-5s Seamless Boot)
  // =========================================================
  var _splashLoading = false;
  var _splashStartTime = 0;
  var _splashLiveDone = false;
  var _splashMoviesDone = false;
  var _splashSeriesDone = false;
  var _splashFinishing = false;
  var _splashWatchdogTimer = null;
  var _splashCompletionTimer = null;

  function showSplashScreen(options) {
    var splashEl = document.getElementById('app-splash');
    if (!splashEl) return;

    _splashLoading = true;
    _splashStartTime = Date.now();
    _splashLiveDone = false;
    _splashMoviesDone = false;
    _splashSeriesDone = false;
    _splashFinishing = false;

    if (_splashWatchdogTimer) clearTimeout(_splashWatchdogTimer);
    if (_splashCompletionTimer) clearTimeout(_splashCompletionTimer);

    splashEl.classList.remove('dismissed');
    splashEl.style.display = 'flex';
    splashEl.style.opacity = '1';
    splashEl.style.pointerEvents = 'auto';

    var fillEl = document.getElementById('splash-progress-fill');
    if (fillEl) fillEl.style.width = '15%';

    var acc = options ? options.account : null;
    if (acc) {
      updateSplashStatus('splash_connecting', 'Connecting to Playlist...');
    } else {
      updateSplashStatus('splash_starting', 'Starting GOATPlayer TV...');
    }

    // Safety watchdog: dismiss after 5.0 seconds maximum to prevent hanging
    _splashWatchdogTimer = setTimeout(function() {
      if (_splashLoading) {
        dismissSplashScreen();
      }
    }, 5000);
  }

  var _splashStatusTimer = null;

  function updateSplashStatus(i18nKey, fallback) {
    var textEl = document.getElementById('splash-status-text');
    if (!textEl) return;
    var msg = (window.TVI18n ? window.TVI18n.t(i18nKey) : '') || fallback || '';
    if (!msg) return;

    if (_splashStatusTimer) {
      clearTimeout(_splashStatusTimer);
      _splashStatusTimer = null;
    }

    textEl.textContent = msg;
    textEl.style.opacity = '1';
  }

  function updateSplashProgress(percent, i18nKey, fallback) {
    var fillEl = document.getElementById('splash-progress-fill');
    if (fillEl) fillEl.style.width = Math.min(100, Math.max(0, percent)) + '%';
    if (i18nKey || fallback) {
      updateSplashStatus(i18nKey, fallback);
    }
  }

  function onSplashLiveLoaded() {
    if (!_splashLoading || _splashFinishing) return;
    _splashLiveDone = true;
    var pct = 40 + (_splashMoviesDone ? 25 : 0) + (_splashSeriesDone ? 25 : 0);
    updateSplashProgress(pct, 'splash_loading_all', 'Loading Live TV, Movies & Series...');
    checkSplashCompletion();
  }

  function onSplashMoviesLoaded() {
    if (!_splashLoading || _splashFinishing) return;
    _splashMoviesDone = true;
    var pct = (_splashLiveDone ? 40 : 15) + 25 + (_splashSeriesDone ? 25 : 0);
    updateSplashProgress(pct, 'splash_sync_categories', 'Synchronizing Categories...');
    checkSplashCompletion();
  }

  function onSplashSeriesLoaded() {
    if (!_splashLoading || _splashFinishing) return;
    _splashSeriesDone = true;
    var pct = (_splashLiveDone ? 40 : 15) + (_splashMoviesDone ? 25 : 0) + 25;
    updateSplashProgress(pct, 'splash_sync_channels', 'Loading Channels & Watchlist...');
    checkSplashCompletion();
  }

  function checkSplashCompletion() {
    if (!_splashLoading || _splashFinishing) return;
    if (_splashLiveDone && _splashMoviesDone && _splashSeriesDone) {
      _splashFinishing = true;
      var elapsed = Date.now() - _splashStartTime;
      // Minimum duration 3500ms (3.5s) to guarantee smooth, unhurried animation
      var minDuration = 3500;
      var remaining = Math.max(0, minDuration - elapsed);

      if (_splashCompletionTimer) clearTimeout(_splashCompletionTimer);
      _splashCompletionTimer = setTimeout(function() {
        updateSplashProgress(100, 'splash_ready', 'Ready');
        setTimeout(function() {
          dismissSplashScreen(function() {
            var activeCat = document.querySelector('#live-categories-list .category-item.active') ||
                            document.querySelector('#live-categories-list .category-item');
            if (activeCat && window.SpatialNav) {
              window.SpatialNav.setFocus(activeCat);
            }
          });
        }, 350);
      }, remaining);
    }
  }

  function dismissSplashScreen(onComplete) {
    var splashEl = document.getElementById('app-splash');
    if (!splashEl) {
      _splashLoading = false;
      _splashFinishing = false;
      var activeModal = document.querySelector('.modal-overlay.active');
      if (!activeModal && typeof onComplete === 'function') onComplete();
      return;
    }

    if (_splashWatchdogTimer) { clearTimeout(_splashWatchdogTimer); _splashWatchdogTimer = null; }
    if (_splashCompletionTimer) { clearTimeout(_splashCompletionTimer); _splashCompletionTimer = null; }

    _splashLoading = false;
    _splashFinishing = false;
    splashEl.classList.add('dismissed');

    setTimeout(function() {
      splashEl.style.display = 'none';
      var activeModal = document.querySelector('.modal-overlay.active');
      if (!activeModal && typeof onComplete === 'function') {
        onComplete();
      }
    }, 750);
  }

  function openModal(modalEl, focusTarget) {
    if (!modalEl) return;
    if (window.SpatialNav) {
      modalEl._prevFocused = window.SpatialNav.getCurrent();
      _lastFocusedBeforeModal = modalEl._prevFocused;
    }
    modalEl.classList.add('active');
    if (window.SpatialNav) {
      if (focusTarget) {
        window.SpatialNav.setFocus(focusTarget);
      } else {
        window.SpatialNav.focusFirst(modalEl);
      }
    }
  }

  function closeModal(modalEl) {
    if (!modalEl) return;
    modalEl.classList.remove('active');
    if (modalEl.id === 'login-modal' && window.TVSync) {
      window.TVSync.stopPolling();
      window.TVSync.closePairingSession(window.TVSync.getDeviceId());
    }
    if (modalEl.id === 'delete-account-modal') {
      _accountPendingDelete = null;
    }
    if (modalEl.id === 'modal-category-manager') {
      _moveModeActive = false;
      _moveModeCategoryId = null;
      window._moveModeActive = false;
      _catMgrCooldownUntil = Date.now() + 450;
      if (_catMgrDirty) {
        _catMgrDirty = false;
        markCategoriesDirty(_activeCategoryManagerType);
        if (_activeCategoryManagerType === 'live') {
          renderLiveCategories(_liveCategories, true, _selectedLiveCategory ? _selectedLiveCategory.category_id : null);
        } else if (_activeCategoryManagerType === 'movie') {
          renderMovieCategories(_movieCategories, true, _selectedMovieCategory ? _selectedMovieCategory.category_id : null);
        } else if (_activeCategoryManagerType === 'series') {
          renderSeriesCategories(_seriesCategories, true, _selectedSeriesCategory ? _selectedSeriesCategory.category_id : null);
        }
      }
    }
    if (modalEl.id === 'modal-master-search') {
      var mi = document.getElementById('master-search-input');
      if (mi) mi.value = '';
      var mcb = document.getElementById('master-search-clear-btn');
      if (mcb) mcb.style.display = 'none';
      _searchTab = 'live';
      var tabLive = document.getElementById('search-tab-live');
      var tabMovies = document.getElementById('search-tab-movies');
      var tabSeries = document.getElementById('search-tab-series');
      if (tabLive) tabLive.classList.add('active');
      if (tabMovies) tabMovies.classList.remove('active');
      if (tabSeries) tabSeries.classList.remove('active');
      executeMasterSearch('');
    }

    var restoreFocus = modalEl._prevFocused;
    modalEl._prevFocused = null;

    if (modalEl.id === 'login-modal') {
      _lastFocusedBeforeModal = null;
      var gridEl = document.getElementById('accounts-grid');
      var topAddBtn = document.getElementById('accounts-add-btn');
      if (gridEl && gridEl.style.display !== 'none' && gridEl.children.length > 0 && window.SpatialNav) {
        window.SpatialNav.focusFirst(gridEl);
      } else if (topAddBtn && window.SpatialNav) {
        window.SpatialNav.setFocus(topAddBtn);
      }
    } else if (restoreFocus && restoreFocus.offsetParent !== null && window.SpatialNav) {
      window.SpatialNav.setFocus(restoreFocus);
    } else if (_lastFocusedBeforeModal && _lastFocusedBeforeModal.offsetParent !== null && window.SpatialNav) {
      window.SpatialNav.setFocus(_lastFocusedBeforeModal);
      _lastFocusedBeforeModal = null;
    }
  }

  function init() {
    var isTizen = !!(window.tizen || (navigator.userAgent && /Tizen/i.test(navigator.userAgent)));
    if (isTizen && document.body) {
      document.body.classList.add('platform-tizen');
    }
    if (typeof window.registerTizenKeys === 'function') {
      window.registerTizenKeys();
    }
    if (window.TVI18n) window.TVI18n.applyTranslations();
    initClock();
    initPlayer();
    initVirtualList();
    setupNavigationShortcuts();
    setupHeaderButtons();
    setupModals();
    setupTabs();
    setupSearchAndSortHandlers();

    document.addEventListener('click', function(e) {
      if (!e.target.closest('.vod-sort-group')) {
        closeMovieSortDropdown();
        closeSeriesSortDropdown();
      }
    });

    // App Startup & Splash Coordination
    var accounts = window.TVStorage.getAccounts();
    var activeAcc = null;

    // Only auto-select if there is exactly ONE account registered!
    // If there are multiple accounts (> 1), NEVER auto-select - let the user choose their playlist!
    if (accounts && accounts.length === 1) {
      activeAcc = accounts[0];
    }

    if (activeAcc) {
      showSplashScreen({ account: activeAcc });
      enterDashboardWithAccount(activeAcc, { showSplash: false });
    } else {
      showSplashScreen({ account: null });
      showAccountListScreen();
      setTimeout(function() {
        updateSplashProgress(45, 'splash_starting', 'Starting GOATPlayer TV...');
      }, 600);
      setTimeout(function() {
        updateSplashProgress(80, 'splash_sync_categories', 'Synchronizing Categories...');
      }, 1400);
      setTimeout(function() {
        updateSplashProgress(100, 'splash_ready', 'Ready');
        setTimeout(function() {
          dismissSplashScreen(function() {
            var gridEl = document.getElementById('accounts-grid');
            if (gridEl && gridEl.style.display !== 'none' && window.SpatialNav) {
              window.SpatialNav.focusFirst(gridEl);
            } else {
              var addBtn = document.getElementById('accounts-add-btn');
              if (addBtn && window.SpatialNav) window.SpatialNav.setFocus(addBtn);
            }
          });
        }, 300);
      }, 2200);
    }
  }

  function initClock() {
    function update() {
      var now = new Date();
      var hours = String(now.getHours()).padStart(2, '0');
      var mins = String(now.getMinutes()).padStart(2, '0');
      var el = document.getElementById('header-clock');
      if (el) el.textContent = hours + ':' + mins;
    }
    update();
    setInterval(update, 30000);
  }

  function initPlayer() {
    _player = new window.TVPlayer({
      containerElement: document.getElementById('player-container'),
      videoElement: document.getElementById('player'),
      liveOsdElement: document.getElementById('live-infobar'),
      vodHudElement: document.getElementById('player-hud-vod')
    });
    window._goatPlayer = _player;

    // Preview Box click enters fullscreen
    var previewBox = document.getElementById('preview-player-box');
    if (previewBox) {
      previewBox.onclick = function(e) {
        if (_player && _player.currentStream && _player.playbackType === 'live') {
          _player.setMode('fullscreen');
        }
      };
    }

    // Player Container click enters fullscreen when in preview mode
    var playerContainer = document.getElementById('player-container');
    if (playerContainer) {
      playerContainer.onclick = function(e) {
        if (e.target.closest('#player-unmute-btn')) return;
        if (_player && _player.currentMode === 'preview' && _player.currentStream && _player.playbackType === 'live') {
          _player.setMode('fullscreen');
        }
      };
    }
  }

  function _saveFavoriteWithSnapshot(accId, streamId, type, streamObj) {
    var newFav = window.TVStorage.toggleFavorite(accId, streamId, type, streamObj);
    if (newFav && streamObj && typeof window.TVStorage.saveStreamSnapshot === 'function') {
      window.TVStorage.saveStreamSnapshot(accId, type, streamObj);
    }
    return newFav;
  }

  function toggleChannelFavorite(stream, wrapEl) {
    if (!_activeAccount || !stream) return;
    var newFav = _saveFavoriteWithSnapshot(_activeAccount.id, stream.stream_id, 'live', stream);
    if (wrapEl) {
      var favBtn = wrapEl.querySelector('.fav-btn');
      var starIcon = (window.TVIcons && window.TVIcons.starFilled) ? window.TVIcons.starFilled : (window.TVIcons ? window.TVIcons.star : '★');
      var starOutlineIcon = (window.TVIcons && window.TVIcons.starOutline) ? window.TVIcons.starOutline : '☆';
      if (favBtn) {
        favBtn.className = 'fav-btn ' + (newFav ? 'active' : '');
        favBtn.innerHTML = newFav ? starIcon : starOutlineIcon;
      }
    }
    var cleanName = stream.name ? stream.name.replace(/^\[.*?\]\s*/, '') : 'Channel';
    var text = newFav ? (window.TVI18n ? window.TVI18n.t('fav_added') : 'Added to Favorites') : (window.TVI18n ? window.TVI18n.t('fav_removed') : 'Removed from Favorites');
    showToast(cleanName + ': ' + text, newFav ? 'star' : 'trash');

    if (_selectedLiveCategory && _selectedLiveCategory.category_id === 'favorites') {
      if (!newFav) {
        _liveStreams = (_liveStreams || []).filter(function(s) {
          return String(s.stream_id) !== String(stream.stream_id);
        });
      } else {
        var exists = (_liveStreams || []).some(function(s) { return String(s.stream_id) === String(stream.stream_id); });
        if (!exists) _liveStreams.push(stream);
      }
      window._liveStreams = _liveStreams;
      if (_player) _player.setChannelList(_liveStreams);
      setDashboardLiveItems(_liveStreams, true);
      var countBadge = document.getElementById('live-channels-count');
      if (countBadge) countBadge.textContent = _liveStreams.length + ' ' + (window.TVI18n ? window.TVI18n.t('unit_channels') : 'Channels');
    }
  }
  window.toggleChannelFavorite = toggleChannelFavorite;

  var SYNC_TIMES_STORAGE_KEY = 'goat_sync_times_v1';
  var _syncModalTimes = (function() {
    try {
      var raw = window.localStorage ? window.localStorage.getItem(SYNC_TIMES_STORAGE_KEY) : null;
      if (raw) {
        var parsed = JSON.parse(raw);
        if (parsed && typeof parsed === 'object') return parsed;
      }
    } catch (_) {}
    return {};
  })();

  function saveSyncModalTimes() {
    try {
      if (window.localStorage) {
        window.localStorage.setItem(SYNC_TIMES_STORAGE_KEY, JSON.stringify(_syncModalTimes));
      }
    } catch (_) {}
  }

  function recordSyncTime(accId, scope, ts, overwriteExisting) {
    if (!accId || !scope) return;
    var k = String(accId);
    if (!_syncModalTimes[k]) _syncModalTimes[k] = {};
    if (!overwriteExisting && _syncModalTimes[k][scope]) return;
    _syncModalTimes[k][scope] = ts || Date.now();
    saveSyncModalTimes();
  }

  function pickDashboardEpgProgram(listings) {
    if (!listings || !listings.length) return null;
    if (typeof window.pickActiveEpgPrograms === 'function') {
      return window.pickActiveEpgPrograms(listings).current;
    }
    return listings[0];
  }

  function updateDashboardRowEpgDom(streamId, listings) {
    var sid = String(streamId);
    var nowEl = document.getElementById('ch-epg-now-' + sid);
    var timeEl = document.getElementById('ch-epg-time-' + sid);
    var barEl = document.getElementById('ch-epg-bar-' + sid);
    var fillEl = document.getElementById('ch-epg-fill-' + sid);
    if (!nowEl && !timeEl && !barEl && !fillEl) return;

    var cur = pickDashboardEpgProgram(listings);
    if (cur) {
      if (nowEl) nowEl.textContent = cur.title || 'LIVE TV';
      var timing = (typeof window.calcEpgItemTiming === 'function') ? window.calcEpgItemTiming(cur) : null;
      if (timing && timing.isLive && timing.durationMin > 0) {
        if (timeEl) timeEl.textContent = timing.remainingLabel || '';
        if (barEl) barEl.style.display = 'block';
        if (fillEl) fillEl.style.width = timing.percent + '%';
      } else {
        if (timeEl) timeEl.textContent = '';
        if (barEl) barEl.style.display = 'none';
        if (fillEl) fillEl.style.width = '0%';
      }
    } else {
      if (nowEl) nowEl.textContent = 'LIVE TV';
      if (timeEl) timeEl.textContent = '';
      if (barEl) barEl.style.display = 'none';
      if (fillEl) fillEl.style.width = '0%';
    }
  }

  var _dashboardEpgTicker = null;

  function tickDashboardLiveEpg() {
    var dash = document.getElementById('view-dashboard');
    if (!dash || !dash.classList.contains('active')) return;
    if (_currentTab !== 'live' || !_activeAccount || _activeAccount.type === 'm3u') return;
    if (!window.TVApi) return;

    // 1. Update visible channel rows in virtual container from RAM cache
    var container = document.getElementById('channels-virtual-container');
    var needsFetch = false;
    if (container && container.offsetParent !== null) {
      var contRect = container.getBoundingClientRect();
      var rows = container.querySelectorAll('.channel-row[data-stream-id]');
      for (var i = 0; i < rows.length; i++) {
        var row = rows[i];
        var rect = row.getBoundingClientRect();
        if (rect.bottom < contRect.top - 80 || rect.top > contRect.bottom + 80) continue;
        var sid = row.getAttribute('data-stream-id');
        if (!sid) continue;
        var cached = (typeof window.TVApi.getCachedShortEpg === 'function')
          ? window.TVApi.getCachedShortEpg(_activeAccount, sid)
          : null;
        if (cached) {
          updateDashboardRowEpgDom(sid, cached);
          if (!pickDashboardEpgProgram(cached)) {
            needsFetch = true;
          }
        } else {
          needsFetch = true;
        }
      }
    }
    if (needsFetch) {
      scheduleDashboardVisibleEpgFetch();
    }

    // 2. Update selected/playing channel's bottom-right EPG timeline, drawer & fullscreen infobar
    var activeStream = (_player && _player.playbackType === 'live' && _player.currentStream)
      ? _player.currentStream
      : _selectedLiveStream;
    if (activeStream && activeStream.stream_id) {
      var applyActiveEpg = function(listings) {
        if (!_activeAccount || _currentTab !== 'live') return;
        var epgListEl = document.getElementById('epg-schedule-list');
        var drawerEpgList = document.getElementById('drawer-epg-list');
        var osdNow = document.getElementById('osd-live-epg-now');
        if (epgListEl) renderEpgTimeline(listings, epgListEl);
        if (drawerEpgList && drawerEpgList.offsetParent !== null) {
          renderEpgTimeline(listings, drawerEpgList);
        }
        if (osdNow) {
          var activeOsd = pickDashboardEpgProgram(listings);
          var noEpgTxt = window.TVI18n ? window.TVI18n.t('no_epg_available') : 'No upcoming programs listed for this channel.';
          osdNow.textContent = activeOsd ? (activeOsd.title || (window.TVI18n ? window.TVI18n.t('live_tv') : 'Live TV')) : noEpgTxt;
        }
        if (_player && _player.currentMode === 'fullscreen' && typeof _player._updateInfobarEpg === 'function') {
          _player._updateInfobarEpg(listings);
        }
      };

      var selCached = (typeof window.TVApi.getCachedShortEpg === 'function')
        ? window.TVApi.getCachedShortEpg(_activeAccount, activeStream.stream_id)
        : null;
      if (selCached && pickDashboardEpgProgram(selCached)) {
        applyActiveEpg(selCached);
      } else if (typeof window.TVApi.getShortEpg === 'function') {
        window.TVApi.getShortEpg(_activeAccount, activeStream.stream_id, { force: !selCached })
          .then(applyActiveEpg)
          .catch(function() {});
      }
    }
  }

  function startDashboardEpgTicker() {
    if (_dashboardEpgTicker) return;
    _dashboardEpgTicker = setInterval(tickDashboardLiveEpg, 30000);
  }

  function cancelDashboardEpgFetch() {
    if (_dashboardEpgTimer) {
      clearTimeout(_dashboardEpgTimer);
      _dashboardEpgTimer = null;
    }
    _dashboardEpgGen++;
    if (_dashboardEpgAbortController) {
      try { _dashboardEpgAbortController.abort(); } catch (_) {}
      _dashboardEpgAbortController = null;
    }
  }

  function scheduleDashboardVisibleEpgFetch() {
    cancelDashboardEpgFetch();
    if (!_activeAccount || _activeAccount.type === 'm3u' || _currentTab !== 'live') return;
    if (!window.TVApi || typeof window.TVApi.getShortEpg !== 'function') return;

    var myGen = _dashboardEpgGen;
    _dashboardEpgTimer = setTimeout(function() {
      _dashboardEpgTimer = null;
      if (myGen !== _dashboardEpgGen) return;
      if (!_activeAccount || _activeAccount.type === 'm3u' || _currentTab !== 'live') return;

      var container = document.getElementById('channels-virtual-container');
      if (!container || container.offsetParent === null) return;

      var contRect = container.getBoundingClientRect();
      var rows = container.querySelectorAll('.channel-row[data-stream-id]');
      var toFetch = [];
      for (var i = 0; i < rows.length; i++) {
        var row = rows[i];
        var rect = row.getBoundingClientRect();
        if (rect.bottom < contRect.top - 80 || rect.top > contRect.bottom + 80) continue;
        var sid = row.getAttribute('data-stream-id');
        if (!sid) continue;
        var cached = (typeof window.TVApi.getCachedShortEpg === 'function')
          ? window.TVApi.getCachedShortEpg(_activeAccount, sid)
          : null;
        if (cached) {
          updateDashboardRowEpgDom(sid, cached);
          continue;
        }
        toFetch.push(sid);
      }

      if (toFetch.length === 0) return;

      var controller = (typeof AbortController === 'function') ? new AbortController() : null;
      _dashboardEpgAbortController = controller;
      var accSnapshot = _activeAccount;
      var idx = 0;
      var activeCount = 0;
      var MAX_CONCURRENCY = 3;

      function runNext() {
        if (myGen !== _dashboardEpgGen) return;
        if (controller && controller.signal && controller.signal.aborted) return;
        if (!_activeAccount || _activeAccount.id !== accSnapshot.id) return;
        while (activeCount < MAX_CONCURRENCY && idx < toFetch.length) {
          (function(streamId) {
            activeCount++;
            var opts = controller ? { signal: controller.signal } : undefined;
            window.TVApi.getShortEpg(accSnapshot, streamId, opts)
              .then(function(listings) {
                if (myGen !== _dashboardEpgGen) return;
                if (controller && controller.signal && controller.signal.aborted) return;
                if (listings && listings.length > 0) {
                  recordSyncTime(accSnapshot.id, 'epg', Date.now(), false);
                }
                updateDashboardRowEpgDom(streamId, listings);
              })
              .catch(function() {})
              .then(function() {
                activeCount--;
                runNext();
              });
          })(toFetch[idx++]);
        }
      }
      runNext();
    }, 250);
  }

  function setDashboardLiveItems(items, isFavorites) {
    if (_virtualList) {
      _virtualList.setItems(items || [], !!isFavorites);
      var activeStream = _selectedLiveStream || (_player && _player.currentStream);
      if (activeStream && items && items.length > 0) {
        var activeSid = String(activeStream.stream_id || activeStream.id || '');
        if (activeSid) {
          for (var i = 0; i < items.length; i++) {
            if (items[i] && String(items[i].stream_id || items[i].id || '') === activeSid) {
              _virtualList.scrollToIndex(i);
              break;
            }
          }
        }
      }
    }
    if (items && items.length > 0) {
      startDashboardEpgTicker();
      scheduleDashboardVisibleEpgFetch();
    } else {
      cancelDashboardEpgFetch();
    }
  }

  function initVirtualList() {
    var container = document.getElementById('channels-virtual-container');
    _virtualList = new window.ChannelList({
      container: container,
      batchSize: 40,
      renderRow: function(rowEl, stream, index, isSelected) {
        var cleanName = stream.name ? stream.name.replace(/^\[.*?\]\s*/, '') : 'Channel';
        var iconUrl = sanitizeImgUrl(stream.stream_icon || '');
        var isFav = _activeAccount ? window.TVStorage.isFavorite(_activeAccount.id, stream.stream_id, 'live') : false;
        var isPlaying = _selectedLiveStream && String(_selectedLiveStream.stream_id) === String(stream.stream_id);
        var isMoving = window._movingLiveStreamId && String(stream.stream_id) === String(window._movingLiveStreamId);
        var moveClass = isMoving ? ' move-active' : '';
        var starIcon = (window.TVIcons && window.TVIcons.starFilled) ? window.TVIcons.starFilled : (window.TVIcons ? window.TVIcons.star : '★');
        var starOutlineIcon = (window.TVIcons && window.TVIcons.starOutline) ? window.TVIcons.starOutline : '☆';
        var tvIcon = (window.TVIcons && window.TVIcons.tv) ? window.TVIcons.tv : '';
        var swapVertIcon = (window.TVIcons && window.TVIcons.swapVert) ? window.TVIcons.swapVert : '↕';

        var sid = String(stream.stream_id);
        var safeSid = escapeHtml(sid);
        var cachedEpg = (_activeAccount && _activeAccount.type !== 'm3u' && window.TVApi && typeof window.TVApi.getCachedShortEpg === 'function')
          ? window.TVApi.getCachedShortEpg(_activeAccount, stream.stream_id)
          : null;
        var epgTitle = 'LIVE TV';
        var epgTime = '';
        var epgPercent = 0;
        var hasEpgBar = false;
        var curProg = pickDashboardEpgProgram(cachedEpg);
        if (curProg) {
          if (curProg.title) epgTitle = curProg.title;
          var timing = (typeof window.calcEpgItemTiming === 'function') ? window.calcEpgItemTiming(curProg) : null;
          if (timing && timing.isLive && timing.durationMin > 0) {
            epgTime = timing.remainingLabel || '';
            epgPercent = timing.percent;
            hasEpgBar = true;
          }
        }

        var rightIndicator =
          '<button class="fav-btn ' + (isFav ? 'active' : '') + '" tabindex="-1" title="Favorite">' + (isFav ? starIcon : starOutlineIcon) + '</button>' +
          '<span class="channel-move-indicator" style="color: #F59E0B;">' + swapVertIcon + '</span>';

        rowEl.innerHTML = 
          '<div class="channel-row ' + (isPlaying ? 'active-playing' : '') + moveClass + ' focusable" style="height:100%; width:100%;" data-stream-id="' + safeSid + '">' +
            '<div class="channel-info">' +
              (iconUrl ? '<img class="channel-logo" loading="lazy" decoding="async" src="' + iconUrl + '" onerror="this.style.display=\'none\'" />' : '<div class="channel-logo">' + tvIcon + '</div>') +
              '<div class="channel-text-col">' +
                '<span class="channel-name">' + escapeHtml(cleanName) + '</span>' +
                '<div class="channel-epg-row">' +
                  '<span class="channel-epg-now" id="ch-epg-now-' + safeSid + '">' + escapeHtml(epgTitle) + '</span>' +
                  '<span class="channel-epg-time" id="ch-epg-time-' + safeSid + '">' + escapeHtml(epgTime) + '</span>' +
                '</div>' +
                '<div class="channel-epg-bar" id="ch-epg-bar-' + safeSid + '" style="display:' + (hasEpgBar ? 'block' : 'none') + ';"><div class="channel-epg-fill" id="ch-epg-fill-' + safeSid + '" style="width:' + epgPercent + '%;"></div></div>' +
              '</div>' +
            '</div>' +
            rightIndicator +
          '</div>';

        var favBtn = rowEl.querySelector('.fav-btn');
        if (favBtn) {
          favBtn.onclick = function(e) {
            e.stopPropagation();
            toggleChannelFavorite(stream, rowEl);
          };
        }
      },
      onSelect: function(stream) {
        selectLiveStream(stream);
      }
    });

    if (container) {
      container.addEventListener('scroll', function() {
        scheduleDashboardVisibleEpgFetch();
      }, { passive: true });
    }

    window._goatVirtualList = _virtualList;
  }

  // =========================================================
  // AIRTIGHT ACCOUNT ISOLATION & CLEANUP (Zero Contamination)
  // =========================================================
  function abortChannelMenuEpg() {
    _channelMenuEpgGen++;
    if (_channelMenuAbortController) {
      try { _channelMenuAbortController.abort(); } catch (_) {}
      _channelMenuAbortController = null;
    }
  }

  function resetAllAccountState() {
    cancelDashboardEpgFetch();
    abortChannelMenuEpg();
    markCategoriesDirty('all');
    _catsDirty.accountId = null;
    _catBatchStates = {};

    // 1. Immediately stop any active playback and detach stream listeners
    if (_player) {
      _player.stop(false);
      _player.setChannelList([]);
    }
    _selectedLiveStream = null;

    // 2. Clear Live TV state & virtual list
    _liveCategories = [];
    _selectedLiveCategory = null;
    _liveStreams = [];
    window._liveStreams = [];
    if (_virtualList) {
      _virtualList.setItems([], true);
    }
    var liveCatsEl = document.getElementById('live-categories-list');
    if (liveCatsEl) {
      var loadMsg = window.TVI18n ? window.TVI18n.t('loading_categories') : 'Loading categories...';
      liveCatsEl.innerHTML = '<div class="col-placeholder" data-i18n="loading_categories">' + loadMsg + '</div>';
    }
    var liveTitle = document.getElementById('live-selected-category-title');
    if (liveTitle) liveTitle.textContent = '--';
    var liveCount = document.getElementById('live-channels-count');
    if (liveCount) liveCount.textContent = '0 ' + (window.TVI18n ? window.TVI18n.t('unit_channels') : 'Channels');

    // 3. Clear Movies state & DOM
    _movieCategories = [];
    _selectedMovieCategory = null;
    _movieStreams = [];
    _movieFilteredList = [];
    _movieSearchQuery = '';
    _movieLoadedCount = 0;
    var movCatsEl = document.getElementById('movies-categories-list');
    if (movCatsEl) {
      var loadMsg = window.TVI18n ? window.TVI18n.t('loading_categories') : 'Loading categories...';
      movCatsEl.innerHTML = '<div class="col-placeholder" data-i18n="loading_categories">' + loadMsg + '</div>';
    }
    var movGrid = document.getElementById('movies-grid-container');
    if (movGrid) {
      movGrid.innerHTML = '';
      movGrid.scrollTop = 0;
    }
    var mCw = document.getElementById('movies-continue-watching');
    if (mCw) { mCw.style.display = 'none'; var mr = document.getElementById('movies-cw-rail'); if (mr) mr.innerHTML = ''; }
    var movTitle = document.getElementById('movies-selected-category-title');
    if (movTitle) movTitle.textContent = '--';
    var movCount = document.getElementById('movies-count');
    if (movCount) movCount.textContent = '0 ' + (window.TVI18n ? window.TVI18n.t('unit_movies') : 'Movies');

    // 4. Clear Series state & DOM
    _seriesCategories = [];
    _selectedSeriesCategory = null;
    _seriesList = [];
    _seriesFilteredList = [];
    _seriesSearchQuery = '';
    _seriesLoadedCount = 0;
    _currentSeriesDetails = null;
    var serCatsEl = document.getElementById('series-categories-list');
    if (serCatsEl) {
      var loadMsg = window.TVI18n ? window.TVI18n.t('loading_categories') : 'Loading categories...';
      serCatsEl.innerHTML = '<div class="col-placeholder" data-i18n="loading_categories">' + loadMsg + '</div>';
    }
    var serGrid = document.getElementById('series-grid-container');
    if (serGrid) {
      serGrid.innerHTML = '';
      serGrid.scrollTop = 0;
    }
    var sCw = document.getElementById('series-continue-watching');
    if (sCw) { sCw.style.display = 'none'; var sr = document.getElementById('series-cw-rail'); if (sr) sr.innerHTML = ''; }
    var serTitle = document.getElementById('series-selected-category-title');
    if (serTitle) serTitle.textContent = '--';
    var serCount = document.getElementById('series-count');
    if (serCount) serCount.textContent = '0 ' + (window.TVI18n ? window.TVI18n.t('unit_shows') : 'Shows');

    // 5. Clear Master Search cache & DOM
    _allAccountLiveStreams = null;
    _allAccountVodStreams = null;
    _allAccountSeriesStreams = null;
    _fetchingMasterLivePromise = null;
    _fetchingMasterMoviesPromise = null;
    _fetchingMasterSeriesPromise = null;
    var masterInput = document.getElementById('master-search-input');
    if (masterInput) masterInput.value = '';
    var masterResults = document.getElementById('master-search-results');
    if (masterResults) masterResults.innerHTML = '';

    // 6. Clear search input values across all columns
    var searchInputIds = [
      'live-cat-search', 'movies-cat-search', 'movies-search-input',
      'series-cat-search', 'series-search-input'
    ];
    searchInputIds.forEach(function(id) {
      var el = document.getElementById(id);
      if (el) el.value = '';
    });

    var clearBtnIds = [
      'live-cat-clear-btn', 'movies-cat-clear-btn', 'movies-search-clear-btn',
      'series-cat-clear-btn', 'series-search-clear-btn', 'master-search-clear-btn'
    ];
    clearBtnIds.forEach(function(id) {
      var b = document.getElementById(id);
      if (b) b.style.display = 'none';
    });

    // 7. Reset Preview Player UI
    document.body.classList.remove('tab-live');
    var pCont = document.getElementById('player-container');
    if (pCont) {
      pCont.style.display = 'none';
      pCont.classList.remove('video-playing');
    }
    var pMsg = document.getElementById('preview-placeholder-msg');
    if (pMsg) pMsg.style.display = 'flex';
    var pSpin = document.getElementById('player-loading-spinner');
    if (pSpin) pSpin.style.display = 'none';
    var pBox = document.getElementById('preview-player-box');
    if (pBox) pBox.classList.remove('has-stream');

    // 8. Close any open overlays or modal states
    var chMenu = document.getElementById('live-channel-menu');
    if (chMenu) chMenu.style.display = 'none';
    var catMenu = document.getElementById('live-category-menu');
    if (catMenu) catMenu.style.display = 'none';
    var epgOverlay = document.getElementById('live-epg-overlay');
    if (epgOverlay) epgOverlay.style.display = 'none';
    var infobar = document.getElementById('live-infobar');
    if (infobar) infobar.classList.remove('show');
    var drawer = document.getElementById('drawer-series-episodes');
    if (drawer) drawer.classList.remove('open');
    _channelMenuChannels = [];
    _categoryMenuCategories = [];

    ['modal-movie-detail', 'modal-series-detail', 'modal-master-search'].forEach(function(mId) {
      var m = document.getElementById(mId);
      if (m && m.classList.contains('active')) {
        m.classList.remove('active');
      }
    });

    // 9. Stop active connection polling timer & reset header badge
    if (_connectionPollTimer) {
      clearInterval(_connectionPollTimer);
      _connectionPollTimer = null;
    }
    var connText = document.getElementById('header-conn-text');
    if (connText) connText.textContent = '-- / --';
    var connBadge = document.getElementById('header-connections-badge');
    if (connBadge) connBadge.classList.remove('warning');
  }

  // =========================================================
  // EXPIRY DATE FORMATTING & REAL-TIME CONNECTION MONITORING
  // =========================================================
  function formatExpiryDate(expDateVal, lang) {
    if (!expDateVal || expDateVal === 'null' || expDateVal === '' || expDateVal === 0 || expDateVal === '0') {
      return window.TVI18n ? window.TVI18n.t('unlimited') : 'Unlimited';
    }
    var sec = parseInt(expDateVal, 10);
    if (isNaN(sec) || sec <= 0) {
      return window.TVI18n ? window.TVI18n.t('unlimited') : 'Unlimited';
    }
    var d = new Date(sec * 1000);
    var day = String(d.getDate()).padStart(2, '0');
    var month = String(d.getMonth() + 1).padStart(2, '0');
    var year = d.getFullYear();
    var isExpired = (sec * 1000) < Date.now();
    var formattedDate = (lang === 'de') ? (day + '.' + month + '.' + year) : (month + '/' + day + '/' + year);
    if (isExpired) {
      var expLabel = window.TVI18n ? window.TVI18n.t('expired') : 'Expired';
      return formattedDate + ' (' + expLabel + ')';
    }
    return formattedDate;
  }

  function isAccountExpired(expDateVal) {
    if (!expDateVal || expDateVal === 'null' || expDateVal === '' || expDateVal === 0 || expDateVal === '0') {
      return false;
    }
    var sec = parseInt(expDateVal, 10);
    if (isNaN(sec) || sec <= 0) return false;
    return (sec * 1000) < Date.now();
  }

  function startConnectionPolling(account) {
    if (_connectionPollTimer) {
      clearInterval(_connectionPollTimer);
      _connectionPollTimer = null;
    }
    if (!account) return;

    function refresh() {
      if (!_activeAccount || _activeAccount.id !== account.id) return;
      if (!window.TVApi || !window.TVApi.getAccountInfo) return;

      window.TVApi.getAccountInfo(_activeAccount)
        .then(function(info) {
          if (!info) return;
          var active = parseInt(info.active_cons || '0', 10);
          var max = parseInt(info.max_connections || '1', 10);
          if (isNaN(active)) active = 0;
          if (isNaN(max) || max < 1) max = 1;

          var badgeEl = document.getElementById('header-connections-badge');
          var textEl = document.getElementById('header-conn-text');
          if (textEl) {
            textEl.textContent = active + ' / ' + max;
          }
          if (badgeEl) {
            if (active >= max) {
              badgeEl.classList.add('warning');
            } else {
              badgeEl.classList.remove('warning');
            }
          }

          // Persist latest metadata to storage
          window.TVStorage.updateAccountInfo(_activeAccount.id, {
            exp_date: info.exp_date,
            max_connections: info.max_connections,
            active_cons: info.active_cons
          });
          _activeAccount.expDate = info.exp_date;
          _activeAccount.maxConnections = info.max_connections;
          _activeAccount.activeConnections = info.active_cons;
        })
        .catch(function() {});
    }

    // Immediate initial snapshot query
    refresh();

    // Safe 60-second polling cycle while in dashboard
    _connectionPollTimer = setInterval(refresh, 60000);
  }

  // =========================================================
  // 1. SCREEN: ACCOUNT LIST SELECTION (Initial Screen)
  // =========================================================
  function showAccountListScreen() {
    resetAllAccountState();
    _activeAccount = null;
    window._activeAccount = null;

    document.getElementById('view-accounts').classList.add('active');
    document.getElementById('view-dashboard').classList.remove('active');

    renderAccountsList();
  }

  function renderAccountsList() {
    var verBadge = document.getElementById('accounts-version-badge');
    if (verBadge) {
      var activeVer = window.__GOAT_TV_VERSION__ ||
        (window.TVBootloader && typeof window.TVBootloader.getActiveVersion === 'function' ? window.TVBootloader.getActiveVersion() : null) ||
        (window.TVUpdater && typeof window.TVUpdater.getActiveVersion === 'function' ? window.TVUpdater.getActiveVersion() : null) ||
        (window.TVUpdater && typeof window.TVUpdater.getVersion === 'function' ? window.TVUpdater.getVersion() : null);
      if (activeVer) verBadge.textContent = 'v' + activeVer;
    }
    var accounts = window.TVStorage.getAccounts();
    var gridEl = document.getElementById('accounts-grid');
    var emptyEl = document.getElementById('accounts-empty');
    if (!gridEl || !emptyEl) return;

    gridEl.innerHTML = '';

    var isAnyModalOpen = !!document.querySelector('.modal-overlay.active');

    if (accounts.length === 0) {
      gridEl.style.display = 'none';
      emptyEl.style.display = 'flex';
      var topAddBtn = document.getElementById('accounts-add-btn');
      if (topAddBtn && window.SpatialNav && !isAnyModalOpen) {
        window.SpatialNav.setFocus(topAddBtn);
      }
      return;
    }

    gridEl.style.display = 'grid';
    emptyEl.style.display = 'none';

    var curLang = (window.TVI18n && window.TVI18n.getLanguage) ? window.TVI18n.getLanguage() : 'en';
    var expiresPrefix = window.TVI18n ? window.TVI18n.t('expires') : 'Expires:';
    var clockIcon = '<svg width="15" height="15" class="tv-icon-xs" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>';
    var userIcon = (window.TVIcons && window.TVIcons.user) || '';
    var playlistIcon = (window.TVIcons && window.TVIcons.playlist) || '';
    var editIcon = (window.TVIcons && window.TVIcons.edit) || '';
    var trashIcon = (window.TVIcons && window.TVIcons.trash) || '';

    accounts.forEach(function(acc) {
      var card = document.createElement('div');
      card.className = 'account-card focusable';
      var editTitle = window.TVI18n ? window.TVI18n.t('edit') : 'Edit';
      var delTitle = window.TVI18n ? window.TVI18n.t('delete') : 'Delete';

      var badgeHtml = '';
      if (acc.type === 'm3u') {
        var chCount = acc.channelCount ? (acc.channelCount + ' ' + (window.TVI18n ? window.TVI18n.t('unit_channels') : 'Channels')) : 'M3U';
        badgeHtml = '<div class="account-expiry-badge active">' +
          '<span class="expiry-value" style="color: var(--accent-light); display: inline-flex; align-items: center;">' + playlistIcon + '<span style="margin-left: 8px;">' + chCount + '</span></span>' +
        '</div>';
      } else {
        var expText = '--';
        var isExpired = false;
        if (acc.expDate !== undefined) {
          expText = formatExpiryDate(acc.expDate, curLang);
          isExpired = isAccountExpired(acc.expDate);
        }
        badgeHtml = '<div class="account-expiry-badge' + (isExpired ? ' expired' : '') + '" id="acc-exp-' + escapeHtml(acc.id) + '">' +
          clockIcon +
          '<span class="expiry-label">' + escapeHtml(expiresPrefix) + '</span> ' +
          '<span class="expiry-value">' + escapeHtml(expText) + '</span>' +
        '</div>';
      }

      card.innerHTML = 
        '<div class="account-card-left">' +
          '<div class="account-avatar">' + (acc.type === 'm3u' ? playlistIcon : userIcon) + '</div>' +
          '<div class="account-details">' +
            '<span class="account-name">' + escapeHtml(acc.name || acc.username || 'M3U Playlist') + '</span>' +
            '<span class="account-url">' + escapeHtml(acc.serverUrl) + '</span>' +
            badgeHtml +
          '</div>' +
        '</div>' +
        '<div class="account-card-actions">' +
          '<button class="account-icon-btn edit focusable" title="' + escapeHtml(editTitle) + '" data-i18n-title="edit">' + editIcon + '</button>' +
          '<button class="account-icon-btn delete focusable" title="' + escapeHtml(delTitle) + '" data-i18n-title="delete">' + trashIcon + '</button>' +
        '</div>';

      // Asynchronous background fallback if expDate not yet cached in storage
      if (acc.type !== 'm3u' && acc.expDate === undefined && window.TVApi && window.TVApi.getAccountInfo) {
        window.TVApi.getAccountInfo(acc)
          .then(function(info) {
            if (info) {
              window.TVStorage.updateAccountInfo(acc.id, {
                exp_date: info.exp_date,
                max_connections: info.max_connections,
                active_cons: info.active_cons
              });
              acc.expDate = info.exp_date;
              acc.maxConnections = info.max_connections;
              acc.activeConnections = info.active_cons;

              var badgeEl = document.getElementById('acc-exp-' + acc.id);
              if (badgeEl) {
                var langNow = (window.TVI18n && window.TVI18n.getLanguage) ? window.TVI18n.getLanguage() : 'en';
                var valEl = badgeEl.querySelector('.expiry-value');
                if (valEl) valEl.textContent = formatExpiryDate(info.exp_date, langNow);
                if (isAccountExpired(info.exp_date)) {
                  badgeEl.classList.add('expired');
                } else {
                  badgeEl.classList.remove('expired');
                }
              }
            }
          })
          .catch(function() {});
      }

      card.onclick = function() {
        enterDashboardWithAccount(acc, { showSplash: true });
      };

      var editBtn = card.querySelector('.account-icon-btn.edit');
      if (editBtn) {
        editBtn.onclick = function(e) {
          e.stopPropagation();
          showEditAccountModal(acc);
        };
      }

      var delBtn = card.querySelector('.account-icon-btn.delete');
      if (delBtn) {
        delBtn.onclick = function(e) {
          e.stopPropagation();
          showDeleteAccountModal(acc);
        };
      }

      gridEl.appendChild(card);
    });

    if (window.SpatialNav && !isAnyModalOpen) window.SpatialNav.focusFirst(gridEl);
  }

  function enterDashboardWithAccount(account, options) {
    // Explicitly close any open modal overlay (including login-modal)
    var openModals = document.querySelectorAll('.modal-overlay.active');
    openModals.forEach(function(m) {
      m.classList.remove('active');
    });

    if (options && options.showSplash) {
      showSplashScreen({ account: account });
    }

    function proceed() {
      var remainingModals = document.querySelectorAll('.modal-overlay.active');
      remainingModals.forEach(function(m) {
        m.classList.remove('active');
      });

      resetAllAccountState();
      _activeAccount = account;
      window._activeAccount = account;
      window.TVStorage.setActiveAccountId(account.id);

      // Start live active / allowed connections tracking
      startConnectionPolling(account);

      document.getElementById('view-accounts').classList.remove('active');
      document.getElementById('view-dashboard').classList.add('active');

      var nameEl = document.getElementById('header-account-name');
      if (nameEl) nameEl.textContent = account.name || account.username;

      // Reset preview player so it shows clean placeholder without buffer spinner
      var pCont = document.getElementById('player-container');
      if (pCont) pCont.style.display = 'none';
      var pMsg = document.getElementById('preview-placeholder-msg');
      if (pMsg) pMsg.style.display = 'flex';
      var pSpin = document.getElementById('player-loading-spinner');
      if (pSpin) pSpin.style.display = 'none';

      // Update sidebar nav destinations according to account sync scopes
      updateNavRailScopes();

      // Switch to first enabled tab
      var initialTab = (account.syncLiveTv !== false) ? 'live' : (account.syncMovies !== false ? 'movies' : 'series');
      switchTab(initialTab);

      // Pre-fetch Movies and Series in parallel during splash if enabled!
      if (account.syncMovies !== false) {
        preloadMovies(account);
      } else {
        onSplashMoviesLoaded();
      }

      if (account.syncSeries !== false) {
        preloadSeries(account);
      } else {
        onSplashSeriesLoaded();
      }
    }

    if (options && options.showSplash) {
      setTimeout(proceed, 20);
    } else {
      proceed();
    }
  }

  function preloadMovies(account) {
    if (!account || account.syncMovies === false) {
      onSplashMoviesLoaded();
      return;
    }
    window.TVApi.getVodCategories(account)
      .then(function(cats) {
        _movieCategories = cats;
        markCategoriesDirty('movie');
        onSplashMoviesLoaded();
      })
      .catch(function() {
        onSplashMoviesLoaded();
      });
  }

  function preloadSeries(account) {
    if (!account || account.syncSeries === false) {
      onSplashSeriesLoaded();
      return;
    }
    window.TVApi.getSeriesCategories(account)
      .then(function(cats) {
        _seriesCategories = cats;
        markCategoriesDirty('series');
        onSplashSeriesLoaded();
      })
      .catch(function() {
        onSplashSeriesLoaded();
      });
  }

  function ensureMasterTabData(tab) {
    if (!_activeAccount) return Promise.resolve([]);
    if (tab === 'live' && _activeAccount.syncLiveTv === false) return Promise.resolve([]);
    if (tab === 'movies' && _activeAccount.syncMovies === false) return Promise.resolve([]);
    if (tab === 'series' && _activeAccount.syncSeries === false) return Promise.resolve([]);
    if (tab === 'live') {
      if (_allAccountLiveStreams) return Promise.resolve(_allAccountLiveStreams);
      if (!_fetchingMasterLivePromise) {
        _fetchingMasterLivePromise = window.TVApi.getLiveStreams(_activeAccount, 'all').then(function(s) {
          if (Array.isArray(s)) {
            s.forEach(function(item) { item._searchName = (item.name || '').toLowerCase(); });
            _allAccountLiveStreams = s;
          }
          _fetchingMasterLivePromise = null;
          return _allAccountLiveStreams || [];
        }).catch(function() {
          _fetchingMasterLivePromise = null;
          return [];
        });
      }
      return _fetchingMasterLivePromise;
    } else if (tab === 'movies') {
      if (_allAccountVodStreams) return Promise.resolve(_allAccountVodStreams);
      if (!_fetchingMasterMoviesPromise) {
        _fetchingMasterMoviesPromise = window.TVApi.getVodStreams(_activeAccount, 'all').then(function(s) {
          if (Array.isArray(s)) {
            s.forEach(function(item) { item._searchName = (item.name || '').toLowerCase(); });
            _allAccountVodStreams = s;
          }
          _fetchingMasterMoviesPromise = null;
          return _allAccountVodStreams || [];
        }).catch(function() {
          _fetchingMasterMoviesPromise = null;
          return [];
        });
      }
      return _fetchingMasterMoviesPromise;
    } else if (tab === 'series') {
      if (_allAccountSeriesStreams) return Promise.resolve(_allAccountSeriesStreams);
      if (!_fetchingMasterSeriesPromise) {
        _fetchingMasterSeriesPromise = window.TVApi.getSeries(_activeAccount, 'all').then(function(s) {
          if (Array.isArray(s)) {
            s.forEach(function(item) { item._searchName = (item.name || '').toLowerCase(); });
            _allAccountSeriesStreams = s;
          }
          _fetchingMasterSeriesPromise = null;
          return _allAccountSeriesStreams || [];
        }).catch(function() {
          _fetchingMasterSeriesPromise = null;
          return [];
        });
      }
      return _fetchingMasterSeriesPromise;
    }
    return Promise.resolve([]);
  }

  function prefetchMasterSearchData(account) {
    if (!account) return;
    ensureMasterTabData('live');
    ensureMasterTabData('movies');
    ensureMasterTabData('series');
  }

  function updateNavRailScopes() {
    if (!_activeAccount) return;
    var liveBtn = document.getElementById('nav-btn-live');
    var movBtn = document.getElementById('nav-btn-movies');
    var serBtn = document.getElementById('nav-btn-series');

    var hasLive = _activeAccount.syncLiveTv !== false;
    var hasMovies = _activeAccount.syncMovies !== false;
    var hasSeries = _activeAccount.syncSeries !== false;

    if (liveBtn) liveBtn.style.display = hasLive ? '' : 'none';
    if (movBtn) movBtn.style.display = hasMovies ? '' : 'none';
    if (serBtn) serBtn.style.display = hasSeries ? '' : 'none';

    // If active tab was disabled, switch to first available tab
    if (_currentTab === 'live' && !hasLive) {
      if (hasMovies) switchTab('movies');
      else if (hasSeries) switchTab('series');
    } else if (_currentTab === 'movies' && !hasMovies) {
      if (hasLive) switchTab('live');
      else if (hasSeries) switchTab('series');
    } else if (_currentTab === 'series' && !hasSeries) {
      if (hasLive) switchTab('live');
      else if (hasMovies) switchTab('movies');
    }
  }

  // =========================================================
  // 2. MAIN NAVIGATION RAIL (Tabs: Live TV, Movies, Series)
  // =========================================================
  function setupTabs() {
    var tabs = [
      { id: 'nav-btn-live', tab: 'live' },
      { id: 'nav-btn-movies', tab: 'movies' },
      { id: 'nav-btn-series', tab: 'series' }
    ];

    tabs.forEach(function(item) {
      var btn = document.getElementById(item.id);
      if (btn) {
        btn.onclick = function() {
          switchTab(item.tab);
        };
      }
    });
  }

  function closeMovieSortDropdown() {
    var dd = document.getElementById('movies-sort-dropdown');
    if (dd) dd.style.display = 'none';
  }

  function closeSeriesSortDropdown() {
    var dd = document.getElementById('series-sort-dropdown');
    if (dd) dd.style.display = 'none';
  }

  function parseAddedTimestamp(val) {
    if (window.TVApi && typeof window.TVApi.parseAddedTimestamp === 'function') {
      return window.TVApi.parseAddedTimestamp(val);
    }
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

  function _fastSortMedia(list, sortMode, isSeries) {
    if (window.TVApi && typeof window.TVApi.fastSortVod === 'function') {
      return window.TVApi.fastSortVod(list, sortMode);
    }
    var items = (list || []).slice();
    for (var i = 0; i < items.length; i++) {
      var it = items[i];
      if (it._sortName === undefined) {
        it._sortName = (it.name || '').toLowerCase().trim();
      }
      if (it._addedTs === undefined) {
        it._addedTs = parseAddedTimestamp(isSeries ? (it.last_modified || it.added) : (it.added || it.last_modified));
      }
    }
    if (sortMode === 'asc') {
      items.sort(function(a, b) {
        return a._sortName < b._sortName ? -1 : (a._sortName > b._sortName ? 1 : 0);
      });
    } else if (sortMode === 'desc') {
      items.sort(function(a, b) {
        return b._sortName < a._sortName ? -1 : (b._sortName > a._sortName ? 1 : 0);
      });
    } else {
      items.sort(function(a, b) {
        if (a._addedTs !== b._addedTs) return b._addedTs - a._addedTs; // Newly added first
        return a._sortName < b._sortName ? -1 : (a._sortName > b._sortName ? 1 : 0);
      });
    }
    return items;
  }

  // Helper for in-memory sorting of Movies
  function _sortVodList(list, sortMode) {
    return _fastSortMedia(list, sortMode, false);
  }

  // Helper for in-memory sorting of Series
  function _sortSeriesList(list, sortMode) {
    return _fastSortMedia(list, sortMode, true);
  }

  // Movie title search (Real-time global search across all movies)
  function executeMovieSearch() {
    if (!_movieSearchQuery) {
      fetchCategoryMovies();
      return;
    }

    var activeAccount = _activeAccount || (window.TVStorage ? window.TVStorage.getActiveAccount() : null);
    if (!activeAccount) return;

    if (_allAccountVodStreams && _allAccountVodStreams.length > 0) {
      _filterAndRenderAllMovies(_allAccountVodStreams, _movieSearchQuery);
    } else {
      var overlay = document.getElementById('movies-loading-overlay');
      if (overlay) overlay.style.display = 'flex';
      window.TVApi.getVodStreams(activeAccount, 'all', 'default')
        .then(function(all) {
          if (overlay) overlay.style.display = 'none';
          _allAccountVodStreams = all;
          if (!_movieSearchQuery) {
            fetchCategoryMovies();
            return;
          }
          _filterAndRenderAllMovies(all, _movieSearchQuery);
        })
        .catch(function() {
          if (overlay) overlay.style.display = 'none';
          _movieFilteredList = [];
          renderMovieGrid(true);
        });
    }
  }

  function _filterAndRenderAllMovies(all, query) {
    var matches = all.filter(function(m) {
      var n = m._searchName || (m._searchName = (m.name || '').toLowerCase());
      return n.indexOf(query) >= 0;
    });
    _movieFilteredList = _sortVodList(matches, _movieSortMode);
    renderMovieGrid(true);
  }

  // Series title search (Real-time global search across all series)
  function executeSeriesSearch() {
    if (!_seriesSearchQuery) {
      fetchCategorySeries();
      return;
    }

    var activeAccount = _activeAccount || (window.TVStorage ? window.TVStorage.getActiveAccount() : null);
    if (!activeAccount) return;

    if (_allAccountSeriesStreams && _allAccountSeriesStreams.length > 0) {
      _filterAndRenderAllSeries(_allAccountSeriesStreams, _seriesSearchQuery);
    } else {
      var overlay = document.getElementById('series-loading-overlay');
      if (overlay) overlay.style.display = 'flex';
      window.TVApi.getSeries(activeAccount, 'all', 'default')
        .then(function(all) {
          if (overlay) overlay.style.display = 'none';
          _allAccountSeriesStreams = all;
          if (!_seriesSearchQuery) {
            fetchCategorySeries();
            return;
          }
          _filterAndRenderAllSeries(all, _seriesSearchQuery);
        })
        .catch(function() {
          if (overlay) overlay.style.display = 'none';
          _seriesFilteredList = [];
          renderSeriesGrid(true);
        });
    }
  }

  function _filterAndRenderAllSeries(all, query) {
    var matches = all.filter(function(s) {
      var n = s._searchName || (s._searchName = (s.name || '').toLowerCase());
      return n.indexOf(query) >= 0;
    });
    _seriesFilteredList = _sortSeriesList(matches, _seriesSortMode);
    renderSeriesGrid(true);
  }

  // Setup Search and Sort Handlers (Attached ONCE at startup)
  function setupSearchAndSortHandlers() {
    var _liveCatDebounce = null;
    var _movCatDebounce = null;
    var _serCatDebounce = null;

    // 1. Live TV Category Search (Debounced 250ms)
    var liveCatSearch = document.getElementById('live-cat-search');
    var liveCatClearBtn = document.getElementById('live-cat-clear-btn');
    if (liveCatSearch) {
      liveCatSearch.oninput = function() {
        if (liveCatClearBtn) {
          liveCatClearBtn.style.display = liveCatSearch.value.length > 0 ? 'flex' : 'none';
        }
        clearTimeout(_liveCatDebounce);
        _liveCatDebounce = setTimeout(function() {
          var q = liveCatSearch.value.toLowerCase().trim();
          var filtered = (_liveCategories || []).filter(function(c) {
            return (c.category_name || '').toLowerCase().indexOf(q) >= 0;
          });
          if (q) markCategoriesDirty('live');
          renderLiveCategories(filtered, true, _selectedLiveCategory ? _selectedLiveCategory.category_id : null);
        }, 250);
      };
    }
    if (liveCatClearBtn && liveCatSearch) {
      liveCatClearBtn.onclick = function() {
        clearTimeout(_liveCatDebounce);
        liveCatSearch.value = '';
        liveCatClearBtn.style.display = 'none';
        renderLiveCategories(_liveCategories || [], true, _selectedLiveCategory ? _selectedLiveCategory.category_id : null);
        liveCatSearch.focus();
        if (window.SpatialNav) window.SpatialNav.setFocus(liveCatSearch);
      };
    }

    // 2. Movies Category Search (Debounced 250ms)
    var movCatSearch = document.getElementById('movies-cat-search');
    var movCatClearBtn = document.getElementById('movies-cat-clear-btn');
    if (movCatSearch) {
      movCatSearch.oninput = function() {
        if (movCatClearBtn) movCatClearBtn.style.display = movCatSearch.value.length > 0 ? 'flex' : 'none';
        clearTimeout(_movCatDebounce);
        _movCatDebounce = setTimeout(function() {
          var q = movCatSearch.value.toLowerCase().trim();
          var filtered = (_movieCategories || []).filter(function(c) {
            return (c.category_name || '').toLowerCase().indexOf(q) >= 0;
          });
          if (q) markCategoriesDirty('movie');
          renderMovieCategories(filtered, true, _selectedMovieCategory ? _selectedMovieCategory.category_id : null);
        }, 250);
      };
    }
    if (movCatClearBtn && movCatSearch) {
      movCatClearBtn.onclick = function() {
        clearTimeout(_movCatDebounce);
        movCatSearch.value = '';
        movCatClearBtn.style.display = 'none';
        renderMovieCategories(_movieCategories || [], true, _selectedMovieCategory ? _selectedMovieCategory.category_id : null);
        movCatSearch.focus();
        if (window.SpatialNav) window.SpatialNav.setFocus(movCatSearch);
      };
    }

    // 3. Movies Title Search (Real-time global search with 300ms debounce)
    var movieSearch = document.getElementById('movies-search-input');
    var movieClearBtn = document.getElementById('movies-search-clear-btn');
    if (movieSearch) {
      movieSearch.oninput = function() {
        if (movieClearBtn) movieClearBtn.style.display = movieSearch.value.length > 0 ? 'flex' : 'none';
        _movieSearchQuery = movieSearch.value.toLowerCase().trim();
        clearTimeout(_movieSearchDebounce);
        _movieSearchDebounce = setTimeout(executeMovieSearch, 300);
      };
    }
    if (movieClearBtn && movieSearch) {
      movieClearBtn.onclick = function() {
        movieSearch.value = '';
        movieClearBtn.style.display = 'none';
        _movieSearchQuery = '';
        executeMovieSearch();
        movieSearch.focus();
        if (window.SpatialNav) window.SpatialNav.setFocus(movieSearch);
      };
    }

    // 4. Movies Sort Dropdown
    var movSortBtn = document.getElementById('movies-sort-btn');
    var movSortDropdown = document.getElementById('movies-sort-dropdown');
    var movSortText = document.getElementById('movies-sort-text');
    if (movSortBtn) {
      movSortBtn.onclick = function(e) {
        if (e) e.stopPropagation();
        closeSeriesSortDropdown();
        if (movSortDropdown) {
          var isOpen = movSortDropdown.style.display !== 'none';
          movSortDropdown.style.display = isOpen ? 'none' : 'flex';
          if (!isOpen && window.SpatialNav) {
            var activeOpt = movSortDropdown.querySelector('.sort-opt-btn.active') || movSortDropdown.firstElementChild;
            if (activeOpt) window.SpatialNav.setFocus(activeOpt);
          }
        }
      };
    }
    if (movSortDropdown) {
      movSortDropdown.querySelectorAll('.sort-opt-btn').forEach(function(btn) {
        btn.onclick = function(e) {
          if (e) e.stopPropagation();
          var sortVal = btn.getAttribute('data-sort');
          _movieSortMode = sortVal;
          if (movSortText) {
            if (sortVal === 'asc') movSortText.textContent = window.TVI18n ? window.TVI18n.t('sort_az') : 'A-Z';
            else if (sortVal === 'desc') movSortText.textContent = window.TVI18n ? window.TVI18n.t('sort_za') : 'Z-A';
            else movSortText.textContent = window.TVI18n ? window.TVI18n.t('sort_newest') : 'Newly Added';
          }
          movSortDropdown.querySelectorAll('.sort-opt-btn').forEach(function(b) {
            var isThis = (b === btn);
            b.classList.toggle('active', isThis);
            var check = b.querySelector('.sort-opt-check');
            if (check) check.style.visibility = isThis ? 'visible' : 'hidden';
          });
          movSortDropdown.style.display = 'none';
          if (movSortBtn && window.SpatialNav) window.SpatialNav.setFocus(movSortBtn);

          if (_movieSearchQuery) {
            executeMovieSearch();
          } else if (_movieStreams && _movieStreams.length > 0) {
            _movieStreams = _sortVodList(_movieStreams, _movieSortMode);
            renderMovieGrid();
          } else {
            fetchCategoryMovies();
          }
        };
      });
    }

    // 5. Series Category Search (Debounced 250ms)
    var serCatSearch = document.getElementById('series-cat-search');
    var serCatClearBtn = document.getElementById('series-cat-clear-btn');
    if (serCatSearch) {
      serCatSearch.oninput = function() {
        if (serCatClearBtn) serCatClearBtn.style.display = serCatSearch.value.length > 0 ? 'flex' : 'none';
        clearTimeout(_serCatDebounce);
        _serCatDebounce = setTimeout(function() {
          var q = serCatSearch.value.toLowerCase().trim();
          var filtered = (_seriesCategories || []).filter(function(c) {
            return (c.category_name || '').toLowerCase().indexOf(q) >= 0;
          });
          if (q) markCategoriesDirty('series');
          renderSeriesCategories(filtered, true, _selectedSeriesCategory ? _selectedSeriesCategory.category_id : null);
        }, 250);
      };
    }
    if (serCatClearBtn && serCatSearch) {
      serCatClearBtn.onclick = function() {
        clearTimeout(_serCatDebounce);
        serCatSearch.value = '';
        serCatClearBtn.style.display = 'none';
        renderSeriesCategories(_seriesCategories || [], true, _selectedSeriesCategory ? _selectedSeriesCategory.category_id : null);
        serCatSearch.focus();
        if (window.SpatialNav) window.SpatialNav.setFocus(serCatSearch);
      };
    }

    // 6. Series Title Search (Real-time global search with 300ms debounce)
    var seriesSearch = document.getElementById('series-search-input');
    var seriesClearBtn = document.getElementById('series-search-clear-btn');
    if (seriesSearch) {
      seriesSearch.oninput = function() {
        if (seriesClearBtn) seriesClearBtn.style.display = seriesSearch.value.length > 0 ? 'flex' : 'none';
        _seriesSearchQuery = seriesSearch.value.toLowerCase().trim();
        clearTimeout(_seriesSearchDebounce);
        _seriesSearchDebounce = setTimeout(executeSeriesSearch, 300);
      };
    }
    if (seriesClearBtn && seriesSearch) {
      seriesClearBtn.onclick = function() {
        seriesSearch.value = '';
        seriesClearBtn.style.display = 'none';
        _seriesSearchQuery = '';
        executeSeriesSearch();
        seriesSearch.focus();
        if (window.SpatialNav) window.SpatialNav.setFocus(seriesSearch);
      };
    }

    // 7. Series Sort Dropdown
    var serSortBtn = document.getElementById('series-sort-btn');
    var serSortDropdown = document.getElementById('series-sort-dropdown');
    var serSortText = document.getElementById('series-sort-text');
    if (serSortBtn) {
      serSortBtn.onclick = function(e) {
        if (e) e.stopPropagation();
        closeMovieSortDropdown();
        if (serSortDropdown) {
          var isOpen = serSortDropdown.style.display !== 'none';
          serSortDropdown.style.display = isOpen ? 'none' : 'flex';
          if (!isOpen && window.SpatialNav) {
            var activeOpt = serSortDropdown.querySelector('.sort-opt-btn.active') || serSortDropdown.firstElementChild;
            if (activeOpt) window.SpatialNav.setFocus(activeOpt);
          }
        }
      };
    }
    if (serSortDropdown) {
      serSortDropdown.querySelectorAll('.sort-opt-btn').forEach(function(btn) {
        btn.onclick = function(e) {
          if (e) e.stopPropagation();
          var sortVal = btn.getAttribute('data-sort');
          _seriesSortMode = sortVal;
          if (serSortText) {
            if (sortVal === 'asc') serSortText.textContent = window.TVI18n ? window.TVI18n.t('sort_az') : 'A-Z';
            else if (sortVal === 'desc') serSortText.textContent = window.TVI18n ? window.TVI18n.t('sort_za') : 'Z-A';
            else serSortText.textContent = window.TVI18n ? window.TVI18n.t('sort_newest') : 'Newly Added';
          }
          serSortDropdown.querySelectorAll('.sort-opt-btn').forEach(function(b) {
            var isThis = (b === btn);
            b.classList.toggle('active', isThis);
            var check = b.querySelector('.sort-opt-check');
            if (check) check.style.visibility = isThis ? 'visible' : 'hidden';
          });
          serSortDropdown.style.display = 'none';
          if (serSortBtn && window.SpatialNav) window.SpatialNav.setFocus(serSortBtn);

          if (_seriesSearchQuery) {
            executeSeriesSearch();
          } else if (_seriesList && _seriesList.length > 0) {
            _seriesList = _sortSeriesList(_seriesList, _seriesSortMode);
            renderSeriesGrid();
          } else {
            fetchCategorySeries();
          }
        };
      });
    }
  }

  function switchTab(tabName) {
    if (_activeAccount) {
      if (tabName === 'live' && _activeAccount.syncLiveTv === false) {
        tabName = _activeAccount.syncMovies !== false ? 'movies' : 'series';
      } else if (tabName === 'movies' && _activeAccount.syncMovies === false) {
        tabName = _activeAccount.syncLiveTv !== false ? 'live' : 'series';
      } else if (tabName === 'series' && _activeAccount.syncSeries === false) {
        tabName = _activeAccount.syncLiveTv !== false ? 'live' : 'movies';
      }
    }
    _currentTab = tabName;

    closeMovieSortDropdown();
    closeSeriesSortDropdown();

    // Update rail buttons
    document.querySelectorAll('.nav-rail-btn').forEach(function(b) {
      b.classList.toggle('active', b.getAttribute('data-tab') === tabName);
    });

    // Update page views
    document.getElementById('page-live').classList.toggle('active', tabName === 'live');
    document.getElementById('page-movies').classList.toggle('active', tabName === 'movies');
    document.getElementById('page-series').classList.toggle('active', tabName === 'series');

    // Clear search inputs across all tabs when switching tabs
    var liveCatSearch = document.getElementById('live-cat-search');
    var movCatSearch = document.getElementById('movies-cat-search');
    var movSearch = document.getElementById('movies-search-input');
    var serCatSearch = document.getElementById('series-cat-search');
    var serSearch = document.getElementById('series-search-input');
    if (liveCatSearch) {
      if (liveCatSearch.value.trim()) markCategoriesDirty('live');
      liveCatSearch.value = '';
    }
    if (movCatSearch) {
      if (movCatSearch.value.trim()) markCategoriesDirty('movie');
      movCatSearch.value = '';
    }
    if (movSearch) { movSearch.value = ''; _movieSearchQuery = ''; }
    if (serCatSearch) {
      if (serCatSearch.value.trim()) markCategoriesDirty('series');
      serCatSearch.value = '';
    }
    if (serSearch) { serSearch.value = ''; _seriesSearchQuery = ''; }

    var clearBtnIds = [
      'live-cat-clear-btn', 'movies-cat-clear-btn', 'movies-search-clear-btn',
      'series-cat-clear-btn', 'series-search-clear-btn', 'master-search-clear-btn'
    ];
    clearBtnIds.forEach(function(id) {
      var b = document.getElementById(id);
      if (b) b.style.display = 'none';
    });

    if (tabName === 'live') {
      document.body.classList.add('tab-live');
      if (!_selectedLiveStream || !_player || !_player.currentStream || _player.playbackType !== 'live') {
        clearLiveEpg();
      }
      if (!_liveCategories || _liveCategories.length === 0) {
        loadLiveTv();
      } else {
        _selectedLiveCategory = null;
        var liveCatListEl = document.getElementById('live-categories-list');
        if (liveCatListEl) liveCatListEl.scrollTop = 0;
        if (_virtualList && _virtualList.container) _virtualList.container.scrollTop = 0;
        renderLiveCategories(_liveCategories, false, null);
        if (liveCatListEl) liveCatListEl.scrollTop = 0;
        var cur = window.SpatialNav ? window.SpatialNav.getCurrent() : null;
        var isOnRail = cur && cur.classList.contains('nav-rail-btn');
        if (!isOnRail && window.SpatialNav) {
          var activeCat = document.querySelector('#live-categories-list .category-item.active') ||
                          document.querySelector('#live-categories-list .category-item');
          if (activeCat) window.SpatialNav.setFocus(activeCat);
          else if (_virtualList) _virtualList.focusActive();
        }
        if (_liveStreams && _liveStreams.length > 0) {
          scheduleDashboardVisibleEpgFetch();
        }
      }
      // Re-sync player container position to preview box after tab switch layout
      if (_player && _player.updatePreviewPosition) {
        setTimeout(function() { _player.updatePreviewPosition(); }, 50);
      }
    } else {
      cancelDashboardEpgFetch();
      document.body.classList.remove('tab-live');
      clearLiveEpg();
      // In Movies or Series, stop Live preview and hide container completely
      if (_player) {
        _player.stop(false);
      }
      var pCont = document.getElementById('player-container');
      if (pCont) {
        pCont.style.display = 'none';
        pCont.classList.remove('video-playing');
      }
      _selectedLiveStream = null;
      var previewBox = document.getElementById('preview-player-box');
      if (previewBox) previewBox.classList.remove('has-stream');

      if (tabName === 'movies') {
        renderContinueWatching('movie');
        if (!_movieCategories || _movieCategories.length === 0) {
          loadMovies(false);
        } else {
          _selectedMovieCategory = null;
          var movCatListEl = document.getElementById('movies-categories-list');
          var movGridEl = document.getElementById('movies-grid');
          if (movCatListEl) movCatListEl.scrollTop = 0;
          if (movGridEl) movGridEl.scrollTop = 0;
          renderMovieCategories(_movieCategories, false, null);
          if (movCatListEl) movCatListEl.scrollTop = 0;
          var curM = window.SpatialNav ? window.SpatialNav.getCurrent() : null;
          var isOnRailM = curM && curM.classList.contains('nav-rail-btn');
          if (!isOnRailM && window.SpatialNav) {
            var activeCatM = document.querySelector('#movies-categories-list .category-item.active') ||
                            document.querySelector('#movies-categories-list .category-item');
            if (activeCatM) window.SpatialNav.setFocus(activeCatM);
          }
        }
      }
      if (tabName === 'series') {
        renderContinueWatching('series');
        if (!_seriesCategories || _seriesCategories.length === 0) {
          loadSeries(false);
        } else {
          _selectedSeriesCategory = null;
          var serCatListEl = document.getElementById('series-categories-list');
          var serGridEl = document.getElementById('series-grid');
          if (serCatListEl) serCatListEl.scrollTop = 0;
          if (serGridEl) serGridEl.scrollTop = 0;
          renderSeriesCategories(_seriesCategories, false, null);
          if (serCatListEl) serCatListEl.scrollTop = 0;
          var curS = window.SpatialNav ? window.SpatialNav.getCurrent() : null;
          var isOnRailS = curS && curS.classList.contains('nav-rail-btn');
          if (!isOnRailS && window.SpatialNav) {
            var activeCatS = document.querySelector('#series-categories-list .category-item.active') ||
                             document.querySelector('#series-categories-list .category-item');
            if (activeCatS) window.SpatialNav.setFocus(activeCatS);
          }
        }
      }
    }
  }

  // =========================================================
  // 3. TAB 1: LIVE TV (3-COLUMN LAYOUT)
  // =========================================================
  function loadLiveTv() {
    if (!_activeAccount || _activeAccount.syncLiveTv === false) {
      onSplashLiveLoaded();
      return;
    }
    var listEl = document.getElementById('live-categories-list');
    if (listEl) listEl.innerHTML = '<div class="col-placeholder" data-i18n="loading_categories">' + (window.TVI18n ? window.TVI18n.t('loading_categories') : 'Loading categories...') + '</div>';

    window.TVApi.getLiveCategories(_activeAccount)
      .then(function(cats) {
        _liveCategories = cats;
        if (_activeAccount) recordSyncTime(_activeAccount.id, 'live', Date.now(), false);
        markCategoriesDirty('live');
        if (!cats || cats.length === 0) {
          var noCatsText = (window.TVI18n && window.TVI18n.getLanguage() === 'de')
            ? 'Keine Senderkategorien gefunden.'
            : 'No live categories found.';
          if (listEl) listEl.innerHTML = '<div class="col-placeholder" style="color:var(--text-dim); padding: 24px;">' + noCatsText + '</div>';
          onSplashLiveLoaded();
          return;
        }
        renderLiveCategories(cats);
      })
      .catch(function() {
        var failText = (window.TVI18n && window.TVI18n.getLanguage() === 'de')
          ? 'Kategorien konnten nicht geladen werden.'
          : (window.TVI18n ? window.TVI18n.t('failed_load_categories') : 'Failed to load categories.');
        if (listEl) listEl.innerHTML = '<div class="col-placeholder" style="color:#EF4444; padding: 24px;">' + failText + '</div>';
        onSplashLiveLoaded();
      });

    // Preview Player expand button
    var previewBtn = document.getElementById('preview-fullscreen-btn');
    var previewBox = document.getElementById('preview-player-box');
    if (previewBtn) {
      previewBtn.onclick = function(e) {
        if (e) {
          e.preventDefault();
          e.stopPropagation();
        }
        if (_player && _player.currentStream && _player.playbackType === 'live') {
          _player.setMode('fullscreen');
        }
      };
    }
    if (previewBox) {
      previewBox.onclick = function(e) {
        if (e && e.target && e.target.closest('#preview-play-pause-btn')) return;
        if (e) {
          e.preventDefault();
        }
        if (_player && _player.currentStream && _player.playbackType === 'live') {
          _player.setMode('fullscreen');
        }
      };
    }
  }

  var _catBatchStates = {};
  var CATEGORY_BATCH_SIZE = 60;

  function setSingleActiveCategory(listId, element) {
    var listEl = document.getElementById(listId);
    if (listEl) {
      var prev = listEl.querySelector('.category-item.active');
      if (prev) prev.classList.remove('active');
    }
    if (element) element.classList.add('active');
  }

  function appendCategoryBatch(state, count) {
    if (!state || !state.listEl || state.renderedCount >= state.items.length) return false;
    var limit = Math.min(state.items.length, state.renderedCount + (count || state.batchSize || CATEGORY_BATCH_SIZE));
    var frag = document.createDocumentFragment();
    for (var i = state.renderedCount; i < limit; i++) {
      var el = state.buildItemEl(state.items[i]);
      if (el) frag.appendChild(el);
    }
    state.listEl.appendChild(frag);
    state.renderedCount = limit;
    return true;
  }

  function loadMoreCategoriesFor(listId) {
    var st = _catBatchStates[listId];
    return st ? appendCategoryBatch(st, CATEGORY_BATCH_SIZE) : false;
  }

  function renderCategoryBatchList(listEl, visibleList, activeCategoryId, buildItemEl) {
    if (!listEl) return null;
    listEl.innerHTML = '';

    var activeIdx = -1;
    if (activeCategoryId !== undefined && activeCategoryId !== null && activeCategoryId !== '') {
      var targetIdStr = String(activeCategoryId);
      for (var i = 0; i < visibleList.length; i++) {
        var cid = String(visibleList[i].category_id || visibleList[i].categoryId);
        if (cid === targetIdStr) {
          activeIdx = i;
          break;
        }
      }
    }

    var initialCount = Math.min(visibleList.length, Math.max(CATEGORY_BATCH_SIZE, activeIdx >= 0 ? activeIdx + 10 : 0));
    var targetEl = null;
    var frag = document.createDocumentFragment();
    for (var j = 0; j < initialCount; j++) {
      var cat = visibleList[j];
      var el = buildItemEl(cat);
      frag.appendChild(el);
      if (j === activeIdx) targetEl = el;
    }
    listEl.appendChild(frag);

    _catBatchStates[listEl.id] = {
      listEl: listEl,
      items: visibleList,
      renderedCount: initialCount,
      batchSize: CATEGORY_BATCH_SIZE,
      buildItemEl: buildItemEl
    };

    if (!listEl._hasCatBatchScroll) {
      listEl._hasCatBatchScroll = true;
      listEl.addEventListener('scroll', function() {
        var st = _catBatchStates[listEl.id];
        if (st && st.renderedCount < st.items.length && (listEl.scrollTop + listEl.clientHeight >= listEl.scrollHeight - 280)) {
          appendCategoryBatch(st, CATEGORY_BATCH_SIZE);
        }
      }, { passive: true });
    }

    return targetEl;
  }

  function renderLiveCategories(cats, keepFocusOnSearch, activeCategoryId) {
    var listEl = document.getElementById('live-categories-list');
    if (!listEl) return;

    var rawCats = cats || [];
    var customLists = (_activeAccount && window.TVStorage) ? window.TVStorage.getCustomLists(_activeAccount.id, 'live') : [];
    var favText = window.TVI18n ? window.TVI18n.t('favorites') : 'Favorites';
    var starIcon = (window.TVIcons && window.TVIcons.starFilled) ? window.TVIcons.starFilled : (window.TVIcons ? window.TVIcons.star : '★');
    var tvIcon = (window.TVIcons && window.TVIcons.tv) ? window.TVIcons.tv : '';
    var listIcon = (window.TVIcons && window.TVIcons.playlist) ? window.TVIcons.playlist : '';

    var favCat = { category_id: 'favorites', category_name: favText, isFav: true };
    var customCats = customLists.map(function(cl) {
      return { category_id: 'custom_list:' + cl.id, category_name: cl.name, isCustom: true, customList: cl };
    });
    var allCats = [favCat].concat(customCats).concat(rawCats);
    var prefs = (_activeAccount && window.TVStorage) ? window.TVStorage.getCategoryPrefs(_activeAccount.id, 'live') : { order: [], hidden: [], newIds: [] };

    // Fast O(1) lookups
    var orderSet = {};
    (prefs.order || []).forEach(function(id) { orderSet[id] = true; });
    var hiddenSet = {};
    (prefs.hidden || []).forEach(function(id) { hiddenSet[id] = true; });

    // Order categories according to prefs.order
    var catMap = {};
    allCats.forEach(function(c) {
      var id = String(c.category_id || c.categoryId);
      catMap[id] = c;
    });

    var orderedList = [];
    var favIdx = prefs.order.indexOf('favorites');
    if (favIdx === -1) {
      if (catMap['favorites']) orderedList.push(catMap['favorites']);
    } else if (favIdx === prefs.order.length - 1 && prefs.order.length > 1 && !prefs.hasManualSort) {
      if (catMap['favorites']) orderedList.push(catMap['favorites']);
    }

    prefs.order.forEach(function(id) {
      if (id === 'favorites' && orderedList.length > 0 && orderedList[0].category_id === 'favorites') return;
      if (catMap[id]) orderedList.push(catMap[id]);
    });
    allCats.forEach(function(c) {
      var id = String(c.category_id || c.categoryId);
      if (id === 'favorites' && orderedList.length > 0 && orderedList[0].category_id === 'favorites') return;
      if (!orderSet[id]) orderedList.push(c);
    });

    // Filter hidden categories
    var visibleList = orderedList.filter(function(c) {
      var id = String(c.category_id || c.categoryId);
      return !hiddenSet[id];
    });

    var listBadgeTxt = escapeHtml((window.TVI18n && window.TVI18n.t('badge_list')) || 'LIST');
    var newBadgeTxt = escapeHtml((window.TVI18n && window.TVI18n.t('badge_new')) || 'NEW');
    var newSet = {};
    (prefs.newIds || []).forEach(function(nid) { newSet[nid] = true; });

    var targetEl = renderCategoryBatchList(listEl, visibleList, activeCategoryId, function(cat) {
      var catId = String(cat.category_id || cat.categoryId);
      var isCatActive = (activeCategoryId && String(activeCategoryId) === catId);
      var el = document.createElement('div');
      el.className = 'category-item focusable' + (isCatActive ? ' active' : '');
      el.setAttribute('data-category-id', catId);

      if (cat.isFav) {
        el.innerHTML =
          '<div class="category-left">' +
            '<span class="category-icon" style="color:var(--accent-gold);">' + starIcon + '</span>' +
            '<span class="category-name-text">' + favText + '</span>' +
          '</div>';
        el.onclick = function() { selectLiveCategory({ category_id: 'favorites', category_name: favText }, el); };
      } else if (cat.isCustom) {
        el.innerHTML =
          '<div class="category-left">' +
            '<span class="category-icon" style="color:#B388FF;">' + listIcon + '</span>' +
            '<span class="category-name-text" style="color:#C4B5FD; font-weight:600;">' + escapeHtml(cat.category_name) + '</span>' +
            '<span class="badge-cat-list">' + listBadgeTxt + '</span>' +
          '</div>';
        el.onclick = function() { selectLiveCustomList(cat.customList, el); };
      } else {
        var isNew = !!newSet[catId];
        var badgeHtml = isNew ? '<span class="badge-cat-new">' + newBadgeTxt + '</span>' : '';
        el.innerHTML =
          '<div class="category-left">' +
            '<span class="category-icon">' + tvIcon + '</span>' +
            '<span class="category-name-text">' + escapeHtml(cat.category_name) + '</span>' +
            badgeHtml +
          '</div>';
        el.onclick = function() {
          if (isNew && _activeAccount && window.TVStorage) {
            window.TVStorage.markCategoryViewed(_activeAccount.id, 'live', cat.category_id);
            newSet[catId] = false;
            var b = el.querySelector('.badge-cat-new');
            if (b) b.remove();
          }
          selectLiveCategory(cat, el);
        };
      }
      return el;
    });
    if (cats === _liveCategories) {
      _catsDirty.live = false;
      _catsDirty.accountId = _activeAccount ? _activeAccount.id : null;
    }

    var catSearchInput = document.getElementById('live-cat-search');
    var isSearchFocused = (document.activeElement === catSearchInput) ||
                          (window.SpatialNav && window.SpatialNav.getCurrent() === catSearchInput);

    if (!targetEl && listEl.firstElementChild) {
      targetEl = listEl.firstElementChild;
    }

    if (targetEl) {
      if (!isSearchFocused && !keepFocusOnSearch) {
        targetEl.click();
        if (!activeCategoryId) listEl.scrollTop = 0;
        var cur = window.SpatialNav ? window.SpatialNav.getCurrent() : null;
        var isOnRail = cur && cur.classList.contains('nav-rail-btn');
        if (!isOnRail && window.SpatialNav) {
          window.SpatialNav.setFocus(targetEl);
        }
      }
    }
  }

  function _backfillSnapshots(accId, type, items) {
    if (!accId || !items || !items.length || !window.TVStorage) return;
    if (typeof window.TVStorage.saveStreamSnapshotsBatch === 'function') {
      window.TVStorage.saveStreamSnapshotsBatch(accId, type, items);
      return;
    }
    if (typeof window.TVStorage.saveStreamSnapshot !== 'function') return;
    for (var i = 0; i < items.length; i++) {
      window.TVStorage.saveStreamSnapshot(accId, type, items[i]);
    }
  }

  function selectLiveCustomList(cl, element) {
    if (!cl) return;
    cancelDashboardEpgFetch();
    _selectedLiveCategory = { category_id: 'custom_list:' + cl.id, category_name: cl.name, isCustomList: true, customListId: cl.id };
    window._selectedLiveCategory = _selectedLiveCategory;

    var catSearch = document.getElementById('live-cat-search');
    var catClearBtn = document.getElementById('live-cat-clear-btn');
    if (catSearch) { catSearch.value = ''; _liveSearchQuery = ''; }
    if (catClearBtn) catClearBtn.style.display = 'none';

    var chSearch = document.getElementById('live-channels-search-input');
    var chClearBtn = document.getElementById('live-channels-search-clear-btn');
    if (chSearch) { chSearch.value = ''; _liveChannelSearchQuery = ''; }
    if (chClearBtn) chClearBtn.style.display = 'none';

    setSingleActiveCategory('live-categories-list', element);

    var titleEl = document.getElementById('live-selected-category-title');
    if (titleEl) titleEl.textContent = cl.name;

    var countBadge = document.getElementById('live-channels-count');
    var loadingOverlay = document.getElementById('channels-loading-overlay');

    // 0ms snapshot resolution before falling back to 'all'
    if (_activeAccount && window.TVStorage && typeof window.TVStorage.getCustomListStreamsResolved === 'function') {
      var resolved = window.TVStorage.getCustomListStreamsResolved(_activeAccount.id, 'live', cl.id);
      if (resolved !== null) {
        if (loadingOverlay) loadingOverlay.style.display = 'none';
        if (countBadge) countBadge.textContent = resolved.length + ' ' + (window.TVI18n ? window.TVI18n.t('unit_channels') : 'Channels');
        _liveStreams = resolved;
        window._liveStreams = resolved;
        if (_player) _player.setChannelList(resolved);
        setDashboardLiveItems(resolved, true);
        return;
      }
    }

    if (loadingOverlay) loadingOverlay.style.display = 'flex';

    var items = (_activeAccount && window.TVStorage) ? window.TVStorage.getCustomListItems(_activeAccount.id, cl.id) : [];
    var orderedIds = items.map(function(it) { return String(it.streamId); });

    function renderMatches(allStreams) {
      if (loadingOverlay) loadingOverlay.style.display = 'none';
      var streamMap = {};
      (allStreams || []).forEach(function(s) { streamMap[String(s.stream_id)] = s; });
      var matches = [];
      orderedIds.forEach(function(id) {
        if (streamMap[id]) matches.push(streamMap[id]);
      });
      if (matches.length < items.length) {
        var existingIds = matches.map(function(m) { return String(m.stream_id); });
        items.forEach(function(it) {
          if (existingIds.indexOf(String(it.streamId)) === -1 && it.streamName) {
            var found = allStreams.find(function(s) { return (s.name || '').trim().toLowerCase() === it.streamName.trim().toLowerCase(); });
            if (found && existingIds.indexOf(String(found.stream_id)) === -1) {
              matches.push(found);
              existingIds.push(String(found.stream_id));
            }
          }
        });
      }
      if (_activeAccount) _backfillSnapshots(_activeAccount.id, 'live', matches);
      if (countBadge) countBadge.textContent = matches.length + ' ' + (window.TVI18n ? window.TVI18n.t('unit_channels') : 'Channels');
      _liveStreams = matches;
      window._liveStreams = matches;
      if (_player) _player.setChannelList(matches);
      setDashboardLiveItems(matches, true);
    }

    if (_allAccountLiveStreams && _allAccountLiveStreams.length > 0) {
      renderMatches(_allAccountLiveStreams);
    } else {
      window.TVApi.getLiveStreams(_activeAccount).then(function(all) {
        _allAccountLiveStreams = all;
        renderMatches(all);
      }).catch(function() {
        if (loadingOverlay) loadingOverlay.style.display = 'none';
        _liveStreams = [];
        window._liveStreams = [];
        if (_player) _player.setChannelList([]);
        setDashboardLiveItems([], true);
      });
    }
  }

  function selectLiveCategory(cat, element) {
    if (!cat) return;
    cancelDashboardEpgFetch();
    _selectedLiveCategory = cat;
    window._selectedLiveCategory = cat;

    var catSearch = document.getElementById('live-cat-search');
    var catClearBtn = document.getElementById('live-cat-clear-btn');
    if (catSearch) { catSearch.value = ''; _liveSearchQuery = ''; }
    if (catClearBtn) catClearBtn.style.display = 'none';

    var chSearch = document.getElementById('live-channels-search-input');
    var chClearBtn = document.getElementById('live-channels-search-clear-btn');
    if (chSearch) { chSearch.value = ''; _liveChannelSearchQuery = ''; }
    if (chClearBtn) chClearBtn.style.display = 'none';

    document.querySelectorAll('#live-categories-list .category-item').forEach(function(el) {
      el.classList.remove('active');
    });
    if (!element) {
      var catIdStr = String(cat.category_id);
      element = document.querySelector('#live-categories-list .category-item[data-category-id="' + catIdStr + '"]');
    }
    if (element) element.classList.add('active');

    var titleEl = document.getElementById('live-selected-category-title');
    if (titleEl) titleEl.textContent = cat.category_name;

    var countBadge = document.getElementById('live-channels-count');
    var loadingOverlay = document.getElementById('channels-loading-overlay');

    if (cat.category_id === 'favorites') {
      var favIds = window.TVStorage.getFavorites(_activeAccount.id, 'live');
      if (favIds.length === 0) {
        if (loadingOverlay) loadingOverlay.style.display = 'none';
        if (countBadge) countBadge.textContent = '0 ' + (window.TVI18n ? window.TVI18n.t('unit_channels') : 'Channels');
        _liveStreams = [];
        _player.setChannelList([]);
        setDashboardLiveItems([], true);
        onSplashLiveLoaded();
        return;
      }
      // 0ms snapshot resolution before falling back to 'all'
      if (typeof window.TVStorage.getFavoriteStreamsResolved === 'function') {
        var resolvedFavs = window.TVStorage.getFavoriteStreamsResolved(_activeAccount.id, 'live');
        if (resolvedFavs !== null) {
          if (loadingOverlay) loadingOverlay.style.display = 'none';
          if (countBadge) countBadge.textContent = resolvedFavs.length + ' ' + (window.TVI18n ? window.TVI18n.t('unit_channels') : 'Channels');
          _liveStreams = resolvedFavs;
          window._liveStreams = resolvedFavs;
          _player.setChannelList(resolvedFavs);
          setDashboardLiveItems(resolvedFavs, true);
          onSplashLiveLoaded();
          return;
        }
      }
      if (loadingOverlay) loadingOverlay.style.display = 'flex';
      if (_allAccountLiveStreams && _allAccountLiveStreams.length > 0) {
        if (loadingOverlay) loadingOverlay.style.display = 'none';
        var streamMap = {};
        _allAccountLiveStreams.forEach(function(s) { streamMap[String(s.stream_id)] = s; });
        var favStreams = [];
        favIds.forEach(function(id) {
          if (streamMap[id]) favStreams.push(streamMap[id]);
        });
        _backfillSnapshots(_activeAccount.id, 'live', favStreams);
        if (countBadge) countBadge.textContent = favStreams.length + ' ' + (window.TVI18n ? window.TVI18n.t('unit_channels') : 'Channels');
        _liveStreams = favStreams;
        window._liveStreams = favStreams;
        _player.setChannelList(favStreams);
        setDashboardLiveItems(favStreams, true);
        onSplashLiveLoaded();
        return;
      }
      window.TVApi.getLiveStreams(_activeAccount)
        .then(function(allStreams) {
          _allAccountLiveStreams = allStreams;
          var streamMap = {};
          allStreams.forEach(function(s) { streamMap[String(s.stream_id)] = s; });
          var favStreams = [];
          favIds.forEach(function(id) {
            if (streamMap[id]) favStreams.push(streamMap[id]);
          });
          _backfillSnapshots(_activeAccount.id, 'live', favStreams);
          if (loadingOverlay) loadingOverlay.style.display = 'none';
          if (countBadge) countBadge.textContent = favStreams.length + ' ' + (window.TVI18n ? window.TVI18n.t('unit_channels') : 'Channels');
          _liveStreams = favStreams;
          window._liveStreams = favStreams;
          _player.setChannelList(favStreams);
          setDashboardLiveItems(favStreams, true);
          onSplashLiveLoaded();
        })
        .catch(function() {
          if (loadingOverlay) loadingOverlay.style.display = 'none';
          setDashboardLiveItems([], true);
          onSplashLiveLoaded();
        });
    } else {
      if (loadingOverlay) loadingOverlay.style.display = 'flex';
      window.TVApi.getLiveStreams(_activeAccount, cat.category_id)
        .then(function(streams) {
          if (loadingOverlay) loadingOverlay.style.display = 'none';
          if (countBadge) countBadge.textContent = streams.length + ' ' + (window.TVI18n ? window.TVI18n.t('unit_channels') : 'Channels');
          _liveStreams = streams;
          window._liveStreams = streams;
          _player.setChannelList(streams);
          setDashboardLiveItems(streams, false);
          onSplashLiveLoaded();
        })
        .catch(function() {
          if (loadingOverlay) loadingOverlay.style.display = 'none';
          setDashboardLiveItems([], false);
          onSplashLiveLoaded();
        });
    }
  }

  function selectLiveStream(stream) {
    if (!stream) return;
    if (_player && _player.currentStream && String(_player.currentStream.stream_id || _player.currentStream.id) === String(stream.stream_id || stream.id)) {
      if (_selectedLiveCategory && _player) {
        _player.currentCategory = _selectedLiveCategory;
        _player.currentCategoryId = String(_selectedLiveCategory.category_id);
        _player.currentCategoryName = _selectedLiveCategory.category_name || 'Live TV';
        if (_liveStreams && _liveStreams.length > 0) {
          _player.setChannelList(_liveStreams);
        }
      }
      // Already playing this stream - clicking the running channel opens fullscreen
      if (_player.currentMode === 'preview') {
        _player.setMode('fullscreen');
      }
      return;
    }
    _selectedLiveStream = stream;
    var catName = _selectedLiveCategory ? _selectedLiveCategory.category_name : 'Live TV';

    if (_player && _liveStreams && _liveStreams.length > 0) {
      _player.setChannelList(_liveStreams);
    }

    // Start Preview Player (remains in Column 3 preview box)
    _player.playLive(stream, _selectedLiveCategory || catName, false);

    // Hide preview placeholder
    var placeholder = document.getElementById('preview-placeholder-msg');
    if (placeholder) placeholder.style.display = 'none';

    var previewBox = document.getElementById('preview-player-box');
    if (previewBox) previewBox.classList.add('has-stream');

    // Update preview overlay title
    var previewTitle = document.getElementById('preview-channel-name');
    if (previewTitle) previewTitle.textContent = stream.name ? stream.name.replace(/^\[.*?\]\s*/, '') : 'Channel';

    // Highlight active row in ChannelList
    if (_virtualList && _virtualList.refreshPlayingState) {
      _virtualList.refreshPlayingState(stream.stream_id);
    }

    // Load Short EPG Schedule for bottom right box
    loadLiveEpg(stream);
  }

  function clearLiveEpg() {
    var epgListEl = document.getElementById('epg-schedule-list');
    var drawerEpgList = document.getElementById('drawer-epg-list');
    var drawerChannelName = document.getElementById('drawer-epg-channel-name');
    var osdNow = document.getElementById('osd-live-epg-now');
    var selectText = window.TVI18n ? window.TVI18n.t('epg_select_channel') : 'Select a channel to view upcoming program schedule.';
    if (epgListEl) {
      epgListEl.innerHTML = '<div class="epg-empty-placeholder" data-i18n="epg_select_channel">' + selectText + '</div>';
    }
    if (drawerEpgList) {
      drawerEpgList.innerHTML = '<div class="epg-empty-placeholder" data-i18n="epg_select_channel">' + selectText + '</div>';
    }
    if (drawerChannelName) drawerChannelName.textContent = '';
    if (osdNow) osdNow.textContent = '';
  }
  window.clearLiveEpg = clearLiveEpg;

  function loadLiveEpg(stream) {
    var epgListEl = document.getElementById('epg-schedule-list');
    var drawerEpgList = document.getElementById('drawer-epg-list');
    var drawerChannelName = document.getElementById('drawer-epg-channel-name');

    var loadingText = window.TVI18n ? window.TVI18n.t('loading_schedule') : 'Loading schedule...';
    var noEpgText = window.TVI18n ? window.TVI18n.t('no_epg_available') : 'No upcoming programs listed for this channel.';

    if (epgListEl) epgListEl.innerHTML = '<div class="col-placeholder">' + loadingText + '</div>';
    if (drawerEpgList) drawerEpgList.innerHTML = '<div class="col-placeholder">' + loadingText + '</div>';
    if (drawerChannelName) drawerChannelName.textContent = stream.name || (window.TVI18n ? window.TVI18n.t('channel_guide') : 'Channel Guide');

    window.TVApi.getShortEpg(_activeAccount, stream.stream_id)
      .then(function(listings) {
        renderEpgTimeline(listings, epgListEl);
        renderEpgTimeline(listings, drawerEpgList);

        // Update live now snippet on Fullscreen OSD
        var osdNow = document.getElementById('osd-live-epg-now');
        if (osdNow) {
          var activeOsdProg = pickDashboardEpgProgram(listings);
          osdNow.textContent = activeOsdProg ? (activeOsdProg.title || (window.TVI18n ? window.TVI18n.t('live_tv') : 'Live TV')) : noEpgText;
        }
      })
      .catch(function() {
        if (epgListEl) epgListEl.innerHTML = '<div class="epg-empty-placeholder">' + noEpgText + '</div>';
        if (drawerEpgList) drawerEpgList.innerHTML = '<div class="epg-empty-placeholder">' + noEpgText + '</div>';
      });
  }

  function renderEpgTimeline(listings, container) {
    if (!container) return;
    container.innerHTML = '';

    var noEpgText = window.TVI18n ? window.TVI18n.t('no_epg_available') : 'No upcoming programs listed for this channel.';

    if (!listings || listings.length === 0) {
      container.innerHTML = '<div class="epg-empty-placeholder">' + noEpgText + '</div>';
      return;
    }

    var nowSec = Math.floor(Date.now() / 1000);
    var filtered = listings.filter(function(item) {
      if (!item) return false;
      var rng = (typeof window.getEpgRangeSec === 'function') ? window.getEpgRangeSec(item) : null;
      return rng ? (rng.stopSec > nowSec) : true;
    });
    if (filtered.length === 0) filtered = listings;

    var picked = (typeof window.pickActiveEpgPrograms === 'function')
      ? window.pickActiveEpgPrograms(filtered)
      : { current: filtered[0], next: filtered[1], activeIndex: 0 };

    filtered.slice(0, 10).forEach(function(item, idx) {
      var el = document.createElement('div');
      var isPlaying = (idx === picked.activeIndex) || (picked.activeIndex === -1 && Number(item.now_playing) === 1);
      el.className = 'epg-item ' + (isPlaying ? 'now-playing' : '');

      var startStr = (typeof window.formatEpgClock === 'function')
        ? window.formatEpgClock(item, false)
        : (item.start ? item.start.substring(11, 16) : '--:--');
      var endStr = (typeof window.formatEpgClock === 'function')
        ? window.formatEpgClock(item, true)
        : (item.end ? item.end.substring(11, 16) : '--:--');

      var itemTiming = (typeof window.calcEpgItemTiming === 'function') ? window.calcEpgItemTiming(item) : null;
      var progressPercent = itemTiming ? itemTiming.percent : 0;

      var liveBadgeHtml = isPlaying ? '<span class="epg-live-badge">LIVE</span>' : '';
      var progressHtml = isPlaying ? ('<div class="epg-progress-line"><div class="epg-progress-active" style="width:' + progressPercent + '%;"></div></div>') : '';

      el.innerHTML = 
        '<div class="epg-item-time-col">' +
          '<span class="epg-time-start">' + escapeHtml(startStr) + '</span>' +
          '<span class="epg-time-end">' + escapeHtml(endStr) + '</span>' +
        '</div>' +
        '<div class="epg-item-info-col">' +
          '<div class="epg-item-title-row">' +
            '<span class="epg-item-title">' + escapeHtml(item.title || 'Program') + '</span>' +
            liveBadgeHtml +
          '</div>' +
          progressHtml +
        '</div>';

      container.appendChild(el);
    });
  }

  // =========================================================
  // SMART IPTV STYLE: CHANNEL MENU, CATEGORY MENU & EPG OVERLAY
  // =========================================================
  var _channelMenuChannels = [];
  var _channelMenuPage = 0;
  var _channelMenuPageSize = 10;
  var _channelMenuSelectedIndex = 0;
  var _channelMenuCategory = null;

  var _categoryMenuCategories = [];
  var _categoryMenuPage = 0;
  var _categoryMenuPageSize = 10;
  var _categoryMenuSelectedIndex = 0;

  function openLiveChannelMenu(category, streamToSelect) {
    closeLiveCategoryMenu();
    closeLiveEpgOverlay();

    var targetStream = streamToSelect || (_player ? _player.currentStream : null);
    var activeAccount = _activeAccount || (window.TVStorage ? window.TVStorage.getActiveAccount() : null);

    var cat = category;
    var favText = window.TVI18n ? window.TVI18n.t('favorites') : 'Favorites';

    if (!cat) {
      var isPlayingFromFavorites = _player && String(_player.currentCategoryId) === 'favorites';
      if (isPlayingFromFavorites) {
        cat = { category_id: 'favorites', category_name: favText };
      } else if (_player && _player.currentCategory && String(_player.currentCategory.category_id) !== 'favorites') {
        cat = _player.currentCategory;
      } else if (targetStream && targetStream.category_id && _liveCategories && _liveCategories.length > 0) {
        cat = _liveCategories.find(function(c) {
          return String(c.category_id) === String(targetStream.category_id);
        });
      } else if (_selectedLiveCategory && String(_selectedLiveCategory.category_id) !== 'favorites') {
        cat = _selectedLiveCategory;
      }
    }
    if (!cat) {
      cat = (_selectedLiveCategory && String(_selectedLiveCategory.category_id) !== 'favorites') ? _selectedLiveCategory : (_liveCategories && _liveCategories[0]);
    }

    if (!cat && activeAccount) {
      window.TVApi.getLiveCategories(activeAccount).then(function(cats) {
        _liveCategories = cats;
        if (cats && cats.length > 0) {
          openLiveChannelMenu(null, targetStream);
        }
      });
      return;
    }
    if (!cat) return;

    _channelMenuCategory = cat;
    _selectedLiveCategory = cat;
    window._selectedLiveCategory = cat;

    if (activeAccount) {
      if (String(cat.category_id) === 'favorites') {
        var favIds = window.TVStorage.getFavorites(activeAccount.id, 'live');
        if (typeof window.TVStorage.getFavoriteStreamsResolved === 'function') {
          var resolvedFavs = window.TVStorage.getFavoriteStreamsResolved(activeAccount.id, 'live');
          if (resolvedFavs !== null) {
            _liveStreams = resolvedFavs;
            window._liveStreams = resolvedFavs;
            _prepareAndShowChannelMenu(cat, targetStream);
            return;
          }
        }
        if (_allAccountLiveStreams && _allAccountLiveStreams.length > 0) {
          var favs = _allAccountLiveStreams.filter(function(s) { return favIds.indexOf(String(s.stream_id)) >= 0; });
          _backfillSnapshots(activeAccount.id, 'live', favs);
          _liveStreams = favs;
          window._liveStreams = favs;
          _prepareAndShowChannelMenu(cat, targetStream);
          return;
        }
        window.TVApi.getLiveStreams(activeAccount).then(function(all) {
          _allAccountLiveStreams = all;
          var favs = all.filter(function(s) { return favIds.indexOf(String(s.stream_id)) >= 0; });
          _backfillSnapshots(activeAccount.id, 'live', favs);
          _liveStreams = favs;
          window._liveStreams = favs;
          _prepareAndShowChannelMenu(cat, targetStream);
        });
        return;
      } else if (String(cat.category_id).indexOf('custom_list:') === 0) {
        var clId = String(cat.category_id).replace('custom_list:', '');
        if (typeof window.TVStorage.getCustomListStreamsResolved === 'function') {
          var resolvedList = window.TVStorage.getCustomListStreamsResolved(activeAccount.id, 'live', clId);
          if (resolvedList !== null) {
            _liveStreams = resolvedList;
            window._liveStreams = resolvedList;
            _prepareAndShowChannelMenu(cat, targetStream);
            return;
          }
        }
        var clItems = window.TVStorage.getCustomListItems(activeAccount.id, clId);
        var clIdMap = {};
        clItems.forEach(function(it) { clIdMap[String(it.streamId)] = true; });
        if (_allAccountLiveStreams && _allAccountLiveStreams.length > 0) {
          var clMatches = _allAccountLiveStreams.filter(function(s) { return !!clIdMap[String(s.stream_id)]; });
          _backfillSnapshots(activeAccount.id, 'live', clMatches);
          _liveStreams = clMatches;
          window._liveStreams = clMatches;
          _prepareAndShowChannelMenu(cat, targetStream);
          return;
        }
        window.TVApi.getLiveStreams(activeAccount).then(function(all) {
          _allAccountLiveStreams = all;
          var clMatches = all.filter(function(s) { return !!clIdMap[String(s.stream_id)]; });
          _backfillSnapshots(activeAccount.id, 'live', clMatches);
          _liveStreams = clMatches;
          window._liveStreams = clMatches;
          _prepareAndShowChannelMenu(cat, targetStream);
        });
        return;
      } else {
        // ALWAYS fetch the exact streams for the selected category so we never show stale/favorites streams
        window.TVApi.getLiveStreams(activeAccount, cat.category_id).then(function(streams) {
          _liveStreams = streams;
          window._liveStreams = streams;
          _prepareAndShowChannelMenu(cat, targetStream);
        });
        return;
      }
    }

    _prepareAndShowChannelMenu(cat, targetStream);
  }

  function _prepareAndShowChannelMenu(cat, targetStream) {
    // Sort channels A-Z using precomputed keys
    var listCopy = (_liveStreams || []).slice();
    for (var i = 0; i < listCopy.length; i++) {
      if (listCopy[i]._cleanSortName === undefined) {
        listCopy[i]._cleanSortName = (listCopy[i].name || '').replace(/^\[.*?\]\s*/, '').toLowerCase();
      }
    }
    _channelMenuChannels = listCopy.sort(function(a, b) {
      return a._cleanSortName < b._cleanSortName ? -1 : (a._cleanSortName > b._cleanSortName ? 1 : 0);
    });

    var foundIdx = -1;
    if (targetStream) {
      var targetId = String(targetStream.stream_id || targetStream.id);
      foundIdx = _channelMenuChannels.findIndex(function(c) {
        return String(c.stream_id || c.id) === targetId;
      });
    }

    if (foundIdx >= 0) {
      _channelMenuSelectedIndex = foundIdx;
      _channelMenuPage = Math.floor(foundIdx / _channelMenuPageSize);
      if (_player) {
        _player.setChannelList(_channelMenuChannels);
      }
    } else {
      _channelMenuSelectedIndex = 0;
      _channelMenuPage = 0;
    }

    var menuEl = document.getElementById('live-channel-menu');
    if (menuEl) menuEl.style.display = 'flex';

    renderChannelMenuPage();
  }

  function renderChannelMenuPage() {
    abortChannelMenuEpg();
    var menuEl = document.getElementById('live-channel-menu');
    var listEl = document.getElementById('channel-menu-list');
    var catNameEl = document.getElementById('channel-menu-category-name');
    var pageInfoEl = document.getElementById('channel-menu-page-indicator');
    if (!menuEl || !listEl) return;

    var totalPages = Math.max(1, Math.ceil(_channelMenuChannels.length / _channelMenuPageSize));
    if (_channelMenuPage >= totalPages) _channelMenuPage = totalPages - 1;
    if (_channelMenuPage < 0) _channelMenuPage = 0;

    var currentMenuCat = _channelMenuCategory || _selectedLiveCategory;
    var catName = currentMenuCat ? currentMenuCat.category_name : 'Channels';
    if (catNameEl) catNameEl.textContent = catName;

    var pageWord = window.TVI18n ? window.TVI18n.t('page') : 'Page';
    if (pageInfoEl) pageInfoEl.textContent = pageWord + ' ' + (_channelMenuPage + 1) + ' / ' + totalPages;

    listEl.innerHTML = '';

    if (_channelMenuChannels.length === 0) {
      listEl.innerHTML = '<div class="col-placeholder">' + (window.TVI18n ? window.TVI18n.t('no_channels_in_category') : 'No channels in this category.') + '</div>';
      return;
    }

    var start = _channelMenuPage * _channelMenuPageSize;
    var end = Math.min(_channelMenuChannels.length, start + _channelMenuPageSize);
    var activeAccount = _activeAccount || (window.TVStorage ? window.TVStorage.getActiveAccount() : null);
    var controller = (typeof AbortController === 'function') ? new AbortController() : null;
    _channelMenuAbortController = controller;
    var menuGen = _channelMenuEpgGen;

    function applyMenuEpg(streamId, listings) {
      var cur = pickDashboardEpgProgram(listings);
      if (cur) {
        var epgEl = document.getElementById('cm-epg-' + streamId);
        var durEl = document.getElementById('cm-dur-' + streamId);
        var fillEl = document.getElementById('cm-fill-' + streamId);

        if (epgEl && cur.title) epgEl.textContent = cur.title;
        var cmTiming = (typeof window.calcEpgItemTiming === 'function') ? window.calcEpgItemTiming(cur) : null;
        if (cmTiming && cmTiming.isLive) {
          if (durEl) durEl.textContent = cmTiming.remainingLabel || '';
          if (fillEl) fillEl.style.width = cmTiming.percent + '%';
        }
      }
    }

    for (var i = start; i < end; i++) {
      (function(idx) {
        var ch = _channelMenuChannels[idx];
        var item = document.createElement('div');
        item.className = 'channel-menu-item focusable';
        item.setAttribute('data-index', idx);
        item.setAttribute('data-stream-id', ch.stream_id);

        if (_player && _player.currentStream && String(_player.currentStream.stream_id) === String(ch.stream_id)) {
          item.classList.add('active-stream');
        }

        var isFav = activeAccount ? window.TVStorage.isFavorite(activeAccount.id, ch.stream_id, 'live') : false;
        var cleanName = ch.name ? ch.name.replace(/^\[.*?\]\s*/, '') : 'Channel';
        var safeStreamId = escapeHtml(ch.stream_id);
        var safeChIcon = sanitizeImgUrl(ch.stream_icon) || 'assets/logo.png';

        item.innerHTML = 
          '<div class="channel-menu-left">' +
            '<span class="channel-menu-num">' + (idx + 1) + '</span>' +
            '<img class="channel-menu-logo" src="' + safeChIcon + '" onerror="this.src=\'assets/logo.png\'" />' +
            '<span class="channel-menu-name">' + escapeHtml(cleanName) + '</span>' +
            '<span class="channel-menu-epg" id="cm-epg-' + safeStreamId + '">--</span>' +
          '</div>' +
          '<div class="channel-menu-right">' +
            '<span class="channel-menu-duration" id="cm-dur-' + safeStreamId + '"></span>' +
            '<div class="channel-menu-prog-bar"><div class="channel-menu-prog-fill" id="cm-fill-' + safeStreamId + '" style="width:0%;"></div></div>' +
            '<span class="channel-menu-fav" id="cm-fav-' + safeStreamId + '">' + (isFav ? ((window.TVIcons && window.TVIcons.starFilled) ? window.TVIcons.starFilled : '★') : '') + '</span>' +
          '</div>';

        item.onclick = function() {
          if (_player) {
            var curId = _player.currentStream ? (_player.currentStream.stream_id || _player.currentStream.id) : null;
            var chId = ch ? (ch.stream_id || ch.id) : null;
            var targetCategory = _channelMenuCategory || _selectedLiveCategory;
            var isSameStream = (curId != null && chId != null && String(curId) === String(chId));
            var isSameCategory = targetCategory && _player.currentCategory && String(targetCategory.category_id) === String(_player.currentCategory.category_id);

            if (isSameStream && isSameCategory) {
              // Clicking the already active stream smoothly closes menu immediately without reloading and opens the info banner
              closeLiveChannelMenu();
              _player.showInfobar(4000);
              return;
            }
            _selectedLiveCategory = targetCategory;
            window._selectedLiveCategory = targetCategory;
            _selectedLiveStream = ch;
            _player.setChannelList(_channelMenuChannels);
            _player.playLive(ch, targetCategory, true);
            closeLiveChannelMenu();
            _player.showInfobar(4000);
          }
        };

        listEl.appendChild(item);

        // Fetch short EPG snippet
        if (activeAccount && activeAccount.type !== 'm3u') {
          var cachedMenuEpg = (window.TVApi && typeof window.TVApi.getCachedShortEpg === 'function')
            ? window.TVApi.getCachedShortEpg(activeAccount, ch.stream_id)
            : null;
          if (cachedMenuEpg) {
            applyMenuEpg(ch.stream_id, cachedMenuEpg);
          } else {
            var opts = controller ? { signal: controller.signal } : undefined;
            window.TVApi.getShortEpg(activeAccount, ch.stream_id, opts)
              .then(function(listings) {
                if (menuGen !== _channelMenuEpgGen) return;
                if (controller && controller.signal && controller.signal.aborted) return;
                applyMenuEpg(ch.stream_id, listings);
              })
              .catch(function(){});
          }
        }
      })(i);
    }

    // Set focus
    var targetFocus = listEl.querySelector('[data-index="' + _channelMenuSelectedIndex + '"]') || listEl.firstElementChild;
    if (window.SpatialNav && targetFocus) {
      window.SpatialNav.setFocus(targetFocus);
    }
  }

  function prevChannelMenuPage(focusLast) {
    abortChannelMenuEpg();
    var totalPages = Math.max(1, Math.ceil(_channelMenuChannels.length / _channelMenuPageSize));
    if (totalPages <= 1) {
      var listEl = document.getElementById('channel-menu-list');
      if (listEl) {
        var target = focusLast ? listEl.lastElementChild : listEl.firstElementChild;
        if (target && window.SpatialNav) window.SpatialNav.setFocus(target);
      }
      return;
    }
    _channelMenuPage = (_channelMenuPage - 1 + totalPages) % totalPages;
    _channelMenuSelectedIndex = focusLast ? Math.min(_channelMenuChannels.length - 1, (_channelMenuPage * _channelMenuPageSize) + _channelMenuPageSize - 1) : (_channelMenuPage * _channelMenuPageSize);
    renderChannelMenuPage();
  }

  function nextChannelMenuPage(focusLast) {
    abortChannelMenuEpg();
    var totalPages = Math.max(1, Math.ceil(_channelMenuChannels.length / _channelMenuPageSize));
    if (totalPages <= 1) {
      var listEl = document.getElementById('channel-menu-list');
      if (listEl) {
        var target = focusLast ? listEl.lastElementChild : listEl.firstElementChild;
        if (target && window.SpatialNav) window.SpatialNav.setFocus(target);
      }
      return;
    }
    _channelMenuPage = (_channelMenuPage + 1) % totalPages;
    _channelMenuSelectedIndex = focusLast ? Math.min(_channelMenuChannels.length - 1, (_channelMenuPage * _channelMenuPageSize) + _channelMenuPageSize - 1) : (_channelMenuPage * _channelMenuPageSize);
    renderChannelMenuPage();
  }

  function closeLiveChannelMenu() {
    abortChannelMenuEpg();
    var menuEl = document.getElementById('live-channel-menu');
    if (menuEl) menuEl.style.display = 'none';
    if (_player && _player.currentCategory) {
      _selectedLiveCategory = _player.currentCategory;
      window._selectedLiveCategory = _player.currentCategory;
    }
  }

  function toggleChannelMenuFavorite(itemEl) {
    if (!itemEl || !_activeAccount) return;
    var streamId = itemEl.getAttribute('data-stream-id');
    var ch = _channelMenuChannels.find(function(c) { return String(c.stream_id) === String(streamId); });
    if (!ch) return;

    var newFav = _saveFavoriteWithSnapshot(_activeAccount.id, streamId, 'live', ch);
    var starEl = document.getElementById('cm-fav-' + streamId);
    if (starEl) starEl.innerHTML = newFav ? ((window.TVIcons && window.TVIcons.starFilled) ? window.TVIcons.starFilled : '★') : '';

    var cleanName = ch.name ? ch.name.replace(/^\[.*?\]\s*/, '') : 'Channel';
    var text = newFav ? (window.TVI18n ? window.TVI18n.t('fav_added') : 'Added to Favorites') : (window.TVI18n ? window.TVI18n.t('fav_removed') : 'Removed from Favorites');
    showToast(cleanName + ': ' + text, newFav ? 'star' : 'trash');

    if (_selectedLiveCategory && _selectedLiveCategory.category_id === 'favorites') {
      if (!newFav) {
        _liveStreams = (_liveStreams || []).filter(function(s) {
          return String(s.stream_id) !== String(streamId);
        });
      } else {
        var exists = (_liveStreams || []).some(function(s) { return String(s.stream_id) === String(streamId); });
        if (!exists) _liveStreams.push(ch);
      }
      window._liveStreams = _liveStreams;
      if (_player) _player.setChannelList(_liveStreams);
      setDashboardLiveItems(_liveStreams, true);
      var countBadge = document.getElementById('live-channels-count');
      if (countBadge) countBadge.textContent = _liveStreams.length + ' ' + (window.TVI18n ? window.TVI18n.t('unit_channels') : 'Channels');
    }

    var currentCat = _channelMenuCategory || _selectedLiveCategory;
    if (currentCat && String(currentCat.category_id) === 'favorites') {
      if (!newFav) {
        _channelMenuChannels = (_channelMenuChannels || []).filter(function(s) {
          return String(s.stream_id) !== String(streamId);
        });
        _liveStreams = _channelMenuChannels;
        window._liveStreams = _channelMenuChannels;
        if (_player) _player.setChannelList(_channelMenuChannels);
        renderChannelMenuPage();
      }
    }
  }

  function openChannelMenuEpg(itemEl) {
    if (!itemEl) return;
    var streamId = itemEl.getAttribute('data-stream-id');
    var ch = _channelMenuChannels.find(function(c) { return String(c.stream_id) === String(streamId); });
    if (ch) {
      openLiveEpgOverlay(ch);
    }
  }

  // CATEGORY MENU OVERLAY (BLUE BUTTON)
  function openLiveCategoryMenu() {
    closeLiveChannelMenu();
    closeLiveEpgOverlay();

    var favText = window.TVI18n ? window.TVI18n.t('favorites') : 'Favorites';
    var favCat = { category_id: 'favorites', category_name: favText };
    _categoryMenuCategories = [favCat].concat(_liveCategories || []);

    var activeAccount = _activeAccount || (window.TVStorage ? window.TVStorage.getActiveAccount() : null);
    if ((!_liveCategories || _liveCategories.length === 0) && activeAccount) {
      window.TVApi.getLiveCategories(activeAccount).then(function(cats) {
        _liveCategories = cats;
        _categoryMenuCategories = [favCat].concat(cats || []);
        renderCategoryMenuPage();
      });
    }

    _categoryMenuPage = 0;
    var foundIdx = -1;
    var activeCat = (_player && _player.currentCategory) || _selectedLiveCategory;
    var isFromFav = _player ? (String(_player.currentCategoryId) === 'favorites') : (activeCat && String(activeCat.category_id) === 'favorites');
    var currentCatId = isFromFav ? 'favorites' : (activeCat && activeCat.category_id ? String(activeCat.category_id) : (_player && _player.currentStream ? String(_player.currentStream.category_id) : null));

    if (isFromFav) {
      foundIdx = 0;
    } else if (currentCatId != null) {
      foundIdx = _categoryMenuCategories.findIndex(function(c) {
        return String(c.category_id) === String(currentCatId);
      });
    }
    if (foundIdx >= 0) {
      _categoryMenuSelectedIndex = foundIdx;
      _categoryMenuPage = Math.floor(foundIdx / _categoryMenuPageSize);
    } else {
      _categoryMenuSelectedIndex = 0;
      _categoryMenuPage = 0;
    }

    var catMenu = document.getElementById('live-category-menu');
    if (catMenu) catMenu.style.display = 'flex';

    renderCategoryMenuPage();
  }

  function renderCategoryMenuPage() {
    var catMenu = document.getElementById('live-category-menu');
    var listEl = document.getElementById('category-menu-list');
    var pageInfoEl = document.getElementById('category-menu-page-indicator');
    if (!catMenu || !listEl) return;

    var totalPages = Math.max(1, Math.ceil(_categoryMenuCategories.length / _categoryMenuPageSize));
    if (_categoryMenuPage >= totalPages) _categoryMenuPage = totalPages - 1;
    if (_categoryMenuPage < 0) _categoryMenuPage = 0;

    var pageWord = window.TVI18n ? window.TVI18n.t('page') : 'Page';
    if (pageInfoEl) pageInfoEl.textContent = pageWord + ' ' + (_categoryMenuPage + 1) + ' / ' + totalPages;

    listEl.innerHTML = '';

    var start = _categoryMenuPage * _categoryMenuPageSize;
    var end = Math.min(_categoryMenuCategories.length, start + _categoryMenuPageSize);
    var activeCat = (_player && _player.currentCategory) || _selectedLiveCategory;
    var isFromFav = _player ? (String(_player.currentCategoryId) === 'favorites') : (activeCat && String(activeCat.category_id) === 'favorites');
    var currentCatId = isFromFav ? 'favorites' : (activeCat && activeCat.category_id ? String(activeCat.category_id) : (_player && _player.currentStream ? String(_player.currentStream.category_id) : null));

    for (var i = start; i < end; i++) {
      (function(idx) {
        var cat = _categoryMenuCategories[idx];
        var item = document.createElement('div');
        item.className = 'category-menu-item focusable';
        item.setAttribute('data-index', idx);

        var isCurrent = (currentCatId != null && String(cat.category_id) === String(currentCatId));
        if (isCurrent) {
          item.classList.add('active-category');
        }

        item.innerHTML = 
          '<div class="category-menu-left">' +
            '<span class="category-menu-num">' + (idx + 1) + '</span>' +
            '<span class="category-menu-name">' + escapeHtml(cat.category_name) + '</span>' +
          '</div>';

        item.onclick = function() {
          closeLiveCategoryMenu();
          openLiveChannelMenu(cat);
        };

        listEl.appendChild(item);
      })(i);
    }

    var targetFocus = listEl.querySelector('[data-index="' + _categoryMenuSelectedIndex + '"]') || listEl.firstElementChild;
    if (window.SpatialNav && targetFocus) {
      window.SpatialNav.setFocus(targetFocus);
    }
  }

  function prevCategoryMenuPage(focusLast) {
    var totalPages = Math.max(1, Math.ceil(_categoryMenuCategories.length / _categoryMenuPageSize));
    if (totalPages <= 1) {
      var listEl = document.getElementById('category-menu-list');
      if (listEl) {
        var target = focusLast ? listEl.lastElementChild : listEl.firstElementChild;
        if (target && window.SpatialNav) window.SpatialNav.setFocus(target);
      }
      return;
    }
    _categoryMenuPage = (_categoryMenuPage - 1 + totalPages) % totalPages;
    _categoryMenuSelectedIndex = focusLast ? Math.min(_categoryMenuCategories.length - 1, (_categoryMenuPage * _categoryMenuPageSize) + _categoryMenuPageSize - 1) : (_categoryMenuPage * _categoryMenuPageSize);
    renderCategoryMenuPage();
  }

  function nextCategoryMenuPage(focusLast) {
    var totalPages = Math.max(1, Math.ceil(_categoryMenuCategories.length / _categoryMenuPageSize));
    if (totalPages <= 1) {
      var listEl = document.getElementById('category-menu-list');
      if (listEl) {
        var target = focusLast ? listEl.lastElementChild : listEl.firstElementChild;
        if (target && window.SpatialNav) window.SpatialNav.setFocus(target);
      }
      return;
    }
    _categoryMenuPage = (_categoryMenuPage + 1) % totalPages;
    _categoryMenuSelectedIndex = focusLast ? Math.min(_categoryMenuCategories.length - 1, (_categoryMenuPage * _categoryMenuPageSize) + _categoryMenuPageSize - 1) : (_categoryMenuPage * _categoryMenuPageSize);
    renderCategoryMenuPage();
  }

  function closeLiveCategoryMenu() {
    var catMenu = document.getElementById('live-category-menu');
    if (catMenu) catMenu.style.display = 'none';
    if (_player && _player.currentCategory) {
      _selectedLiveCategory = _player.currentCategory;
      window._selectedLiveCategory = _player.currentCategory;
    }
  }

  // FULL EPG OVERLAY (GREEN BUTTON)
  function openLiveEpgOverlay(channel) {
    if (!channel) return;

    var overlay = document.getElementById('live-epg-overlay');
    var titleEl = document.getElementById('epg-overlay-channel-title');
    var listEl = document.getElementById('epg-overlay-list');
    var closeBtn = document.getElementById('epg-overlay-close-btn');
    if (!overlay || !listEl) return;

    var cleanName = channel.name ? channel.name.replace(/^\[.*?\]\s*/, '') : 'Channel';
    if (titleEl) titleEl.textContent = cleanName + ' - EPG';

    listEl.innerHTML = '<div class="col-placeholder">' + (window.TVI18n ? window.TVI18n.t('loading_schedule') : 'Loading schedule...') + '</div>';
    overlay.style.display = 'flex';

    if (closeBtn) {
      closeBtn.onclick = function(e) {
        if (e) {
          e.preventDefault();
          e.stopPropagation();
        }
        closeLiveEpgOverlay();
      };
    }

    var activeAccount = _activeAccount || (window.TVStorage ? window.TVStorage.getActiveAccount() : null);
    if (activeAccount) {
      window.TVApi.getShortEpg(activeAccount, channel.stream_id)
        .then(function(listings) {
          listEl.innerHTML = '';
          if (!listings || listings.length === 0) {
            listEl.innerHTML = '<div class="col-placeholder">' + (window.TVI18n ? window.TVI18n.t('no_epg_available') : 'No upcoming programs listed.') + '</div>';
            return;
          }

          var nowPlayingBadge = window.TVI18n ? window.TVI18n.t('now_playing') : 'NOW PLAYING';
          listings.forEach(function(item, idx) {
            var el = document.createElement('div');
            var isPlaying = (idx === 0);
            el.className = 'epg-overlay-item focusable ' + (isPlaying ? 'now-playing' : '');
            var startStr = item.start ? item.start.substring(11, 16) : '--:--';
            var endStr = item.end ? item.end.substring(11, 16) : '--:--';
            var descHtml = item.description ? ('<div class="epg-item-desc">' + escapeHtml(item.description) + '</div>') : '';
            var liveBadgeHtml = isPlaying ? '<span class="epg-live-badge">LIVE</span>' : '';

            el.innerHTML = 
              '<div class="epg-item-time-col">' +
                '<span class="epg-time-start">' + escapeHtml(startStr) + '</span>' +
                '<span class="epg-time-end">' + escapeHtml(endStr) + '</span>' +
              '</div>' +
              '<div class="epg-item-info-col">' +
                '<div class="epg-item-title-row">' +
                  '<span class="epg-item-title">' + escapeHtml(item.title || 'Program') + '</span>' +
                  liveBadgeHtml +
                '</div>' +
                descHtml +
              '</div>';

            listEl.appendChild(el);
          });

          if (window.SpatialNav && listEl.firstElementChild) {
            window.SpatialNav.setFocus(listEl.firstElementChild);
          }
        })
        .catch(function() {
          listEl.innerHTML = '<div class="col-placeholder">' + (window.TVI18n ? window.TVI18n.t('no_epg_available') : 'No upcoming programs listed.') + '</div>';
        });
    }

    if (window.SpatialNav && closeBtn) {
      window.SpatialNav.setFocus(closeBtn);
    }
  }

  function closeLiveEpgOverlay() {
    var overlay = document.getElementById('live-epg-overlay');
    if (overlay) overlay.style.display = 'none';

    var cmEl = document.getElementById('live-channel-menu');
    if (cmEl && cmEl.style.display !== 'none') {
      var listEl = document.getElementById('channel-menu-list');
      var focusTarget = listEl ? (listEl.querySelector('.active-stream') || listEl.firstElementChild) : null;
      if (window.SpatialNav && focusTarget) {
        window.SpatialNav.setFocus(focusTarget);
      }
    }
  }

  // Expose global helpers for spatial nav color buttons and navigation
  window.openLiveChannelMenu = openLiveChannelMenu;
  window.closeLiveChannelMenu = closeLiveChannelMenu;
  window.prevChannelMenuPage = prevChannelMenuPage;
  window.nextChannelMenuPage = nextChannelMenuPage;
  window.openLiveCategoryMenu = openLiveCategoryMenu;
  window.closeLiveCategoryMenu = closeLiveCategoryMenu;
  window.prevCategoryMenuPage = prevCategoryMenuPage;
  window.nextCategoryMenuPage = nextCategoryMenuPage;
  window.toggleChannelMenuFavorite = toggleChannelMenuFavorite;
  window.openChannelMenuEpg = openChannelMenuEpg;
  window.openLiveEpgOverlay = openLiveEpgOverlay;
  window.closeLiveEpgOverlay = closeLiveEpgOverlay;

  // =========================================================
  // 4. TAB 2: VOD MOVIES
  // =========================================================
  function loadMovies(isPreload) {
    if (!_activeAccount) return;
    var listEl = document.getElementById('movies-categories-list');

    if (_movieCategories && _movieCategories.length > 0) {
      if (!isPreload && _currentTab === 'movies') {
        var activeCat = listEl ? (listEl.querySelector('.category-item.active') || listEl.querySelector('.category-item')) : null;
        if (activeCat && window.SpatialNav) window.SpatialNav.setFocus(activeCat);
      }
      return;
    }

    if (listEl) listEl.innerHTML = '<div class="col-placeholder" data-i18n="loading_categories">' + (window.TVI18n ? window.TVI18n.t('loading_categories') : 'Loading categories...') + '</div>';

    window.TVApi.getVodCategories(_activeAccount)
      .then(function(cats) {
        _movieCategories = cats;
        if (_activeAccount) recordSyncTime(_activeAccount.id, 'movies', Date.now(), false);
        markCategoriesDirty('movie');
        if (!cats || cats.length === 0) {
          var noCatsText = (window.TVI18n && window.TVI18n.getLanguage() === 'de')
            ? 'Keine Filmkategorien gefunden.'
            : 'No movie categories found.';
          if (listEl) listEl.innerHTML = '<div class="col-placeholder" style="color:var(--text-dim); padding: 24px;">' + noCatsText + '</div>';
          onSplashMoviesLoaded();
          return;
        }
        renderMovieCategories(cats, false, null, isPreload);
        onSplashMoviesLoaded();
      })
      .catch(function() {
        var failText = (window.TVI18n && window.TVI18n.getLanguage() === 'de')
          ? 'Filmkategorien konnten nicht geladen werden.'
          : (window.TVI18n ? window.TVI18n.t('failed_load_categories') : 'Failed to load categories.');
        if (listEl) listEl.innerHTML = '<div class="col-placeholder" style="color:#EF4444; padding: 24px;">' + failText + '</div>';
        onSplashMoviesLoaded();
      });
  }

  var _movieLoadedCount = 0;
  var _movieBatchSize = 30;

  function renderMovieCategories(cats, keepFocusOnSearch, activeCategoryId, isPreload) {
    var listEl = document.getElementById('movies-categories-list');
    if (!listEl) return;

    var rawCats = cats || [];
    var customLists = (_activeAccount && window.TVStorage) ? window.TVStorage.getCustomLists(_activeAccount.id, 'movie') : [];
    var watchText = window.TVI18n ? window.TVI18n.t('watchlist') : 'Watchlist';
    var starIcon = (window.TVIcons && window.TVIcons.starFilled) ? window.TVIcons.starFilled : (window.TVIcons ? window.TVIcons.star : '★');
    var filmIcon = (window.TVIcons && window.TVIcons.film) ? window.TVIcons.film : '';
    var playlistIcon = (window.TVIcons && window.TVIcons.playlist) ? window.TVIcons.playlist : '';

    var favCat = { category_id: 'favorites', category_name: watchText, isFav: true };
    var customCats = customLists.map(function(cl) {
      return { category_id: 'custom_list:' + cl.id, category_name: cl.name, isCustom: true, customList: cl };
    });
    var allCats = [favCat].concat(customCats).concat(rawCats);
    var prefs = (_activeAccount && window.TVStorage) ? window.TVStorage.getCategoryPrefs(_activeAccount.id, 'movie') : { order: [], hidden: [], newIds: [] };

    // Fast O(1) lookups
    var orderSet = {};
    (prefs.order || []).forEach(function(id) { orderSet[id] = true; });
    var hiddenSet = {};
    (prefs.hidden || []).forEach(function(id) { hiddenSet[id] = true; });

    // Order categories according to prefs.order
    var catMap = {};
    allCats.forEach(function(c) {
      var id = String(c.category_id || c.categoryId);
      catMap[id] = c;
    });

    var orderedList = [];
    var favIdx = prefs.order.indexOf('favorites');
    if (favIdx === -1) {
      if (catMap['favorites']) orderedList.push(catMap['favorites']);
    } else if (favIdx === prefs.order.length - 1 && prefs.order.length > 1 && !prefs.hasManualSort) {
      if (catMap['favorites']) orderedList.push(catMap['favorites']);
    }

    prefs.order.forEach(function(id) {
      if (id === 'favorites' && orderedList.length > 0 && orderedList[0].category_id === 'favorites') return;
      if (catMap[id]) orderedList.push(catMap[id]);
    });
    allCats.forEach(function(c) {
      var id = String(c.category_id || c.categoryId);
      if (id === 'favorites' && orderedList.length > 0 && orderedList[0].category_id === 'favorites') return;
      if (!orderSet[id]) orderedList.push(c);
    });

    // Filter hidden categories
    var visibleList = orderedList.filter(function(c) {
      var id = String(c.category_id || c.categoryId);
      return !hiddenSet[id];
    });

    var mListBadgeTxt = escapeHtml((window.TVI18n && window.TVI18n.t('badge_list')) || 'LIST');
    var mNewBadgeTxt = escapeHtml((window.TVI18n && window.TVI18n.t('badge_new')) || 'NEW');
    var newSet = {};
    (prefs.newIds || []).forEach(function(nid) { newSet[nid] = true; });

    var targetEl = renderCategoryBatchList(listEl, visibleList, activeCategoryId, function(cat) {
      var catId = String(cat.category_id || cat.categoryId);
      var isCatActive = (activeCategoryId && String(activeCategoryId) === catId);
      var el = document.createElement('div');
      el.className = 'category-item focusable' + (isCatActive ? ' active' : '');
      el.setAttribute('data-category-id', catId);

      if (cat.isFav) {
        el.innerHTML =
          '<div class="category-left">' +
            '<span class="category-icon" style="color:var(--accent-gold);">' + starIcon + '</span>' +
            '<span class="category-name-text">' + watchText + '</span>' +
          '</div>';
        el.onclick = function() { selectMovieCategory({ category_id: 'favorites', category_name: watchText }, el); };
      } else if (cat.isCustom) {
        el.innerHTML =
          '<div class="category-left">' +
            '<span class="category-icon" style="color:#B388FF;">' + playlistIcon + '</span>' +
            '<span class="category-name-text" style="color:#C4B5FD; font-weight:600;">' + escapeHtml(cat.category_name) + '</span>' +
            '<span class="badge-cat-list">' + mListBadgeTxt + '</span>' +
          '</div>';
        el.onclick = function() { selectMovieCustomList(cat.customList, el); };
      } else {
        var isNew = !!newSet[catId];
        var badgeHtml = isNew ? '<span class="badge-cat-new">' + mNewBadgeTxt + '</span>' : '';
        el.innerHTML =
          '<div class="category-left">' +
            '<span class="category-icon">' + filmIcon + '</span>' +
            '<span class="category-name-text">' + escapeHtml(cat.category_name) + '</span>' +
            badgeHtml +
          '</div>';
        el.onclick = function() {
          if (isNew && _activeAccount && window.TVStorage) {
            window.TVStorage.markCategoryViewed(_activeAccount.id, 'movie', cat.category_id);
            newSet[catId] = false;
            var b = el.querySelector('.badge-cat-new');
            if (b) b.remove();
          }
          selectMovieCategory(cat, el);
        };
      }
      return el;
    });
    if (cats === _movieCategories) {
      _catsDirty.movie = false;
      _catsDirty.accountId = _activeAccount ? _activeAccount.id : null;
    }

    var catSearchInput = document.getElementById('movies-cat-search');
    var isSearchFocused = (document.activeElement === catSearchInput) ||
                          (window.SpatialNav && window.SpatialNav.getCurrent() === catSearchInput);

    if (!targetEl && listEl.firstElementChild) {
      targetEl = listEl.firstElementChild;
    }

    if (targetEl && !isPreload) {
      if (!isSearchFocused && !keepFocusOnSearch) {
        targetEl.click();
        if (!activeCategoryId) listEl.scrollTop = 0;
        if (_currentTab === 'movies') {
          var cur = window.SpatialNav ? window.SpatialNav.getCurrent() : null;
          var isOnRail = cur && cur.classList.contains('nav-rail-btn');
          if (!isOnRail && window.SpatialNav) {
            window.SpatialNav.setFocus(targetEl);
          }
        }
      }
    }
  }

  function selectMovieCustomList(cl, element) {
    if (!cl) return;
    _selectedMovieCategory = { category_id: 'custom_list:' + cl.id, category_name: cl.name, isCustomList: true, customListId: cl.id };

    var movSearch = document.getElementById('movies-search-input');
    var movClearBtn = document.getElementById('movies-search-clear-btn');
    if (movSearch) { movSearch.value = ''; _movieSearchQuery = ''; }
    if (movClearBtn) movClearBtn.style.display = 'none';

    var gridEl = document.getElementById('movies-grid-container');
    if (gridEl) {
      gridEl.innerHTML = '';
      gridEl.scrollTop = 0;
    }

    setSingleActiveCategory('movies-categories-list', element);

    var overlay = document.getElementById('movies-loading-overlay');
    if (overlay) overlay.style.display = 'flex';

    // 0ms snapshot resolution before falling back to 'all'
    if (_activeAccount && window.TVStorage && typeof window.TVStorage.getCustomListStreamsResolved === 'function') {
      var resolved = window.TVStorage.getCustomListStreamsResolved(_activeAccount.id, 'movie', cl.id);
      if (resolved !== null) {
        if (overlay) overlay.style.display = 'none';
        _movieStreams = _sortVodList(resolved, _movieSortMode);
        renderMovieGrid();
        return;
      }
    }

    var items = (_activeAccount && window.TVStorage) ? window.TVStorage.getCustomListItems(_activeAccount.id, cl.id) : [];
    if (_allAccountVodStreams && _allAccountVodStreams.length > 0) {
      if (overlay) overlay.style.display = 'none';
      var itemMap = {};
      items.forEach(function(it) { itemMap[String(it.streamId)] = it; });
      var matches = _allAccountVodStreams.filter(function(m) { return !!itemMap[String(m.stream_id)]; });
      if (matches.length < items.length) {
        var existingIds = matches.map(function(m) { return String(m.stream_id); });
        items.forEach(function(it) {
          if (existingIds.indexOf(String(it.streamId)) === -1 && it.streamName) {
            var found = _allAccountVodStreams.find(function(m) { return (m.name || '').trim().toLowerCase() === it.streamName.trim().toLowerCase(); });
            if (found && existingIds.indexOf(String(found.stream_id)) === -1) {
              matches.push(found);
              existingIds.push(String(found.stream_id));
            }
          }
        });
      }
      if (_activeAccount) _backfillSnapshots(_activeAccount.id, 'movie', matches);
      _movieStreams = _sortVodList(matches, _movieSortMode);
      renderMovieGrid();
      return;
    }

    ensureMasterTabData('movies').then(function(all) {
      if (overlay) overlay.style.display = 'none';
      var itemMap = {};
      items.forEach(function(it) { itemMap[String(it.streamId)] = it; });
      var matches = (all || []).filter(function(m) { return !!itemMap[String(m.stream_id)]; });
      if (_activeAccount) _backfillSnapshots(_activeAccount.id, 'movie', matches);
      _movieStreams = _sortVodList(matches, _movieSortMode);
      renderMovieGrid();
    }).catch(function() {
      if (overlay) overlay.style.display = 'none';
      _movieStreams = [];
      renderMovieGrid();
    });
  }

  function selectMovieCategory(cat, element) {
    _selectedMovieCategory = cat;

    var movSearch = document.getElementById('movies-search-input');
    var movClearBtn = document.getElementById('movies-search-clear-btn');
    if (movSearch) { movSearch.value = ''; _movieSearchQuery = ''; }
    if (movClearBtn) movClearBtn.style.display = 'none';

    // Clear old posters immediately to release TV GPU memory
    var gridEl = document.getElementById('movies-grid-container');
    if (gridEl) {
      gridEl.innerHTML = '';
      gridEl.scrollTop = 0;
    }

    setSingleActiveCategory('movies-categories-list', element);

    fetchCategoryMovies();
  }

  function fetchCategoryMovies() {
    if (!_selectedMovieCategory) return;
    var overlay = document.getElementById('movies-loading-overlay');
    if (overlay) overlay.style.display = 'flex';

    if (_selectedMovieCategory.category_id === 'favorites') {
      var favIds = window.TVStorage.getFavorites(_activeAccount.id, 'movie');
      if (favIds.length === 0) {
        if (overlay) overlay.style.display = 'none';
        _movieStreams = [];
        _movieFilteredList = [];
        renderMovieGrid(true);
        return;
      }
      // 0ms snapshot resolution before falling back to 'all'
      if (typeof window.TVStorage.getFavoriteStreamsResolved === 'function') {
        var resolvedFavs = window.TVStorage.getFavoriteStreamsResolved(_activeAccount.id, 'movie');
        if (resolvedFavs !== null) {
          if (overlay) overlay.style.display = 'none';
          _movieStreams = _sortVodList(resolvedFavs, _movieSortMode);
          renderMovieGrid();
          return;
        }
      }
      if (_allAccountVodStreams && _allAccountVodStreams.length > 0) {
        if (overlay) overlay.style.display = 'none';
        var favMatches = _allAccountVodStreams.filter(function(m) {
          return favIds.indexOf(String(m.stream_id)) >= 0;
        });
        _backfillSnapshots(_activeAccount.id, 'movie', favMatches);
        _movieStreams = _sortVodList(favMatches, _movieSortMode);
        renderMovieGrid();
        return;
      }
      window.TVApi.getVodStreams(_activeAccount, 'all', _movieSortMode)
        .then(function(all) {
          if (overlay) overlay.style.display = 'none';
          _allAccountVodStreams = all;
          var favMatches = all.filter(function(m) {
            return favIds.indexOf(String(m.stream_id)) >= 0;
          });
          _backfillSnapshots(_activeAccount.id, 'movie', favMatches);
          _movieStreams = _sortVodList(favMatches, _movieSortMode);
          renderMovieGrid();
        })
        .catch(function() {
          if (overlay) overlay.style.display = 'none';
          _movieStreams = [];
          renderMovieGrid();
        });
    } else {
      window.TVApi.getVodStreams(_activeAccount, _selectedMovieCategory.category_id, _movieSortMode)
        .then(function(streams) {
          if (overlay) overlay.style.display = 'none';
          _movieStreams = streams;
          renderMovieGrid();
        })
        .catch(function() {
          if (overlay) overlay.style.display = 'none';
          _movieStreams = [];
          renderMovieGrid();
        });
    }
  }

  function getEmptyVodStateHtml(type, isWatchlist) {
    var lang = window.TVI18n ? window.TVI18n.getLanguage() : 'en';
    var isDe = (lang === 'de');
    
    var iconSvg = '';
    var title = '';
    var subtitle = '';

    if (isWatchlist) {
      iconSvg = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>';
      if (type === 'movies') {
        title = isDe ? 'Keine Filme in der Watchlist' : 'No Movies in Watchlist';
        subtitle = isDe ? 'Füge Filme zu deiner Watchlist hinzu, indem du in den Filmdetails auf Watchlist klickst.' : 'Add movies to your Watchlist by selecting Watchlist in the movie details.';
      } else {
        title = isDe ? 'Keine Serien in der Watchlist' : 'No Series in Watchlist';
        subtitle = isDe ? 'Füge Serien zu deiner Watchlist hinzu, indem du in den Seriendetails auf Watchlist klickst.' : 'Add series to your Watchlist by selecting Watchlist in the series details.';
      }
    } else if (type === 'movies') {
      iconSvg = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="2" width="20" height="20" rx="2.18" ry="2.18"/><line x1="7" y1="2" x2="7" y2="22"/><line x1="17" y1="2" x2="17" y2="22"/><line x1="2" y1="12" x2="22" y2="12"/><line x1="2" y1="7" x2="7" y2="7"/><line x1="2" y1="17" x2="7" y2="17"/><line x1="17" y1="17" x2="22" y2="17"/><line x1="17" y1="7" x2="22" y2="7"/></svg>';
      title = isDe ? 'Keine Filme gefunden' : 'No Movies Found';
      subtitle = isDe ? 'Versuche einen anderen Suchbegriff oder wähle eine andere Kategorie.' : 'Try adjusting your search query or select a different category.';
    } else {
      iconSvg = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polygon points="12 2 2 7 12 12 22 7 12 2"/><polyline points="2 17 12 22 22 17"/><polyline points="2 12 12 17 22 12"/></svg>';
      title = isDe ? 'Keine Serien gefunden' : 'No Series Found';
      subtitle = isDe ? 'Versuche einen anderen Suchbegriff oder wähle eine andere Kategorie.' : 'Try adjusting your search query or select a different category.';
    }

    return '<div class="vod-empty-state">' +
             '<div class="vod-empty-icon-wrap">' + iconSvg + '</div>' +
             '<div class="vod-empty-title">' + title + '</div>' +
             '<div class="vod-empty-subtitle">' + subtitle + '</div>' +
           '</div>';
  }

  function formatRuntime(raw) {
    if (!raw) return '';
    var sec = parseDurationSecs(raw);
    if (sec <= 0) return String(raw).trim();
    var h = Math.floor(sec / 3600);
    var m = Math.floor((sec % 3600) / 60);
    if (h > 0) {
      return h + 'h ' + String(m).padStart(2, '0') + 'm';
    }
    return m + ' min';
  }

  function parseDurationSecs(raw) {
    if (window.TVStorage && window.TVStorage.parseDurationSecs) {
      return window.TVStorage.parseDurationSecs(raw);
    }
    if (raw === null || raw === undefined || raw === '') return 0;
    if (typeof raw === 'number') {
      if (isNaN(raw) || !isFinite(raw) || raw <= 0) return 0;
      return (raw < 300) ? Math.floor(raw * 60) : Math.floor(raw);
    }
    var str = String(raw).trim();
    if (!str) return 0;
    var timeMatch = str.match(/^(\d{1,2}):(\d{2}):(\d{2})$/);
    if (timeMatch) {
      var h = parseInt(timeMatch[1], 10) || 0;
      var m = parseInt(timeMatch[2], 10) || 0;
      var s = parseInt(timeMatch[3], 10) || 0;
      return (h * 3600) + (m * 60) + s;
    }
    var shortMatch = str.match(/^(\d{1,3}):(\d{2})$/);
    if (shortMatch) {
      var sm = parseInt(shortMatch[1], 10) || 0;
      var ss = parseInt(shortMatch[2], 10) || 0;
      return (sm * 60) + ss;
    }
    if (/^\d+(\.\d+)?$/.test(str)) {
      var num = parseFloat(str);
      if (isNaN(num) || !isFinite(num) || num <= 0) return 0;
      return (num < 300) ? Math.floor(num * 60) : Math.floor(num);
    }
    return 0;
  }

  function hasItems(val) {
    if (!val) return false;
    if (typeof val === 'string') {
      var trimmed = val.trim();
      if (!trimmed || trimmed === '[]' || trimmed === '{}' || trimmed === '""' || trimmed === "''" || 
          trimmed === 'null' || trimmed === 'undefined' || trimmed.toLowerCase() === 'none' || 
          trimmed.toLowerCase() === 'no' || trimmed.toLowerCase() === 'false' || trimmed === '{ }' || trimmed === '[ ]') {
        return false;
      }
      return true;
    }
    if (Array.isArray(val)) return val.length > 0;
    if (typeof val === 'object') {
      var keys = Object.keys(val);
      if (keys.length === 0) return false;
      var hasAnyVal = keys.some(function(k) { return hasItems(val[k]); });
      return hasAnyVal;
    }
    return true;
  }

  function toArray(val) {
    if (!val) return [];
    if (typeof val === 'string') {
      var trimmed = val.trim();
      if ((trimmed.startsWith('[') && trimmed.endsWith(']')) || (trimmed.startsWith('{') && trimmed.endsWith('}'))) {
        try {
          var parsed = JSON.parse(trimmed);
          return toArray(parsed);
        } catch(e) {}
      }
      return trimmed.split(/[,|;\/]+/).map(function(s) { return s.trim(); }).filter(Boolean);
    }
    if (Array.isArray(val)) return val;
    if (typeof val === 'object' && val !== null) {
      var keys = Object.keys(val);
      var isIndexedMap = keys.every(function(k) { return !isNaN(parseInt(k, 10)); });
      if (isIndexedMap) {
        return keys.map(function(k) { return val[k]; }).filter(Boolean);
      }
      if (val.codec_name || val.codec_type || val.channels || val.tags || val.language || val.title) {
        return [val];
      }
      var items = [];
      keys.forEach(function(k) {
        var v = val[k];
        if (!v) return;
        if (typeof v === 'string') {
          items.push({ language: k, title: v });
        } else if (typeof v === 'object') {
          if (!v.language && !v.lang && !v.tags) v.language = k;
          items.push(v);
        }
      });
      if (items.length > 0) return items;
      return keys.map(function(k) { return val[k]; }).filter(Boolean);
    }
    return [];
  }

  function getLangDisplay(codeOrName) {
    if (window.getLanguageDisplayName) {
      return window.getLanguageDisplayName(codeOrName);
    }
    return (codeOrName && typeof codeOrName === 'string') ? codeOrName.trim() : '';
  }

  function _parseAudioItem(item, idx) {
    if (!item) return null;
    var lang = '';
    var title = '';
    var codec = '';
    var channels = '';
    var id = String(idx);

    if (typeof item === 'string') {
      var clean = item.trim();
      if (!clean || clean.toLowerCase() === 'none' || clean.toLowerCase() === 'false' || clean.toLowerCase() === 'no') return null;
      var knownCodecs = ['aac', 'ac3', 'eac3', 'mp3', 'dts', 'dca', 'truehd', 'flac', 'vorbis', 'opus', 'mp2', 'pcm'];
      if (knownCodecs.indexOf(clean.toLowerCase()) !== -1) {
        codec = clean.toLowerCase();
      } else {
        lang = clean;
      }
    } else if (typeof item === 'object') {
      var sTags = item.tags || item.TAGS || item.Tags || {};
      lang = sTags.language || sTags.Language || sTags.lang || item.language || item.lang || item.ISO639 || item.iso || item.code || item.audio_lang || '';
      title = sTags.title || sTags.Title || item.title || item.name || item.label || item.description || item.handler_name || '';
      codec = (item.codec_name || item.codec || '').toLowerCase();
      channels = item.channels || item.channel_layout || '';
      if (item.id !== undefined) id = String(item.id);
      else if (item.index !== undefined) id = String(item.index);
    }

    var cLang = (lang && lang.toLowerCase() !== 'und' && lang.toLowerCase() !== 'unk') ? lang : '';
    var cTitle = (title && title.toLowerCase() !== 'und' && title.toLowerCase() !== 'unk') ? title : '';
    var displayLabel = cTitle || cLang || ('Audio ' + (idx + 1));

    return {
      index: idx,
      streamIndex: idx,
      id: id,
      title: displayLabel,
      name: displayLabel,
      language: cLang,
      lang: cLang,
      codec: codec,
      codec_name: codec,
      channels: String(channels)
    };
  }

  function _parseSubItem(item, idx) {
    if (!item) return null;
    var lang = '';
    var title = '';
    var codec = '';
    var id = String(idx);

    if (typeof item === 'string') {
      var clean = item.trim();
      if (!clean || clean.toLowerCase() === 'none' || clean.toLowerCase() === 'no' || clean.toLowerCase() === 'false' || clean.toLowerCase() === 'off') return null;
      lang = clean;
    } else if (typeof item === 'object') {
      var sTags = item.tags || item.TAGS || item.Tags || {};
      lang = sTags.language || sTags.Language || sTags.lang || item.language || item.lang || item.ISO639 || item.iso || item.code || item.sub_lang || '';
      title = sTags.title || sTags.Title || item.title || item.name || item.label || item.description || '';
      codec = (item.codec_name || item.codec || '').toLowerCase();
      if (item.id !== undefined) id = String(item.id);
      else if (item.index !== undefined) id = String(item.index);
    }

    var cLang = (lang && lang.toLowerCase() !== 'und' && lang.toLowerCase() !== 'unk') ? lang : '';
    var cTitle = (title && title.toLowerCase() !== 'und' && title.toLowerCase() !== 'unk') ? title : '';
    var displayLabel = cTitle || cLang || ('Subtitle ' + (idx + 1));

    var subUrl = (typeof item === 'object' && item) ? (item.url || item.link || item.file || item.path || '') : '';
    if (typeof item === 'string' && (/^https?:\/\//i.test(item) || /\.vtt|\.srt/i.test(item))) {
      subUrl = item;
    }

    return {
      index: idx,
      streamIndex: idx,
      id: id,
      title: displayLabel,
      name: displayLabel,
      language: lang,
      lang: lang,
      codec: codec,
      url: subUrl,
      isExternal: !!subUrl
    };
  }

  function extractMediaTracksFromInfo(vodInfo) {
    var audios = [];
    var subs = [];
    if (!vodInfo) return { audios: audios, subs: subs };

    console.log('[TrackDebug] >>> extractMediaTracksFromInfo called <<<');
    try {
      console.log('[TrackDebug] vodInfo keys:', Object.keys(vodInfo));
      if (vodInfo.info && typeof vodInfo.info === 'object') {
        console.log('[TrackDebug] vodInfo.info keys:', Object.keys(vodInfo.info));
      }
      if (vodInfo.movie_data && typeof vodInfo.movie_data === 'object') {
        console.log('[TrackDebug] vodInfo.movie_data keys:', Object.keys(vodInfo.movie_data));
      }
      ['media_info', 'info', 'movie_data'].forEach(function(k) {
        if (typeof vodInfo[k] === 'string') {
          try { vodInfo[k] = JSON.parse(vodInfo[k]); } catch(e){}
        }
      });

      // 1. FFprobe streams from all candidate locations
      var streamCandidates = [
        vodInfo.media_info && vodInfo.media_info.streams,
        vodInfo.info && vodInfo.info.streams,
        vodInfo.movie_data && vodInfo.movie_data.streams,
        vodInfo.movie_data && vodInfo.movie_data.media_info && vodInfo.movie_data.media_info.streams,
        vodInfo.streams
      ];

      // 2. Audio candidates fallback/enrichment
      var audioCandidates = [
        vodInfo.media_info && vodInfo.media_info.audio,
        vodInfo.media_info && vodInfo.media_info.audio_tracks,
        vodInfo.media_info && vodInfo.media_info.audios,
        vodInfo.info && vodInfo.info.audio,
        vodInfo.info && vodInfo.info.audio_tracks,
        vodInfo.info && vodInfo.info.audios,
        vodInfo.movie_data && vodInfo.movie_data.audio,
        vodInfo.movie_data && vodInfo.movie_data.audio_tracks,
        vodInfo.movie_data && vodInfo.movie_data.info && vodInfo.movie_data.info.audio,
        vodInfo.audio,
        vodInfo.audios,
        vodInfo.audio_tracks
      ];

      // 3. Subtitle candidates fallback/enrichment
      var subCandidates = [
        vodInfo.media_info && vodInfo.media_info.subtitles,
        vodInfo.media_info && vodInfo.media_info.sub_titles,
        vodInfo.media_info && vodInfo.media_info.subtitle_tracks,
        vodInfo.info && vodInfo.info.subtitles,
        vodInfo.info && vodInfo.info.sub_titles,
        vodInfo.info && vodInfo.info.subtitle_tracks,
        vodInfo.info && vodInfo.info.all_subtitles,
        vodInfo.movie_data && vodInfo.movie_data.subtitles,
        vodInfo.movie_data && vodInfo.movie_data.sub_titles,
        vodInfo.movie_data && vodInfo.movie_data.subtitle_tracks,
        vodInfo.movie_data && vodInfo.movie_data.info && vodInfo.movie_data.info.subtitles,
        vodInfo.subtitles,
        vodInfo.sub_titles,
        vodInfo.subtitle_tracks,
        vodInfo.all_subtitles
      ];

      // Dynamic scan of all objects in vodInfo for unexpected vendor key names
      function scanForTrackCandidates(obj, label) {
        if (!obj || typeof obj !== 'object') return;
        Object.keys(obj).forEach(function(k) {
          var lk = k.toLowerCase();
          var v = obj[k];
          if (!v) return;
          if (typeof v === 'string' && (v.startsWith('{') || v.startsWith('['))) {
            try { v = JSON.parse(v); } catch(e){}
          }
          if (lk.indexOf('audio') !== -1 || lk.indexOf('sound') !== -1 || lk.indexOf('tonspur') !== -1) {
            if (audioCandidates.indexOf(v) === -1) {
              console.log('[TrackDebug] Dynamic candidate found for audio in ' + label + '.' + k + ':', v);
              audioCandidates.push(v);
            }
          } else if (lk.indexOf('sub') !== -1 || lk.indexOf('untertitel') !== -1 || lk.indexOf('caption') !== -1) {
            if (subCandidates.indexOf(v) === -1) {
              console.log('[TrackDebug] Dynamic candidate found for sub in ' + label + '.' + k + ':', v);
              subCandidates.push(v);
            }
          } else if (lk.indexOf('stream') !== -1 || lk.indexOf('track') !== -1) {
            if (streamCandidates.indexOf(v) === -1) {
              console.log('[TrackDebug] Dynamic candidate found for stream in ' + label + '.' + k + ':', v);
              streamCandidates.push(v);
            }
          }
        });
      }

      scanForTrackCandidates(vodInfo, 'vodInfo');
      if (vodInfo.info && typeof vodInfo.info === 'object') scanForTrackCandidates(vodInfo.info, 'vodInfo.info');
      if (vodInfo.movie_data && typeof vodInfo.movie_data === 'object') scanForTrackCandidates(vodInfo.movie_data, 'vodInfo.movie_data');
      if (vodInfo.media_info && typeof vodInfo.media_info === 'object') scanForTrackCandidates(vodInfo.media_info, 'vodInfo.media_info');

      for (var i = 0; i < streamCandidates.length; i++) {
        if (hasItems(streamCandidates[i])) {
          var parsedStreams = toArray(streamCandidates[i]);
          if (parsedStreams.length > 0) {
            console.log('[TrackDebug] Found streams in candidate [' + i + '], count=' + parsedStreams.length);
            parsedStreams.forEach(function(s) {
              if (!s) return;
              var cType = (s.codec_type || '').toLowerCase();
              var cName = (s.codec_name || s.codec || '').toLowerCase();
              if (!cType && cName) {
                var knownAudio = ['aac', 'ac3', 'eac3', 'mp3', 'dts', 'dca', 'truehd', 'flac', 'vorbis', 'opus', 'mp2', 'pcm'];
                var knownSub = ['subrip', 'srt', 'ass', 'ssa', 'mov_text', 'hdmv_pgs', 'pgs', 'dvd_sub', 'vobsub', 'webvtt', 'vtt', 'text', 'dvb_sub', 'teletext'];
                for (var a = 0; a < knownAudio.length; a++) {
                  if (cName.indexOf(knownAudio[a]) !== -1) { cType = 'audio'; break; }
                }
                if (!cType) {
                  for (var b = 0; b < knownSub.length; b++) {
                    if (cName.indexOf(knownSub[b]) !== -1) { cType = 'subtitle'; break; }
                  }
                }
              }
              if (cType === 'audio') {
                var aObj = _parseAudioItem(s, audios.length);
                if (aObj) audios.push(aObj);
              } else if (cType === 'subtitle') {
                var sObj = _parseSubItem(s, subs.length);
                if (sObj) subs.push(sObj);
              }
            });
            if (audios.length > 0 || subs.length > 0) break;
          }
        }
      }

      for (var j = 0; j < audioCandidates.length; j++) {
        if (hasItems(audioCandidates[j])) {
          var aList = toArray(audioCandidates[j]);
          if (aList.length > audios.length) {
            var parsedA = [];
            aList.forEach(function(item) {
              var p = _parseAudioItem(item, parsedA.length);
              if (p) parsedA.push(p);
            });
            if (parsedA.length > audios.length) {
              console.log('[TrackDebug] Enriched audios from candidate [' + j + ']: ' + audios.length + ' -> ' + parsedA.length);
              audios = parsedA;
            }
          }
        }
      }

      // 3. Subtitle candidates fallback/enrichment
      var subCandidates = [
        vodInfo.media_info && vodInfo.media_info.subtitles,
        vodInfo.media_info && vodInfo.media_info.sub_titles,
        vodInfo.media_info && vodInfo.media_info.subtitle_tracks,
        vodInfo.info && vodInfo.info.subtitles,
        vodInfo.info && vodInfo.info.sub_titles,
        vodInfo.info && vodInfo.info.subtitle_tracks,
        vodInfo.info && vodInfo.info.all_subtitles,
        vodInfo.movie_data && vodInfo.movie_data.subtitles,
        vodInfo.movie_data && vodInfo.movie_data.sub_titles,
        vodInfo.movie_data && vodInfo.movie_data.subtitle_tracks,
        vodInfo.movie_data && vodInfo.movie_data.info && vodInfo.movie_data.info.subtitles,
        vodInfo.subtitles,
        vodInfo.sub_titles,
        vodInfo.subtitle_tracks,
        vodInfo.all_subtitles
      ];

      for (var k = 0; k < subCandidates.length; k++) {
        if (hasItems(subCandidates[k])) {
          var sList = toArray(subCandidates[k]);
          if (sList.length > subs.length) {
            var parsedS = [];
            sList.forEach(function(item) {
              var p = _parseSubItem(item, parsedS.length);
              if (p) parsedS.push(p);
            });
            if (parsedS.length > subs.length) {
              console.log('[TrackDebug] Enriched subs from candidate [' + k + ']: ' + subs.length + ' -> ' + parsedS.length);
              subs = parsedS;
            }
          }
        }
      }

      console.log('[TrackDebug] extractMediaTracksFromInfo final: ' + audios.length + ' audios, ' + subs.length + ' subs');
      if (audios.length > 0) {
        audios.forEach(function(a, idx) {
          console.log('[AudioState:A-Discovered] API metadata audio track #' + idx + ' (codec=' + (a.codec || 'unknown') + ', lang=' + (a.language || a.lang || 'und') + ', title="' + (a.title || a.name || '') + '")');
        });
      }
      if (subs.length > 0) console.log('[TrackDebug] Extracted subs:', subs);
    } catch(err) {
      console.error('[TrackDebug] Exception in extractMediaTracksFromInfo:', err);
    }

    return { audios: audios, subs: subs };
  }

  function extractAudioTracksFromInfo(vodInfo) {
    return extractMediaTracksFromInfo(vodInfo).audios;
  }
  window.extractAudioTracksFromInfo = extractAudioTracksFromInfo;

  function extractSubtitleTracksFromInfo(vodInfo) {
    return extractMediaTracksFromInfo(vodInfo).subs;
  }
  window.extractSubtitleTracksFromInfo = extractSubtitleTracksFromInfo;

  function openResumePlaybackModal(item, type, position, duration, onConfirm) {
    var modal = document.getElementById('modal-resume-playback');
    var confirmBtn = document.getElementById('resume-confirm-btn');
    var confirmText = document.getElementById('resume-confirm-text');
    var startOverBtn = document.getElementById('resume-startover-btn');
    var closeBtn = document.getElementById('resume-close-btn');
    if (!modal) return;

    var posFormatted = _player ? _player._formatTime(position) : (Math.floor(position / 60) + ' min');
    var resumeLabel = window.TVI18n ? window.TVI18n.t('resume') : 'Resume';
    
    if (confirmText) {
      confirmText.textContent = resumeLabel + ' (' + posFormatted + ')';
    }

    function doResume() {
      closeModal(modal);
      if (typeof onConfirm === 'function') onConfirm(position);
    }

    function doStartOver() {
      closeModal(modal);
      if (typeof onConfirm === 'function') onConfirm(0);
    }

    if (confirmBtn) confirmBtn.onclick = doResume;
    if (startOverBtn) startOverBtn.onclick = doStartOver;
    if (closeBtn) closeBtn.onclick = function() { closeModal(modal); };

    openModal(modal, confirmBtn);
  }

  function renderContinueWatching(type) {
    if (!_activeAccount || !window.TVStorage) return;

    if (type === 'movie') {
      var mSection = document.getElementById('movies-continue-watching');
      var mRail = document.getElementById('movies-cw-rail');
      if (!mSection || !mRail) return;

      var items = window.TVStorage.getContinueWatching(_activeAccount.id, 'movie');
      if (!items || items.length === 0) {
        mSection.style.display = 'none';
        mRail.innerHTML = '';
        return;
      }

      mSection.style.display = 'flex';
      mRail.innerHTML = '';

      items.forEach(function(item) {
        var card = document.createElement('div');
        card.className = 'cw-card focusable';
        card.setAttribute('data-stream-id', item.streamId);
        var dur = parseDurationSecs(item.duration);
        if (dur <= 100) {
          var fullMovie = (_movieStreams || []).find(function(m) { return String(m.stream_id) === String(item.streamId); });
          if (fullMovie) {
            var mDur = (window.extractDurationFromInfo ? window.extractDurationFromInfo(fullMovie) : 0) || parseDurationSecs(fullMovie.duration_secs || fullMovie.duration || (fullMovie.info && (fullMovie.info.duration_secs || fullMovie.info.duration)) || 0);
            if (mDur > 100) {
              dur = mDur;
              item.duration = dur;
              if (window.TVStorage && _activeAccount) {
                window.TVStorage.saveProgress(_activeAccount.id, item);
              }
            }
          }
        }
        var pct = (dur > 100) ? Math.min(99, Math.max(0, Math.round((item.position / dur) * 100))) : 0;
        var poster = sanitizeImgUrl(item.posterUrl) || 'assets/logo.png';

        var cwCloseIcon = (window.TVIcons && window.TVIcons.close) ? window.TVIcons.close : '✕';
        var cwPlayIcon = (window.TVIcons && window.TVIcons.play) ? window.TVIcons.play : '▶';

        card.innerHTML = 
          '<div class="cw-poster-wrapper">' +
            '<img class="cw-poster-img" src="' + poster + '" alt="" />' +
            '<button class="cw-remove-btn focusable" title="Remove" aria-label="Remove">' + cwCloseIcon + '</button>' +
            '<span class="cw-play-badge">' + cwPlayIcon + '</span>' +
          '</div>' +
          '<div class="cw-card-info">' +
            '<div class="cw-card-title">' + escapeHtml(item.title || 'Movie') + '</div>' +
            '<div class="cw-progress-track">' +
              '<div class="cw-progress-fill" style="width:' + pct + '%;"></div>' +
            '</div>' +
          '</div>';

        if (dur <= 100 && _activeAccount && window.TVApi) {
          window.TVApi.getVodInfo(_activeAccount, item.streamId).then(function(info) {
            if (!info) return;
            var realDur = (window.extractDurationFromInfo ? window.extractDurationFromInfo(info) : 0) || parseDurationSecs((info.info && (info.info.duration_secs || info.info.duration || info.info.runtime)) || (info.movie_data && (info.movie_data.duration_secs || info.movie_data.duration || info.movie_data.runtime)) || 0);
            if (realDur > 100) {
              item.duration = realDur;
              if (window.TVStorage && _activeAccount) {
                window.TVStorage.saveProgress(_activeAccount.id, item);
              }
              var fill = card.querySelector('.cw-progress-fill');
              if (fill) {
                var newPct = Math.min(99, Math.max(0, Math.round((item.position / realDur) * 100)));
                fill.style.width = newPct + '%';
              }
            }
          }).catch(function(){});

          if (window.TVContainerProber) {
            var cExt = item.containerExtension || 'mp4';
            var vUrl = window.TVApi.getVodStreamUrl(_activeAccount, item.streamId, cExt);
            window.TVContainerProber.probeStream(vUrl).then(function(demuxed) {
              if (demuxed && demuxed.duration > 100) {
                item.duration = demuxed.duration;
                if (window.TVStorage && _activeAccount) {
                  window.TVStorage.saveProgress(_activeAccount.id, item);
                }
                var fill = card.querySelector('.cw-progress-fill');
                if (fill) {
                  var newPct = Math.min(99, Math.max(0, Math.round((item.position / demuxed.duration) * 100)));
                  fill.style.width = newPct + '%';
                }
              }
            }).catch(function(){});
          }
        }

        var removeBtn = card.querySelector('.cw-remove-btn');
        if (removeBtn) {
          removeBtn.onclick = function(e) {
            if (e && e.stopPropagation) e.stopPropagation();
            if (window.TVStorage && _activeAccount) {
              window.TVStorage.deleteProgress(_activeAccount.id, item.streamId);
            }
            var nextFocus = card.nextElementSibling || card.previousElementSibling;
            if (!nextFocus) {
              nextFocus = document.querySelector('#movies-grid-container .poster-card') || document.getElementById('movies-search-input');
            }
            if (window.SpatialNav) {
              var isFocused = card.classList.contains('focused') || (removeBtn && removeBtn.classList.contains('focused')) || (document.activeElement === card || document.activeElement === removeBtn);
              if (isFocused && nextFocus) {
                window.SpatialNav.setFocus(nextFocus);
              }
            }
            card.style.transition = 'all 0.2s ease-out';
            card.style.opacity = '0';
            card.style.transform = 'scale(0.8)';
            setTimeout(function() {
              card.remove();
              if (mRail.children.length === 0) {
                mSection.style.display = 'none';
              }
            }, 200);
            showToast(window.TVI18n ? window.TVI18n.t('removed') || 'Removed from Continue Watching' : 'Removed', 'trash');
          };
        }

        card.onclick = function() {
          _lastMediaSourceCard = { type: 'movie', streamId: item.streamId };
          var fullMovie = (_movieStreams || []).find(function(m) { return String(m.stream_id) === String(item.streamId); });
          var targetMovie = fullMovie || {
            stream_id: item.streamId,
            name: item.title,
            stream_icon: item.posterUrl,
            container_extension: item.containerExtension || 'mp4'
          };
          var itemDur = parseDurationSecs(item.duration || targetMovie.duration_secs || targetMovie.duration || 0);
          if (item.position >= 3 && !item.isCompleted && (itemDur <= 30 || (item.position / itemDur) < 0.95)) {
            openResumePlaybackModal(targetMovie, 'movie', item.position, itemDur, function(chosenPos) {
              var meta = {
                streamId: item.streamId,
                type: 'movie',
                title: item.title || 'Movie',
                posterUrl: item.posterUrl || '',
                containerExtension: item.containerExtension || targetMovie.container_extension || 'mp4',
                duration: itemDur,
                startPosition: chosenPos,
                audioTracks: item.audioTracks || [],
                subtitleTracks: item.subtitleTracks || []
              };
              _player.playVod(targetMovie, 'vod', item.title || 'Movie', '', null, meta);
            });
          } else {
            openMovieDetail(targetMovie);
          }
        };

        mRail.appendChild(card);
      });
    }

    if (type === 'series') {
      var sSection = document.getElementById('series-continue-watching');
      var sRail = document.getElementById('series-cw-rail');
      if (!sSection || !sRail) return;

      var sItems = window.TVStorage.getContinueWatching(_activeAccount.id, 'series');
      if (!sItems || sItems.length === 0) {
        sSection.style.display = 'none';
        sRail.innerHTML = '';
        return;
      }

      sSection.style.display = 'flex';
      sRail.innerHTML = '';

      sItems.forEach(function(item) {
        var card = document.createElement('div');
        card.className = 'cw-card focusable';
        card.setAttribute('data-stream-id', item.streamId);
        if (item.seriesId) card.setAttribute('data-series-id', item.seriesId);
        var sNum = item.season || 1;
        var eNum = item.episode || 1;
        var sPill = 'S' + String(sNum).padStart(2, '0') + ' E' + String(eNum).padStart(2, '0');
        var dur = parseDurationSecs(item.duration);
        var pct = (item.isAdvanced || dur <= 100) ? 0 : Math.min(99, Math.max(0, Math.round((item.position / dur) * 100)));
        var poster = sanitizeImgUrl(item.posterUrl) || 'assets/logo.png';

        var sCwCloseIcon = (window.TVIcons && window.TVIcons.close) ? window.TVIcons.close : '✕';
        var sCwPlayIcon = (window.TVIcons && window.TVIcons.play) ? window.TVIcons.play : '▶';

        card.innerHTML = 
          '<div class="cw-poster-wrapper">' +
            '<img class="cw-poster-img" src="' + poster + '" alt="" />' +
            '<span class="cw-badge">[' + escapeHtml(sPill) + ']</span>' +
            '<button class="cw-remove-btn focusable" title="Remove" aria-label="Remove">' + sCwCloseIcon + '</button>' +
            '<span class="cw-play-badge">' + sCwPlayIcon + '</span>' +
          '</div>' +
          '<div class="cw-card-info">' +
            (item.seriesName ? '<div class="cw-series-name">' + escapeHtml(item.seriesName) + '</div>' : '') +
            '<div class="cw-card-title">' + escapeHtml(item.title || ('Episode ' + eNum)) + '</div>' +
            '<div class="cw-progress-track">' +
              '<div class="cw-progress-fill" style="width:' + pct + '%;"></div>' +
            '</div>' +
          '</div>';

        if (!item.isAdvanced && dur <= 100 && item.seriesId && _activeAccount && window.TVApi) {
          window.TVApi.getSeriesInfo(_activeAccount, item.seriesId).then(function(sInfo) {
            if (!sInfo || !sInfo.episodes) return;
            var allEps = [];
            Object.keys(sInfo.episodes).forEach(function(sk) {
              allEps = allEps.concat(window.normalizeEpisodeList(sInfo.episodes[sk]));
            });
            var matched = allEps.find(function(e) { return String(e.id || e.stream_id) === String(item.streamId); });
            if (matched) {
              var epDur = (window.extractDurationFromInfo ? window.extractDurationFromInfo(matched) : 0) || parseDurationSecs((matched.info && (matched.info.duration_secs || matched.info.duration || matched.info.runtime)) || (matched.duration_secs || matched.duration) || 0);
              if (epDur > 100) {
                item.duration = epDur;
                if (window.TVStorage && _activeAccount) {
                  window.TVStorage.saveProgress(_activeAccount.id, item);
                }
                var sFill = card.querySelector('.cw-progress-fill');
                if (sFill) {
                  var newPct = Math.min(99, Math.max(0, Math.round((item.position / epDur) * 100)));
                  sFill.style.width = newPct + '%';
                }
              }
            }
          }).catch(function(){});

          if (window.TVContainerProber) {
            var sExt = item.containerExtension || 'mp4';
            var sUrl = window.TVApi.getSeriesStreamUrl(_activeAccount, item.streamId, sExt);
            window.TVContainerProber.probeStream(sUrl).then(function(demuxed) {
              if (demuxed && demuxed.duration > 100) {
                item.duration = demuxed.duration;
                if (window.TVStorage && _activeAccount) {
                  window.TVStorage.saveProgress(_activeAccount.id, item);
                }
                var sFill = card.querySelector('.cw-progress-fill');
                if (sFill) {
                  var newPct = Math.min(99, Math.max(0, Math.round((item.position / demuxed.duration) * 100)));
                  sFill.style.width = newPct + '%';
                }
              }
            }).catch(function(){});
          }
        }

        var removeBtn = card.querySelector('.cw-remove-btn');
        if (removeBtn) {
          removeBtn.onclick = function(e) {
            if (e && e.stopPropagation) e.stopPropagation();
            if (window.TVStorage && _activeAccount) {
              window.TVStorage.deleteProgress(_activeAccount.id, item.streamId);
            }
            var nextFocus = card.nextElementSibling || card.previousElementSibling;
            if (!nextFocus) {
              nextFocus = document.querySelector('#series-grid-container .poster-card') || document.getElementById('series-search-input');
            }
            if (window.SpatialNav) {
              var isFocused = card.classList.contains('focused') || (removeBtn && removeBtn.classList.contains('focused')) || (document.activeElement === card || document.activeElement === removeBtn);
              if (isFocused && nextFocus) {
                window.SpatialNav.setFocus(nextFocus);
              }
            }
            card.style.transition = 'all 0.2s ease-out';
            card.style.opacity = '0';
            card.style.transform = 'scale(0.8)';
            setTimeout(function() {
              card.remove();
              if (sRail.children.length === 0) {
                sSection.style.display = 'none';
              }
            }, 200);
            showToast(window.TVI18n ? window.TVI18n.t('removed') || 'Removed from Continue Watching' : 'Removed', 'trash');
          };
        }

        card.onclick = function() {
          _lastMediaSourceCard = { type: 'series', streamId: item.streamId, seriesId: item.seriesId };
          var seriesId = item.seriesId;
          var fullSeries = (_seriesList || []).find(function(s) { return String(s.series_id) === String(seriesId); });
          var targetObj = fullSeries || {
            series_id: seriesId,
            name: item.seriesName || item.title,
            cover: item.posterUrl
          };

          var sItemDur = parseDurationSecs(item.duration);
          if (item.position >= 3 && !item.isCompleted && (sItemDur <= 30 || (item.position / sItemDur) < 0.95)) {
            openResumePlaybackModal(item, 'series', item.position, sItemDur, function(chosenPos) {
              var epObj = {
                id: item.streamId,
                stream_id: item.streamId,
                name: item.title,
                title: item.title,
                container_extension: item.containerExtension || 'mp4'
              };
              var meta = {
                streamId: item.streamId,
                seriesId: item.seriesId,
                type: 'series',
                title: item.title,
                seriesName: item.seriesName,
                season: item.season || 1,
                episode: item.episode || 1,
                posterUrl: item.posterUrl || '',
                containerExtension: item.containerExtension || 'mp4',
                duration: sItemDur,
                startPosition: chosenPos,
                audioTracks: item.audioTracks || [],
                subtitleTracks: item.subtitleTracks || []
              };
              _player.playVod(epObj, 'series', item.seriesName || item.title, item.title, function() { playNextEpisodeForCurrentSeries(); }, meta);
            });
          } else {
            openSeriesDetail(targetObj, String(sNum), eNum);
          }
        };

        sRail.appendChild(card);
      });
    }
  }

  function renderMovieGrid(alreadyFiltered) {
    var gridEl = document.getElementById('movies-grid-container');
    var countBadge = document.getElementById('movies-count-badge');
    if (!gridEl) return;
    gridEl.innerHTML = '';
    gridEl.scrollTop = 0;
    _movieLoadedCount = 0;

    renderContinueWatching('movie');

    if (!alreadyFiltered) {
      var filtered = _movieStreams || [];
      if (_movieSearchQuery) {
        filtered = filtered.filter(function(m) {
          return (m.name || '').toLowerCase().indexOf(_movieSearchQuery) >= 0;
        });
      }
      _movieFilteredList = filtered;
    }

    if (countBadge) countBadge.textContent = _movieFilteredList.length + ' ' + (window.TVI18n ? window.TVI18n.t('unit_movies') : 'Movies');

    if (_movieFilteredList.length === 0) {
      var isWatchlist = _selectedMovieCategory && _selectedMovieCategory.category_id === 'favorites';
      gridEl.innerHTML = getEmptyVodStateHtml('movies', isWatchlist);
      return;
    }

    // Attach scroll listener once
    if (!gridEl._hasScrollListener) {
      gridEl._hasScrollListener = true;
      gridEl.addEventListener('scroll', function() {
        if (!_isLoadingMovieBatch && gridEl.scrollTop + gridEl.clientHeight >= gridEl.scrollHeight - 350) {
          loadNextMovieBatch();
        }
      });
    }

    _isLoadingMovieBatch = false;
    loadNextMovieBatch();
  }

  var _isLoadingMovieBatch = false;

  function loadNextMovieBatch() {
    var gridEl = document.getElementById('movies-grid-container');
    if (!gridEl || _isLoadingMovieBatch || _movieLoadedCount >= _movieFilteredList.length) return;
    _isLoadingMovieBatch = true;

    var start = _movieLoadedCount;
    var end = Math.min(_movieFilteredList.length, start + _movieBatchSize);
    var frag = document.createDocumentFragment();

    for (var i = start; i < end; i++) {
      var movie = _movieFilteredList[i];
      var card = document.createElement('div');
      card.className = 'poster-card focusable';
      card.setAttribute('data-movie-idx', i);
      if (movie.stream_id) card.setAttribute('data-stream-id', movie.stream_id);
      var posterUrl = sanitizeImgUrl(movie.stream_icon || '');
      var parsedRating = movie.rating ? parseFloat(movie.rating) : NaN;
      var rating = !isNaN(parsedRating) ? parsedRating.toFixed(1) : null;
      var movieName = (movie.name || 'Movie').replace(/^[0-9]+\.\s*/, '');

      var filmFallbackSvg = (window.TVIcons && window.TVIcons.film) ? window.TVIcons.film : '';
      var starSvg = (window.TVIcons && window.TVIcons.starFilled) ? window.TVIcons.starFilled : '★';

      card.innerHTML = 
        '<div class="poster-card-fallback">' + filmFallbackSvg + '</div>' +
        (posterUrl ? '<img class="poster-card-img" loading="lazy" decoding="async" src="' + posterUrl + '" onerror="this.style.display=\'none\'" />' : '') +
        '<div class="poster-card-gradient"></div>' +
        (rating ? '<span class="poster-rating-badge">' + starSvg + ' ' + rating + '</span>' : '') +
        '<div class="poster-card-title">' + escapeHtml(movieName) + '</div>';

      (function(m, idx) {
        card.onclick = function() {
          openMovieDetail(m);
        };
        card._onFocus = function() {
          if (idx >= _movieLoadedCount - 12) {
            loadNextMovieBatch();
          }
        };
      })(movie, i);

      frag.appendChild(card);
    }

    gridEl.appendChild(frag);
    _movieLoadedCount = end;
    _isLoadingMovieBatch = false;
  }

  function openMovieDetail(movie) {
    _lastMediaSourceCard = { type: 'movie', streamId: movie.stream_id || movie.id };
    var modal = document.getElementById('modal-movie-detail');
    var posterEl = document.getElementById('movie-detail-poster');
    var titleEl = document.getElementById('movie-detail-title');
    var yearEl = document.getElementById('movie-detail-year');
    var ratingEl = document.getElementById('movie-detail-rating');
    var plotEl = document.getElementById('movie-detail-plot');
    var playBtn = document.getElementById('movie-play-btn');
    var favBtn = document.getElementById('movie-fav-btn');

    var durEl = document.getElementById('movie-detail-duration');
    if (durEl) durEl.textContent = '';
    if (posterEl) posterEl.src = sanitizeRawUrl(movie.stream_icon) || 'assets/logo.png';
    if (titleEl) titleEl.textContent = movie.name || 'Movie';
    if (yearEl) yearEl.textContent = movie.year || 'VOD';
    var starFilledSvg = (window.TVIcons && window.TVIcons.starFilled) ? window.TVIcons.starFilled : '★';
    var starOutlineSvg = (window.TVIcons && window.TVIcons.starOutline) ? window.TVIcons.starOutline : '☆';
    if (ratingEl) ratingEl.innerHTML = movie.rating ? starFilledSvg + ' ' + parseFloat(movie.rating).toFixed(1) : starFilledSvg + ' N/A';
    if (plotEl) plotEl.textContent = window.TVI18n ? window.TVI18n.t('loading_movie_details') : 'Loading movie details...';

    var _currentVodInfo = null;
    var targetMovieId = movie.stream_id || movie.id;
    var extInit = movie.container_extension || 'mp4';
    var streamUrl = (_activeAccount && window.TVApi) ? window.TVApi.getVodStreamUrl(_activeAccount, targetMovieId, extInit) : '';
    var _probedTracks = (streamUrl && window.TVContainerProber) ? window.TVContainerProber.getCachedTracks(streamUrl) : null;
    if (streamUrl && window.TVContainerProber && !_probedTracks) {
      window.TVContainerProber.probeStream(streamUrl).then(function(demuxed) {
        if (demuxed) _probedTracks = demuxed;
      }).catch(function(){});
    }

    // Fetch full VOD info
    var _currentVodInfoPromise = window.TVApi.getVodInfo(_activeAccount, targetMovieId)
      .then(function(info) {
        _currentVodInfo = info;
        if (info && info.info) {
          if (plotEl) plotEl.textContent = info.info.plot || info.info.description || (window.TVI18n ? window.TVI18n.t('no_description') : 'No description available.');
          if (info.info.genre) {
            var genreEl = document.getElementById('movie-detail-genre');
            if (genreEl) genreEl.textContent = info.info.genre;
          }
          var rawDur = (window.extractDurationFromInfo ? window.extractDurationFromInfo(info) : 0) || info.info.duration_secs || info.info.duration || (info.movie_data && (info.movie_data.duration_secs || info.movie_data.duration));
          if (durEl && rawDur) {
            durEl.textContent = formatRuntime(rawDur);
          }
        }
        if (info && info.movie_data && info.movie_data.container_extension && info.movie_data.container_extension !== extInit) {
          var realExt = info.movie_data.container_extension;
          var realUrl = (_activeAccount && window.TVApi) ? window.TVApi.getVodStreamUrl(_activeAccount, targetMovieId, realExt) : '';
          if (realUrl && window.TVContainerProber) {
            window.TVContainerProber.probeStream(realUrl).then(function(demuxed) {
              if (demuxed) _probedTracks = demuxed;
            }).catch(function(){});
          }
        }
        return info;
      })
      .catch(function() {
        if (plotEl) plotEl.textContent = window.TVI18n ? window.TVI18n.t('no_description') : 'No detailed plot available.';
        return null;
      });

    if (playBtn) {
      playBtn.onclick = function() {
        var sId = movie.stream_id || movie.id;
        var savedProg = (_activeAccount && window.TVStorage) ? window.TVStorage.getProgress(_activeAccount.id, sId) : null;
        var mDur = (savedProg && savedProg.duration > 100) ? parseDurationSecs(savedProg.duration) : ((window.extractDurationFromInfo ? window.extractDurationFromInfo(_currentVodInfo) : 0) || (window.extractDurationFromInfo ? window.extractDurationFromInfo(movie) : 0) || parseDurationSecs((movie && (movie.duration_secs || movie.duration)) || (_currentVodInfo && _currentVodInfo.info && (_currentVodInfo.info.duration_secs || _currentVodInfo.info.duration)) || (_currentVodInfo && _currentVodInfo.movie_data && (_currentVodInfo.movie_data.duration_secs || _currentVodInfo.movie_data.duration)) || 0));
        var hasProgress = savedProg && savedProg.position >= 3 && !savedProg.isCompleted && (mDur <= 30 || (savedProg.position / mDur) < 0.95);

        function executePlay(startPos) {
          closeModal(modal);
          var audioMeta = [];
          var subMeta = [];
          if (_currentVodInfo) {
            audioMeta = extractAudioTracksFromInfo(_currentVodInfo);
            subMeta = extractSubtitleTracksFromInfo(_currentVodInfo);
          }
          if (_probedTracks) {
            if (_probedTracks.audios && _probedTracks.audios.length > audioMeta.length) {
              audioMeta = _probedTracks.audios;
            }
            if (_probedTracks.subs && _probedTracks.subs.length > subMeta.length) {
              subMeta = _probedTracks.subs;
            }
          }
          var ext = (_currentVodInfo && _currentVodInfo.movie_data && _currentVodInfo.movie_data.container_extension) || movie.container_extension || 'mp4';
          var meta = {
            streamId: sId,
            type: 'movie',
            title: movie.name || 'Movie',
            posterUrl: movie.stream_icon || '',
            containerExtension: ext,
            duration: mDur,
            startPosition: startPos,
            audioTracks: audioMeta,
            subtitleTracks: subMeta,
            imdbId: (_currentVodInfo && _currentVodInfo.info && (_currentVodInfo.info.imdb_id || _currentVodInfo.info.imdb)) || (movie && (movie.imdb_id || movie.imdb)) || '',
            kinopoisk_url: (_currentVodInfo && _currentVodInfo.info && _currentVodInfo.info.kinopoisk_url) || (movie && movie.kinopoisk_url) || '',
            tmdbId: (_currentVodInfo && _currentVodInfo.info && _currentVodInfo.info.tmdb_id) || (movie && movie.tmdb_id) || ''
          };
          _player.playVod(movie, 'vod', movie.name, '', null, meta);

          if (!_currentVodInfo && _currentVodInfoPromise) {
            _currentVodInfoPromise.then(function(info) {
              if (info && _player && _player.currentVodMeta && String(_player.currentVodMeta.streamId) === String(sId)) {
                if (info.info) {
                  if (info.info.imdb_id || info.info.imdb) _player.currentVodMeta.imdbId = info.info.imdb_id || info.info.imdb;
                  if (info.info.kinopoisk_url) _player.currentVodMeta.kinopoisk_url = info.info.kinopoisk_url;
                  if (info.info.tmdb_id) _player.currentVodMeta.tmdbId = info.info.tmdb_id;
                }
                var rawInfoDur = (window.extractDurationFromInfo ? window.extractDurationFromInfo(info) : 0) || (info.info && (info.info.duration_secs || info.info.duration)) || (info.movie_data && (info.movie_data.duration_secs || info.movie_data.duration));
                var infoDur = parseDurationSecs(rawInfoDur);
                if (infoDur > 100 && (!_player.currentVodMeta.duration || _player.currentVodMeta.duration <= 100)) {
                  _player.currentVodMeta.duration = infoDur;
                  _player._updateVodDuration();
                }
                var aTracks = extractAudioTracksFromInfo(info);
                var sTracks = extractSubtitleTracksFromInfo(info);
                if (aTracks.length > 0 && (!_player.currentVodMeta.audioTracks || aTracks.length > _player.currentVodMeta.audioTracks.length)) {
                  _player.currentVodMeta.audioTracks = aTracks;
                }
                if (sTracks.length > 0 && (!_player.currentVodMeta.subtitleTracks || sTracks.length > _player.currentVodMeta.subtitleTracks.length)) {
                  _player.currentVodMeta.subtitleTracks = sTracks;
                }
                if (_player._applyPreferences) _player._applyPreferences();
                if (window.onTracksUpdated) window.onTracksUpdated();
              }
            });
          }
        }

        if (hasProgress) {
          openResumePlaybackModal(movie, 'movie', savedProg.position, mDur, function(chosenPos) {
            executePlay(chosenPos);
          });
        } else {
          executePlay(0);
        }
      };
    }

    if (favBtn) {
      var isFav = window.TVStorage.isFavorite(_activeAccount.id, movie.stream_id, 'movie');
      var starFilledSvg = (window.TVIcons && window.TVIcons.starFilled) ? window.TVIcons.starFilled : '★';
      var starOutlineSvg = (window.TVIcons && window.TVIcons.starOutline) ? window.TVIcons.starOutline : '☆';
      var icon = isFav ? starFilledSvg : starOutlineSvg;
      var rawTxt = isFav ? (window.TVI18n ? window.TVI18n.t('in_watchlist') : 'In Watchlist') : (window.TVI18n ? window.TVI18n.t('watchlist') : 'Watchlist');
      var txt = rawTxt.replace(/^[★☆\s]+/, '');
      favBtn.innerHTML = '<span class="btn-icon">' + icon + '</span> <span>' + escapeHtml(txt) + '</span>';
      favBtn.onclick = function() {
        var newFav = _saveFavoriteWithSnapshot(_activeAccount.id, movie.stream_id, 'movie', movie);
        var nIcon = newFav ? starFilledSvg : starOutlineSvg;
        var nRawTxt = newFav ? (window.TVI18n ? window.TVI18n.t('in_watchlist') : 'In Watchlist') : (window.TVI18n ? window.TVI18n.t('watchlist') : 'Watchlist');
        var nTxt = nRawTxt.replace(/^[★☆\s]+/, '');
        favBtn.innerHTML = '<span class="btn-icon">' + nIcon + '</span> <span>' + escapeHtml(nTxt) + '</span>';
        var cleanName = (movie.name || 'Movie').replace(/^[0-9]+\.\s*/, '');
        var toastText = newFav ? (window.TVI18n && window.TVI18n.getLanguage() === 'de' ? 'Zur Watchlist hinzugefügt' : 'Added to Watchlist') : (window.TVI18n && window.TVI18n.getLanguage() === 'de' ? 'Aus Watchlist entfernt' : 'Removed from Watchlist');
        showToast(cleanName + ': ' + toastText, newFav ? 'star' : 'trash');

        // Immediately update Watchlist category if currently viewing it
        if (_selectedMovieCategory && _selectedMovieCategory.category_id === 'favorites') {
          if (!newFav) {
            _movieStreams = (_movieStreams || []).filter(function(m) {
              return String(m.stream_id) !== String(movie.stream_id);
            });
            _movieFilteredList = (_movieFilteredList || []).filter(function(m) {
              return String(m.stream_id) !== String(movie.stream_id);
            });
          } else {
            var exists = (_movieStreams || []).some(function(m) { return String(m.stream_id) === String(movie.stream_id); });
            if (!exists) {
              _movieStreams = _movieStreams || [];
              _movieFilteredList = _movieFilteredList || [];
              _movieStreams.unshift(movie);
              _movieFilteredList.unshift(movie);
            }
          }
          renderMovieGrid(true);
        }
      };
    }

    openModal(modal, playBtn);
  }

  // =========================================================
  // 5. TAB 3: SERIES
  // =========================================================
  function loadSeries(isPreload) {
    if (!_activeAccount || _activeAccount.syncSeries === false) {
      onSplashSeriesLoaded();
      return;
    }
    var listEl = document.getElementById('series-categories-list');

    if (_seriesCategories && _seriesCategories.length > 0) {
      if (!isPreload && _currentTab === 'series') {
        var activeCat = listEl ? (listEl.querySelector('.category-item.active') || listEl.querySelector('.category-item')) : null;
        if (activeCat && window.SpatialNav) window.SpatialNav.setFocus(activeCat);
      }
      return;
    }

    if (listEl) listEl.innerHTML = '<div class="col-placeholder" data-i18n="loading_categories">' + (window.TVI18n ? window.TVI18n.t('loading_categories') : 'Loading categories...') + '</div>';

    window.TVApi.getSeriesCategories(_activeAccount)
      .then(function(cats) {
        _seriesCategories = cats;
        if (_activeAccount) recordSyncTime(_activeAccount.id, 'series', Date.now(), false);
        markCategoriesDirty('series');
        if (!cats || cats.length === 0) {
          var noCatsText = (window.TVI18n && window.TVI18n.getLanguage() === 'de')
            ? 'Keine Serienkategorien gefunden.'
            : 'No series categories found.';
          if (listEl) listEl.innerHTML = '<div class="col-placeholder" style="color:var(--text-dim); padding: 24px;">' + noCatsText + '</div>';
          onSplashSeriesLoaded();
          return;
        }
        renderSeriesCategories(cats, false, null, isPreload);
        onSplashSeriesLoaded();
      })
      .catch(function() {
        var failText = (window.TVI18n && window.TVI18n.getLanguage() === 'de')
          ? 'Serienkategorien konnten nicht geladen werden.'
          : (window.TVI18n ? window.TVI18n.t('failed_load_categories') : 'Failed to load categories.');
        if (listEl) listEl.innerHTML = '<div class="col-placeholder" style="color:#EF4444; padding: 24px;">' + failText + '</div>';
        onSplashSeriesLoaded();
      });
  }

  var _seriesLoadedCount = 0;
  var _seriesBatchSize = 30;

  function renderSeriesCategories(cats, keepFocusOnSearch, activeCategoryId, isPreload) {
    var listEl = document.getElementById('series-categories-list');
    if (!listEl) return;

    var rawCats = cats || [];
    var customLists = (_activeAccount && window.TVStorage) ? window.TVStorage.getCustomLists(_activeAccount.id, 'series') : [];
    var watchText = window.TVI18n ? window.TVI18n.t('watchlist') : 'Watchlist';
    var starIcon = (window.TVIcons && window.TVIcons.starFilled) ? window.TVIcons.starFilled : (window.TVIcons ? window.TVIcons.star : '★');
    var seriesIcon = (window.TVIcons && window.TVIcons.series) ? window.TVIcons.series : '';
    var playlistIcon = (window.TVIcons && window.TVIcons.playlist) ? window.TVIcons.playlist : '';

    var favCat = { category_id: 'favorites', category_name: watchText, isFav: true };
    var customCats = customLists.map(function(cl) {
      return { category_id: 'custom_list:' + cl.id, category_name: cl.name, isCustom: true, customList: cl };
    });
    var allCats = [favCat].concat(customCats).concat(rawCats);
    var prefs = (_activeAccount && window.TVStorage) ? window.TVStorage.getCategoryPrefs(_activeAccount.id, 'series') : { order: [], hidden: [], newIds: [] };

    // Fast O(1) lookups
    var orderSet = {};
    (prefs.order || []).forEach(function(id) { orderSet[id] = true; });
    var hiddenSet = {};
    (prefs.hidden || []).forEach(function(id) { hiddenSet[id] = true; });

    // Order categories according to prefs.order
    var catMap = {};
    allCats.forEach(function(c) {
      var id = String(c.category_id || c.categoryId);
      catMap[id] = c;
    });

    var orderedList = [];
    var favIdx = prefs.order.indexOf('favorites');
    if (favIdx === -1) {
      if (catMap['favorites']) orderedList.push(catMap['favorites']);
    } else if (favIdx === prefs.order.length - 1 && prefs.order.length > 1 && !prefs.hasManualSort) {
      if (catMap['favorites']) orderedList.push(catMap['favorites']);
    }

    prefs.order.forEach(function(id) {
      if (id === 'favorites' && orderedList.length > 0 && orderedList[0].category_id === 'favorites') return;
      if (catMap[id]) orderedList.push(catMap[id]);
    });
    allCats.forEach(function(c) {
      var id = String(c.category_id || c.categoryId);
      if (id === 'favorites' && orderedList.length > 0 && orderedList[0].category_id === 'favorites') return;
      if (!orderSet[id]) orderedList.push(c);
    });

    // Filter hidden categories
    var visibleList = orderedList.filter(function(c) {
      var id = String(c.category_id || c.categoryId);
      return !hiddenSet[id];
    });

    var sListBadgeTxt = escapeHtml((window.TVI18n && window.TVI18n.t('badge_list')) || 'LIST');
    var sNewBadgeTxt = escapeHtml((window.TVI18n && window.TVI18n.t('badge_new')) || 'NEW');
    var newSet = {};
    (prefs.newIds || []).forEach(function(nid) { newSet[nid] = true; });

    var targetEl = renderCategoryBatchList(listEl, visibleList, activeCategoryId, function(cat) {
      var catId = String(cat.category_id || cat.categoryId);
      var isCatActive = (activeCategoryId && String(activeCategoryId) === catId);
      var el = document.createElement('div');
      el.className = 'category-item focusable' + (isCatActive ? ' active' : '');
      el.setAttribute('data-category-id', catId);

      if (cat.isFav) {
        el.innerHTML =
          '<div class="category-left">' +
            '<span class="category-icon" style="color:var(--accent-gold);">' + starIcon + '</span>' +
            '<span class="category-name-text">' + watchText + '</span>' +
          '</div>';
        el.onclick = function() { selectSeriesCategory({ category_id: 'favorites', category_name: watchText }, el); };
      } else if (cat.isCustom) {
        el.innerHTML =
          '<div class="category-left">' +
            '<span class="category-icon" style="color:#B388FF;">' + playlistIcon + '</span>' +
            '<span class="category-name-text" style="color:#C4B5FD; font-weight:600;">' + escapeHtml(cat.category_name) + '</span>' +
            '<span class="badge-cat-list">' + sListBadgeTxt + '</span>' +
          '</div>';
        el.onclick = function() { selectSeriesCustomList(cat.customList, el); };
      } else {
        var isNew = !!newSet[catId];
        var badgeHtml = isNew ? '<span class="badge-cat-new">' + sNewBadgeTxt + '</span>' : '';
        el.innerHTML =
          '<div class="category-left">' +
            '<span class="category-icon">' + seriesIcon + '</span>' +
            '<span class="category-name-text">' + escapeHtml(cat.category_name) + '</span>' +
            badgeHtml +
          '</div>';
        el.onclick = function() {
          if (isNew && _activeAccount && window.TVStorage) {
            window.TVStorage.markCategoryViewed(_activeAccount.id, 'series', cat.category_id);
            newSet[catId] = false;
            var b = el.querySelector('.badge-cat-new');
            if (b) b.remove();
          }
          selectSeriesCategory(cat, el);
        };
      }
      return el;
    });
    if (cats === _seriesCategories) {
      _catsDirty.series = false;
      _catsDirty.accountId = _activeAccount ? _activeAccount.id : null;
    }

    var catSearchInput = document.getElementById('series-cat-search');
    var isSearchFocused = (document.activeElement === catSearchInput) ||
                          (window.SpatialNav && window.SpatialNav.getCurrent() === catSearchInput);

    if (!targetEl && listEl.firstElementChild) {
      targetEl = listEl.firstElementChild;
    }

    if (targetEl && !isPreload) {
      if (!isSearchFocused && !keepFocusOnSearch) {
        targetEl.click();
        if (!activeCategoryId) listEl.scrollTop = 0;
        if (_currentTab === 'series') {
          var cur = window.SpatialNav ? window.SpatialNav.getCurrent() : null;
          var isOnRail = cur && cur.classList.contains('nav-rail-btn');
          if (!isOnRail && window.SpatialNav) {
            window.SpatialNav.setFocus(targetEl);
          }
        }
      }
    }
  }

  function selectSeriesCustomList(cl, element) {
    if (!cl) return;
    _selectedSeriesCategory = { category_id: 'custom_list:' + cl.id, category_name: cl.name, isCustomList: true, customListId: cl.id };

    var serSearch = document.getElementById('series-search-input');
    var serClearBtn = document.getElementById('series-search-clear-btn');
    if (serSearch) { serSearch.value = ''; _seriesSearchQuery = ''; }
    if (serClearBtn) serClearBtn.style.display = 'none';

    var gridEl = document.getElementById('series-grid-container');
    if (gridEl) {
      gridEl.innerHTML = '';
      gridEl.scrollTop = 0;
    }

    setSingleActiveCategory('series-categories-list', element);

    var overlay = document.getElementById('series-loading-overlay');
    if (overlay) overlay.style.display = 'flex';

    // 0ms snapshot resolution before falling back to 'all'
    if (_activeAccount && window.TVStorage && typeof window.TVStorage.getCustomListStreamsResolved === 'function') {
      var resolved = window.TVStorage.getCustomListStreamsResolved(_activeAccount.id, 'series', cl.id);
      if (resolved !== null) {
        if (overlay) overlay.style.display = 'none';
        _seriesList = _sortSeriesList(resolved, _seriesSortMode);
        renderSeriesGrid();
        return;
      }
    }

    var items = (_activeAccount && window.TVStorage) ? window.TVStorage.getCustomListItems(_activeAccount.id, cl.id) : [];
    if (_allAccountSeriesStreams && _allAccountSeriesStreams.length > 0) {
      if (overlay) overlay.style.display = 'none';
      var itemMap = {};
      items.forEach(function(it) { itemMap[String(it.streamId)] = it; });
      var matches = _allAccountSeriesStreams.filter(function(s) { return !!itemMap[String(s.series_id)]; });
      if (matches.length < items.length) {
        var existingIds = matches.map(function(s) { return String(s.series_id); });
        items.forEach(function(it) {
          if (existingIds.indexOf(String(it.streamId)) === -1 && it.streamName) {
            var found = _allAccountSeriesStreams.find(function(s) { return (s.name || '').trim().toLowerCase() === it.streamName.trim().toLowerCase(); });
            if (found && existingIds.indexOf(String(found.series_id)) === -1) {
              matches.push(found);
              existingIds.push(String(found.series_id));
            }
          }
        });
      }
      if (_activeAccount) _backfillSnapshots(_activeAccount.id, 'series', matches);
      _seriesList = _sortSeriesList(matches, _seriesSortMode);
      renderSeriesGrid();
      return;
    }

    ensureMasterTabData('series').then(function(all) {
      if (overlay) overlay.style.display = 'none';
      var itemMap = {};
      items.forEach(function(it) { itemMap[String(it.streamId)] = it; });
      var matches = (all || []).filter(function(s) { return !!itemMap[String(s.series_id)]; });
      if (_activeAccount) _backfillSnapshots(_activeAccount.id, 'series', matches);
      _seriesList = _sortSeriesList(matches, _seriesSortMode);
      renderSeriesGrid();
    }).catch(function() {
      if (overlay) overlay.style.display = 'none';
      _seriesList = [];
      renderSeriesGrid();
    });
  }

  function selectSeriesCategory(cat, element) {
    _selectedSeriesCategory = cat;

    var serSearch = document.getElementById('series-search-input');
    var serClearBtn = document.getElementById('series-search-clear-btn');
    if (serSearch) { serSearch.value = ''; _seriesSearchQuery = ''; }
    if (serClearBtn) serClearBtn.style.display = 'none';

    // Clear old posters immediately to release TV GPU memory
    var gridEl = document.getElementById('series-grid-container');
    if (gridEl) {
      gridEl.innerHTML = '';
      gridEl.scrollTop = 0;
    }

    setSingleActiveCategory('series-categories-list', element);

    fetchCategorySeries();
  }

  function fetchCategorySeries() {
    if (!_selectedSeriesCategory) return;
    var overlay = document.getElementById('series-loading-overlay');
    if (overlay) overlay.style.display = 'flex';

    if (_selectedSeriesCategory.category_id === 'favorites') {
      var favIds = window.TVStorage.getFavorites(_activeAccount.id, 'series');
      if (favIds.length === 0) {
        if (overlay) overlay.style.display = 'none';
        _seriesList = [];
        _seriesFilteredList = [];
        renderSeriesGrid(true);
        return;
      }
      // 0ms snapshot resolution before falling back to 'all'
      if (typeof window.TVStorage.getFavoriteStreamsResolved === 'function') {
        var resolvedFavs = window.TVStorage.getFavoriteStreamsResolved(_activeAccount.id, 'series');
        if (resolvedFavs !== null) {
          if (overlay) overlay.style.display = 'none';
          _seriesList = _sortSeriesList(resolvedFavs, _seriesSortMode);
          renderSeriesGrid();
          return;
        }
      }
      if (_allAccountSeriesStreams && _allAccountSeriesStreams.length > 0) {
        if (overlay) overlay.style.display = 'none';
        var favMatches = _allAccountSeriesStreams.filter(function(s) {
          return favIds.indexOf(String(s.series_id)) >= 0;
        });
        _backfillSnapshots(_activeAccount.id, 'series', favMatches);
        _seriesList = _sortSeriesList(favMatches, _seriesSortMode);
        renderSeriesGrid();
        return;
      }
      window.TVApi.getSeries(_activeAccount, 'all', _seriesSortMode)
        .then(function(all) {
          if (overlay) overlay.style.display = 'none';
          _allAccountSeriesStreams = all;
          var favMatches = all.filter(function(s) {
            return favIds.indexOf(String(s.series_id)) >= 0;
          });
          _backfillSnapshots(_activeAccount.id, 'series', favMatches);
          _seriesList = _sortSeriesList(favMatches, _seriesSortMode);
          renderSeriesGrid();
        })
        .catch(function() {
          if (overlay) overlay.style.display = 'none';
          _seriesList = [];
          renderSeriesGrid();
        });
    } else {
      window.TVApi.getSeries(_activeAccount, _selectedSeriesCategory.category_id, _seriesSortMode)
        .then(function(series) {
          if (overlay) overlay.style.display = 'none';
          _seriesList = series;
          renderSeriesGrid();
        })
        .catch(function() {
          if (overlay) overlay.style.display = 'none';
          _seriesList = [];
          renderSeriesGrid();
        });
    }
  }

  function renderSeriesGrid(alreadyFiltered) {
    var gridEl = document.getElementById('series-grid-container');
    var countBadge = document.getElementById('series-count-badge');
    if (!gridEl) return;
    gridEl.innerHTML = '';
    gridEl.scrollTop = 0;
    _seriesLoadedCount = 0;

    renderContinueWatching('series');

    if (!alreadyFiltered) {
      var filtered = _seriesList || [];
      if (_seriesSearchQuery) {
        filtered = filtered.filter(function(s) {
          return (s.name || '').toLowerCase().indexOf(_seriesSearchQuery) >= 0;
        });
      }
      _seriesFilteredList = filtered;
    }

    if (countBadge) countBadge.textContent = _seriesFilteredList.length + ' ' + (window.TVI18n ? window.TVI18n.t('unit_shows') : 'Shows');

    if (_seriesFilteredList.length === 0) {
      var isWatchlist = _selectedSeriesCategory && _selectedSeriesCategory.category_id === 'favorites';
      gridEl.innerHTML = getEmptyVodStateHtml('series', isWatchlist);
      return;
    }

    // Attach scroll listener once
    if (!gridEl._hasScrollListener) {
      gridEl._hasScrollListener = true;
      gridEl.addEventListener('scroll', function() {
        if (!_isLoadingSeriesBatch && gridEl.scrollTop + gridEl.clientHeight >= gridEl.scrollHeight - 350) {
          loadNextSeriesBatch();
        }
      });
    }

    _isLoadingSeriesBatch = false;
    loadNextSeriesBatch();
  }

  var _isLoadingSeriesBatch = false;

  function loadNextSeriesBatch() {
    var gridEl = document.getElementById('series-grid-container');
    if (!gridEl || _isLoadingSeriesBatch || _seriesLoadedCount >= _seriesFilteredList.length) return;
    _isLoadingSeriesBatch = true;

    var start = _seriesLoadedCount;
    var end = Math.min(_seriesFilteredList.length, start + _seriesBatchSize);
    var frag = document.createDocumentFragment();

    for (var i = start; i < end; i++) {
      var series = _seriesFilteredList[i];
      var card = document.createElement('div');
      card.className = 'poster-card focusable';
      card.setAttribute('data-series-idx', i);
      if (series.series_id) card.setAttribute('data-series-id', series.series_id);
      var posterUrl = sanitizeImgUrl(series.cover || '');
      var parsedRating = series.rating ? parseFloat(series.rating) : NaN;
      var rating = !isNaN(parsedRating) ? parsedRating.toFixed(1) : null;
      var seriesName = (series.name || 'Series').replace(/^[0-9]+\.\s*/, '');

      var seriesFallbackSvg = (window.TVIcons && window.TVIcons.series) ? window.TVIcons.series : '';
      var starSvg = (window.TVIcons && window.TVIcons.starFilled) ? window.TVIcons.starFilled : '★';

      card.innerHTML = 
        '<div class="poster-card-fallback">' + seriesFallbackSvg + '</div>' +
        (posterUrl ? '<img class="poster-card-img" loading="lazy" decoding="async" src="' + posterUrl + '" onerror="this.style.display=\'none\'" />' : '') +
        '<div class="poster-card-gradient"></div>' +
        (rating ? '<span class="poster-rating-badge">' + starSvg + ' ' + rating + '</span>' : '') +
        '<div class="poster-card-title">' + escapeHtml(seriesName) + '</div>';

      (function(s, idx) {
        card.onclick = function() {
          openSeriesDetail(s);
        };
        card._onFocus = function() {
          if (idx >= _seriesLoadedCount - 12) {
            loadNextSeriesBatch();
          }
        };
      })(series, i);

      frag.appendChild(card);
    }

    gridEl.appendChild(frag);
    _seriesLoadedCount = end;
    _isLoadingSeriesBatch = false;
  }

  function openSeriesDetail(series, targetSeason, targetEpisodeNum) {
    _lastMediaSourceCard = { type: 'series', seriesId: series.series_id || series.id };
    _currentSeriesData = series;
    var modal = document.getElementById('modal-series-detail');
    var posterEl = document.getElementById('series-detail-poster');
    var titleEl = document.getElementById('series-detail-title');
    var ratingEl = document.getElementById('series-detail-rating');
    var plotEl = document.getElementById('series-detail-plot');
    var tabsEl = document.getElementById('series-season-tabs');
    var epContainer = document.getElementById('series-episodes-container');

    // Auto-detect Continue Watching target season and episode if not explicitly passed
    var sId = series.series_id || series.id;
    if ((!targetSeason || !targetEpisodeNum) && window.TVStorage && _activeAccount) {
      var cwList = window.TVStorage.getContinueWatching(_activeAccount.id, 'series');
      var cwMatch = (cwList || []).find(function(item) {
        return String(item.seriesId) === String(sId);
      });
      if (cwMatch) {
        targetSeason = String(cwMatch.season || 1);
        targetEpisodeNum = cwMatch.episode || 1;
        console.log('[SeriesDetail] Autofocusing Continue Watching target: S' + targetSeason + ' E' + targetEpisodeNum);
      }
    }

    if (posterEl) posterEl.src = sanitizeRawUrl(series.cover) || 'assets/logo.png';
    if (titleEl) titleEl.textContent = series.name || 'Series';
    var starFilledSvg = (window.TVIcons && window.TVIcons.starFilled) ? window.TVIcons.starFilled : '★';
    var starOutlineSvg = (window.TVIcons && window.TVIcons.starOutline) ? window.TVIcons.starOutline : '☆';
    if (ratingEl) ratingEl.innerHTML = series.rating ? starFilledSvg + ' ' + parseFloat(series.rating).toFixed(1) : starFilledSvg + ' N/A';
    if (plotEl) plotEl.textContent = window.TVI18n ? window.TVI18n.t('loading_series_details') : 'Loading series details...';
    if (tabsEl) tabsEl.innerHTML = '';
    if (epContainer) epContainer.innerHTML = '<div class="col-placeholder">' + (window.TVI18n ? window.TVI18n.t('loading_seasons_episodes') : 'Loading seasons & episodes...') + '</div>';

    var favBtn = document.getElementById('series-fav-btn');
    if (favBtn) {
      var isFav = window.TVStorage.isFavorite(_activeAccount.id, series.series_id, 'series');
      var icon = isFav ? starFilledSvg : starOutlineSvg;
      var rawTxt = isFav ? (window.TVI18n ? window.TVI18n.t('in_watchlist') : 'In Watchlist') : (window.TVI18n ? window.TVI18n.t('watchlist') : 'Watchlist');
      var txt = rawTxt.replace(/^[★☆\s]+/, '');
      favBtn.innerHTML = '<span class="btn-icon">' + icon + '</span> <span>' + escapeHtml(txt) + '</span>';
      favBtn.onclick = function() {
        var newFav = _saveFavoriteWithSnapshot(_activeAccount.id, series.series_id, 'series', series);
        var nIcon = newFav ? starFilledSvg : starOutlineSvg;
        var nRawTxt = newFav ? (window.TVI18n ? window.TVI18n.t('in_watchlist') : 'In Watchlist') : (window.TVI18n ? window.TVI18n.t('watchlist') : 'Watchlist');
        var nTxt = nRawTxt.replace(/^[★☆\s]+/, '');
        favBtn.innerHTML = '<span class="btn-icon">' + nIcon + '</span> <span>' + escapeHtml(nTxt) + '</span>';
        var cleanName = (series.name || 'Series').replace(/^[0-9]+\.\s*/, '');
        var toastText = newFav ? (window.TVI18n && window.TVI18n.getLanguage() === 'de' ? 'Zur Watchlist hinzugefügt' : 'Added to Watchlist') : (window.TVI18n && window.TVI18n.getLanguage() === 'de' ? 'Aus Watchlist entfernt' : 'Removed from Watchlist');
        showToast(cleanName + ': ' + toastText, newFav ? 'star' : 'trash');

        // Immediately update Watchlist category if currently viewing it
        if (_selectedSeriesCategory && _selectedSeriesCategory.category_id === 'favorites') {
          if (!newFav) {
            _seriesList = (_seriesList || []).filter(function(s) {
              return String(s.series_id) !== String(series.series_id);
            });
            _seriesFilteredList = (_seriesFilteredList || []).filter(function(s) {
              return String(s.series_id) !== String(series.series_id);
            });
          } else {
            var exists = (_seriesList || []).some(function(s) { return String(s.series_id) === String(series.series_id); });
            if (!exists) {
              _seriesList = _seriesList || [];
              _seriesFilteredList = _seriesFilteredList || [];
              _seriesList.unshift(series);
              _seriesFilteredList.unshift(series);
            }
          }
          renderSeriesGrid(true);
        }
      };
    }

    openModal(modal, favBtn || document.getElementById('series-detail-close-btn'));

    window.TVApi.getSeriesInfo(_activeAccount, series.series_id)
      .then(function(data) {
        if (!data) {
          if (plotEl) plotEl.textContent = window.TVI18n ? window.TVI18n.t('failed_load_details') : 'Failed to load series details.';
          return;
        }
        data._seriesId = String(series.series_id);
        _currentSeriesDetails = data;
        window._currentSeriesDetails = data;
        if (data.info && plotEl) {
          plotEl.textContent = data.info.plot || (window.TVI18n ? window.TVI18n.t('no_description') : 'No plot available.');
        }

        var episodes = data.episodes || {};
        var seasonKeys = Object.keys(episodes);

        if (seasonKeys.length === 0) {
          if (epContainer) epContainer.innerHTML = '<div class="col-placeholder">' + (window.TVI18n ? window.TVI18n.t('no_episodes_available') : 'No episodes available.') + '</div>';
          return;
        }

        var selectedSeason = (targetSeason && episodes[targetSeason]) ? targetSeason : seasonKeys[0];

        // Render Season Tabs
        if (tabsEl) {
          tabsEl.innerHTML = '';
          seasonKeys.forEach(function(sKey) {
            var tabBtn = document.createElement('button');
            tabBtn.className = 'season-tab-btn focusable ' + (sKey === selectedSeason ? 'active' : '');
            tabBtn.textContent = (window.TVI18n ? window.TVI18n.t('season_prefix') : 'Season ') + sKey;
            tabBtn.onclick = function() {
              tabsEl.querySelectorAll('.season-tab-btn').forEach(function(b) { b.classList.remove('active'); });
              tabBtn.classList.add('active');
              _currentSeriesSeason = sKey;
              renderSeriesEpisodes(window.normalizeEpisodeList(episodes[sKey]), series.name);
            };
            tabsEl.appendChild(tabBtn);
          });
        }

        _currentSeriesSeason = selectedSeason;
        var selectedEps = window.normalizeEpisodeList(episodes[selectedSeason]);
        renderSeriesEpisodes(selectedEps, series.name);

        // Pre-probe first episode in background to ensure zero lag / no duplicate stream probing on play
        if (selectedEps.length > 0 && window.TVContainerProber && _activeAccount && window.TVApi) {
          var firstEp = (targetEpisodeNum ? selectedEps.find(function(e){ return String(e.episode_num) === String(targetEpisodeNum); }) : null) || selectedEps[0];
          if (firstEp) {
            var fExt = firstEp.container_extension || (data.info && data.info.container_extension) || series.container_extension || 'mp4';
            var fUrl = window.TVApi.getSeriesStreamUrl(_activeAccount, firstEp.id || firstEp.stream_id, fExt);
            window.TVContainerProber.probeStream(fUrl).catch(function(){});
          }
        }

        // Deep-linking: scroll to target episode, focus, and highlight
        if (targetEpisodeNum && epContainer) {
          setTimeout(function() {
            var targetCard = epContainer.querySelector('[data-episode-num="' + targetEpisodeNum + '"]');
            if (!targetCard) {
              var allCards = epContainer.querySelectorAll('.episode-card');
              for (var c = 0; c < allCards.length; c++) {
                var cNum = allCards[c].getAttribute('data-episode-num');
                if (cNum && parseInt(cNum, 10) === parseInt(targetEpisodeNum, 10)) {
                  targetCard = allCards[c];
                  break;
                }
              }
            }
            if (targetCard) {
              targetCard.scrollIntoView({ behavior: 'smooth', block: 'center' });
              if (window.SpatialNav) {
                window.SpatialNav.setFocus(targetCard);
              }
              targetCard.classList.add('deep-link-highlight');
              setTimeout(function() {
                targetCard.classList.remove('deep-link-highlight');
              }, 3600);
            }
          }, 250);
        }
      })
      .catch(function() {
        if (plotEl) plotEl.textContent = window.TVI18n ? window.TVI18n.t('failed_load_details') : 'Failed to load series details.';
      });
  }

  function renderSeriesEpisodes(episodes, seriesName) {
    var epContainer = document.getElementById('series-episodes-container');
    var drawerList = document.getElementById('drawer-series-list');
    if (!epContainer) return;
    epContainer.innerHTML = '';
    if (drawerList) drawerList.innerHTML = '';

    episodes = window.normalizeEpisodeList(episodes);

    if (!episodes || episodes.length === 0) {
      epContainer.innerHTML = '<div class="col-placeholder">' + (window.TVI18n ? window.TVI18n.t('no_episodes_for_season') : 'No episodes found for this season.') + '</div>';
      return;
    }

    var playLabel = window.TVI18n ? window.TVI18n.t('play_episode') : 'Play';
    var activeAcc = _activeAccount || (window.TVStorage ? window.TVStorage.getActiveAccount() : null);

    episodes.forEach(function(ep, epIdx) {
      var card = document.createElement('div');
      card.className = 'episode-card focusable';
      var epNum = ep.episode_num || (epIdx + 1);
      var epTitle = ep.title || ('Episode ' + epNum);
      var sNum = _currentSeriesSeason || '1';
      var sPill = 'S' + String(sNum).padStart(2, '0') + ' E' + String(epNum).padStart(2, '0');

      card.setAttribute('data-stream-id', ep.id || ep.stream_id);
      card.setAttribute('data-season', sNum);
      card.setAttribute('data-episode-num', epNum);

      // Check progress & completion status from TVStorage
      var epProg = (activeAcc && window.TVStorage) ? window.TVStorage.getProgress(activeAcc.id, ep.id || ep.stream_id) : null;
      var rawEpDur = (epProg && epProg.duration) || (ep.info && (ep.info.duration_secs || ep.info.duration)) || (ep.duration_secs || ep.duration) || 0;
      var epDur = parseDurationSecs(rawEpDur);
      var isComp = epProg && (epProg.isCompleted || (epDur > 30 && (epProg.position / epDur) >= 0.95));
      var progPct = (epProg && epDur > 30 && !isComp) ? Math.min(100, Math.round((epProg.position / epDur) * 100)) : 0;

      var checkSvg = (window.TVIcons && window.TVIcons.check) ? window.TVIcons.check : '✓';
      var playSvg = (window.TVIcons && window.TVIcons.play) ? window.TVIcons.play : '▶';

      var completedBadgeHtml = isComp ? '<span class="episode-completed-badge" title="Completed">' + checkSvg + '</span>' : '';
      var progressBarHtml = (!isComp && progPct > 0) ? '<div class="episode-progress-track"><div class="episode-progress-fill" style="width:' + progPct + '%;"></div></div>' : '';

      var epImg = sanitizeImgUrl((ep.info && (ep.info.movie_image || ep.info.cover)) || (_currentSeriesData && (_currentSeriesData.cover || _currentSeriesData.poster)) || '');
      var thumbHtml = 
        '<div class="episode-thumb-wrap">' +
          (epImg ? '<img class="episode-thumb-img" src="' + epImg + '" alt="" onerror="this.style.display=\'none\';" />' : '') +
          '<span class="episode-thumb-fallback">E' + escapeHtml(String(epNum).padStart(2, '0')) + '</span>' +
          '<span class="episode-thumb-play">' + playSvg + '</span>' +
        '</div>';

      card.innerHTML = 
        '<div class="episode-card-main">' +
          '<div class="episode-info">' +
            thumbHtml +
            '<div class="episode-text-col">' +
              '<span class="episode-title">' + escapeHtml(epTitle) + '</span>' +
              '<span class="episode-duration">' + escapeHtml(formatRuntime(ep.info && ep.info.duration)) + '</span>' +
            '</div>' +
          '</div>' +
          '<div class="episode-right-actions">' +
            completedBadgeHtml +
            '<button class="btn-primary" style="padding:8px 18px; font-size:18px; pointer-events:none; display:inline-flex; align-items:center;">' + playSvg + '<span style="margin-left:8px;">' + escapeHtml(playLabel) + '</span></button>' +
          '</div>' +
        '</div>' +
        progressBarHtml;

      function playThisEpisode() {
        var sId = ep.id || ep.stream_id;
        var activeAcc = _activeAccount || (window.TVStorage ? window.TVStorage.getActiveAccount() : null);
        var savedProg = (activeAcc && window.TVStorage) ? window.TVStorage.getProgress(activeAcc.id, sId) : null;
        var epDurForResume = parseDurationSecs((savedProg && savedProg.duration) || (ep.info && (ep.info.duration_secs || ep.info.duration)) || (ep.duration_secs || ep.duration) || 0);
        var hasProg = savedProg && savedProg.position >= 3 && !savedProg.isCompleted && (epDurForResume <= 30 || (savedProg.position / epDurForResume) < 0.95);

        function startPlayback(startPos) {
          closeModal(document.getElementById('modal-series-detail'));
          var drawer = document.getElementById('drawer-series-episodes');
          if (drawer) drawer.classList.remove('open');

          var isLastSeason = false;
          if (_currentSeriesDetails && _currentSeriesDetails.episodes) {
            var allSKeys = Object.keys(_currentSeriesDetails.episodes);
            isLastSeason = (String(sNum) === String(allSKeys[allSKeys.length - 1]));
          }

          var nextEpCand = (epIdx + 1 < episodes.length) ? episodes[epIdx + 1] : null;
          var nextSeasonCand = null;
          if (!nextEpCand && _currentSeriesDetails && _currentSeriesDetails.episodes) {
            var allSKeys = Object.keys(_currentSeriesDetails.episodes);
            var curSIdx = allSKeys.indexOf(String(sNum));
            if (curSIdx >= 0 && curSIdx + 1 < allSKeys.length) {
              var nextSKey = allSKeys[curSIdx + 1];
              var nextSEps = window.normalizeEpisodeList(_currentSeriesDetails.episodes[nextSKey]);
              if (nextSEps.length > 0) {
                nextEpCand = nextSEps[0];
                nextSeasonCand = nextSKey;
              }
            }
          }

          var nextTitleCand = nextEpCand ? (nextEpCand.title || ('Episode ' + (nextEpCand.episode_num || (epIdx + 2)))) : '';
          var nextIdCand = nextEpCand ? (nextEpCand.id || nextEpCand.stream_id) : null;

          var audioTracksMeta = extractAudioTracksFromInfo(ep);
          var subTracksMeta = extractSubtitleTracksFromInfo(ep);

          var epExt = ep.container_extension || (_currentSeriesData && _currentSeriesData.container_extension) || 'mp4';
          var epUrl = (activeAcc && window.TVApi) ? window.TVApi.getSeriesStreamUrl(activeAcc, sId, epExt) : '';
          var cachedProbed = (epUrl && window.TVContainerProber && window.TVContainerProber.getCachedTracks) ? window.TVContainerProber.getCachedTracks(epUrl) : null;
          if (cachedProbed) {
            if (cachedProbed.audios && cachedProbed.audios.length > audioTracksMeta.length) {
              audioTracksMeta = cachedProbed.audios;
            }
            if (cachedProbed.subs && cachedProbed.subs.length > subTracksMeta.length) {
              subTracksMeta = cachedProbed.subs;
            }
          }

          var meta = {
            streamId: sId,
            seriesId: (_currentSeriesData && (_currentSeriesData.series_id || _currentSeriesData.id)) || (_currentSeriesDetails && _currentSeriesDetails.info && _currentSeriesDetails.info.series_id),
            type: 'series',
            title: epTitle,
            nextEpisodeTitle: nextTitleCand,
            nextStreamId: nextIdCand,
            nextSeason: nextSeasonCand,
            nextEpisodeNum: nextEpCand ? (nextEpCand.episode_num || 1) : null,
            containerExtension: epExt,
            audioTracks: audioTracksMeta,
            subtitleTracks: subTracksMeta,
            seriesName: seriesName,
            season: parseInt(sNum, 10) || 1,
            episode: parseInt(epNum, 10) || (epIdx + 1),
            posterUrl: (_currentSeriesData && (_currentSeriesData.cover || _currentSeriesData.poster)) || '',
            isFinale: isLastSeason && (epIdx === episodes.length - 1),
            duration: epDurForResume,
            startPosition: startPos
          };

          _player.playVod(ep, 'series', seriesName, '[' + sPill + '] ' + epTitle, function() { playNextEpisodeForCurrentSeries(); }, meta);
        }

        if (hasProg) {
          openResumePlaybackModal(ep, 'series', savedProg.position, epDurForResume, function(chosenPos) {
            startPlayback(chosenPos);
          });
        } else {
          startPlayback(0);
        }
      }

      card.onclick = playThisEpisode;
      card._onFocus = function() {
        if (activeAcc && window.TVApi && window.TVContainerProber && (ep.id || ep.stream_id)) {
          var epExt = ep.container_extension || (_currentSeriesData && _currentSeriesData.container_extension) || 'mp4';
          var epUrl = window.TVApi.getSeriesStreamUrl(activeAcc, ep.id || ep.stream_id, epExt);
          window.TVContainerProber.probeStream(epUrl).catch(function(){});
        }
      };
      epContainer.appendChild(card);

      // Clone for in-player episode drawer
      if (drawerList) {
        var dCard = card.cloneNode(true);
        dCard.onclick = playThisEpisode;
        drawerList.appendChild(dCard);
      }
    });
  }

  // =========================================================
  // 6. HEADER CONTROLS (Master Search, Preferences, Languages)
  // =========================================================
  function setupHeaderButtons() {
    // Master Search Button
    var searchBtn = document.getElementById('header-search-btn');
    if (searchBtn) {
      searchBtn.onclick = function() {
        var modal = document.getElementById('modal-master-search');
        var mi = document.getElementById('master-search-input');
        var mcb = document.getElementById('master-search-clear-btn');

        // Always reset Master Search to Live TV tab upon open
        _searchTab = 'live';
        var tabLive = document.getElementById('search-tab-live');
        var tabMovies = document.getElementById('search-tab-movies');
        var tabSeries = document.getElementById('search-tab-series');
        if (tabLive) tabLive.classList.add('active');
        if (tabMovies) tabMovies.classList.remove('active');
        if (tabSeries) tabSeries.classList.remove('active');

        if (mcb && mi) {
          mcb.style.display = mi.value.length > 0 ? 'flex' : 'none';
        }

        openModal(modal, mi);

        // Lazily ensure active tab data for master search is loading or cached
        ensureMasterTabData(_searchTab);

        if (mi && mi.value.trim().length >= 2) {
          executeMasterSearch(mi.value.toLowerCase().trim());
        } else {
          executeMasterSearch('');
        }
      };
    }

    // Preferences Button
    var prefBtn = document.getElementById('header-pref-btn');
    if (prefBtn) {
      prefBtn.onclick = function() {
        var modal = document.getElementById('modal-preferences');
        var prefs = window.TVStorage.getPreferences();

        var audioPills = document.querySelectorAll('#pref-audio-group .pref-option-btn');
        audioPills.forEach(function(pill) {
          pill.classList.toggle('active', pill.getAttribute('data-val') === (prefs.audioLanguage || 'original'));
        });

        var subPills = document.querySelectorAll('#pref-sub-group .pref-option-btn');
        subPills.forEach(function(pill) {
          pill.classList.toggle('active', pill.getAttribute('data-val') === (prefs.subtitleLanguage || 'off'));
        });

        var activeAudio = document.querySelector('#pref-audio-group .pref-option-btn.active') ||
                         document.querySelector('#pref-audio-group .pref-option-btn');
        openModal(modal, activeAudio);
      };
    }

    // Preferences Button Group Click Handlers
    document.querySelectorAll('#pref-audio-group .pref-option-btn').forEach(function(btn) {
      btn.onclick = function() {
        document.querySelectorAll('#pref-audio-group .pref-option-btn').forEach(function(b) { b.classList.remove('active'); });
        btn.classList.add('active');
      };
    });

    document.querySelectorAll('#pref-sub-group .pref-option-btn').forEach(function(btn) {
      btn.onclick = function() {
        document.querySelectorAll('#pref-sub-group .pref-option-btn').forEach(function(b) { b.classList.remove('active'); });
        btn.classList.add('active');
      };
    });

    // Preferences Save
    var prefSaveBtn = document.getElementById('pref-save-btn');
    if (prefSaveBtn) {
      prefSaveBtn.onclick = function() {
        var activeAudio = document.querySelector('#pref-audio-group .pref-option-btn.active');
        var activeSub = document.querySelector('#pref-sub-group .pref-option-btn.active');
        var audioVal = activeAudio ? activeAudio.getAttribute('data-val') : 'original';
        var subVal = activeSub ? activeSub.getAttribute('data-val') : 'off';

        window.TVStorage.setPreference('audioLanguage', audioVal);
        window.TVStorage.setPreference('subtitleLanguage', subVal);
        closeModal(document.getElementById('modal-preferences'));
        showToast(window.TVI18n ? window.TVI18n.t('prefs_saved') : 'Preferences saved!', 'settings');
      };
    }

    // Language Switcher Button
    var langBtn = document.getElementById('header-lang-btn');
    if (langBtn) {
      langBtn.onclick = function() {
        var modal = document.getElementById('modal-language');
        var curLang = window.TVI18n ? window.TVI18n.getLanguage() : 'en';
        var optEn = document.getElementById('lang-opt-en');
        var optDe = document.getElementById('lang-opt-de');
        var checkEn = document.getElementById('check-en');
        var checkDe = document.getElementById('check-de');
        if (optEn) optEn.classList.toggle('selected', curLang === 'en');
        if (optDe) optDe.classList.toggle('selected', curLang === 'de');
        if (checkEn) {
          checkEn.classList.toggle('visible', curLang === 'en');
          checkEn.style.visibility = (curLang === 'en') ? 'visible' : 'hidden';
          checkEn.style.opacity = (curLang === 'en') ? '1' : '0';
        }
        if (checkDe) {
          checkDe.classList.toggle('visible', curLang === 'de');
          checkDe.style.visibility = (curLang === 'de') ? 'visible' : 'hidden';
          checkDe.style.opacity = (curLang === 'de') ? '1' : '0';
        }
        openModal(modal, (curLang === 'de') ? optDe : optEn);
      };
    }

    // Playlist & EPG Sync Modal (uses module-level persisted _syncModalTimes)

    function formatSyncClock(ts) {
      if (!ts) return '';
      var d = new Date(ts);
      var hh = String(d.getHours()).padStart(2, '0');
      var mm = String(d.getMinutes()).padStart(2, '0');
      return hh + ':' + mm;
    }

    function setSyncRowStatus(scope, state) {
      var el = document.getElementById('sync-status-' + scope);
      if (!el) return;
      var t = function(k, fb) { return (window.TVI18n && window.TVI18n.t) ? window.TVI18n.t(k) : fb; };
      if (state === 'syncing') {
        el.textContent = t('syncing', 'Syncing...');
        el.style.color = '#fbbf24';
      } else if (state === 'done') {
        var accId = _activeAccount ? String(_activeAccount.id) : '';
        var ts = (accId && _syncModalTimes[accId]) ? _syncModalTimes[accId][scope] : Date.now();
        el.textContent = t('sync_done', 'Synced') + ' (' + formatSyncClock(ts) + ')';
        el.style.color = '#34d399';
      } else if (state === 'failed') {
        el.textContent = t('sync_failed', 'Sync failed');
        el.style.color = '#f87171';
      } else if (state === 'cleared') {
        el.textContent = t('cache_cleared', 'Cache cleared');
        el.style.color = 'rgba(255,255,255,0.6)';
      } else {
        var idleAccId = _activeAccount ? String(_activeAccount.id) : '';
        var idleTs = (idleAccId && _syncModalTimes[idleAccId]) ? _syncModalTimes[idleAccId][scope] : null;
        if (idleTs) {
          el.textContent = t('last_synced', 'Cached') + ' (' + formatSyncClock(idleTs) + ')';
          el.style.color = '#34d399';
        } else {
          el.textContent = t('never_synced', 'Not cached yet');
          el.style.color = '';
        }
      }
    }

    function refreshSyncModalUi() {
      if (!_activeAccount) return;
      var isM3u = _activeAccount.type === 'm3u';
      var hasLive = _activeAccount.syncLiveTv !== false;
      var hasMovies = !isM3u && _activeAccount.syncMovies !== false;
      var hasSeries = !isM3u && _activeAccount.syncSeries !== false;

      var scopesSection = document.getElementById('sync-scopes-section');
      if (scopesSection) {
        scopesSection.style.display = isM3u ? 'none' : '';
      }

      var scopeDefs = [
        { id: 'sync-toggle-live', enabled: hasLive },
        { id: 'sync-toggle-movies', enabled: hasMovies },
        { id: 'sync-toggle-series', enabled: hasSeries }
      ];
      var visibleChips = [];
      scopeDefs.forEach(function(def) {
        var chip = document.getElementById(def.id);
        if (!chip) return;
        chip.classList.toggle('active', def.enabled);
        chip.disabled = isM3u;
        if (!isM3u) visibleChips.push(chip);
      });

      // Conditionally render sync rows strictly matching active scopes (mirrors Flutter)
      var rowSpecs = [
        { rowId: 'sync-row-live', btnId: 'sync-btn-live', visible: hasLive },
        { rowId: 'sync-row-movies', btnId: 'sync-btn-movies', visible: hasMovies },
        { rowId: 'sync-row-series', btnId: 'sync-btn-series', visible: hasSeries },
        { rowId: 'sync-row-epg', btnId: 'sync-btn-epg', visible: !isM3u && hasLive }
      ];
      var visibleRowBtns = [];
      rowSpecs.forEach(function(spec) {
        var rowEl = document.getElementById(spec.rowId);
        var btnEl = document.getElementById(spec.btnId);
        if (rowEl) rowEl.style.display = spec.visible ? '' : 'none';
        if (btnEl) {
          btnEl.disabled = !spec.visible;
          btnEl.style.opacity = '';
          if (spec.visible) visibleRowBtns.push(btnEl);
        }
      });

      // Dynamic D-Pad wiring across only visible elements
      var closeBtn = document.getElementById('sync-modal-close-btn');
      var clearBtn = document.getElementById('sync-btn-clear-cache');
      var allBtn = document.getElementById('sync-btn-all');
      var firstChip = visibleChips.length > 0 ? visibleChips[0] : null;
      var firstRowBtn = visibleRowBtns.length > 0 ? visibleRowBtns[0] : null;
      var lastRowBtn = visibleRowBtns.length > 0 ? visibleRowBtns[visibleRowBtns.length - 1] : null;

      if (closeBtn) {
        var closeDownTarget = firstChip || firstRowBtn || allBtn;
        if (closeDownTarget) closeBtn.setAttribute('data-nav-down', '#' + closeDownTarget.id);
      }

      for (var c = 0; c < visibleChips.length; c++) {
        var chipEl = visibleChips[c];
        chipEl.setAttribute('data-nav-up', '#sync-modal-close-btn');
        chipEl.setAttribute('data-nav-down', '#' + (firstRowBtn ? firstRowBtn.id : 'sync-btn-all'));
        if (c > 0) chipEl.setAttribute('data-nav-left', '#' + visibleChips[c - 1].id);
        else chipEl.removeAttribute('data-nav-left');
        if (c < visibleChips.length - 1) chipEl.setAttribute('data-nav-right', '#' + visibleChips[c + 1].id);
        else chipEl.removeAttribute('data-nav-right');
      }

      for (var r = 0; r < visibleRowBtns.length; r++) {
        var rBtn = visibleRowBtns[r];
        var upTarget = (r === 0) ? (firstChip ? firstChip.id : 'sync-modal-close-btn') : visibleRowBtns[r - 1].id;
        var downTarget = (r === visibleRowBtns.length - 1) ? 'sync-btn-all' : visibleRowBtns[r + 1].id;
        rBtn.setAttribute('data-nav-up', '#' + upTarget);
        rBtn.setAttribute('data-nav-down', '#' + downTarget);
        rBtn.removeAttribute('data-nav-left');
        rBtn.removeAttribute('data-nav-right');
      }

      var footerUpId = lastRowBtn ? lastRowBtn.id : (firstChip ? firstChip.id : 'sync-modal-close-btn');
      if (clearBtn) {
        clearBtn.setAttribute('data-nav-up', '#' + footerUpId);
        clearBtn.setAttribute('data-nav-right', '#sync-btn-all');
      }
      if (allBtn) {
        allBtn.setAttribute('data-nav-up', '#' + footerUpId);
        allBtn.setAttribute('data-nav-left', '#sync-btn-clear-cache');
      }

      ['live', 'movies', 'series', 'epg'].forEach(function(sc) {
        setSyncRowStatus(sc, 'idle');
      });

      // Hydrate missing cache timestamps from IndexedDB metadata so restarts keep accurate timestamps
      var hydAccId = String(_activeAccount.id);
      if (window.TVIdbCache && typeof window.TVIdbCache.get === 'function') {
        [
          { scope: 'live', key: hydAccId + '_live_cats' },
          { scope: 'movies', key: hydAccId + '_vod_cats' },
          { scope: 'series', key: hydAccId + '_series_cats' }
        ].forEach(function(entry) {
          if (_syncModalTimes[hydAccId] && _syncModalTimes[hydAccId][entry.scope]) return;
          window.TVIdbCache.get(entry.key).then(function(cached) {
            if (cached && cached.updatedAt && _activeAccount && String(_activeAccount.id) === hydAccId) {
              recordSyncTime(hydAccId, entry.scope, cached.updatedAt, false);
              setSyncRowStatus(entry.scope, 'idle');
            }
          }).catch(function() {});
        });
      }
    }

    function syncSingleScope(scope) {
      if (!_activeAccount || !window.TVApi) return Promise.resolve(false);
      var acc = _activeAccount;
      var accId = String(acc.id);
      if (!_syncModalTimes[accId]) _syncModalTimes[accId] = {};
      setSyncRowStatus(scope, 'syncing');

      var p;
      if (scope === 'live') {
        if (window.TVApi.clearCache) window.TVApi.clearCache(acc.id, 'live');
        markCategoriesDirty('live');
        _allAccountLiveStreams = null;
        p = window.TVApi.getLiveCategories(acc, { force: true }).then(function(cats) {
          _liveCategories = cats || [];
          if (acc.type === 'm3u') {
            return window.TVApi.getLiveStreams(acc, 'all', { force: true }).then(function(streams) {
              _allAccountLiveStreams = streams || [];
              if (_currentTab === 'live') loadLiveTv();
            });
          }
          if (_currentTab === 'live') loadLiveTv();
        });
      } else if (scope === 'movies') {
        if (acc.type === 'm3u') {
          _syncModalTimes[accId][scope] = Date.now();
          setSyncRowStatus(scope, 'done');
          return Promise.resolve(true);
        }
        if (window.TVApi.clearCache) window.TVApi.clearCache(acc.id, 'vod');
        markCategoriesDirty('movie');
        _allAccountMovies = null;
        p = window.TVApi.getVodCategories(acc, { force: true }).then(function(cats) {
          _movieCategories = cats || [];
          if (_currentTab === 'movies') loadMovies(false);
        });
      } else if (scope === 'series') {
        if (acc.type === 'm3u') {
          _syncModalTimes[accId][scope] = Date.now();
          setSyncRowStatus(scope, 'done');
          return Promise.resolve(true);
        }
        if (window.TVApi.clearCache) window.TVApi.clearCache(acc.id, 'series');
        markCategoriesDirty('series');
        _allAccountSeries = null;
        p = window.TVApi.getSeriesCategories(acc, { force: true }).then(function(cats) {
          _seriesCategories = cats || [];
          if (_currentTab === 'series') loadSeries(false);
        });
      } else if (scope === 'epg') {
        if (window.TVApi.clearCache) window.TVApi.clearCache(acc.id, 'epg');
        var targets = [];
        if (Array.isArray(_liveStreams) && _liveStreams.length > 0) {
          targets = _liveStreams.slice(0, 12);
        } else if (_player && _player.currentStream) {
          targets = [_player.currentStream];
        }
        if (targets.length === 0 || acc.type === 'm3u') {
          p = Promise.resolve();
        } else {
          var tIdx = 0;
          var runEpgWorker = function() {
            if (tIdx >= targets.length) return Promise.resolve();
            var st = targets[tIdx++];
            if (!st || !st.stream_id) return runEpgWorker();
            return window.TVApi.getShortEpg(acc, st.stream_id, { force: true }).then(function(listings) {
              updateDashboardRowEpgDom(st.stream_id, listings);
              return runEpgWorker();
            }, function() {
              return runEpgWorker();
            });
          };
          var eWorkers = [];
          for (var ew = 0; ew < 3; ew++) eWorkers.push(runEpgWorker());
          p = Promise.all(eWorkers).then(function() {
            if (_currentTab === 'live') scheduleDashboardVisibleEpgFetch();
          });
        }
      } else {
        p = Promise.resolve();
      }

      return p.then(function() {
        _syncModalTimes[accId][scope] = Date.now();
        saveSyncModalTimes();
        setSyncRowStatus(scope, 'done');
        return true;
      }, function(err) {
        console.warn('Sync failed for ' + scope + ':', err);
        setSyncRowStatus(scope, 'failed');
        return false;
      });
    }

    var syncHeaderBtn = document.getElementById('header-sync-btn');
    if (syncHeaderBtn) {
      syncHeaderBtn.onclick = function() {
        if (!_activeAccount) return;
        refreshSyncModalUi();
        var modal = document.getElementById('modal-playlist-sync');
        var focusTarget = document.getElementById('sync-btn-all') || document.getElementById('sync-toggle-live');
        openModal(modal, focusTarget);
      };
    }

    [
      { id: 'sync-toggle-live', key: 'syncLiveTv', cacheScope: 'live' },
      { id: 'sync-toggle-movies', key: 'syncMovies', cacheScope: 'vod' },
      { id: 'sync-toggle-series', key: 'syncSeries', cacheScope: 'series' }
    ].forEach(function(item) {
      var chip = document.getElementById(item.id);
      if (!chip) return;
      chip.onclick = function() {
        if (!_activeAccount || !window.TVStorage) return;
        if (_activeAccount.type === 'm3u' && item.key !== 'syncLiveTv') return;
        var curVal = _activeAccount[item.key] !== false;
        var nextVal = !curVal;
        if (!nextVal) {
          var liveOn = (item.key === 'syncLiveTv') ? false : (_activeAccount.syncLiveTv !== false);
          var movOn = (item.key === 'syncMovies') ? false : (_activeAccount.syncMovies !== false);
          var serOn = (item.key === 'syncSeries') ? false : (_activeAccount.syncSeries !== false);
          if (!liveOn && !movOn && !serOn) {
            var warnTxt = (window.TVI18n && window.TVI18n.getLanguage() === 'de')
              ? 'Mindestens ein Bereich muss aktiv bleiben'
              : 'At least one scope must stay enabled';
            showToast(warnTxt, 'alert');
            return;
          }
        }
        var patch = {};
        patch[item.key] = nextVal;
        if (typeof window.TVStorage.updateSyncScopes === 'function') {
          var updated = window.TVStorage.updateSyncScopes(_activeAccount.id, patch);
          if (updated) {
            _activeAccount.syncLiveTv = updated.syncLiveTv;
            _activeAccount.syncMovies = updated.syncMovies;
            _activeAccount.syncSeries = updated.syncSeries;
          } else {
            _activeAccount[item.key] = nextVal;
          }
        } else {
          _activeAccount[item.key] = nextVal;
        }
        if (!nextVal && window.TVApi && window.TVApi.clearCache) {
          window.TVApi.clearCache(_activeAccount.id, item.cacheScope);
        }
        markCategoriesDirty(item.key === 'syncMovies' ? 'movie' : (item.key === 'syncSeries' ? 'series' : 'live'));
        if (window.TVSync && window.TVSync.pushPlaylists) {
          window.TVSync.pushPlaylists();
        }
        updateNavRailScopes();
        renderAccountsList();
        refreshSyncModalUi();
      };
    });

    [
      { id: 'sync-btn-live', scope: 'live' },
      { id: 'sync-btn-movies', scope: 'movies' },
      { id: 'sync-btn-series', scope: 'series' },
      { id: 'sync-btn-epg', scope: 'epg' }
    ].forEach(function(item) {
      var btn = document.getElementById(item.id);
      if (!btn) return;
      btn.onclick = function() {
        if (!_activeAccount || btn.disabled) return;
        btn.disabled = true;
        syncSingleScope(item.scope).then(function(ok) {
          btn.disabled = (_activeAccount && _activeAccount.type === 'm3u' && item.scope !== 'live');
          if (ok) {
            showToast(window.TVI18n ? window.TVI18n.t('sync_done') : 'Synced', 'check');
          } else {
            showToast(window.TVI18n ? window.TVI18n.t('sync_failed') : 'Sync failed', 'alert');
          }
        });
      };
    });

    var syncAllBtn = document.getElementById('sync-btn-all');
    if (syncAllBtn) {
      syncAllBtn.onclick = function() {
        if (!_activeAccount || syncAllBtn.disabled) return;
        syncAllBtn.disabled = true;
        var clearBtnRef = document.getElementById('sync-btn-clear-cache');
        if (clearBtnRef) clearBtnRef.disabled = true;
        var isM3u = _activeAccount.type === 'm3u';
        var scopesToRun = [];
        if (_activeAccount.syncLiveTv !== false) scopesToRun.push('live');
        if (!isM3u && _activeAccount.syncMovies !== false) scopesToRun.push('movies');
        if (!isM3u && _activeAccount.syncSeries !== false) scopesToRun.push('series');
        if (!isM3u && _activeAccount.syncLiveTv !== false) scopesToRun.push('epg');

        Promise.all(scopesToRun.map(function(sc) { return syncSingleScope(sc); }))
          .then(function(results) {
            syncAllBtn.disabled = false;
            if (clearBtnRef) clearBtnRef.disabled = false;
            var anyFailed = results.some(function(r) { return !r; });
            if (anyFailed) {
              showToast(window.TVI18n ? window.TVI18n.t('sync_failed') : 'Sync failed', 'alert');
            } else {
              showToast(window.TVI18n ? window.TVI18n.t('sync_done') : 'Synced', 'check');
            }
          });
      };
    }

    var syncClearCacheBtn = document.getElementById('sync-btn-clear-cache');
    if (syncClearCacheBtn) {
      syncClearCacheBtn.onclick = function() {
        if (!_activeAccount) return;
        if (window.TVApi && window.TVApi.clearCache) {
          window.TVApi.clearCache(_activeAccount.id);
        }
        _allAccountLiveStreams = null;
        _allAccountMovies = null;
        _allAccountSeries = null;
        _liveCategories = [];
        _movieCategories = [];
        _seriesCategories = [];
        _syncModalTimes[String(_activeAccount.id)] = {};
        saveSyncModalTimes();
        markCategoriesDirty('all');
        ['live', 'movies', 'series', 'epg'].forEach(function(sc) {
          setSyncRowStatus(sc, 'cleared');
        });
        showToast(window.TVI18n ? window.TVI18n.t('cache_cleared') : 'Cache cleared', 'trash');
        if (_currentTab === 'live') loadLiveTv();
        else if (_currentTab === 'movies') loadMovies(false);
        else if (_currentTab === 'series') loadSeries(false);
      };
    }

    function onLanguageChanged() {
      markCategoriesDirty('all');
      // Re-render account cards with updated language date format (dd.mm.yyyy vs mm/dd/yyyy)
      var accountsView = document.getElementById('view-accounts');
      if (accountsView && accountsView.classList.contains('active')) {
        renderAccountsList();
      }

      var favText = window.TVI18n ? window.TVI18n.t('favorites') : 'Favorites';
      var watchText = window.TVI18n ? window.TVI18n.t('watchlist') : 'Watchlist';

      // 1. Live TV categories & headers
      if (_selectedLiveCategory && _selectedLiveCategory.category_id === 'favorites') {
        _selectedLiveCategory.category_name = favText;
        var liveTitleEl = document.getElementById('live-selected-category-title');
        if (liveTitleEl) liveTitleEl.textContent = favText;
      }
      var pageLive = document.getElementById('page-live');
      if (pageLive && pageLive.classList.contains('active') && _liveCategories && _liveCategories.length > 0) {
        var liveCatSearch = document.getElementById('live-cat-search');
        var q = (liveCatSearch ? liveCatSearch.value : '').toLowerCase().trim();
        var filteredLive = q ? _liveCategories.filter(function(c) {
          return c.category_name.toLowerCase().indexOf(q) >= 0;
        }) : _liveCategories;
        renderLiveCategories(filteredLive, true, _selectedLiveCategory ? _selectedLiveCategory.category_id : null);
      }
      var liveCountBadge = document.getElementById('live-channels-count');
      if (liveCountBadge && _liveStreams) {
        liveCountBadge.textContent = _liveStreams.length + ' ' + (window.TVI18n ? window.TVI18n.t('unit_channels') : 'Channels');
      }

      // 2. Movies categories & headers
      if (_selectedMovieCategory && _selectedMovieCategory.category_id === 'favorites') {
        _selectedMovieCategory.category_name = watchText;
      }
      var pageMovies = document.getElementById('page-movies');
      if (pageMovies && pageMovies.classList.contains('active') && _movieCategories && _movieCategories.length > 0) {
        var movieCatSearch = document.getElementById('movies-cat-search');
        var mq = (movieCatSearch ? movieCatSearch.value : '').toLowerCase().trim();
        var filteredMovies = mq ? _movieCategories.filter(function(c) {
          return c.category_name.toLowerCase().indexOf(mq) >= 0;
        }) : _movieCategories;
        renderMovieCategories(filteredMovies, true, _selectedMovieCategory ? _selectedMovieCategory.category_id : null);
      }
      var moviesCountBadge = document.getElementById('movies-count-badge');
      if (moviesCountBadge && _movieStreams) {
        moviesCountBadge.textContent = _movieStreams.length + ' ' + (window.TVI18n ? window.TVI18n.t('unit_movies') : 'Movies');
      }

      // 3. Series categories & headers
      if (_selectedSeriesCategory && _selectedSeriesCategory.category_id === 'favorites') {
        _selectedSeriesCategory.category_name = watchText;
      }
      var pageSeries = document.getElementById('page-series');
      if (pageSeries && pageSeries.classList.contains('active') && _seriesCategories && _seriesCategories.length > 0) {
        var seriesCatSearch = document.getElementById('series-cat-search');
        var sq = (seriesCatSearch ? seriesCatSearch.value : '').toLowerCase().trim();
        var filteredSeries = sq ? _seriesCategories.filter(function(c) {
          return c.category_name.toLowerCase().indexOf(sq) >= 0;
        }) : _seriesCategories;
        renderSeriesCategories(filteredSeries, true, _selectedSeriesCategory ? _selectedSeriesCategory.category_id : null);
      }
      var seriesCountBadge = document.getElementById('series-count-badge');
      if (seriesCountBadge && _seriesList) {
        seriesCountBadge.textContent = _seriesList.length + ' ' + (window.TVI18n ? window.TVI18n.t('unit_shows') : 'Shows');
      }

      // 4. Overlays & bouquet menu
      if (_categoryMenuCategories && _categoryMenuCategories.length > 0) {
        if (_categoryMenuCategories[0].category_id === 'favorites') {
          _categoryMenuCategories[0].category_name = favText;
        }
      }
      if (_selectedLiveCategory && _selectedLiveCategory.category_id === 'favorites') {
        var catNameEl = document.getElementById('channel-menu-category-name');
        if (catNameEl) catNameEl.textContent = favText;
      }

      // 5. Update sort buttons if in default mode
      if (_movieSortMode === 'default') {
        var movieSortText = document.getElementById('movies-sort-text');
        if (movieSortText) movieSortText.textContent = window.TVI18n ? window.TVI18n.t('sort_newest') : 'Newly Added';
      }
      if (_seriesSortMode === 'default') {
        var seriesSortText = document.getElementById('series-sort-text');
        if (seriesSortText) seriesSortText.textContent = window.TVI18n ? window.TVI18n.t('sort_newest') : 'Newly Added';
      }
    }

    window.addEventListener('tv-language-changed', onLanguageChanged);

    // Language Options (English / Deutsch)
    var langEn = document.getElementById('lang-opt-en');
    var langDe = document.getElementById('lang-opt-de');
    function selectLanguage(targetLang) {
      closeModal(document.getElementById('modal-language'));
      var curLang = window.TVI18n ? window.TVI18n.getLanguage() : 'en';
      if (curLang === targetLang) return;

      var optEn = document.getElementById('lang-opt-en');
      var optDe = document.getElementById('lang-opt-de');
      var checkEn = document.getElementById('check-en');
      var checkDe = document.getElementById('check-de');
      if (optEn) optEn.classList.toggle('selected', targetLang === 'en');
      if (optDe) optDe.classList.toggle('selected', targetLang === 'de');
      if (checkEn) {
        checkEn.classList.toggle('visible', targetLang === 'en');
        checkEn.style.visibility = (targetLang === 'en') ? 'visible' : 'hidden';
        checkEn.style.opacity = (targetLang === 'en') ? '1' : '0';
      }
      if (checkDe) {
        checkDe.classList.toggle('visible', targetLang === 'de');
        checkDe.style.visibility = (targetLang === 'de') ? 'visible' : 'hidden';
        checkDe.style.opacity = (targetLang === 'de') ? '1' : '0';
      }

      if (window.TVI18n) window.TVI18n.setLanguage(targetLang);

      var toastMsg = (targetLang === 'de')
        ? (window.TVI18n ? window.TVI18n.t('lang_changed_de') : 'Sprache auf Deutsch geändert')
        : (window.TVI18n ? window.TVI18n.t('lang_changed_en') : 'Language set to English');
      showToast(toastMsg, 'globe');
    }

    if (langEn) {
      langEn.onclick = function() { selectLanguage('en'); };
    }
    if (langDe) {
      langDe.onclick = function() { selectLanguage('de'); };
    }

    // Switch Account Button
    var switchBtn = document.getElementById('header-switch-btn');
    if (switchBtn) {
      switchBtn.onclick = function() {
        showAccountListScreen();
      };
    }

    // Master Search Input Handler (Real-time keystroke searching with 300ms debounce)
    var masterInput = document.getElementById('master-search-input');
    var masterClearBtn = document.getElementById('master-search-clear-btn');
    var _masterSearchDebounce = null;
    if (masterInput) {
      masterInput.oninput = function() {
        if (masterClearBtn) {
          masterClearBtn.style.display = masterInput.value.length > 0 ? 'flex' : 'none';
        }
        clearTimeout(_masterSearchDebounce);
        _masterSearchDebounce = setTimeout(function() {
          executeMasterSearch(masterInput.value.toLowerCase().trim());
        }, 300);
      };
    }
    if (masterClearBtn && masterInput) {
      masterClearBtn.onclick = function() {
        masterInput.value = '';
        masterClearBtn.style.display = 'none';
        executeMasterSearch('');
        masterInput.focus();
        if (window.SpatialNav) window.SpatialNav.setFocus(masterInput);
      };
    }

    // Master Search Tab Switching with Lazy Tab Data Loading
    var searchTabs = [
      { id: 'search-tab-live', type: 'live' },
      { id: 'search-tab-movies', type: 'movies' },
      { id: 'search-tab-series', type: 'series' }
    ];
    searchTabs.forEach(function(st) {
      var btn = document.getElementById(st.id);
      if (btn) {
        btn.onclick = function() {
          searchTabs.forEach(function(s) { document.getElementById(s.id).classList.remove('active'); });
          btn.classList.add('active');
          _searchTab = st.type;
          var curQ = masterInput ? masterInput.value.toLowerCase().trim() : '';
          executeMasterSearch(curQ);
        };
      }
    });
  }

  function executeMasterSearch(query) {
    var resultsArea = document.getElementById('master-search-results');
    if (!resultsArea) return;
    resultsArea.innerHTML = '';

    var countLiveEl = document.getElementById('search-count-live');
    var countMoviesEl = document.getElementById('search-count-movies');
    var countSeriesEl = document.getElementById('search-count-series');

    if (!query || query.length < 2) {
      if (countLiveEl) countLiveEl.textContent = _allAccountLiveStreams ? '0' : '--';
      if (countMoviesEl) countMoviesEl.textContent = _allAccountVodStreams ? '0' : '--';
      if (countSeriesEl) countSeriesEl.textContent = _allAccountSeriesStreams ? '0' : '--';
      var minCharsText = window.TVI18n ? window.TVI18n.t('search_min_chars') : 'Type at least 2 characters to search...';
      resultsArea.innerHTML = '<div class="search-placeholder">' + minCharsText + '</div>';
      // Pre-fetch active tab in background so it's ready when user starts typing
      ensureMasterTabData(_searchTab);
      return;
    }

    var noMatchesText = window.TVI18n ? window.TVI18n.t('no_results') : 'No results found.';
    var playText = window.TVI18n ? window.TVI18n.t('play_episode') : 'Play';
    var playIcon = window.TVIcons ? window.TVIcons.play : '▶';
    var tvIcon = (window.TVIcons && window.TVIcons.tv) || '';

    if (_searchTab === 'live') {
      if (!_allAccountLiveStreams) {
        if (countLiveEl) countLiveEl.textContent = '...';
        var liveSearchText = (window.TVI18n && window.TVI18n.getLanguage() === 'de') ? 'Sender werden gesucht...' : 'Searching Live TV...';
        resultsArea.innerHTML = 
          '<div class="search-placeholder">' +
            '<div class="spinner" style="width:36px;height:36px;margin:0 auto 12px auto;border-width:3px;"></div>' +
            '<span>' + liveSearchText + '</span>' +
          '</div>';
        ensureMasterTabData('live').then(function() {
          if (_searchTab === 'live') {
            var mi = document.getElementById('master-search-input');
            var curQ = mi ? mi.value.toLowerCase().trim() : '';
            executeMasterSearch(curQ);
          }
        });
        return;
      }
      var liveMatches = _allAccountLiveStreams.filter(function(s) {
        var n = s._searchName || (s._searchName = (s.name || '').toLowerCase());
        return n.indexOf(query) >= 0;
      });
      if (countLiveEl) countLiveEl.textContent = liveMatches.length;

      if (liveMatches.length === 0) {
        resultsArea.innerHTML = '<div class="search-placeholder">' + noMatchesText + '</div>';
        return;
      }
      liveMatches.slice(0, 30).forEach(function(ch) {
        var item = document.createElement('div');
        item.className = 'search-result-row focusable';
        var safeChIcon = sanitizeImgUrl(ch.stream_icon);
        item.innerHTML = 
          '<div class="search-row-left">' +
            (safeChIcon ? '<img class="search-row-thumb" src="' + safeChIcon + '" loading="lazy" onerror="this.style.display=\'none\'" />' : '<div class="search-row-thumb" style="display:flex;align-items:center;justify-content:center;">' + tvIcon + '</div>') +
            '<div class="search-row-info">' +
              '<span class="search-row-title">' + escapeHtml(ch.name ? ch.name.replace(/^\[.*?\]\s*/, '') : 'Channel') + '</span>' +
              '<div class="search-row-meta">' +
                '<span class="search-meta-badge">LIVE TV</span>' +
              '</div>' +
            '</div>' +
          '</div>' +
          '<button class="btn-primary" style="padding:10px 20px; font-size:18px; display:inline-flex; align-items:center;">' + playIcon + '<span style="margin-left:8px;">' + escapeHtml(playText) + '</span></button>';
        item.onclick = function() {
          closeModal(document.getElementById('modal-master-search'));
          switchTab('live');

          var matchingCat = null;
          if (ch.category_id && _liveCategories && _liveCategories.length > 0) {
            matchingCat = _liveCategories.find(function(c) {
              return String(c.category_id) === String(ch.category_id);
            });
          }
          if (matchingCat) {
            _selectedLiveCategory = matchingCat;
            var catEl = document.querySelector('#live-categories-list .category-item[data-category-id="' + matchingCat.category_id + '"]');
            if (catEl) {
              setSingleActiveCategory('live-categories-list', catEl);
            }
            var titleEl = document.getElementById('live-selected-category-title');
            if (titleEl) titleEl.textContent = matchingCat.category_name;

            if (_activeAccount) {
              window.TVApi.getLiveStreams(_activeAccount, matchingCat.category_id).then(function(streams) {
                _liveStreams = streams;
                window._liveStreams = streams;
                if (_player) _player.setChannelList(streams);
                if (_virtualList) {
                  setDashboardLiveItems(streams, false);
                  _virtualList.refreshPlayingState(ch.stream_id);
                  var chIdx = streams.findIndex(function(s) { return String(s.stream_id) === String(ch.stream_id); });
                  if (chIdx >= 0 && _virtualList.scrollToIndex) _virtualList.scrollToIndex(chIdx);
                }
              }).catch(function(){});
            }
          }

          selectLiveStream(ch);
          _player.setMode('fullscreen');
        };
        resultsArea.appendChild(item);
      });
    } else if (_searchTab === 'movies') {
      if (!_allAccountVodStreams) {
        if (countMoviesEl) countMoviesEl.textContent = '...';
        var movSearchText = (window.TVI18n && window.TVI18n.getLanguage() === 'de') ? 'Filme werden gesucht...' : 'Searching movies...';
        resultsArea.innerHTML = 
          '<div class="search-placeholder">' +
            '<div class="spinner" style="width:36px;height:36px;margin:0 auto 12px auto;border-width:3px;"></div>' +
            '<span>' + movSearchText + '</span>' +
          '</div>';
        ensureMasterTabData('movies').then(function() {
          if (_searchTab === 'movies') {
            var mi = document.getElementById('master-search-input');
            var curQ = mi ? mi.value.toLowerCase().trim() : '';
            executeMasterSearch(curQ);
          }
        });
        return;
      }
      var movieMatches = _allAccountVodStreams.filter(function(m) {
        var n = m._searchName || (m._searchName = (m.name || '').toLowerCase());
        return n.indexOf(query) >= 0;
      });
      if (countMoviesEl) countMoviesEl.textContent = movieMatches.length;

      if (movieMatches.length === 0) {
        resultsArea.innerHTML = '<div class="search-placeholder">' + noMatchesText + '</div>';
        return;
      }
      var playMovieText = window.TVI18n ? window.TVI18n.t('play_movie') : 'Play Movie';
      var starFilledSvg = (window.TVIcons && window.TVIcons.starFilled) ? window.TVIcons.starFilled : '★';
      movieMatches.slice(0, 30).forEach(function(m) {
        var row = document.createElement('div');
        row.className = 'search-result-row focusable';
        var parsedRating = m.rating ? parseFloat(m.rating) : NaN;
        var rating = !isNaN(parsedRating) ? parsedRating.toFixed(1) : null;
        var year = m.year || (m.release_date ? m.release_date.substring(0, 4) : null);
        var iconUrl = sanitizeImgUrl(m.stream_icon) || 'assets/logo.png';
        row.innerHTML = 
          '<div class="search-row-left">' +
            '<img class="search-row-thumb" src="' + iconUrl + '" loading="lazy" onerror="this.src=\'assets/logo.png\'" />' +
            '<div class="search-row-info">' +
              '<span class="search-row-title">' + escapeHtml(m.name || 'Movie') + '</span>' +
              '<div class="search-row-meta">' +
                '<span class="search-meta-badge">' + escapeHtml(window.TVI18n ? window.TVI18n.t('movies') : 'Movie') + '</span>' +
                (year ? '<span>' + escapeHtml(year) + '</span>' : '') +
                (rating ? '<span class="search-meta-rating">' + starFilledSvg + ' ' + rating + '</span>' : '') +
              '</div>' +
            '</div>' +
          '</div>' +
          '<button class="btn-primary" style="padding:10px 20px; font-size:18px; display:inline-flex; align-items:center;">' + playIcon + '<span style="margin-left:8px;">' + escapeHtml(playMovieText) + '</span></button>';
        row.onclick = function() {
          closeModal(document.getElementById('modal-master-search'));
          openMovieDetail(m);
        };
        resultsArea.appendChild(row);
      });
    } else if (_searchTab === 'series') {
      if (!_allAccountSeriesStreams) {
        if (countSeriesEl) countSeriesEl.textContent = '...';
        var serSearchText = (window.TVI18n && window.TVI18n.getLanguage() === 'de') ? 'Serien werden gesucht...' : 'Searching series...';
        resultsArea.innerHTML = 
          '<div class="search-placeholder">' +
            '<div class="spinner" style="width:36px;height:36px;margin:0 auto 12px auto;border-width:3px;"></div>' +
            '<span>' + serSearchText + '</span>' +
          '</div>';
        ensureMasterTabData('series').then(function() {
          if (_searchTab === 'series') {
            var mi = document.getElementById('master-search-input');
            var curQ = mi ? mi.value.toLowerCase().trim() : '';
            executeMasterSearch(curQ);
          }
        });
        return;
      }
      var seriesMatches = _allAccountSeriesStreams.filter(function(s) {
        var n = s._searchName || (s._searchName = (s.name || '').toLowerCase());
        return n.indexOf(query) >= 0;
      });
      if (countSeriesEl) countSeriesEl.textContent = seriesMatches.length;

      if (seriesMatches.length === 0) {
        resultsArea.innerHTML = '<div class="search-placeholder">' + noMatchesText + '</div>';
        return;
      }
      var episodesText = window.TVI18n ? window.TVI18n.t('episodes') : 'Episodes';
      var starFilledSvg = (window.TVIcons && window.TVIcons.starFilled) ? window.TVIcons.starFilled : '★';
      seriesMatches.slice(0, 30).forEach(function(s) {
        var row = document.createElement('div');
        row.className = 'search-result-row focusable';
        var parsedRating = s.rating ? parseFloat(s.rating) : NaN;
        var rating = !isNaN(parsedRating) ? parsedRating.toFixed(1) : null;
        var iconUrl = sanitizeImgUrl(s.cover || s.stream_icon) || 'assets/logo.png';
        row.innerHTML = 
          '<div class="search-row-left">' +
            '<img class="search-row-thumb" src="' + iconUrl + '" loading="lazy" onerror="this.src=\'assets/logo.png\'" />' +
            '<div class="search-row-info">' +
              '<span class="search-row-title">' + escapeHtml(s.name || 'Series') + '</span>' +
              '<div class="search-row-meta">' +
                '<span class="search-meta-badge">' + escapeHtml(window.TVI18n ? window.TVI18n.t('series') : 'Series') + '</span>' +
                (rating ? '<span class="search-meta-rating">' + starFilledSvg + ' ' + rating + '</span>' : '') +
              '</div>' +
            '</div>' +
          '</div>' +
          '<button class="btn-primary" style="padding:10px 20px; font-size:18px; display:inline-flex; align-items:center;">' + playIcon + '<span style="margin-left:8px;">' + escapeHtml(episodesText) + '</span></button>';
        row.onclick = function() {
          closeModal(document.getElementById('modal-master-search'));
          openSeriesDetail(s);
        };
        resultsArea.appendChild(row);
      });
    }
  }

  // =========================================================
  // 7. IN-PLAYER HUD & OVERLAYS CONTROLS
  // =========================================================
  function openAudioSelectorModal() {
    var modal = document.getElementById('modal-audio-selector');
    var closeBtn = document.getElementById('audio-selector-close-btn');
    var listEl = document.getElementById('audio-selector-list');
    if (!modal) return;

    function renderAudioList() {
      if (!listEl) return;
      listEl.innerHTML = '';
      var audioTracks = _player ? _player.getAudioTracks() : [];
      console.log('[TrackDebug] openAudioSelectorModal: received ' + (audioTracks ? audioTracks.length : 0) + ' tracks:', audioTracks);
      var curVodMeta = _player ? _player.currentVodMeta : null;
      var mediaId = (curVodMeta && (curVodMeta.seriesId || curVodMeta.streamId)) || '';
      var rememberedAudio = (mediaId && window.TVStorage) ? window.TVStorage.getMediaAudioChoice(mediaId) : null;
      var prefs = window.TVStorage ? window.TVStorage.getPreferences() : { audioLanguage: 'de' };

      if (!audioTracks || audioTracks.length === 0) {
        var defaultBtn = document.createElement('button');
        defaultBtn.className = 'track-opt-btn focusable active';
        var defTxt = window.TVI18n ? (window.TVI18n.t('default_audio') || 'Default Audio') : 'Default Audio';
        defaultBtn.innerHTML = '<span>' + defTxt + '</span><span class="track-check">' + (window.TVIcons ? window.TVIcons.check : '✓') + '</span>';
        defaultBtn.onclick = function() {
          showToast(defTxt, 'audio');
          closeModal(modal);
        };
        listEl.appendChild(defaultBtn);

        var msgEl = document.createElement('div');
        msgEl.className = 'track-empty-msg';
        msgEl.style.padding = '14px 16px';
        msgEl.style.textAlign = 'center';
        msgEl.style.color = 'rgba(255,255,255,0.45)';
        msgEl.style.fontSize = '20px';
        if (_player && _player._tracksLoading) {
          msgEl.textContent = window.TVI18n ? (window.TVI18n.t('loading_tracks') || 'Loading audio tracks...') : 'Loading audio tracks...';
        } else {
          msgEl.textContent = window.TVI18n ? (window.TVI18n.t('no_audio_tracks') || 'No additional audio tracks provided by stream') : 'No additional audio tracks provided by stream';
        }
        listEl.appendChild(msgEl);
      } else {
        audioTracks.forEach(function(at) {
          var btn = document.createElement('button');
          var isAct = at.active;
          if (rememberedAudio && (at.title === rememberedAudio || at.name === rememberedAudio || at.language === rememberedAudio)) {
            isAct = true;
          }
          btn.className = 'track-opt-btn focusable ' + (isAct ? 'active' : '');
          var checkHtml = isAct ? '<span class="track-check">' + (window.TVIcons ? window.TVIcons.check : '✓') + '</span>' : '';
          var trackLabel = at.title || at.name || at.language || at.id || ('Audio ' + (at.index + 1));
          btn.innerHTML = '<span>' + escapeHtml(trackLabel) + '</span>' + checkHtml;
          btn.onclick = function() {
            if (_player) {
              _player.setAudioTrack(at.index);
              if (typeof _player.unmute === 'function') _player.unmute();
            }
            var choice = at.title || at.name || at.language || at.id;
            if (mediaId && window.TVStorage) {
              window.TVStorage.setMediaAudioChoice(mediaId, choice);
            }
            if (at.language && window.TVStorage) {
              window.TVStorage.setPreference('audioLanguage', at.language);
            }
            listEl.querySelectorAll('.track-opt-btn').forEach(function(b) {
              b.classList.remove('active');
              var ch = b.querySelector('.track-check');
              if (ch) ch.remove();
            });
            btn.classList.add('active');
            btn.insertAdjacentHTML('beforeend', '<span class="track-check">' + (window.TVIcons ? window.TVIcons.check : '✓') + '</span>');
            showToast('Audio: ' + trackLabel, 'audio');
          };
          listEl.appendChild(btn);
        });
      }
    }

    renderAudioList();
    var unlistenAudio = window.addTrackUpdateListener ? window.addTrackUpdateListener(function() {
      if (modal.style.display === 'flex') {
        renderAudioList();
      }
    }) : null;

    var firstFocus = listEl.querySelector('.track-opt-btn.active') || listEl.querySelector('.track-opt-btn') || closeBtn;
    openModal(modal, firstFocus);
    if (closeBtn) {
      closeBtn.onclick = function() {
        if (unlistenAudio) unlistenAudio();
        closeModal(modal);
      };
    }
  }

  function openSubtitleSelectorModal() {
    var modal = document.getElementById('modal-sub-selector');
    var closeBtn = document.getElementById('sub-selector-close-btn');
    var listEl = document.getElementById('sub-selector-list');
    if (!modal) return;

    function renderSubtitleList() {
      if (!listEl) return;
      listEl.innerHTML = '';
      var subData = _player ? _player.getSubtitleTracks() : { tracks: [], isOff: true };
      var curVodMeta = _player ? _player.currentVodMeta : null;
      var mediaId = (curVodMeta && (curVodMeta.seriesId || curVodMeta.streamId)) || '';
      var rememberedSub = (mediaId && window.TVStorage) ? window.TVStorage.getMediaSubtitleChoice(mediaId) : null;
      var prefs = window.TVStorage ? window.TVStorage.getPreferences() : { subtitleLanguage: 'off' };
      var isExplicitOff = (rememberedSub === 'off' || rememberedSub === 'no') || (!rememberedSub && (prefs.subtitleLanguage === 'off' || prefs.subtitleLanguage === 'no'));

      // Auto button (1:1 with Windows app)
      var autoBtn = document.createElement('button');
      var isAutoActive = !isExplicitOff && (rememberedSub === 'auto' || prefs.subtitleLanguage === 'auto');
      autoBtn.className = 'track-opt-btn focusable ' + (isAutoActive ? 'active' : '');
      var autoTxt = window.TVI18n ? (window.TVI18n.t('subtitles_auto') || 'Auto / Automatisch') : 'Auto / Automatisch';
      var autoCheck = isAutoActive ? '<span class="track-check">' + (window.TVIcons ? window.TVIcons.check : '✓') + '</span>' : '';
      autoBtn.innerHTML = '<span>' + autoTxt + '</span>' + autoCheck;
      autoBtn.onclick = function() {
        if (mediaId && window.TVStorage) {
          window.TVStorage.setMediaSubtitleChoice(mediaId, 'auto');
        }
        if (window.TVStorage) window.TVStorage.setPreference('subtitleLanguage', 'auto');
        if (_player && typeof _player._applyPreferences === 'function') _player._applyPreferences();
        listEl.querySelectorAll('.track-opt-btn').forEach(function(b) {
          b.classList.remove('active');
          var ch = b.querySelector('.track-check');
          if (ch) ch.remove();
        });
        autoBtn.classList.add('active');
        autoBtn.insertAdjacentHTML('beforeend', '<span class="track-check">' + (window.TVIcons ? window.TVIcons.check : '✓') + '</span>');
        showToast(autoTxt, 'subtitle');
      };
      listEl.appendChild(autoBtn);

      // Off button (1:1 with Windows app)
      var offBtn = document.createElement('button');
      var isOffActive = isExplicitOff || (subData.isOff && !isAutoActive);
      offBtn.className = 'track-opt-btn focusable ' + (isOffActive ? 'active' : '');
      var offTxt = window.TVI18n ? (window.TVI18n.t('subtitles_off') || 'Off / Deaktiviert') : 'Off / Deaktiviert';
      var offCheck = isOffActive ? '<span class="track-check">' + (window.TVIcons ? window.TVIcons.check : '✓') + '</span>' : '';
      offBtn.innerHTML = '<span>' + offTxt + '</span>' + offCheck;
      offBtn.onclick = function() {
        if (_player) _player.setSubtitleTrack('off');
        if (mediaId && window.TVStorage) {
          window.TVStorage.setMediaSubtitleChoice(mediaId, 'off');
        }
        if (window.TVStorage) window.TVStorage.setPreference('subtitleLanguage', 'off');
        listEl.querySelectorAll('.track-opt-btn').forEach(function(b) {
          b.classList.remove('active');
          var ch = b.querySelector('.track-check');
          if (ch) ch.remove();
        });
        offBtn.classList.add('active');
        offBtn.insertAdjacentHTML('beforeend', '<span class="track-check">' + (window.TVIcons ? window.TVIcons.check : '✓') + '</span>');
        showToast(offTxt, 'subtitle');
      };
      listEl.appendChild(offBtn);

      var validTracks = (subData.tracks || []).filter(function(st) {
        return st.id !== 'no' && st.id !== 'auto';
      });

      if (validTracks.length > 0) {
        validTracks.forEach(function(st) {
          var sBtn = document.createElement('button');
          var isAct = !isOffActive && (st.active || (rememberedSub && (st.title === rememberedSub || st.name === rememberedSub || st.language === rememberedSub)));
          sBtn.className = 'track-opt-btn focusable ' + (isAct ? 'active' : '');
          var checkHtml = isAct ? '<span class="track-check">' + (window.TVIcons ? window.TVIcons.check : '✓') + '</span>' : '';
          var sLabel = st.title || st.name || st.language || st.id || ('Subtitle ' + (st.index + 1));
          sBtn.innerHTML = '<span>' + escapeHtml(sLabel) + '</span>' + checkHtml;
          sBtn.onclick = function() {
            if (_player) _player.setSubtitleTrack(st.index);
            var choice = st.title || st.name || st.language || st.id;
            if (mediaId && window.TVStorage) {
              window.TVStorage.setMediaSubtitleChoice(mediaId, choice);
            }
            if (st.lang && window.TVStorage) {
              window.TVStorage.setPreference('subtitleLanguage', st.lang);
            }
            listEl.querySelectorAll('.track-opt-btn').forEach(function(b) {
              b.classList.remove('active');
              var ch = b.querySelector('.track-check');
              if (ch) ch.remove();
            });
            sBtn.classList.add('active');
            sBtn.insertAdjacentHTML('beforeend', '<span class="track-check">' + (window.TVIcons ? window.TVIcons.check : '✓') + '</span>');
            
            var isForced = window.TrackLanguageMatcher ? window.TrackLanguageMatcher.isForced(sLabel) : (sLabel.toLowerCase().indexOf('forced') !== -1);
            var toastMsg = sLabel;
            if (isForced) {
              var fNotice = window.TVI18n ? (window.TVI18n.t('forced_sub_notice') || ' (Active during foreign dialogue)') : ' (Active during foreign dialogue)';
              toastMsg = sLabel + fNotice;
            }
            showToast(toastMsg, 'subtitle');
          };
          listEl.appendChild(sBtn);
        });
      } else {
        var msgEl = document.createElement('div');
        msgEl.className = 'track-empty-msg';
        msgEl.style.padding = '14px 16px';
        msgEl.style.textAlign = 'center';
        msgEl.style.color = 'rgba(255,255,255,0.45)';
        msgEl.style.fontSize = '20px';
        if (_player && _player._tracksLoading) {
          msgEl.textContent = window.TVI18n ? (window.TVI18n.t('loading_tracks') || 'Loading subtitle tracks...') : 'Loading subtitle tracks...';
        } else {
          msgEl.textContent = window.TVI18n ? (window.TVI18n.t('no_subtitles_found') || 'No subtitles available for this stream') : 'No subtitles available for this stream';
        }
        listEl.appendChild(msgEl);
      }
    }

    renderSubtitleList();
    var unlistenSub = window.addTrackUpdateListener ? window.addTrackUpdateListener(function() {
      if (modal.style.display === 'flex') {
        renderSubtitleList();
      }
    }) : null;

    var firstFocus = listEl.querySelector('.track-opt-btn.active') || listEl.querySelector('.track-opt-btn') || closeBtn;
    openModal(modal, firstFocus);
    if (closeBtn) {
      closeBtn.onclick = function() {
        if (unlistenSub) unlistenSub();
        closeModal(modal);
      };
    }
  }

  function matchesSeriesDetails(details, seriesId) {
    if (!details || !details.episodes || !seriesId) return false;
    var target = String(seriesId);
    if (details._seriesId && String(details._seriesId) === target) return true;
    return Boolean(details.info && details.info.series_id && String(details.info.series_id) === target);
  }

  function playNextEpisodeForCurrentSeries() {
    if (!_player || _player.playbackType !== 'series' || !_player.currentVodMeta) return;
    var meta = _player.currentVodMeta;
    var seriesId = meta.seriesId || (_currentSeriesData && (_currentSeriesData.series_id || _currentSeriesData.id));
    if (!seriesId) return;

    function proceedWithDetails(details) {
      if (!details || !details.episodes) return;
      var episodesMap = details.episodes;
      var sNum = String(meta.season || 1);
      var curEps = window.normalizeEpisodeList(episodesMap[sNum]);
      var curStreamId = String(meta.streamId);
      var curIdx = curEps.findIndex(function(e) {
        return String(e.id || e.stream_id) === curStreamId || (e.episode_num && parseInt(e.episode_num, 10) === parseInt(meta.episode, 10));
      });

      var seriesName = meta.seriesName || (details.info && details.info.name) || (_currentSeriesData && _currentSeriesData.name) || 'Series';
      var allSKeys = Object.keys(episodesMap);
      var isLastSeason = (sNum === allSKeys[allSKeys.length - 1]);

      if (curIdx >= 0 && curIdx + 1 < curEps.length) {
        var nextEp = curEps[curIdx + 1];
        var nNum = nextEp.episode_num || (curIdx + 2);
        var nPill = 'S' + String(sNum).padStart(2, '0') + ' E' + String(nNum).padStart(2, '0');
        var afterNext = (curIdx + 2 < curEps.length) ? curEps[curIdx + 2] : null;
        var nextMeta = Object.assign({}, meta, {
          streamId: nextEp.id || nextEp.stream_id,
          title: nextEp.title || ('Episode ' + nNum),
          nextEpisodeTitle: afterNext ? (afterNext.title || ('Episode ' + (afterNext.episode_num || (curIdx + 3)))) : '',
          nextStreamId: afterNext ? (afterNext.id || afterNext.stream_id) : null,
          episode: parseInt(nNum, 10) || (curIdx + 2),
          duration: parseDurationSecs((nextEp && nextEp.info && (nextEp.info.duration_secs || nextEp.info.duration)) || (nextEp && (nextEp.duration_secs || nextEp.duration)) || 0),
          audioTracks: extractAudioTracksFromInfo(nextEp),
          subtitleTracks: extractSubtitleTracksFromInfo(nextEp),
          isFinale: isLastSeason && (curIdx + 1 === curEps.length - 1),
          startPosition: 0
        });
        _player.playVod(nextEp, 'series', seriesName, '[' + nPill + '] ' + (nextEp.title || ('Episode ' + nNum)), function() { playNextEpisodeForCurrentSeries(); }, nextMeta);
      } else {
        var curSeasonIdx = allSKeys.indexOf(sNum);
        if (curSeasonIdx >= 0 && curSeasonIdx + 1 < allSKeys.length) {
          var nextSKey = allSKeys[curSeasonIdx + 1];
          var nextSeasonEps = window.normalizeEpisodeList(episodesMap[nextSKey]);
          if (nextSeasonEps && nextSeasonEps.length > 0) {
            var fe = nextSeasonEps[0];
            var feNum = fe.episode_num || 1;
            var fePill = 'S' + String(nextSKey).padStart(2, '0') + ' E' + String(feNum).padStart(2, '0');
            var isNextLast = (curSeasonIdx + 1 === allSKeys.length - 1);
            var feMeta = Object.assign({}, meta, {
              streamId: fe.id || fe.stream_id,
              title: fe.title || ('Episode ' + feNum),
              season: parseInt(nextSKey, 10) || (meta.season + 1),
              episode: parseInt(feNum, 10) || 1,
              duration: parseDurationSecs((fe && fe.info && (fe.info.duration_secs || fe.info.duration)) || (fe && (fe.duration_secs || fe.duration)) || 0),
              audioTracks: extractAudioTracksFromInfo(fe),
              subtitleTracks: extractSubtitleTracksFromInfo(fe),
              isFinale: isNextLast && (nextSeasonEps.length === 1),
              startPosition: 0
            });
            _currentSeriesSeason = nextSKey;
            _player.playVod(fe, 'series', seriesName, '[' + fePill + '] ' + (fe.title || ('Episode ' + feNum)), function() { playNextEpisodeForCurrentSeries(); }, feMeta);
          }
        } else {
          showToast(window.TVI18n && window.TVI18n.getLanguage() === 'de' ? 'Staffel-Finale erreicht' : 'Series finale reached', 'film');
        }
      }
    }

    var cachedDetails = _currentSeriesDetails || window._currentSeriesDetails;
    if (matchesSeriesDetails(cachedDetails, seriesId)) {
      proceedWithDetails(cachedDetails);
    } else {
      var activeAcc = _activeAccount || (window.TVStorage ? window.TVStorage.getActiveAccount() : null);
      if (activeAcc && seriesId) {
        window.TVApi.getSeriesInfo(activeAcc, seriesId).then(function(details) {
          if (details) details._seriesId = String(seriesId);
          _currentSeriesDetails = details;
          window._currentSeriesDetails = details;
          proceedWithDetails(details);
        });
      }
    }
  }

  function openSeriesEpisodesDrawer() {
    var drawer = document.getElementById('drawer-series-episodes');
    var tabsEl = document.getElementById('drawer-season-tabs');
    var listEl = document.getElementById('drawer-series-list');
    var nameEl = document.getElementById('drawer-series-name');
    if (!drawer) return;

    var curVodMeta = _player ? _player.currentVodMeta : null;
    var targetSeriesId = (curVodMeta && curVodMeta.seriesId) || (_currentSeriesData && (_currentSeriesData.series_id || _currentSeriesData.id));
    var cachedDetails = _currentSeriesDetails || window._currentSeriesDetails;
    var hasMatchingCache = matchesSeriesDetails(cachedDetails, targetSeriesId);
    var seriesName = (curVodMeta && curVodMeta.seriesName)
      || (hasMatchingCache && cachedDetails.info && cachedDetails.info.name)
      || (_currentSeriesData && String(_currentSeriesData.series_id || _currentSeriesData.id) === String(targetSeriesId) && _currentSeriesData.name)
      || 'Series';
    if (nameEl) {
      nameEl.textContent = seriesName;
    }

    drawer.classList.add('open');

    function populateDrawer(details) {
      if (!details || !details.episodes) {
        if (listEl) listEl.innerHTML = '<div class="col-placeholder">' + (window.TVI18n ? window.TVI18n.t('no_episodes_available') : 'No episodes available.') + '</div>';
        return;
      }
      var episodes = details.episodes;
      var seasonKeys = Object.keys(episodes);
      if (seasonKeys.length === 0) {
        if (listEl) listEl.innerHTML = '<div class="col-placeholder">' + (window.TVI18n ? window.TVI18n.t('no_episodes_available') : 'No episodes available.') + '</div>';
        return;
      }

      var curSeason = (curVodMeta && curVodMeta.season && episodes[String(curVodMeta.season)])
        ? String(curVodMeta.season)
        : (_currentSeriesSeason || seasonKeys[0]);
      _currentSeriesSeason = curSeason;

      // Render season tabs in drawer
      if (tabsEl) {
        tabsEl.innerHTML = '';
        seasonKeys.forEach(function(sKey) {
          var tabBtn = document.createElement('button');
          tabBtn.className = 'season-tab-btn focusable ' + (sKey === curSeason ? 'active' : '');
          tabBtn.textContent = (window.TVI18n ? window.TVI18n.t('season_prefix') : 'Season ') + sKey;
          tabBtn.onclick = function() {
            tabsEl.querySelectorAll('.season-tab-btn').forEach(function(b) { b.classList.remove('active'); });
            tabBtn.classList.add('active');
            _currentSeriesSeason = sKey;
            renderDrawerEpisodes(window.normalizeEpisodeList(episodes[sKey]), seriesName);
          };
          tabsEl.appendChild(tabBtn);
        });
      }

      renderDrawerEpisodes(window.normalizeEpisodeList(episodes[curSeason]), seriesName);

      setTimeout(function() {
        var playingEpCard = listEl ? (listEl.querySelector('.episode-card.playing-now') || listEl.querySelector('.episode-card')) : null;
        if (playingEpCard) {
          playingEpCard.scrollIntoView({ behavior: 'smooth', block: 'center' });
          if (window.SpatialNav) {
            window.SpatialNav.setFocus(playingEpCard);
          }
        }
      }, 80);
    }

    if (hasMatchingCache) {
      populateDrawer(cachedDetails);
    } else {
      var activeAcc = _activeAccount || (window.TVStorage ? window.TVStorage.getActiveAccount() : null);
      if (targetSeriesId && activeAcc) {
        if (listEl) {
          listEl.innerHTML = '<div class="col-placeholder">' + (window.TVI18n ? window.TVI18n.t('loading_seasons_episodes') : 'Loading seasons & episodes...') + '</div>';
        }
        window.TVApi.getSeriesInfo(activeAcc, targetSeriesId).then(function(sInfo) {
          if (sInfo) sInfo._seriesId = String(targetSeriesId);
          _currentSeriesDetails = sInfo;
          window._currentSeriesDetails = sInfo;
          if (!curVodMeta || !curVodMeta.seriesName) {
            seriesName = (sInfo && sInfo.info && sInfo.info.name) || seriesName;
            if (nameEl) nameEl.textContent = seriesName;
          }
          populateDrawer(sInfo);
        }).catch(function() {
          if (listEl) listEl.innerHTML = '<div class="col-placeholder">' + (window.TVI18n ? window.TVI18n.t('no_episodes_available') : 'No episodes available.') + '</div>';
        });
      } else {
        if (listEl) listEl.innerHTML = '<div class="col-placeholder">' + (window.TVI18n ? window.TVI18n.t('no_episodes_available') : 'No episodes available.') + '</div>';
      }
    }
  }

  function renderDrawerEpisodes(eps, seriesName) {
    var listEl = document.getElementById('drawer-series-list');
    if (!listEl) return;
    listEl.innerHTML = '';

    eps = window.normalizeEpisodeList(eps);

    if (!eps || eps.length === 0) {
      listEl.innerHTML = '<div class="col-placeholder">' + (window.TVI18n ? window.TVI18n.t('no_episodes_for_season') : 'No episodes found.') + '</div>';
      return;
    }

    var playLabel = window.TVI18n ? window.TVI18n.t('play_episode') : 'Play';
    var activeAcc = _activeAccount || (window.TVStorage ? window.TVStorage.getActiveAccount() : null);
    var curVodMeta = _player ? _player.currentVodMeta : null;

    eps.forEach(function(ep, epIdx) {
      var card = document.createElement('div');
      var sId = ep.id || ep.stream_id;
      var isPlayingNow = curVodMeta && (String(curVodMeta.streamId) === String(sId));
      card.className = 'episode-card focusable' + (isPlayingNow ? ' playing-now' : '');
      var epNum = ep.episode_num || (epIdx + 1);
      var epTitle = ep.title || ('Episode ' + epNum);
      var sNum = _currentSeriesSeason || '1';
      var sPill = 'S' + String(sNum).padStart(2, '0') + ' E' + String(epNum).padStart(2, '0');

      var epProg = (activeAcc && window.TVStorage) ? window.TVStorage.getProgress(activeAcc.id, sId) : null;
      var rawEpDur = (epProg && epProg.duration) || (ep.info && (ep.info.duration_secs || ep.info.duration)) || (ep.duration_secs || ep.duration) || 0;
      var epDur = parseDurationSecs(rawEpDur);
      var isComp = epProg && (epProg.isCompleted || (epDur > 30 && (epProg.position / epDur) >= 0.95));
      var progPct = (epProg && epDur > 30 && !isComp) ? Math.min(100, Math.round((epProg.position / epDur) * 100)) : 0;

      var checkSvg = (window.TVIcons && window.TVIcons.check) ? window.TVIcons.check : '✓';
      var playSvg = (window.TVIcons && window.TVIcons.play) ? window.TVIcons.play : '▶';

      var completedBadgeHtml = isComp ? '<span class="episode-completed-badge" title="Completed">' + checkSvg + '</span>' : '';
      var progressBarHtml = (!isComp && progPct > 0) ? '<div class="episode-progress-track"><div class="episode-progress-fill" style="width:' + progPct + '%;"></div></div>' : '';

      var epImg = sanitizeImgUrl((ep.info && (ep.info.movie_image || ep.info.cover)) || (_currentSeriesData && (_currentSeriesData.cover || _currentSeriesData.poster)) || '');
      var thumbHtml = 
        '<div class="episode-thumb-wrap">' +
          (epImg ? '<img class="episode-thumb-img" src="' + epImg + '" alt="" onerror="this.style.display=\'none\';" />' : '') +
          '<span class="episode-thumb-fallback">E' + escapeHtml(String(epNum).padStart(2, '0')) + '</span>' +
          '<span class="episode-thumb-play">' + playSvg + '</span>' +
        '</div>';

      card.innerHTML = 
        '<div class="episode-card-main">' +
          '<div class="episode-info">' +
            thumbHtml +
            '<div class="episode-text-col">' +
              '<span class="episode-title">' + escapeHtml(epTitle) + '</span>' +
              '<span class="episode-duration">' + escapeHtml(formatRuntime(ep.info && ep.info.duration)) + '</span>' +
            '</div>' +
          '</div>' +
          '<div class="episode-right-actions">' +
            completedBadgeHtml +
            '<button class="btn-primary" style="padding:8px 18px; font-size:18px; pointer-events:none; display:inline-flex; align-items:center;">' + playSvg + '<span style="margin-left:8px;">' + escapeHtml(playLabel) + '</span></button>' +
          '</div>' +
        '</div>' +
        progressBarHtml;

      card.onclick = function() {
        var epDurForDrawer = parseDurationSecs((epProg && epProg.duration) || (ep.info && (ep.info.duration_secs || ep.info.duration)) || (ep && (ep.duration_secs || ep.duration)) || 0);
        var hasProg = epProg && epProg.position >= 3 && !epProg.isCompleted && (epDurForDrawer <= 30 || (epProg.position / epDurForDrawer) < 0.95);

        function startEpisodePlay(startPos) {
          var drawer = document.getElementById('drawer-series-episodes');
          if (drawer) drawer.classList.remove('open');

          var isLastSeason = false;
          var curDetails = _currentSeriesDetails || window._currentSeriesDetails;
          if (curDetails && curDetails.episodes) {
            var allSKeys = Object.keys(curDetails.episodes);
            isLastSeason = (String(sNum) === String(allSKeys[allSKeys.length - 1]));
          }

          var nextEpCand = (epIdx + 1 < eps.length) ? eps[epIdx + 1] : null;
          var nextSeasonCand = null;
          if (!nextEpCand && curDetails && curDetails.episodes) {
            var allSKeys = Object.keys(curDetails.episodes);
            var curSIdx = allSKeys.indexOf(String(sNum));
            if (curSIdx >= 0 && curSIdx + 1 < allSKeys.length) {
              var nextSKey = allSKeys[curSIdx + 1];
              var nextSEps = window.normalizeEpisodeList(curDetails.episodes[nextSKey]);
              if (nextSEps.length > 0) {
                nextEpCand = nextSEps[0];
                nextSeasonCand = nextSKey;
              }
            }
          }

          var nextTitleCand = nextEpCand ? (nextEpCand.title || ('Episode ' + (nextEpCand.episode_num || (epIdx + 2)))) : '';
          var nextIdCand = nextEpCand ? (nextEpCand.id || nextEpCand.stream_id) : null;

          var audioTracksMeta = extractAudioTracksFromInfo(ep);
          var subTracksMeta = extractSubtitleTracksFromInfo(ep);

          var meta = {
            streamId: sId,
            seriesId: (curVodMeta && curVodMeta.seriesId) || (_currentSeriesDetails && (_currentSeriesDetails._seriesId || (_currentSeriesDetails.info && _currentSeriesDetails.info.series_id))) || (_currentSeriesData && (_currentSeriesData.series_id || _currentSeriesData.id)),
            type: 'series',
            title: epTitle,
            nextEpisodeTitle: nextTitleCand,
            nextStreamId: nextIdCand,
            nextSeason: nextSeasonCand,
            nextEpisodeNum: nextEpCand ? (nextEpCand.episode_num || 1) : null,
            containerExtension: ep.container_extension || (_currentSeriesData && _currentSeriesData.container_extension) || 'mp4',
            audioTracks: audioTracksMeta,
            subtitleTracks: subTracksMeta,
            seriesName: seriesName,
            season: parseInt(sNum, 10) || 1,
            episode: parseInt(epNum, 10) || (epIdx + 1),
            posterUrl: (curVodMeta && curVodMeta.posterUrl) || (_currentSeriesDetails && _currentSeriesDetails.info && _currentSeriesDetails.info.cover) || (_currentSeriesData && (_currentSeriesData.cover || _currentSeriesData.poster)) || '',
            isFinale: isLastSeason && (epIdx === eps.length - 1),
            duration: epDurForDrawer,
            startPosition: startPos
          };

          _player.playVod(ep, 'series', seriesName, '[' + sPill + '] ' + epTitle, function() { playNextEpisodeForCurrentSeries(); }, meta);
        }

        if (hasProg) {
          openResumePlaybackModal(ep, 'series', epProg.position, epDurForDrawer, function(chosenPos) {
            startEpisodePlay(chosenPos);
          });
        } else {
          startEpisodePlay(0);
        }
      };

      listEl.appendChild(card);
    });
  }

  function restoreMediaFocusAfterVod() {
    var activePage = document.querySelector('.dashboard-page.active');
    var pageId = activePage ? activePage.id : 'page-movies';
    var isMovies = (pageId === 'page-movies');
    var isSeries = (pageId === 'page-series');

    var type = _lastMediaSourceCard ? _lastMediaSourceCard.type : (isSeries ? 'series' : 'movie');
    var streamId = _lastMediaSourceCard ? _lastMediaSourceCard.streamId : null;
    var seriesId = _lastMediaSourceCard ? _lastMediaSourceCard.seriesId : null;

    function applyFocus() {
      var target = null;
      if (type === 'movie' || isMovies) {
        if (streamId) {
          target = document.querySelector('#movies-cw-rail [data-stream-id="' + streamId + '"]') ||
                   document.querySelector('#movies-grid-container [data-stream-id="' + streamId + '"]');
        }
        if (!target) {
          target = document.querySelector('#movies-cw-rail .cw-card') ||
                   document.querySelector('#movies-grid-container .poster-card') ||
                   document.getElementById('movies-search-input') ||
                   document.getElementById('nav-btn-movies');
        }
      } else if (type === 'series' || isSeries) {
        if (seriesId) {
          target = document.querySelector('#series-grid-container [data-series-id="' + seriesId + '"]');
        }
        if (!target && streamId) {
          target = document.querySelector('#series-cw-rail [data-stream-id="' + streamId + '"]');
        }
        if (!target) {
          target = document.querySelector('#series-cw-rail .cw-card') ||
                   document.querySelector('#series-grid-container .poster-card') ||
                   document.getElementById('series-search-input') ||
                   document.getElementById('nav-btn-series');
        }
      }

      if (target && window.SpatialNav) {
        window.SpatialNav.setFocus(target);
        return true;
      }
      return false;
    }

    if (!applyFocus()) {
      setTimeout(applyFocus, 40);
      setTimeout(applyFocus, 120);
    }
  }

  function setupNavigationShortcuts() {
    // VOD Player Scrubber & Buttons
    var playBtn = document.getElementById('vod-play-btn');
    var vodClose = document.getElementById('vod-close-btn');
    var vodProgressBar = document.getElementById('vod-progress-bar');
    var episodesBtn = document.getElementById('vod-episodes-btn');
    var nextEpBtn = document.getElementById('vod-next-ep-btn');
    var audioBtn = document.getElementById('vod-audio-btn');
    var subBtn = document.getElementById('vod-sub-btn');
    var epgOverlayClose = document.getElementById('epg-overlay-close-btn');

    if (playBtn) playBtn.onclick = function() { _player.togglePlayPause(); };
    if (vodClose) {
      vodClose.onclick = function() {
        if (_player && typeof _player._saveCurrentProgress === 'function') {
          _player._saveCurrentProgress(false);
        }
        _player.stop(false);
        _player.setMode('preview');
        renderContinueWatching('movie');
        renderContinueWatching('series');
        restoreMediaFocusAfterVod();
      };
    }
    if (nextEpBtn) {
      nextEpBtn.onclick = function() {
        if (_player && typeof _player.onNextEpisode === 'function') {
          _player.onNextEpisode();
        } else {
          playNextEpisodeForCurrentSeries();
        }
      };
    }
    if (episodesBtn) {
      episodesBtn.onclick = function() {
        openSeriesEpisodesDrawer();
      };
    }
    if (audioBtn) {
      audioBtn.onclick = function() {
        openAudioSelectorModal();
      };
    }
    if (subBtn) {
      subBtn.onclick = function() {
        openSubtitleSelectorModal();
      };
    }
    
    if (vodProgressBar) {
      vodProgressBar.onclick = function(e) {
        if (!e || e.clientX === undefined || e.clientX === 0 || (!e.pointerType && e.clientX < 10)) {
          if (_player && typeof _player._commitPendingSeek === 'function') {
            _player._commitPendingSeek();
          }
          if (_player && _player.videoEl && _player.videoEl.paused) {
            _player.play();
          }
          return;
        }
        var rect = vodProgressBar.getBoundingClientRect();
        if (e.clientX < rect.left || e.clientX > rect.right) return;
        var ratio = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width));
        _player.seekToRatio(ratio);
      };
    }

    if (episodesBtn) {
      episodesBtn.onclick = function() {
        openSeriesEpisodesDrawer();
      };
    }

    if (epgOverlayClose) {
      epgOverlayClose.onclick = function(e) {
        if (e) {
          e.preventDefault();
          e.stopPropagation();
        }
        closeLiveEpgOverlay();
      };
    }

    // Series episodes drawer close button
    var seriesClose = document.getElementById('drawer-series-close-btn');
    if (seriesClose) {
      seriesClose.onclick = function() {
        var dr = document.getElementById('drawer-series-episodes');
        if (dr) dr.classList.remove('open');
      };
    }

    // Remote D-Pad Zap & Media Controls in Fullscreen Mode
    window.addEventListener('keydown', function(e) {
      var code = e.keyCode || e.which;
      var isFullscreen = (_player && _player.currentMode === 'fullscreen') || document.body.classList.contains('player-fullscreen');
      if (isFullscreen) {
        var isModalOpen = !!document.querySelector('.modal-overlay.active');
        var isDrawerOpen = !!document.querySelector('.slide-drawer.open');
        if (isModalOpen || isDrawerOpen) return;

        var channelMenu = document.getElementById('live-channel-menu');
        var isChannelMenuOpen = channelMenu && channelMenu.style.display !== 'none';
        var catMenu = document.getElementById('live-category-menu');
        var isCatMenuOpen = catMenu && catMenu.style.display !== 'none';
        var epgOverlay = document.getElementById('live-epg-overlay');
        var isEpgOverlayOpen = epgOverlay && epgOverlay.style.display !== 'none';

        if (_player.playbackType === 'live') {
          // A) When in Full EPG Overlay: strictly trap keys inside EPG
          if (isEpgOverlayOpen) {
            return;
          }

          // B) When in Category / Bouquet Menu Overlay
          if (isCatMenuOpen) {
            if (code === 37 || code === 428 || code === 34 || (e.key && e.key === 'ChannelDown')) { // Left or Ch- -> Previous Category Page
              e.preventDefault();
              prevCategoryMenuPage(false);
              return;
            } else if (code === 39 || code === 427 || code === 33 || (e.key && e.key === 'ChannelUp')) { // Right or Ch+ -> Next Category Page
              e.preventDefault();
              nextCategoryMenuPage(false);
              return;
            }
            return;
          }

          // C) When in Channel Menu Overlay
          if (isChannelMenuOpen) {
            if (code === 37 || code === 428 || code === 34 || (e.key && e.key === 'ChannelDown')) { // Left or Ch- -> Previous Channel Page
              e.preventDefault();
              prevChannelMenuPage(false);
              return;
            } else if (code === 39 || code === 427 || code === 33 || (e.key && e.key === 'ChannelUp')) { // Right or Ch+ -> Next Channel Page
              e.preventDefault();
              nextChannelMenuPage(false);
              return;
            }
            return;
          }

          // D) Fullscreen Live TV (no overlays open):
          if (code === 37 || code === 38 || code === 428 || code === 34 || (e.key && e.key === 'ChannelDown')) { // Left or Up or Ch- -> Previous channel in category + Infobar
            e.preventDefault();
            _player.zapPrev();
          } else if (code === 39 || code === 40 || code === 427 || code === 33 || (e.key && e.key === 'ChannelUp')) { // Right or Down or Ch+ -> Next channel in category + Infobar
            e.preventDefault();
            _player.zapNext();
          } else if (code === 13) { // OK -> Open Smart IPTV Bouquet Channel Menu
            if (!isChannelMenuOpen && !isCatMenuOpen && !isEpgOverlayOpen) {
              e.preventDefault();
              openLiveChannelMenu();
            }
          } else if (code === 406 || code === 66 || (e.key && (e.key === 'ColorF3Blue' || e.key.toLowerCase() === 'blue' || e.key.toLowerCase() === 'b'))) {
            // Blue Button -> Open Category Menu
            e.preventDefault();
            openLiveCategoryMenu();
          } else if (code === 404 || code === 71 || (e.key && (e.key === 'ColorF1Green' || e.key.toLowerCase() === 'green' || e.key.toLowerCase() === 'g'))) {
            // Green Button -> Open EPG for current stream in fullscreen
            e.preventDefault();
            if (_player && _player.currentStream) {
              openLiveEpgOverlay(_player.currentStream);
            }
          } else if (code === 405 || code === 70 || code === 89 || (e.key && (e.key === 'ColorF2Yellow' || e.key.toLowerCase() === 'yellow' || e.key.toLowerCase() === 'f' || e.key.toLowerCase() === 'y'))) {
            // Yellow Button -> Toggle favorite on currently playing channel
            e.preventDefault();
            if (_player && _player.currentStream && _activeAccount) {
              var newFav = _saveFavoriteWithSnapshot(_activeAccount.id, _player.currentStream.stream_id, 'live', _player.currentStream);
              _player.showInfobar(3000);
              var cleanName = _player.currentStream.name ? _player.currentStream.name.replace(/^\[.*?\]\s*/, '') : 'Channel';
              var text = newFav ? (window.TVI18n ? window.TVI18n.t('fav_added') : 'Added to Favorites') : (window.TVI18n ? window.TVI18n.t('fav_removed') : 'Removed from Favorites');
              showToast(cleanName + ': ' + text, 'star');
              if (_selectedLiveCategory && _selectedLiveCategory.category_id === 'favorites') {
                if (!newFav) {
                  _liveStreams = (_liveStreams || []).filter(function(s) {
                    return String(s.stream_id) !== String(_player.currentStream.stream_id);
                  });
                } else {
                  var exists = (_liveStreams || []).some(function(s) { return String(s.stream_id) === String(_player.currentStream.stream_id); });
                  if (!exists) _liveStreams.push(_player.currentStream);
                }
                window._liveStreams = _liveStreams;
                _player.setChannelList(_liveStreams);
                setDashboardLiveItems(_liveStreams, true);
                var countBadge = document.getElementById('live-channels-count');
                if (countBadge) countBadge.textContent = _liveStreams.length + ' ' + (window.TVI18n ? window.TVI18n.t('unit_channels') : 'Channels');
              }
            }
          } else if (code === 415 || code === 19 || code === 10252) { // Media Play/Pause
            e.preventDefault();
            _player.togglePlayPause();
          }
        } else {
          // VOD playback
          var vodHud = document.getElementById('player-hud-vod');
          var isHudOpen = vodHud && vodHud.classList.contains('visible');

          if (code === 412) { // MediaRewind hardware key -> seek -10s
            e.preventDefault();
            _player.seekBy(-10, e.repeat);
          } else if (code === 417) { // MediaFastForward hardware key -> seek +10s
            e.preventDefault();
            _player.seekBy(10, e.repeat);
          } else if (code === 415 || code === 19 || code === 10252) { // MediaPlay/Pause hardware key
            e.preventDefault();
            _player.togglePlayPause();
          } else if (!isHudOpen) {
            // When HUD is hidden, ArrowLeft / ArrowRight directly seek and focus the scrubber
            if (code === 37) { // Left -> Seek -10s
              e.preventDefault();
              _player.seekBy(-10, e.repeat);
              var scrL = document.getElementById('vod-progress-bar');
              if (scrL && window.SpatialNav) {
                window.SpatialNav.setFocus(scrL);
              }
            } else if (code === 39) { // Right -> Seek +10s
              e.preventDefault();
              _player.seekBy(10, e.repeat);
              var scrR = document.getElementById('vod-progress-bar');
              if (scrR && window.SpatialNav) {
                window.SpatialNav.setFocus(scrR);
              }
            } else if (code === 38 || code === 40 || code === 13) {
              // Up, Down, OK -> wake HUD and focus Play/Pause
              e.preventDefault();
              _player.showHud();
              var pBtn = document.getElementById('vod-play-btn');
              if (pBtn && window.SpatialNav) {
                window.SpatialNav.setFocus(pBtn);
              }
            }
          }
          // When HUD is open, SpatialNav handles arrow navigation and OK clicks across HUD buttons
        }

        // Volume keys are intentionally not intercepted so the physical TV remote & native TV HUD handle volume natively across all platforms
      }
    }, false);

    // Global TV Back Button Handler
    window.SpatialNav.pushBackHandler(function() {
      // 1. If Exit modal is open -> close it
      var exitModal = document.getElementById('exit-modal');
      if (exitModal && exitModal.classList.contains('active')) {
        closeModal(exitModal);
        return true;
      }

      // 2. If Smart IPTV Live Overlays are open -> close top overlay
      var epgOverlay = document.getElementById('live-epg-overlay');
      if (epgOverlay && epgOverlay.style.display !== 'none') {
        closeLiveEpgOverlay();
        return true;
      }

      var catMenu = document.getElementById('live-category-menu');
      if (catMenu && catMenu.style.display !== 'none') {
        closeLiveCategoryMenu();
        // If channel menu is also open, refocus active channel
        var channelMenu = document.getElementById('live-channel-menu');
        if (channelMenu && channelMenu.style.display !== 'none') {
          var firstItem = channelMenu.querySelector('.channel-menu-item.active') || channelMenu.querySelector('.channel-menu-item');
          if (firstItem && window.SpatialNav) window.SpatialNav.setFocus(firstItem);
        }
        return true;
      }

      var channelMenu = document.getElementById('live-channel-menu');
      if (channelMenu && channelMenu.style.display !== 'none') {
        closeLiveChannelMenu();
        return true;
      }

      // 3. If In-Player Series episodes drawer is open -> close it
      var seriesDrawer = document.getElementById('drawer-series-episodes');
      if (seriesDrawer && seriesDrawer.classList.contains('open')) {
        seriesDrawer.classList.remove('open');
        return true;
      }

      // 4. If any Modal is active -> close topmost modal
      var activeModals = document.querySelectorAll('.modal-overlay.active');
      if (activeModals.length > 0) {
        var topModal = activeModals[activeModals.length - 1];
        closeModal(topModal);
        if (topModal.id === 'login-modal' && window.TVSync) {
          window.TVSync.stopPolling();
        }
        return true;
      }

      // 5. If Player HUD is visible in Fullscreen VOD -> close HUD first
      var vodHud = document.getElementById('player-hud-vod');
      if (vodHud && vodHud.classList.contains('visible')) {
        _player.hideHud();
        return true;
      }

      // 6. If Player is in Fullscreen -> return to Preview mode or stop VOD
      if ((_player && _player.currentMode === 'fullscreen') || document.body.classList.contains('player-fullscreen')) {
        if (_player.playbackType === 'live') {
          _player.setMode('preview');
          if (_player.currentCategory) {
            selectLiveCategory(_player.currentCategory);
          }
        } else {
          _player.stop(false);
          _player.setMode('preview');
          renderContinueWatching('movie');
          renderContinueWatching('series');
          restoreMediaFocusAfterVod();
        }
        return true;
      }

      // 6. If in Dashboard -> return to Account List screen
      var dashboard = document.getElementById('view-dashboard');
      if (dashboard && dashboard.classList.contains('active')) {
        showAccountListScreen();
        return true;
      }

      // 7. At root Accounts Screen -> show Exit confirmation
      showExitModal();
      return true;
    });
  }

  // =========================================================
  // 8. ADD ACCOUNT & MODAL SETUP
  // =========================================================
  var _editingAccountId = null;

  function setupModals() {
    var addBtn = document.getElementById('accounts-add-btn');
    if (addBtn) addBtn.onclick = function() { showAddAccountModal(); };

    // Close buttons for modals
    var modalCloses = [
      { id: 'modal-close-btn', modal: 'login-modal' },
      { id: 'login-cancel-btn', modal: 'login-modal' },
      { id: 'movie-detail-close-btn', modal: 'modal-movie-detail' },
      { id: 'series-detail-close-btn', modal: 'modal-series-detail' },
      { id: 'master-search-close-btn', modal: 'modal-master-search' },
      { id: 'pref-close-btn', modal: 'modal-preferences' },
      { id: 'lang-close-btn', modal: 'modal-language' },
      { id: 'audio-selector-close-btn', modal: 'modal-audio-selector' },
      { id: 'sub-selector-close-btn', modal: 'modal-sub-selector' },
      { id: 'resume-close-btn', modal: 'modal-resume-playback' },
      { id: 'exit-cancel-btn', modal: 'exit-modal' },
      { id: 'delete-account-close-btn', modal: 'delete-account-modal' },
      { id: 'delete-account-cancel-btn', modal: 'delete-account-modal' },
      { id: 'cat-mgr-close-btn', modal: 'modal-category-manager' },
      { id: 'ctx-close-btn', modal: 'modal-stream-context' },
      { id: 'create-list-close-btn', modal: 'modal-create-list' },
      { id: 'create-list-cancel-btn', modal: 'modal-create-list' },
      { id: 'custom-list-options-close-btn', modal: 'modal-custom-list-options' },
      { id: 'opt-list-cancel-btn', modal: 'modal-custom-list-options' },
      { id: 'delete-list-close-btn', modal: 'modal-delete-list' },
      { id: 'delete-list-cancel-btn', modal: 'modal-delete-list' },
      { id: 'sync-modal-close-btn', modal: 'modal-playlist-sync' }
    ];

    modalCloses.forEach(function(item) {
      var btn = document.getElementById(item.id);
      if (btn) {
        btn.onclick = function() {
          var m = document.getElementById(item.modal);
          if (m) closeModal(m);
          if (item.modal === 'delete-account-modal') {
            _accountPendingDelete = null;
          }
          if (item.modal === 'login-modal' && window.TVSync) {
            window.TVSync.stopPolling();
          }
        };
      }
    });

    // Category Manager Modal Toolbar
    var toggleHiddenBtn = document.getElementById('cat-mgr-toggle-hidden');
    if (toggleHiddenBtn) {
      toggleHiddenBtn.onclick = function() {
        _showHiddenCategories = !_showHiddenCategories;
        if (_moveModeActive) exitCategoryMoveMode();
        renderCategoryManagerList();
      };
    }

    var unhideAllBtn = document.getElementById('cat-mgr-unhide-all');
    if (unhideAllBtn) {
      unhideAllBtn.onclick = function() {
        if (_activeAccount && window.TVStorage) {
          var allCats = getAllCategoriesForManager(_activeCategoryManagerType);
          var prefs = window.TVStorage.getCategoryPrefs(_activeAccount.id, _activeCategoryManagerType);
          var hiddenMap = {};
          (prefs.hidden || []).forEach(function(id) { hiddenMap[id] = true; });
          var allVisible = allCats.length > 0 && allCats.every(function(c) {
            return !hiddenMap[String(c.category_id || c.categoryId)];
          });
          _catMgrDirty = true;
          markCategoriesDirty(_activeCategoryManagerType);
          if (_moveModeActive) exitCategoryMoveMode();
          if (allVisible) {
            prefs.hidden = allCats.map(function(c) { return String(c.category_id || c.categoryId); });
            window.TVStorage.saveCategoryPrefs(_activeAccount.id, _activeCategoryManagerType, prefs);
            renderCategoryManagerList();
            showToast((window.TVI18n && window.TVI18n.getLanguage() === 'de') ? 'Alle Kategorien ausgeblendet' : 'All categories hidden', 'check');
          } else {
            window.TVStorage.unhideAllCategories(_activeAccount.id, _activeCategoryManagerType);
            renderCategoryManagerList();
            showToast((window.TVI18n && window.TVI18n.getLanguage() === 'de') ? 'Alle Kategorien eingeblendet' : 'All categories shown', 'check');
          }
        }
      };
    }

    var resetAzBtn = document.getElementById('cat-mgr-reset-az');
    if (resetAzBtn) {
      resetAzBtn.onclick = function() {
        if (_activeAccount && window.TVStorage) {
          var allCats = getAllCategoriesForManager(_activeCategoryManagerType);
          window.TVStorage.resetCategorySortOrder(_activeAccount.id, _activeCategoryManagerType, allCats);
          _catMgrDirty = true;
          markCategoriesDirty(_activeCategoryManagerType);
          if (_moveModeActive) exitCategoryMoveMode();
          renderCategoryManagerList();
          showToast((window.TVI18n && window.TVI18n.getLanguage() === 'de') ? 'A-Z Sortierung wiederhergestellt' : 'A-Z sort restored', 'check');
        }
      };
    }

    // Category Manager Open Buttons in Search Bars
    var liveCatManageBtn = document.getElementById('live-cat-manage-btn');
    if (liveCatManageBtn) liveCatManageBtn.onclick = function() { openCategoryManager('live'); };
    var moviesCatManageBtn = document.getElementById('movies-cat-manage-btn');
    if (moviesCatManageBtn) moviesCatManageBtn.onclick = function() { openCategoryManager('movie'); };
    var seriesCatManageBtn = document.getElementById('series-cat-manage-btn');
    if (seriesCatManageBtn) seriesCatManageBtn.onclick = function() { openCategoryManager('series'); };

    // Stream Context Custom List Actions
    var ctxCreateListBtn = document.getElementById('ctx-create-list-btn');
    if (ctxCreateListBtn) {
      ctxCreateListBtn.onclick = function() {
        if (Date.now() < _ignoreContextClicksUntil) return;
        openCreateOrRenameListModal('create', null, _activeContextType);
      };
    }

    var createListSubmit = document.getElementById('create-list-submit-btn');
    if (createListSubmit) {
      createListSubmit.onclick = function() {
        var input = document.getElementById('create-list-input');
        var name = (input ? input.value : '').trim();
        if (!name) return;
        var ctxModal = document.getElementById('modal-stream-context');
        var catMgrModal = document.getElementById('modal-category-manager');
        var listType = _activeCreateListType ||
                       (_activeCustomList && _activeCustomList.type) ||
                       ((ctxModal && ctxModal.classList.contains('active')) ? _activeContextType : _activeCategoryManagerType) ||
                       'live';
        var targetCustomId = null;
        if (_createListMode === 'rename' && _activeCustomList) {
          targetCustomId = _activeCustomList.id;
          window.TVStorage.renameCustomList(_activeAccount.id, _activeCustomList.id, name, listType);
          closeModal(document.getElementById('modal-create-list'));
          showToast((window.TVI18n && window.TVI18n.getLanguage() === 'de') ? 'Liste "' + name + '" umbenannt' : 'List "' + name + '" renamed', 'check');
        } else {
          var newList = window.TVStorage.createCustomList(_activeAccount.id, name, listType);
          if (newList) {
            targetCustomId = newList.id;
            if (ctxModal && ctxModal.classList.contains('active') && _activeContextStream) {
              if (typeof window.TVStorage.saveStreamSnapshot === 'function') {
                window.TVStorage.saveStreamSnapshot(_activeAccount.id, listType, _activeContextStream);
              }
              window.TVStorage.addStreamToCustomList(_activeAccount.id, newList.id, _activeContextStream);
            }
          }
          markCategoriesDirty(listType);
          closeModal(document.getElementById('modal-create-list'));
          showToast((window.TVI18n && window.TVI18n.getLanguage() === 'de') ? 'Liste "' + name + '" erstellt' : 'List "' + name + '" created', 'check');
        }
        if (ctxModal && ctxModal.classList.contains('active')) {
          renderContextCustomLists();
          var ctxRow = targetCustomId ? document.querySelector('#ctx-custom-lists-container .ctx-list-row[data-list-id="' + targetCustomId + '"]') : null;
          var ctxFallback = ctxRow || document.getElementById('ctx-create-list-btn');
          if (ctxFallback && window.SpatialNav) window.SpatialNav.setFocus(ctxFallback);
        }
        if (catMgrModal && catMgrModal.classList.contains('active')) {
          _catMgrDirty = true;
          renderCategoryManagerList();
          var mgrRow = targetCustomId ? document.querySelector('#cat-mgr-list .cat-mgr-item[data-custom-id="' + targetCustomId + '"]') : null;
          var mgrFallback = mgrRow || document.querySelector('#cat-mgr-list .cat-mgr-item') || document.getElementById('cat-mgr-toggle-hidden');
          if (mgrFallback && window.SpatialNav) window.SpatialNav.setFocus(mgrFallback);
        }
        if (listType === 'live') renderLiveCategories(_liveCategories, true, _selectedLiveCategory ? _selectedLiveCategory.category_id : null);
        else if (listType === 'movie') renderMovieCategories(_movieCategories, true, _selectedMovieCategory ? _selectedMovieCategory.category_id : null);
        else if (listType === 'series') renderSeriesCategories(_seriesCategories, true, _selectedSeriesCategory ? _selectedSeriesCategory.category_id : null);
      };
    }

    // Custom List Options Modal Actions
    var optListMoveBtn = document.getElementById('opt-list-move-btn');
    if (optListMoveBtn) {
      optListMoveBtn.onclick = function() {
        var cl = _activeCustomList;
        closeModal(document.getElementById('modal-custom-list-options'));
        if (!cl) return;
        var moveCatId = 'custom_list:' + cl.id;
        var catMgrModal = document.getElementById('modal-category-manager');
        if (catMgrModal && catMgrModal.classList.contains('active')) {
          var prevId = _moveModeCategoryId;
          _moveModeActive = true;
          _moveModeCategoryId = moveCatId;
          window._moveModeActive = true;
          updateCatMgrToolbarState();
          if (prevId && prevId !== moveCatId) {
            var prevEl = document.querySelector('#cat-mgr-list .cat-mgr-item[data-cat-id="' + prevId + '"]');
            if (prevEl) patchCatMgrRow(prevEl, !!_catMgrHiddenSet[prevId], false);
          }
          var listEl = document.getElementById('cat-mgr-list');
          if (listEl) {
            for (var i = 0; i < _catMgrDisplayedList.length; i++) {
              if (String(_catMgrDisplayedList[i].category_id || _catMgrDisplayedList[i].categoryId) === moveCatId) {
                while (_catMgrRenderedCount <= i && appendCatMgrBatch()) {}
                break;
              }
            }
            var targetEl = listEl.querySelector('.cat-mgr-item[data-cat-id="' + moveCatId + '"]');
            if (targetEl) {
              patchCatMgrRow(targetEl, !!_catMgrHiddenSet[moveCatId], true);
              if (window.SpatialNav) window.SpatialNav.setFocus(targetEl);
            }
          }
        } else {
          var ctxModal = document.getElementById('modal-stream-context');
          if (ctxModal && ctxModal.classList.contains('active')) {
            closeModal(ctxModal);
          }
          _catMgrCooldownUntil = 0;
          openCategoryManager(cl.type || _activeContextType || _activeCategoryManagerType, moveCatId);
        }
      };
    }

    var optListRenameBtn = document.getElementById('opt-list-rename-btn');
    if (optListRenameBtn) {
      optListRenameBtn.onclick = function() {
        var cl = _activeCustomList;
        closeModal(document.getElementById('modal-custom-list-options'));
        if (cl) {
          openCreateOrRenameListModal('rename', cl, cl.type);
        }
      };
    }

    var optListDeleteBtn = document.getElementById('opt-list-delete-btn');
    if (optListDeleteBtn) {
      optListDeleteBtn.onclick = function() {
        var cl = _activeCustomList;
        closeModal(document.getElementById('modal-custom-list-options'));
        if (cl) {
          openDeleteListModal(cl);
        }
      };
    }

    var optListCancelBtn = document.getElementById('opt-list-cancel-btn');
    if (optListCancelBtn) {
      optListCancelBtn.onclick = function() {
        closeModal(document.getElementById('modal-custom-list-options'));
      };
    }

    var deleteListConfirmBtn = document.getElementById('delete-list-confirm-btn');
    if (deleteListConfirmBtn) {
      deleteListConfirmBtn.onclick = function() {
        if (_activeCustomList && _activeAccount) {
          var deletedId = _activeCustomList.id;
          var name = _activeCustomList.name || '';
          var listType = (_activeCustomList && _activeCustomList.type) || _activeCategoryManagerType || _activeContextType || 'live';
          window.TVStorage.deleteCustomList(_activeAccount.id, deletedId, listType);
          markCategoriesDirty(listType);
          _activeCustomList = null;
          closeModal(document.getElementById('modal-delete-list'));
          showToast((window.TVI18n && window.TVI18n.getLanguage() === 'de') ? 'Liste "' + name + '" gelöscht' : 'List "' + name + '" deleted', 'trash');
          var ctxModal = document.getElementById('modal-stream-context');
          if (ctxModal && ctxModal.classList.contains('active')) {
            renderContextCustomLists();
            var ctxFocus = document.querySelector('#ctx-custom-lists-container .ctx-list-row') || document.getElementById('ctx-create-list-btn');
            if (ctxFocus && window.SpatialNav) window.SpatialNav.setFocus(ctxFocus);
          }
          var catMgrModal = document.getElementById('modal-category-manager');
          if (catMgrModal && catMgrModal.classList.contains('active')) {
            _catMgrDirty = true;
            renderCategoryManagerList();
            var mgrFocus = document.querySelector('#cat-mgr-list .cat-mgr-item') || document.getElementById('cat-mgr-toggle-hidden');
            if (mgrFocus && window.SpatialNav) window.SpatialNav.setFocus(mgrFocus);
          }
          if (listType === 'live') {
            var liveFallbackId = (_selectedLiveCategory && _selectedLiveCategory.category_id === 'custom_list:' + deletedId) ? 'favorites' : null;
            renderLiveCategories(_liveCategories, true, liveFallbackId);
          } else if (listType === 'movie') {
            var movFallbackId = (_selectedMovieCategory && _selectedMovieCategory.category_id === 'custom_list:' + deletedId) ? 'favorites' : null;
            renderMovieCategories(_movieCategories, true, movFallbackId);
          } else if (listType === 'series') {
            var serFallbackId = (_selectedSeriesCategory && _selectedSeriesCategory.category_id === 'custom_list:' + deletedId) ? 'favorites' : null;
            renderSeriesCategories(_seriesCategories, true, serFallbackId);
          }
        }
      };
    }

    // Scope selection chips in Login / Add Account modal
    ['login-scope-live', 'login-scope-movies', 'login-scope-series'].forEach(function(chipId) {
      var chip = document.getElementById(chipId);
      if (chip) {
        chip.onclick = function() {
          var activeChips = document.querySelectorAll('.scope-chips-row .scope-chip.active');
          if (chip.classList.contains('active') && activeChips.length <= 1) {
            var msg = (window.TVI18n && window.TVI18n.t('min_one_scope')) ||
                      ((window.TVI18n && window.TVI18n.getLanguage() === 'de') ? 'Mindestens ein Bereich muss aktiv bleiben' : 'At least one category must remain active');
            showToast(msg, 'alert');
            return;
          }
          var isAct = !chip.classList.contains('active');
          setScopeChip(chipId, isAct);
        };
      }
    });

    var doneBtnInit = document.getElementById('remote-done-btn');
    if (doneBtnInit) {
      doneBtnInit.onclick = function(e) {
        handleRemoteDone(e);
      };
    }

    var exitConfirm = document.getElementById('exit-confirm-btn');
    if (exitConfirm) exitConfirm.onclick = function() { exitApp(); };

    var deleteAccountConfirm = document.getElementById('delete-account-confirm-btn');
    if (deleteAccountConfirm) {
      deleteAccountConfirm.onclick = function() {
        if (_accountPendingDelete) {
          var acc = _accountPendingDelete;
          _accountPendingDelete = null;
          window.TVStorage.deleteAccount(acc.id);
          if (window.TVSync && window.TVSync.pushPlaylists) {
            window.TVSync.pushPlaylists();
          }
          if (window.TVApi && window.TVApi.clearCache) {
            window.TVApi.clearCache(acc.id);
          }
          if (_activeAccount && _activeAccount.id === acc.id) {
            resetAllAccountState();
            _activeAccount = null;
            window._activeAccount = null;
          }
          closeModal(document.getElementById('delete-account-modal'));
          var toastDel = (window.TVI18n && window.TVI18n.getLanguage() === 'de') ? ' gelöscht' : ' deleted';
          showToast((acc.name || acc.username) + toastDel, 'trash');
          renderAccountsList();
        }
      };
    }

    // Segmented tab switch in Add Account Modal
    var tabManual = document.getElementById('tab-btn-manual');
    var tabRemote = document.getElementById('tab-btn-remote');
    var viewManual = document.getElementById('view-manual');
    var viewRemote = document.getElementById('view-remote');

    if (tabManual && tabRemote) {
      tabManual.onclick = function() {
        tabManual.classList.add('active');
        tabRemote.classList.remove('active');
        viewManual.classList.add('active');
        viewRemote.classList.remove('active');
        tabManual.setAttribute('data-nav-down', '#login-playlist-name');
        tabRemote.setAttribute('data-nav-down', '#login-playlist-name');
        if (window.TVSync) window.TVSync.stopPolling();
      };
      tabRemote.onclick = function() {
        tabRemote.classList.add('active');
        tabManual.classList.remove('active');
        viewRemote.classList.add('active');
        viewManual.classList.remove('active');
        tabManual.setAttribute('data-nav-down', '#remote-refresh-btn');
        tabRemote.setAttribute('data-nav-down', '#remote-refresh-btn');
        initRemotePairing();
      };
    }

    var refreshQrBtn = document.getElementById('remote-refresh-btn');
    if (refreshQrBtn) refreshQrBtn.onclick = function() { initRemotePairing(); };

    // Playlist Type Switcher (Xtream vs M3U)
    var currentType = 'xtream';
    var typeBtnXtream = document.getElementById('type-btn-xtream');
    var typeBtnM3u = document.getElementById('type-btn-m3u');
    var groupUser = document.getElementById('group-username');
    var groupPass = document.getElementById('group-password');
    var labelServer = document.getElementById('label-server');
    var inputServer = document.getElementById('login-server');
    var userInput = document.getElementById('login-username');
    var passInput = document.getElementById('login-password');
    var submitBtn = document.getElementById('login-submit-btn');

    function setPlaylistType(type) {
      currentType = type;
      var syncScopesGroup = document.getElementById('login-sync-scopes-group');
      if (type === 'm3u') {
        if (typeBtnM3u) typeBtnM3u.classList.add('active');
        if (typeBtnXtream) typeBtnXtream.classList.remove('active');
        if (groupUser) groupUser.style.display = 'none';
        if (groupPass) groupPass.style.display = 'none';
        if (syncScopesGroup) syncScopesGroup.style.display = 'none';
        if (userInput) userInput.required = false;
        if (passInput) passInput.required = false;
        if (labelServer) {
          labelServer.innerHTML = '<span>' + (window.TVI18n ? window.TVI18n.t('m3u_url') : 'M3U Playlist URL') + '</span> <span class="label-required">*</span>';
        }
        if (inputServer) {
          inputServer.placeholder = 'https://example.com/playlist.m3u';
          inputServer.setAttribute('data-nav-down', '#login-submit-btn');
        }
        if (submitBtn) {
          submitBtn.setAttribute('data-nav-up', '#login-server');
          var cancelBtn = document.getElementById('login-cancel-btn');
          if (cancelBtn) cancelBtn.setAttribute('data-nav-up', '#login-server');
        }
      } else {
        if (typeBtnXtream) typeBtnXtream.classList.add('active');
        if (typeBtnM3u) typeBtnM3u.classList.remove('active');
        if (groupUser) groupUser.style.display = 'block';
        if (groupPass) groupPass.style.display = 'block';
        if (syncScopesGroup) syncScopesGroup.style.display = 'block';
        if (userInput) userInput.required = true;
        if (passInput) passInput.required = true;
        if (labelServer) {
          labelServer.innerHTML = '<span>' + (window.TVI18n ? window.TVI18n.t('server_url') : 'Server URL') + '</span> <span class="label-required">*</span>';
        }
        if (inputServer) {
          inputServer.placeholder = 'http://example.com:8080';
          inputServer.setAttribute('data-nav-down', '#login-username');
        }
        if (passInput) {
          passInput.setAttribute('data-nav-down', '#login-scope-live');
        }
        if (submitBtn) {
          submitBtn.setAttribute('data-nav-up', '#login-scope-live');
          var cancelBtn = document.getElementById('login-cancel-btn');
          if (cancelBtn) cancelBtn.setAttribute('data-nav-up', '#login-scope-live');
        }
      }
    }
    if (typeBtnXtream) typeBtnXtream.onclick = function() { setPlaylistType('xtream'); };
    if (typeBtnM3u) typeBtnM3u.onclick = function() { setPlaylistType('m3u'); };

    // Login Form Submit
    var loginForm = document.getElementById('login-form');
    if (loginForm) {
      loginForm.onsubmit = function(e) {
        e.preventDefault();
        var playlistName = document.getElementById('login-playlist-name').value;
        var server = document.getElementById('login-server').value;
        var user = document.getElementById('login-username').value;
        var pass = document.getElementById('login-password').value;
        var statusEl = document.getElementById('login-status');
        var submitBtn = document.getElementById('login-submit-btn');

        var scopeLive = document.getElementById('login-scope-live') ? document.getElementById('login-scope-live').classList.contains('active') : true;
        var scopeMovies = document.getElementById('login-scope-movies') ? document.getElementById('login-scope-movies').classList.contains('active') : true;
        var scopeSeries = document.getElementById('login-scope-series') ? document.getElementById('login-scope-series').classList.contains('active') : true;

        var oldAcc = null;
        if (_editingAccountId && window.TVStorage && typeof window.TVStorage.getAccounts === 'function') {
          var existingAccs = window.TVStorage.getAccounts() || [];
          oldAcc = existingAccs.find(function(a) { return String(a.id) === String(_editingAccountId); }) || null;
        }
        var oldIsM3u = oldAcc ? (oldAcc.type === 'm3u') : false;
        var newIsM3u = (currentType === 'm3u');
        var trimServer = (server || '').trim();
        var trimUser = (user || '').trim();
        var credsUnchanged = !!(oldAcc && oldIsM3u === newIsM3u &&
          trimServer === String(oldAcc.serverUrl || '').trim() &&
          (newIsM3u || (trimUser === String(oldAcc.username || '').trim() && (pass || '') === String(oldAcc.password || ''))));

        if (credsUnchanged) {
          var cleanNameSame = playlistName.trim();
          if (newIsM3u) {
            if (!cleanNameSame) {
              var partsSame = trimServer.split('?')[0].split('/');
              var fnSame = partsSame[partsSame.length - 1] || 'playlist.m3u';
              cleanNameSame = fnSame.replace(/\.(m3u8?)$/i, '').toUpperCase() + ' (M3U)';
            }
          } else if (!cleanNameSame) {
            cleanNameSame = oldAcc.name || oldAcc.username || trimUser;
          }
          var sameAccData = {
            id: _editingAccountId,
            type: newIsM3u ? 'm3u' : undefined,
            serverUrl: trimServer,
            username: newIsM3u ? '' : trimUser,
            password: newIsM3u ? '' : pass,
            name: cleanNameSame,
            syncLiveTv: newIsM3u ? (oldAcc.syncLiveTv !== false) : scopeLive,
            syncMovies: newIsM3u ? (oldAcc.syncMovies !== false) : scopeMovies,
            syncSeries: newIsM3u ? (oldAcc.syncSeries !== false) : scopeSeries
          };
          if (!newIsM3u && window.TVApi && window.TVApi.clearCache) {
            if (!scopeLive) window.TVApi.clearCache(sameAccData.id, 'live');
            if (!scopeMovies) window.TVApi.clearCache(sameAccData.id, 'vod');
            if (!scopeSeries) window.TVApi.clearCache(sameAccData.id, 'series');
          }
          var savedSameAcc = window.TVStorage.saveAccount(sameAccData);
          _editingAccountId = null;
          if (submitBtn) submitBtn.disabled = false;
          if (window.TVSync && window.TVSync.pushPlaylists) {
            window.TVSync.pushPlaylists();
          }
          closeModal(document.getElementById('login-modal'));
          var sameMsg = (window.TVI18n && window.TVI18n.getLanguage() === 'de')
            ? 'Playlist aktualisiert: ' + (savedSameAcc.name || savedSameAcc.username)
            : 'Playlist updated: ' + (savedSameAcc.name || savedSameAcc.username);
          showToast(sameMsg, 'edit');
          renderAccountsList();
          updateNavRailScopes();
          enterDashboardWithAccount(savedSameAcc, { showSplash: false });
          return;
        }

        if (currentType === 'm3u') {
          if (statusEl) statusEl.textContent = window.TVI18n ? window.TVI18n.t('loading_m3u') : 'Downloading and parsing M3U playlist...';
          if (submitBtn) submitBtn.disabled = true;

          window.TVApi.authenticateM3u(server, playlistName)
            .then(function(res) {
              var cleanName = playlistName.trim();
              if (!cleanName) {
                var urlParts = server.split('?')[0].split('/');
                var filename = urlParts[urlParts.length - 1] || 'playlist.m3u';
                cleanName = filename.replace(/\.(m3u8?)$/i, '').toUpperCase() + ' (M3U)';
              }
              var accData = {
                type: 'm3u',
                serverUrl: server.trim(),
                username: '',
                password: '',
                name: cleanName,
                channelCount: res.streamCount,
                categoryCount: res.categoryCount,
                syncLiveTv: true,
                syncMovies: true,
                syncSeries: true
              };
              if (_editingAccountId) accData.id = _editingAccountId;
              var acc = window.TVStorage.saveAccount(accData);
              _editingAccountId = null;
              if (submitBtn) submitBtn.disabled = false;
              if (window.TVStorage.saveM3uData) {
                window.TVStorage.saveM3uData(acc.id, res.parsed);
              }
              if (window.TVSync && window.TVSync.pushPlaylists) {
                window.TVSync.pushPlaylists();
              }
              closeModal(document.getElementById('login-modal'));
              var toastMsg = (window.TVI18n && window.TVI18n.getLanguage() === 'de')
                ? 'M3U-Playlist hinzugefügt: ' + acc.name + ' (' + res.streamCount + ' Sender)'
                : 'M3U Playlist added: ' + acc.name + ' (' + res.streamCount + ' channels)';
              showToast(toastMsg, 'tv');
              renderAccountsList();
              updateNavRailScopes();
              enterDashboardWithAccount(acc, { showSplash: true });
            })
            .catch(function(err) {
              if (submitBtn) submitBtn.disabled = false;
              var errPrefix = (window.TVI18n && window.TVI18n.getLanguage() === 'de') ? 'Fehler: ' : 'Error: ';
              if (statusEl) statusEl.textContent = errPrefix + (err.message || 'Failed to load M3U playlist');
            });
          return;
        }

        if (statusEl) statusEl.textContent = window.TVI18n ? window.TVI18n.t('connecting_server') : 'Connecting to IPTV server...';
        if (submitBtn) submitBtn.disabled = true;

        window.TVApi.authenticate(server, user, pass)
          .then(function(data) {
            var accData = {
              serverUrl: server,
              username: user,
              password: pass,
              name: playlistName.trim().length > 0 ? playlistName.trim() : (data.userInfo && data.userInfo.username) || user,
              expDate: (data.userInfo && data.userInfo.exp_date !== undefined) ? data.userInfo.exp_date : null,
              maxConnections: (data.userInfo && data.userInfo.max_connections !== undefined) ? data.userInfo.max_connections : null,
              activeConnections: (data.userInfo && data.userInfo.active_cons !== undefined) ? data.userInfo.active_cons : null,
              syncLiveTv: scopeLive,
              syncMovies: scopeMovies,
              syncSeries: scopeSeries
            };
            if (_editingAccountId) {
              accData.id = _editingAccountId;
              if (window.TVApi && window.TVApi.clearCache) {
                if (!scopeLive) window.TVApi.clearCache(accData.id, 'live');
                if (!scopeMovies) window.TVApi.clearCache(accData.id, 'vod');
                if (!scopeSeries) window.TVApi.clearCache(accData.id, 'series');
              }
            }
            var acc = window.TVStorage.saveAccount(accData);
            _editingAccountId = null;
            if (submitBtn) submitBtn.disabled = false;
            if (window.TVSync && window.TVSync.pushPlaylists) {
              window.TVSync.pushPlaylists();
            }
            closeModal(document.getElementById('login-modal'));
            var toastPrefix = window.TVI18n ? window.TVI18n.t('account_added_toast') : 'Account added: ';
            showToast(toastPrefix + (acc.name || acc.username), 'info');
            renderAccountsList();
            updateNavRailScopes();
            enterDashboardWithAccount(acc, { showSplash: true });
          })
          .catch(function(err) {
            if (submitBtn) submitBtn.disabled = false;
            var errPrefix = (window.TVI18n && window.TVI18n.getLanguage() === 'de') ? 'Fehler: ' : 'Error: ';
            if (statusEl) statusEl.textContent = errPrefix + err.message;
          });
      };
    }
  }

  function showAddAccountModal() {
    _editingAccountId = null;
    var modal = document.getElementById('login-modal');
    var titleEl = document.getElementById('modal-account-title');
    if (titleEl) titleEl.textContent = window.TVI18n ? window.TVI18n.t('add_account') : 'Add Account';
    document.getElementById('login-playlist-name').value = '';
    document.getElementById('login-server').value = '';
    document.getElementById('login-username').value = '';
    document.getElementById('login-password').value = '';
    document.getElementById('login-status').textContent = '';
    var submitBtnAdd = document.getElementById('login-submit-btn');
    if (submitBtnAdd) submitBtnAdd.disabled = false;

    var modeTabs = document.getElementById('login-mode-tabs');
    if (modeTabs) modeTabs.style.display = 'flex';

    setScopeChip('login-scope-live', true);
    setScopeChip('login-scope-movies', true);
    setScopeChip('login-scope-series', true);

    var tabManual = document.getElementById('tab-btn-manual');
    var tabRemote = document.getElementById('tab-btn-remote');
    var viewManual = document.getElementById('view-manual');
    var viewRemote = document.getElementById('view-remote');
    if (tabManual && tabRemote && viewManual && viewRemote) {
      tabManual.classList.add('active');
      tabRemote.classList.remove('active');
      viewManual.classList.add('active');
      viewRemote.classList.remove('active');
      tabManual.setAttribute('data-nav-down', '#type-btn-xtream');
      tabRemote.setAttribute('data-nav-down', '#type-btn-xtream');
      if (window.TVSync) window.TVSync.stopPolling();
    }

    var typeBtnXtream = document.getElementById('type-btn-xtream');
    if (typeBtnXtream) typeBtnXtream.click();

    openModal(modal, document.getElementById('login-playlist-name'));
  }

  function showEditAccountModal(acc) {
    _editingAccountId = acc ? acc.id : null;
    var modal = document.getElementById('login-modal');
    var titleEl = document.getElementById('modal-account-title');
    if (titleEl) titleEl.textContent = window.TVI18n ? window.TVI18n.t('edit_account') : 'Edit Account';
    document.getElementById('login-playlist-name').value = acc.name || '';
    document.getElementById('login-server').value = acc.serverUrl || '';
    document.getElementById('login-username').value = acc.username || '';
    document.getElementById('login-password').value = acc.password || '';
    document.getElementById('login-status').textContent = '';
    var submitBtnEdit = document.getElementById('login-submit-btn');
    if (submitBtnEdit) submitBtnEdit.disabled = false;

    var modeTabs = document.getElementById('login-mode-tabs');
    if (modeTabs) modeTabs.style.display = 'none';

    var viewManual = document.getElementById('view-manual');
    var viewRemote = document.getElementById('view-remote');
    if (viewManual) viewManual.classList.add('active');
    if (viewRemote) viewRemote.classList.remove('active');
    if (window.TVSync) window.TVSync.stopPolling();

    setScopeChip('login-scope-live', acc.syncLiveTv !== false);
    setScopeChip('login-scope-movies', acc.syncMovies !== false);
    setScopeChip('login-scope-series', acc.syncSeries !== false);

    if (acc.type === 'm3u') {
      var typeBtnM3u = document.getElementById('type-btn-m3u');
      if (typeBtnM3u) typeBtnM3u.click();
    } else {
      var typeBtnXtream = document.getElementById('type-btn-xtream');
      if (typeBtnXtream) typeBtnXtream.click();
    }

    openModal(modal, document.getElementById('login-playlist-name'));
  }

  var _accountPendingDelete = null;

  function showDeleteAccountModal(acc) {
    if (!acc) return;
    _accountPendingDelete = acc;
    var modal = document.getElementById('delete-account-modal');
    var msgEl = document.getElementById('delete-account-msg');
    if (msgEl) {
      var template = window.TVI18n ? window.TVI18n.t('delete_confirm') : 'Delete account "{name}"?';
      msgEl.textContent = template.replace('{name}', acc.name || acc.username);
    }
    openModal(modal, document.getElementById('delete-account-cancel-btn'));
  }

  function handleRemoteDone(e) {
    if (e) {
      try { e.preventDefault(); e.stopPropagation(); } catch(err){}
    }
    if (window.TVSync) {
      window.TVSync.stopPolling();
      window.TVSync.closePairingSession(window.TVSync.getDeviceId());
    }
    if (_remoteTimer) {
      clearInterval(_remoteTimer);
      _remoteTimer = null;
    }
    _lastAddedAccount = null;

    var modal = document.getElementById('login-modal');
    if (modal) {
      closeModal(modal);
    }

    renderAccountsList();
    setTimeout(function() {
      var gridEl = document.getElementById('accounts-grid');
      if (gridEl && gridEl.style.display !== 'none' && gridEl.children.length > 0 && window.SpatialNav) {
        window.SpatialNav.focusFirst(gridEl);
      } else {
        var addBtn = document.getElementById('accounts-add-btn');
        if (addBtn && window.SpatialNav) {
          window.SpatialNav.setFocus(addBtn);
        }
      }
    }, 100);
  }

  function initRemotePairing() {
    _lastAddedAccount = null;
    var qrLoading = document.getElementById('qr-loading');
    var qrBox = document.getElementById('qrcode-box');
    var devIdEl = document.getElementById('remote-device-id');
    var pinEl = document.getElementById('remote-pin');
    var statusEl = document.getElementById('remote-status-text');

    if (qrLoading) qrLoading.style.display = 'flex';
    if (statusEl) statusEl.textContent = window.TVI18n ? window.TVI18n.t('generating_session') : 'Generating pairing session...';

    if (_remoteTimer) {
      clearInterval(_remoteTimer);
      _remoteTimer = null;
    }

    window.TVSync.startPairingSession()
      .then(function(session) {
        _remoteSession = session;
        if (qrLoading) qrLoading.style.display = 'none';
        if (devIdEl) devIdEl.textContent = session.deviceId;
        if (pinEl) pinEl.textContent = session.pin;
        if (statusEl) statusEl.textContent = window.TVI18n ? window.TVI18n.t('waiting_for_playlist') : 'Waiting for playlist from phone...';

        if (qrBox) {
          qrBox.innerHTML = '';
          try {
            _qrCodeInstance = new window.QRCode(qrBox, {
              text: session.qrUrl,
              width: 190,
              height: 190,
              colorDark: '#000000',
              colorLight: '#FFFFFF',
              correctLevel: window.QRCode.CorrectLevel.M
            });
          } catch(e){}
        }

        var doneBtn = document.getElementById('remote-done-btn');
        if (doneBtn) doneBtn.style.display = 'none';
        var statusRow = document.querySelector('.info-status-row');
        if (statusRow) statusRow.classList.remove('received');

        var countdownEl = document.getElementById('remote-countdown');
        function updateCountdown() {
          var remSec = Math.max(0, Math.floor((session.expiresAt.getTime() - Date.now()) / 1000));
          var m = String(Math.floor(remSec / 60)).padStart(2, '0');
          var s = String(remSec % 60).padStart(2, '0');
          if (countdownEl) countdownEl.textContent = m + ':' + s;
          if (remSec <= 0) {
            clearInterval(_remoteTimer);
            if (statusEl) statusEl.textContent = window.TVI18n ? window.TVI18n.t('session_expired') : 'Session expired. Click "New Code" to refresh.';
          }
        }
        updateCountdown();
        _remoteTimer = setInterval(updateCountdown, 1000);

        window.TVSync.startPolling(session.deviceId, function(event) {
          var showRemoteSuccessUi = function(acc, toastText, toastIcon, statusText, ackFn) {
            if (typeof ackFn === 'function') {
              ackFn();
            } else if (window.TVSync && window.TVSync.pushPlaylists) {
              window.TVSync.pushPlaylists();
            }
            renderAccountsList();
            showToast(toastText, toastIcon);

            var doneBtn = document.getElementById('remote-done-btn');
            if (doneBtn) {
              doneBtn.style.display = 'inline-flex';
              doneBtn.onclick = function(e) {
                handleRemoteDone(e);
              };
              if (window.SpatialNav) {
                window.SpatialNav.setFocus(doneBtn);
                setTimeout(function() {
                  window.SpatialNav.setFocus(doneBtn);
                }, 50);
              }
            }

            var tabRemote = document.getElementById('tab-btn-remote');
            var tabManual = document.getElementById('tab-btn-manual');
            if (tabRemote) tabRemote.setAttribute('data-nav-down', '#remote-done-btn');
            if (tabManual) tabManual.setAttribute('data-nav-down', '#remote-done-btn');

            var statusRow = document.querySelector('.info-status-row');
            if (statusRow) statusRow.classList.add('received');
            if (statusEl) {
              statusEl.textContent = statusText;
            }
          };

          var showRemoteErrorUi = function(err, fallbackMsg, ackFn) {
            var detailMsg = (err && err.message) ? err.message : fallbackMsg;
            if (typeof ackFn === 'function') {
              ackFn(detailMsg);
            }
            var errPrefix = (window.TVI18n && window.TVI18n.getLanguage() === 'de') ? 'Verbindungsfehler: ' : 'Connection error: ';
            var msg = errPrefix + detailMsg;
            showToast(msg, 'alert');
            var statusRow = document.querySelector('.info-status-row');
            if (statusRow) statusRow.classList.remove('received');
            if (statusEl) statusEl.textContent = msg;
          };

          if (event && event.type === 'accountAdded' && event.account) {
            var incoming = event.account;
            var isM3u = incoming.type === 'm3u' || (!incoming.username && !incoming.password) || (incoming.serverUrl && (incoming.serverUrl.indexOf('.m3u') !== -1 || incoming.serverUrl.indexOf('.m3u8') !== -1));
            var accName = incoming.name || incoming.username || (isM3u ? 'M3U Playlist' : 'Remote Playlist');
            var statusRowAdd = document.querySelector('.info-status-row');
            if (statusRowAdd) statusRowAdd.classList.remove('received');
            if (statusEl) {
              statusEl.textContent = isM3u
                ? (window.TVI18n ? window.TVI18n.t('loading_m3u') : 'Downloading and parsing M3U playlist...')
                : (window.TVI18n ? window.TVI18n.t('connecting_server') : 'Connecting to IPTV server...');
            }

            if (isM3u) {
              window.TVApi.authenticateM3u(incoming.serverUrl, accName)
                .then(function(res) {
                  var acc = window.TVStorage.saveAccount({
                    id: incoming.id || undefined,
                    type: 'm3u',
                    serverUrl: incoming.serverUrl,
                    username: '',
                    password: '',
                    name: accName,
                    channelCount: res ? res.streamCount : 0,
                    categoryCount: res ? res.categoryCount : 0,
                    syncLiveTv: incoming.syncLiveTv !== false,
                    syncMovies: incoming.syncMovies !== false,
                    syncSeries: incoming.syncSeries !== false
                  });
                  if (res && res.parsed && window.TVStorage && window.TVStorage.saveM3uData) {
                    window.TVStorage.saveM3uData(acc.id, res.parsed);
                  }
                  _lastAddedAccount = acc;
                  var toastPrefix = window.TVI18n ? window.TVI18n.t('playlist_received_toast') : 'Playlist received: ';
                  var statusTxt = window.TVI18n ? window.TVI18n.t('playlist_received') : 'Playlist received';
                  showRemoteSuccessUi(acc, toastPrefix + (acc.name || acc.username), 'mobile', statusTxt, event.ack);
                })
                .catch(function(err) {
                  showRemoteErrorUi(err, 'Failed to load M3U playlist', event.ack);
                });
            } else {
              window.TVApi.authenticate(incoming.serverUrl, incoming.username || '', incoming.password || '')
                .then(function(data) {
                  var expDate = (data && data.userInfo && data.userInfo.exp_date !== undefined) ? data.userInfo.exp_date : null;
                  var maxConnections = (data && data.userInfo && data.userInfo.max_connections !== undefined) ? data.userInfo.max_connections : null;
                  var activeConnections = (data && data.userInfo && data.userInfo.active_cons !== undefined) ? data.userInfo.active_cons : null;
                  var acc = window.TVStorage.saveAccount({
                    id: incoming.id || undefined,
                    serverUrl: incoming.serverUrl,
                    username: incoming.username || '',
                    password: incoming.password || '',
                    name: accName,
                    expDate: expDate,
                    maxConnections: maxConnections,
                    activeConnections: activeConnections,
                    syncLiveTv: incoming.syncLiveTv !== false,
                    syncMovies: incoming.syncMovies !== false,
                    syncSeries: incoming.syncSeries !== false
                  });
                  _lastAddedAccount = acc;
                  var toastPrefix = window.TVI18n ? window.TVI18n.t('playlist_received_toast') : 'Playlist received: ';
                  var statusTxt = window.TVI18n ? window.TVI18n.t('playlist_received') : 'Playlist received';
                  showRemoteSuccessUi(acc, toastPrefix + (acc.name || acc.username), 'mobile', statusTxt, event.ack);
                })
                .catch(function(err) {
                  showRemoteErrorUi(err, 'Authentication failed', event.ack);
                });
            }
          } else if (event && event.type === 'accountUpdated' && event.account) {
            var updAccIn = event.account;
            var updatedToastPrefix = (window.TVI18n && window.TVI18n.getLanguage() === 'de') ? 'Playlist aktualisiert: ' : 'Playlist updated: ';
            var updatedStatusTxt = (window.TVI18n && window.TVI18n.getLanguage() === 'de') ? 'Playlist aktualisiert' : 'Playlist updated';

            var applyUpdatedActive = function(acc) {
              if (_activeAccount && String(_activeAccount.id) === String(acc.id)) {
                _activeAccount.name = acc.name;
                _activeAccount.serverUrl = acc.serverUrl;
                _activeAccount.username = acc.username;
                _activeAccount.password = acc.password;
                _activeAccount.type = acc.type;
                _activeAccount.expDate = acc.expDate;
                _activeAccount.maxConnections = acc.maxConnections;
                _activeAccount.syncLiveTv = acc.syncLiveTv;
                _activeAccount.syncMovies = acc.syncMovies;
                _activeAccount.syncSeries = acc.syncSeries;
                var nameEl = document.getElementById('header-account-name');
                if (nameEl) nameEl.textContent = _activeAccount.name || _activeAccount.username;
                updateNavRailScopes();
                markCategoriesDirty('all');
              }
            };

            if (event.credentialsChanged) {
              var updIsM3u = updAccIn.type === 'm3u' || (!updAccIn.username && !updAccIn.password) || (updAccIn.serverUrl && (updAccIn.serverUrl.indexOf('.m3u') !== -1 || updAccIn.serverUrl.indexOf('.m3u8') !== -1));
              var updName = updAccIn.name || updAccIn.username || (updIsM3u ? 'M3U Playlist' : 'Remote Playlist');
              var statusRowUpd = document.querySelector('.info-status-row');
              if (statusRowUpd) statusRowUpd.classList.remove('received');
              if (statusEl) {
                statusEl.textContent = updIsM3u
                  ? (window.TVI18n ? window.TVI18n.t('loading_m3u') : 'Downloading and parsing M3U playlist...')
                  : (window.TVI18n ? window.TVI18n.t('connecting_server') : 'Connecting to IPTV server...');
              }

              if (updIsM3u) {
                window.TVApi.authenticateM3u(updAccIn.serverUrl, updName)
                  .then(function(res) {
                    var acc = window.TVStorage.saveAccount({
                      id: updAccIn.id || undefined,
                      type: 'm3u',
                      serverUrl: updAccIn.serverUrl,
                      username: '',
                      password: '',
                      name: updName,
                      channelCount: res ? res.streamCount : 0,
                      categoryCount: res ? res.categoryCount : 0,
                      syncLiveTv: updAccIn.syncLiveTv !== false,
                      syncMovies: updAccIn.syncMovies !== false,
                      syncSeries: updAccIn.syncSeries !== false
                    });
                    if (window.TVApi && window.TVApi.clearCache) window.TVApi.clearCache(acc.id);
                    if (res && res.parsed && window.TVStorage && window.TVStorage.saveM3uData) {
                      window.TVStorage.saveM3uData(acc.id, res.parsed);
                    }
                    applyUpdatedActive(acc);
                    showRemoteSuccessUi(acc, updatedToastPrefix + (acc.name || acc.username), 'edit', updatedStatusTxt, event.ack);
                  })
                  .catch(function(err) {
                    showRemoteErrorUi(err, 'Failed to load M3U playlist', event.ack);
                  });
              } else {
                window.TVApi.authenticate(updAccIn.serverUrl, updAccIn.username || '', updAccIn.password || '')
                  .then(function(data) {
                    var expDate = (data && data.userInfo && data.userInfo.exp_date !== undefined) ? data.userInfo.exp_date : null;
                    var maxConnections = (data && data.userInfo && data.userInfo.max_connections !== undefined) ? data.userInfo.max_connections : null;
                    var activeConnections = (data && data.userInfo && data.userInfo.active_cons !== undefined) ? data.userInfo.active_cons : null;
                    var acc = window.TVStorage.saveAccount({
                      id: updAccIn.id || undefined,
                      serverUrl: updAccIn.serverUrl,
                      username: updAccIn.username || '',
                      password: updAccIn.password || '',
                      name: updName,
                      expDate: expDate,
                      maxConnections: maxConnections,
                      activeConnections: activeConnections,
                      syncLiveTv: updAccIn.syncLiveTv !== false,
                      syncMovies: updAccIn.syncMovies !== false,
                      syncSeries: updAccIn.syncSeries !== false
                    });
                    if (window.TVApi && window.TVApi.clearCache) window.TVApi.clearCache(acc.id);
                    applyUpdatedActive(acc);
                    showRemoteSuccessUi(acc, updatedToastPrefix + (acc.name || acc.username), 'edit', updatedStatusTxt, event.ack);
                  })
                  .catch(function(err) {
                    showRemoteErrorUi(err, 'Authentication failed', event.ack);
                  });
              }
            } else {
              applyUpdatedActive(updAccIn);
              showRemoteSuccessUi(updAccIn, updatedToastPrefix + (updAccIn.name || updAccIn.username), 'edit', updatedStatusTxt);
            }
          } else if (event && event.type === 'accountDeleted') {
            renderAccountsList();
            if (_activeAccount && String(_activeAccount.id) === String(event.id)) {
              resetAllAccountState();
              document.getElementById('view-dashboard').classList.remove('active');
              document.getElementById('view-accounts').classList.add('active');
            }
            var deletedToast = (window.TVI18n && window.TVI18n.getLanguage() === 'de') ? 'Playlist gelöscht' : 'Playlist deleted';
            showToast(deletedToast, 'trash');
          }
        });
      })
      .catch(function(err) {
        if (qrLoading) qrLoading.style.display = 'none';
        var errPrefix = (window.TVI18n && window.TVI18n.getLanguage() === 'de') ? 'Fehler: ' : 'Error: ';
        if (statusEl) statusEl.textContent = errPrefix + err.message;
      });
  }

  function showToast(message, icon) {
    var banner = document.getElementById('toast-banner');
    var msgEl = document.getElementById('toast-message');
    var iconEl = document.getElementById('toast-icon');
    if (!banner || !msgEl) return;

    msgEl.textContent = message;
    if (iconEl) {
      if (icon) {
        var svgIcon = null;
        if (window.TVIcons) {
          if (icon === 'star') svgIcon = window.TVIcons.starFilled;
          else if (icon === 'edit') svgIcon = window.TVIcons.edit;
          else if (icon === 'trash') svgIcon = window.TVIcons.trash;
          else if (icon === 'check') svgIcon = window.TVIcons.check;
          else if (icon === 'tv') svgIcon = window.TVIcons.tv;
          else if (icon === 'film' || icon === 'movie') svgIcon = window.TVIcons.film;
          else if (icon === 'series' || icon === 'folder') svgIcon = window.TVIcons.series;
          else if (icon === 'playlist' || icon === 'list') svgIcon = window.TVIcons.playlist;
          else if (icon === 'alert' || icon === 'warning') svgIcon = window.TVIcons.alertCircle || window.TVIcons.info;
          else if (icon === 'info' || icon === 'party') svgIcon = window.TVIcons.info;
          else if (icon === 'close') svgIcon = window.TVIcons.close;
          else if (icon === 'play') svgIcon = window.TVIcons.play;
          else if (icon === 'swapVert' || icon === 'reorder') svgIcon = window.TVIcons.swapVert;
          else if (icon === 'audio' || icon === 'volume') svgIcon = window.TVIcons.audio || window.TVIcons.settings;
          else if (icon === 'subtitle' || icon === 'sub') svgIcon = window.TVIcons.subtitles || window.TVIcons.settings;
          else if (icon === 'settings' || icon === 'gear') svgIcon = window.TVIcons.settings;
          else if (icon === 'mobile' || icon === 'phone') svgIcon = window.TVIcons.mobile || window.TVIcons.info;
          else if (icon === 'globe' || icon === 'lang') svgIcon = window.TVIcons.globe || window.TVIcons.settings;
          else if (typeof icon === 'string' && icon.indexOf('<svg') !== -1) svgIcon = icon;
        }
        if (svgIcon) {
          iconEl.innerHTML = svgIcon;
        } else {
          iconEl.textContent = icon;
        }
        iconEl.style.display = 'inline-flex';
      } else {
        iconEl.innerHTML = '';
        iconEl.style.display = 'none';
      }
    }
    banner.classList.add('show');

    if (window._toastTimer) clearTimeout(window._toastTimer);
    window._toastTimer = setTimeout(function() {
      banner.classList.remove('show');
    }, 4000);
  }

  function showExitModal() {
    var modal = document.getElementById('exit-modal');
    if (modal) {
      openModal(modal, document.getElementById('exit-cancel-btn'));
    }
  }

  function exitApp() {
    if (window.webOS && window.webOS.platformBack) {
      window.webOS.platformBack();
    } else if (window.tizen && window.tizen.application) {
      window.tizen.application.getCurrentApplication().exit();
    } else {
      window.close();
    }
  }

  // Scope Chip toggle helper
  function setScopeChip(id, active) {
    var chip = document.getElementById(id);
    if (!chip) return;
    chip.classList.toggle('active', !!active);
    var scope = chip.getAttribute('data-scope');
    var labelText = (scope === 'live' ? (window.TVI18n ? window.TVI18n.t('live_tv') : 'Live TV') :
                    (scope === 'movies' ? (window.TVI18n ? window.TVI18n.t('movies') : 'Movies') :
                    (window.TVI18n ? window.TVI18n.t('series') : 'Series')));
    var iconSvg = (scope === 'live' ? (window.TVIcons ? window.TVIcons.tv : '') :
                  (scope === 'movies' ? (window.TVIcons ? window.TVIcons.film : '') :
                  (window.TVIcons ? window.TVIcons.series : '')));
    var checkSvg = (active && window.TVIcons) ? window.TVIcons.check : '';

    chip.innerHTML = 
      '<span class="scope-chip-icon">' + iconSvg + '</span>' +
      '<span class="scope-chip-label">' + labelText + '</span>' +
      '<span class="scope-chip-check">' + checkSvg + '</span>';
  }

  // =========================================================
  // CATEGORY MANAGER & MOVE MODE (v2.1)
  // =========================================================
  var _activeCategoryManagerType = 'live';
  var _showHiddenCategories = false;
  var _moveModeActive = false;
  var _moveModeCategoryId = null;
  var _catMgrDirty = false;
  var _catMgrCooldownUntil = 0;
  var _catMgrMoveToggleLockUntil = 0;
  var _catMgrDisplayedList = [];
  var _catMgrHiddenSet = {};
  var _catMgrNewSet = {};
  var _catMgrTotalCount = 0;
  var _catMgrHiddenCount = 0;
  var _catMgrRenderedCount = 0;
  var _catMgrBatchSize = 50;
  var _catMgrScrollBound = false;

  function getAllCategoriesForManager(type) {
    var rawCats = (type === 'live' ? _liveCategories : (type === 'movie' ? _movieCategories : _seriesCategories)) || [];
    var customLists = (_activeAccount && window.TVStorage) ? window.TVStorage.getCustomLists(_activeAccount.id, type) : [];
    var favLabel = (type === 'live'
      ? ((window.TVI18n && window.TVI18n.t('favorites')) || 'Favorites')
      : ((window.TVI18n && window.TVI18n.t('watchlist')) || 'Watchlist'));
    var favCat = { category_id: 'favorites', category_name: favLabel, isFav: true };
    var customCats = customLists.map(function(cl) {
      return { category_id: 'custom_list:' + cl.id, category_name: cl.name, isCustom: true, customList: cl };
    });
    return [favCat].concat(customCats).concat(rawCats);
  }

  function updateCatMgrToolbarState() {
    var toggleHiddenText = document.getElementById('cat-mgr-toggle-hidden-text');
    var toggleHiddenBtn = document.getElementById('cat-mgr-toggle-hidden');
    if (toggleHiddenText) {
      if (_showHiddenCategories) {
        toggleHiddenText.textContent = (window.TVI18n && window.TVI18n.t('hide_hidden_categories')) || 'Ausgeblendete verbergen';
      } else {
        var tmpl = (window.TVI18n && window.TVI18n.t('show_hidden_count')) || 'Ausgeblendete anzeigen ({count})';
        toggleHiddenText.textContent = tmpl.replace('{count}', _catMgrHiddenCount);
      }
    }
    if (toggleHiddenBtn) {
      toggleHiddenBtn.classList.toggle('active', _showHiddenCategories);
    }

    var unhideBtn = document.getElementById('cat-mgr-unhide-all');
    var unhideText = document.getElementById('cat-mgr-unhide-all-text');
    if (unhideBtn) {
      var allVis = _catMgrTotalCount > 0 && _catMgrHiddenCount === 0;
      var unhideLabel = allVis ? ((window.TVI18n && window.TVI18n.t('hide_all')) || 'Alle ausblenden') : ((window.TVI18n && window.TVI18n.t('show_all')) || 'Alle einblenden');
      if (unhideText) unhideText.textContent = unhideLabel;
      else unhideBtn.textContent = unhideLabel;
    }

    var moveBadge = document.getElementById('cat-mgr-move-badge');
    if (moveBadge) {
      moveBadge.style.display = _moveModeActive ? 'inline-flex' : 'none';
    }
    window._moveModeActive = _moveModeActive;
  }

  function patchCatMgrRow(itemEl, isHidden, isMoving) {
    if (!itemEl) return;
    itemEl.classList.toggle('move-active', !!isMoving);
    itemEl.classList.toggle('is-hidden', !!isHidden);

    var cb = itemEl.querySelector('.cat-mgr-checkbox');
    if (cb) {
      cb.classList.toggle('checked', !isHidden);
      cb.innerHTML = !isHidden ? ((window.TVIcons && window.TVIcons.checkboxChecked) || '') : ((window.TVIcons && window.TVIcons.checkboxEmpty) || '');
    }

    var nameEl = itemEl.querySelector('.cat-mgr-name');
    if (nameEl) nameEl.classList.toggle('dimmed', !!isHidden);

    var pill = itemEl.querySelector('.cat-mgr-move-pill');
    if (pill) {
      pill.classList.toggle('active', !!isMoving);
      pill.textContent = isMoving
        ? ((window.TVI18n && window.TVI18n.t('done_btn')) || 'Done')
        : ((window.TVI18n && window.TVI18n.t('move_btn')) || 'Move');
    }

    var handle = itemEl.querySelector('.cat-mgr-handle');
    if (handle) {
      handle.innerHTML = isMoving ? ((window.TVIcons && window.TVIcons.swapVert) || '') : ((window.TVIcons && window.TVIcons.dragHandle) || '');
    }
  }

  function showCatMgrEmptyMessage(listEl) {
    var emptyEl = document.createElement('div');
    emptyEl.className = 'cat-mgr-empty';
    emptyEl.style.cssText = 'padding: 36px; text-align: center; color: rgba(255,255,255,0.65); font-size: 22px; line-height: 1.5;';
    emptyEl.textContent = (window.TVI18n && window.TVI18n.t('all_categories_hidden')) || 'Alle Kategorien sind ausgeblendet. Klicke oben auf "Ausgeblendete anzeigen", um sie wieder einzublenden.';
    listEl.appendChild(emptyEl);
  }

  function createCatMgrRowEl(cat) {
    var catId = String(cat.category_id || cat.categoryId);
    var isHidden = !!_catMgrHiddenSet[catId];
    var isNew = !!_catMgrNewSet[catId];
    var isMoving = _moveModeActive && (_moveModeCategoryId === catId);

    var itemEl = document.createElement('div');
    itemEl.className = 'cat-mgr-item focusable' + (isMoving ? ' move-active' : '') + (isHidden ? ' is-hidden' : '');
    itemEl.setAttribute('data-cat-id', catId);
    if (cat.isCustom) {
      itemEl.setAttribute('data-is-custom', 'true');
      itemEl.setAttribute('data-custom-id', cat.customList ? cat.customList.id : catId.replace('custom_list:', ''));
    }

    var handleSvg = isMoving ? ((window.TVIcons && window.TVIcons.swapVert) || '') : ((window.TVIcons && window.TVIcons.dragHandle) || '');
    var newTxt = escapeHtml((window.TVI18n && window.TVI18n.t('badge_new')) || 'NEW');
    var listTxt = escapeHtml((window.TVI18n && window.TVI18n.t('badge_list')) || 'LIST');
    var badgeNew = isNew ? '<span class="badge-cat-new">' + newTxt + '</span>' : '';
    var customBadge = cat.isCustom ? '<span class="badge-cat-new badge-custom-list">' + listTxt + '</span>' : '';
    var checkSvg = !isHidden ? ((window.TVIcons && window.TVIcons.checkboxChecked) || '') : ((window.TVIcons && window.TVIcons.checkboxEmpty) || '');

    var typeIcon = cat.isFav ? ('<span class="cat-mgr-type-icon is-fav">' + ((window.TVIcons && window.TVIcons.starFilled) || '') + '</span>') :
                   (cat.isCustom ? ('<span class="cat-mgr-type-icon is-custom">' + ((window.TVIcons && window.TVIcons.playlist) || '') + '</span>') :
                   ('<span class="cat-mgr-type-icon">' + (_activeCategoryManagerType === 'live' ? ((window.TVIcons && window.TVIcons.tv) || '') : (_activeCategoryManagerType === 'movie' ? ((window.TVIcons && window.TVIcons.film) || '') : ((window.TVIcons && window.TVIcons.series) || ''))) + '</span>'));

    var doneTxt = escapeHtml((window.TVI18n && window.TVI18n.t('done_btn')) || 'Done');
    var moveTxt = escapeHtml((window.TVI18n && window.TVI18n.t('move_btn')) || 'Move');
    var movePill = isMoving ? '<span class="cat-mgr-move-pill active">' + doneTxt + '</span>' : '<span class="cat-mgr-move-pill">' + moveTxt + '</span>';

    itemEl.innerHTML =
      '<div class="cat-mgr-item-left">' +
        '<div class="cat-mgr-checkbox' + (!isHidden ? ' checked' : '') + '">' + checkSvg + '</div>' +
        typeIcon +
        '<span class="cat-mgr-name' + (isHidden ? ' dimmed' : '') + '">' + escapeHtml(cat.category_name || cat.name || '') + '</span>' +
        customBadge +
        badgeNew +
      '</div>' +
      '<div class="cat-mgr-item-right">' +
        movePill +
        '<span class="cat-mgr-handle">' + handleSvg + '</span>' +
      '</div>';

    itemEl.onclick = function() {
      var listEl = document.getElementById('cat-mgr-list');
      if (_moveModeActive) {
        exitCategoryMoveMode();
        if (window.SpatialNav) window.SpatialNav.setFocus(itemEl);
        return;
      }
      var currentlyHidden = !!_catMgrHiddenSet[catId];
      var nextHidden = !currentlyHidden;
      window.TVStorage.setCategoryVisibility(_activeAccount.id, _activeCategoryManagerType, catId, currentlyHidden);
      _catMgrDirty = true;
      markCategoriesDirty(_activeCategoryManagerType);
      if (nextHidden) {
        _catMgrHiddenSet[catId] = true;
        _catMgrHiddenCount++;
      } else {
        delete _catMgrHiddenSet[catId];
        _catMgrHiddenCount = Math.max(0, _catMgrHiddenCount - 1);
      }
      updateCatMgrToolbarState();

      if (_showHiddenCategories) {
        patchCatMgrRow(itemEl, nextHidden, false);
        if (window.SpatialNav) window.SpatialNav.setFocus(itemEl);
      } else if (nextHidden && listEl) {
        var nextSib = itemEl.nextElementSibling;
        var prevSib = itemEl.previousElementSibling;
        if (itemEl.parentNode) itemEl.parentNode.removeChild(itemEl);
        _catMgrRenderedCount = Math.max(0, _catMgrRenderedCount - 1);
        for (var i = 0; i < _catMgrDisplayedList.length; i++) {
          if (String(_catMgrDisplayedList[i].category_id || _catMgrDisplayedList[i].categoryId) === catId) {
            _catMgrDisplayedList.splice(i, 1);
            break;
          }
        }
        if (!nextSib && _catMgrRenderedCount < _catMgrDisplayedList.length) {
          appendCatMgrBatch(10);
          nextSib = prevSib ? prevSib.nextElementSibling : listEl.querySelector('.cat-mgr-item');
        }
        if (_catMgrDisplayedList.length === 0) {
          showCatMgrEmptyMessage(listEl);
          var toggleBtn = document.getElementById('cat-mgr-toggle-hidden');
          if (toggleBtn && window.SpatialNav) window.SpatialNav.setFocus(toggleBtn);
        } else {
          var itemToFocus = nextSib || prevSib || listEl.querySelector('.cat-mgr-item') || document.getElementById('cat-mgr-toggle-hidden');
          if (itemToFocus && window.SpatialNav) window.SpatialNav.setFocus(itemToFocus);
        }
      }
    };

    return itemEl;
  }

  function appendCatMgrBatch(count) {
    var listEl = document.getElementById('cat-mgr-list');
    if (!listEl || _catMgrRenderedCount >= _catMgrDisplayedList.length) return false;
    var batchSize = count || _catMgrBatchSize;
    var end = Math.min(_catMgrDisplayedList.length, _catMgrRenderedCount + batchSize);
    var frag = document.createDocumentFragment();
    for (var i = _catMgrRenderedCount; i < end; i++) {
      frag.appendChild(createCatMgrRowEl(_catMgrDisplayedList[i]));
    }
    listEl.appendChild(frag);
    _catMgrRenderedCount = end;
    return true;
  }

  function loadMoreCategoryManagerItems() {
    return appendCatMgrBatch(_catMgrBatchSize);
  }

  function openCategoryManager(type, initialMoveCatId) {
    var modal = document.getElementById('modal-category-manager');
    if (!modal) return;
    if (modal.classList.contains('active') || Date.now() < _catMgrCooldownUntil) return;

    _activeCategoryManagerType = type || _currentTab || 'live';
    if (_activeCategoryManagerType === 'movies') _activeCategoryManagerType = 'movie';
    _showHiddenCategories = false;
    _moveModeActive = !!initialMoveCatId;
    _moveModeCategoryId = initialMoveCatId || null;
    _catMgrDirty = false;
    _catMgrCooldownUntil = Date.now() + 450;
    window._moveModeActive = _moveModeActive;

    var titleEl = document.getElementById('cat-mgr-title');
    var tipEl = document.getElementById('cat-mgr-tip-text');
    var typeLabel = (_activeCategoryManagerType === 'live' ? (window.TVI18n ? window.TVI18n.t('live_tv') : 'Live TV') :
                    (_activeCategoryManagerType === 'movie' ? (window.TVI18n ? window.TVI18n.t('movies') : 'Filme') :
                    (window.TVI18n ? window.TVI18n.t('series') : 'Serien')));
    if (titleEl) {
      var manageKey = _activeCategoryManagerType === 'live' ? 'manage_live_categories' :
                      (_activeCategoryManagerType === 'movie' ? 'manage_movie_categories' : 'manage_series_categories');
      titleEl.textContent = (window.TVI18n && window.TVI18n.t(manageKey)) || ('Kategorien anpassen (' + typeLabel + ')');
    }
    if (tipEl) {
      tipEl.textContent = (window.TVI18n && window.TVI18n.t('cat_mgr_tip')) || 'Tipp: OK = Ein-/Ausblenden • GELB oder OK halten = Verschieben / Liste bearbeiten';
    }

    renderCategoryManagerList();

    var listEl = document.getElementById('cat-mgr-list');
    if (listEl) listEl.scrollTop = 0;

    var targetFocus = null;
    if (initialMoveCatId && listEl) {
      for (var i = 0; i < _catMgrDisplayedList.length; i++) {
        if (String(_catMgrDisplayedList[i].category_id || _catMgrDisplayedList[i].categoryId) === initialMoveCatId) {
          while (_catMgrRenderedCount <= i && appendCatMgrBatch()) {}
          break;
        }
      }
      targetFocus = listEl.querySelector('.cat-mgr-item[data-cat-id="' + initialMoveCatId + '"]');
    }
    var firstFocus = targetFocus || document.querySelector('#cat-mgr-list .cat-mgr-item') || document.getElementById('cat-mgr-toggle-hidden');
    openModal(modal, firstFocus);
  }

  function renderCategoryManagerList() {
    var listEl = document.getElementById('cat-mgr-list');
    if (!listEl) return;
    if (!_catMgrScrollBound) {
      _catMgrScrollBound = true;
      listEl.addEventListener('scroll', function() {
        if (listEl.scrollTop + listEl.clientHeight >= listEl.scrollHeight - 240) {
          loadMoreCategoryManagerItems();
        }
      }, { passive: true });
    }
    listEl.innerHTML = '';

    var allCats = getAllCategoriesForManager(_activeCategoryManagerType);
    var prefs = (_activeAccount && window.TVStorage) ? window.TVStorage.getCategoryPrefs(_activeAccount.id, _activeCategoryManagerType) : { order: [], hidden: [], newIds: [] };

    // Fast O(1) lookups
    var orderSet = {};
    (prefs.order || []).forEach(function(id) { orderSet[id] = true; });
    _catMgrHiddenSet = {};
    (prefs.hidden || []).forEach(function(id) { _catMgrHiddenSet[id] = true; });
    _catMgrNewSet = {};
    (prefs.newIds || []).forEach(function(id) { _catMgrNewSet[id] = true; });

    // Order categories according to prefs.order
    var catMap = {};
    allCats.forEach(function(c) {
      catMap[String(c.category_id || c.categoryId)] = c;
    });

    var orderedList = [];
    var favIdx = (prefs.order || []).indexOf('favorites');
    if (favIdx === -1) {
      if (catMap['favorites']) orderedList.push(catMap['favorites']);
    } else if (favIdx === prefs.order.length - 1 && prefs.order.length > 1 && !prefs.hasManualSort) {
      if (catMap['favorites']) orderedList.push(catMap['favorites']);
    }

    (prefs.order || []).forEach(function(id) {
      if (id === 'favorites' && orderedList.length > 0 && orderedList[0].category_id === 'favorites') return;
      if (catMap[id]) orderedList.push(catMap[id]);
    });
    allCats.forEach(function(c) {
      var id = String(c.category_id || c.categoryId);
      if (id === 'favorites' && orderedList.length > 0 && orderedList[0].category_id === 'favorites') return;
      if (!orderSet[id]) {
        if (id.indexOf('custom_list:') === 0) {
          var insertIdx = 0;
          while (insertIdx < orderedList.length) {
            var oid = String(orderedList[insertIdx].category_id || orderedList[insertIdx].categoryId);
            if (oid !== 'favorites' && oid.indexOf('custom_list:') !== 0) break;
            insertIdx++;
          }
          orderedList.splice(insertIdx, 0, c);
        } else {
          orderedList.push(c);
        }
      }
    });
    if (!prefs.hasManualSort) {
      var tierFav = [];
      var tierCustom = [];
      var tierReg = [];
      orderedList.forEach(function(c) {
        var cid = String(c.category_id || c.categoryId);
        if (cid === 'favorites') tierFav.push(c);
        else if (cid.indexOf('custom_list:') === 0) tierCustom.push(c);
        else tierReg.push(c);
      });
      orderedList = tierFav.concat(tierCustom).concat(tierReg);
    }

    _catMgrTotalCount = orderedList.length;
    var hiddenCount = 0;
    var displayedList = [];
    for (var i = 0; i < orderedList.length; i++) {
      var c = orderedList[i];
      var cid = String(c.category_id || c.categoryId);
      var isH = !!_catMgrHiddenSet[cid];
      if (isH) hiddenCount++;
      if (_showHiddenCategories || !isH) {
        displayedList.push(c);
      }
    }
    _catMgrHiddenCount = hiddenCount;
    _catMgrDisplayedList = displayedList;
    _catMgrRenderedCount = 0;

    updateCatMgrToolbarState();

    if (displayedList.length === 0) {
      showCatMgrEmptyMessage(listEl);
      return;
    }

    appendCatMgrBatch(_catMgrBatchSize);
  }

  function moveCategoryInManager(dir) {
    if (!_moveModeActive || !_moveModeCategoryId) return false;
    var listEl = document.getElementById('cat-mgr-list');
    if (!listEl || _catMgrDisplayedList.length < 2) return false;

    var visIdx = -1;
    for (var i = 0; i < _catMgrDisplayedList.length; i++) {
      if (String(_catMgrDisplayedList[i].category_id || _catMgrDisplayedList[i].categoryId) === _moveModeCategoryId) {
        visIdx = i;
        break;
      }
    }
    if (visIdx === -1) return false;
    var targetVisIdx = visIdx + dir;
    if (targetVisIdx < 0 || targetVisIdx >= _catMgrDisplayedList.length) return false;

    while (_catMgrRenderedCount <= targetVisIdx && appendCatMgrBatch()) {}

    var targetCatId = String(_catMgrDisplayedList[targetVisIdx].category_id || _catMgrDisplayedList[targetVisIdx].categoryId);

    var allCats = getAllCategoriesForManager(_activeCategoryManagerType);
    var prefs = window.TVStorage.getCategoryPrefs(_activeAccount.id, _activeCategoryManagerType);
    var currentOrder = (prefs.order || []).slice();
    var orderMap = {};
    for (var o = 0; o < currentOrder.length; o++) orderMap[currentOrder[o]] = true;
    for (var a = 0; a < allCats.length; a++) {
      var aid = String(allCats[a].category_id || allCats[a].categoryId);
      if (!orderMap[aid]) {
        currentOrder.push(aid);
        orderMap[aid] = true;
      }
    }

    var fromIdx = currentOrder.indexOf(_moveModeCategoryId);
    var toIdx = currentOrder.indexOf(targetCatId);
    if (fromIdx === -1 || toIdx === -1) return false;

    var tmpOrd = currentOrder[fromIdx];
    currentOrder[fromIdx] = currentOrder[toIdx];
    currentOrder[toIdx] = tmpOrd;

    window.TVStorage.reorderCategories(_activeAccount.id, _activeCategoryManagerType, currentOrder);
    _catMgrDirty = true;
    markCategoriesDirty(_activeCategoryManagerType);

    var tmpVis = _catMgrDisplayedList[visIdx];
    _catMgrDisplayedList[visIdx] = _catMgrDisplayedList[targetVisIdx];
    _catMgrDisplayedList[targetVisIdx] = tmpVis;

    var movingEl = listEl.querySelector('.cat-mgr-item[data-cat-id="' + _moveModeCategoryId + '"]');
    var targetEl = listEl.querySelector('.cat-mgr-item[data-cat-id="' + targetCatId + '"]');
    if (movingEl && targetEl) {
      if (dir < 0) {
        listEl.insertBefore(movingEl, targetEl);
      } else {
        listEl.insertBefore(targetEl, movingEl);
      }
      movingEl.scrollIntoView({ block: 'nearest' });
      if (window.SpatialNav) {
        window.SpatialNav.setFocus(movingEl);
      }
    }
    return true;
  }

  function exitCategoryMoveMode() {
    var prevId = _moveModeCategoryId;
    _moveModeActive = false;
    _moveModeCategoryId = null;
    window._moveModeActive = false;
    updateCatMgrToolbarState();

    if (prevId) {
      var prevEl = document.querySelector('#cat-mgr-list .cat-mgr-item[data-cat-id="' + prevId + '"]');
      if (prevEl) patchCatMgrRow(prevEl, !!_catMgrHiddenSet[prevId], false);
    }
  }

  function onCategoryManagerItemLongPress(itemEl) {
    if (!itemEl) return;
    var now = Date.now();
    if (now < _catMgrMoveToggleLockUntil) return;
    _catMgrMoveToggleLockUntil = now + 300;

    var isCustom = itemEl.getAttribute('data-is-custom') === 'true';
    var catId = itemEl.getAttribute('data-cat-id');

    if (isCustom && !_moveModeActive) {
      var customLists = (_activeAccount && window.TVStorage) ? window.TVStorage.getCustomLists(_activeAccount.id, _activeCategoryManagerType) : [];
      var customId = itemEl.getAttribute('data-custom-id') || catId.replace('custom_list:', '');
      var found = customLists.find(function(cl) { return String(cl.id) === String(customId); });
      if (found) {
        openCustomListOptionsModal(found);
        return;
      }
    }

    if (_moveModeActive && _moveModeCategoryId === catId) {
      exitCategoryMoveMode();
      if (window.SpatialNav) window.SpatialNav.setFocus(itemEl);
    } else {
      var prevId = _moveModeCategoryId;
      _moveModeActive = true;
      _moveModeCategoryId = catId;
      window._moveModeActive = true;
      updateCatMgrToolbarState();

      if (prevId && prevId !== catId) {
        var prevEl = document.querySelector('#cat-mgr-list .cat-mgr-item[data-cat-id="' + prevId + '"]');
        if (prevEl) patchCatMgrRow(prevEl, !!_catMgrHiddenSet[prevId], false);
      }
      patchCatMgrRow(itemEl, !!_catMgrHiddenSet[catId], true);
      if (window.SpatialNav) window.SpatialNav.setFocus(itemEl);
    }
  }

  // =========================================================
  // STREAM CONTEXT MENU & CUSTOM LISTS (v2.1)
  // =========================================================
  var _activeContextStream = null;
  var _activeContextType = 'live';
  var _activeCustomList = null;
  var _createListMode = 'create';
  var _activeCreateListType = null;
  var _ignoreContextClicksUntil = 0;

  function showStreamContextMenu(stream, type) {
    if (!stream || document.body.classList.contains('player-fullscreen')) return;
    _ignoreContextClicksUntil = Date.now() + 450;
    _activeContextStream = stream;
    _activeContextType = type || 'live';
    if (_activeContextType === 'movies') _activeContextType = 'movie';

    var modal = document.getElementById('modal-stream-context');
    if (!modal) return;

    var titleEl = document.getElementById('ctx-stream-title');
    var thumbEl = document.getElementById('ctx-stream-icon');
    var headerSvg = document.getElementById('ctx-header-svg');
    var favBtn = document.getElementById('ctx-fav-btn');
    var favIcon = document.getElementById('ctx-fav-icon');
    var favLabel = document.getElementById('ctx-fav-label');
    var moveBtn = document.getElementById('ctx-move-btn');

    var streamId = String(stream.stream_id || stream.streamId || stream.series_id || stream.seriesId);
    var streamName = stream.name || stream.title || ('Stream ' + streamId);
    var streamIcon = stream.stream_icon || stream.streamIcon || stream.cover || '';

    if (titleEl) titleEl.textContent = streamName;
    if (thumbEl) {
      if (streamIcon) {
        thumbEl.src = streamIcon;
        thumbEl.style.display = 'block';
        if (headerSvg) headerSvg.style.display = 'none';
      } else {
        thumbEl.style.display = 'none';
        if (headerSvg) headerSvg.style.display = 'inline-flex';
      }
    }

    var inReorderableCategory = (_activeContextType === 'live') && (
      (_selectedLiveCategory && _selectedLiveCategory.category_id === 'favorites') ||
      (_selectedLiveCategory && typeof _selectedLiveCategory.category_id === 'string' && _selectedLiveCategory.category_id.indexOf('custom_list:') === 0)
    );

    if (moveBtn) {
      if (inReorderableCategory) {
        moveBtn.style.display = 'flex';
        moveBtn.onclick = function() {
          if (Date.now() < _ignoreContextClicksUntil) return;
          closeModal(modal);
          window._channelMoveModeActive = true;
          window._movingLiveStreamId = streamId;
          if (_virtualList && typeof _virtualList.refreshMovingState === 'function') {
            _virtualList.refreshMovingState(streamId);
          }
          var toastMsg = (window.TVI18n && window.TVI18n.getLanguage() === 'de')
            ? 'Verschiebemodus aktiv (▲/▼) — OK zum Speichern'
            : 'Move mode active (▲/▼) — Press OK to save';
          showToast(toastMsg, '↕');
        };
      } else {
        moveBtn.style.display = 'none';
      }
    }

    var isFav = window.TVStorage.isFavorite(_activeAccount.id, streamId, _activeContextType);
    if (favBtn) favBtn.classList.toggle('fav-active', !!isFav);
    if (favIcon) favIcon.innerHTML = isFav ? ((window.TVIcons && window.TVIcons.starFilled) || '') : ((window.TVIcons && window.TVIcons.starOutline) || '');
    if (favLabel) {
      var favKey = isFav ? 'remove_from_favorites' : 'add_to_favorites';
      favLabel.textContent = (window.TVI18n && window.TVI18n.t(favKey)) || (isFav ? 'Aus Favoriten entfernen' : 'Zu Favoriten hinzufügen');
    }

    favBtn.onclick = function() {
      if (Date.now() < _ignoreContextClicksUntil) return;
      var res = _saveFavoriteWithSnapshot(_activeAccount.id, streamId, _activeContextType, _activeContextStream);
      favBtn.classList.toggle('fav-active', !!res);
      favIcon.innerHTML = res ? ((window.TVIcons && window.TVIcons.starFilled) || '') : ((window.TVIcons && window.TVIcons.starOutline) || '');
      var newKey = res ? 'remove_from_favorites' : 'add_to_favorites';
      favLabel.textContent = (window.TVI18n && window.TVI18n.t(newKey)) || (res ? 'Aus Favoriten entfernen' : 'Zu Favoriten hinzufügen');
      var toastKey = res ? (_activeContextType === 'live' ? 'fav_added' : 'in_watchlist') : (_activeContextType === 'live' ? 'fav_removed' : 'removed');
      var toastFallback = res ? 'Added to Favorites' : 'Removed from Favorites';
      showToast((window.TVI18n && window.TVI18n.t(toastKey)) || toastFallback, res ? 'star' : 'trash');

      if (_activeContextType === 'live' && _selectedLiveCategory && _selectedLiveCategory.category_id === 'favorites') {
        selectLiveCategory(_selectedLiveCategory);
      } else if (_activeContextType === 'movie' && _selectedMovieCategory && _selectedMovieCategory.category_id === 'favorites') {
        selectMovieCategory(_selectedMovieCategory);
      } else if (_activeContextType === 'series' && _selectedSeriesCategory && _selectedSeriesCategory.category_id === 'favorites') {
        selectSeriesCategory(_selectedSeriesCategory);
      }
    };

    renderContextCustomLists();
    var initialFocus = inReorderableCategory ? moveBtn : favBtn;
    openModal(modal, initialFocus);
  }

  function showStreamContextMenuForCard(cardEl, type) {
    if (!cardEl || document.body.classList.contains('player-fullscreen')) return;
    var stream = null;
    if (type === 'movie' || type === 'movies') {
      var id = cardEl.getAttribute('data-stream-id') || cardEl.getAttribute('data-id');
      stream = (_movieStreams || []).find(function(m) { return String(m.stream_id) === String(id); }) ||
               (_movieFilteredList || []).find(function(m) { return String(m.stream_id) === String(id); }) ||
               (_allAccountVodStreams || []).find(function(m) { return String(m.stream_id) === String(id); });
      if (!stream) {
        var title = (cardEl.querySelector('.poster-card-title, .poster-title') || {}).textContent || '';
        stream = { stream_id: id, name: title, stream_icon: (cardEl.querySelector('img') || {}).src || '' };
      }
      showStreamContextMenu(stream, 'movie');
    } else if (type === 'series') {
      var sId = cardEl.getAttribute('data-series-id') || cardEl.getAttribute('data-id');
      stream = (_seriesList || []).find(function(s) { return String(s.series_id) === String(sId); }) ||
               (_seriesFilteredList || []).find(function(s) { return String(s.series_id) === String(sId); }) ||
               (_allAccountSeriesStreams || []).find(function(s) { return String(s.series_id) === String(sId); });
      if (!stream) {
        var sTitle = (cardEl.querySelector('.poster-card-title, .poster-title') || {}).textContent || '';
        stream = { series_id: sId, name: sTitle, cover: (cardEl.querySelector('img') || {}).src || '' };
      }
      showStreamContextMenu(stream, 'series');
    }
  }

  function renderContextCustomLists() {
    var box = document.getElementById('ctx-custom-lists-container');
    if (!box) return;
    box.innerHTML = '';

    var streamId = String(_activeContextStream.stream_id || _activeContextStream.streamId || _activeContextStream.series_id || _activeContextStream.seriesId);
    var customLists = window.TVStorage.getCustomLists(_activeAccount.id, _activeContextType);

    if (customLists.length === 0) {
      var emptyMsg = document.createElement('div');
      emptyMsg.style.cssText = 'font-size:21px; color:rgba(255,255,255,0.55); padding:12px 6px; line-height:1.45;';
      emptyMsg.textContent = (window.TVI18n && window.TVI18n.t('no_custom_lists')) || 'Keine eigenen Listen vorhanden.';
      box.appendChild(emptyMsg);
      return;
    }

    customLists.forEach(function(cl) {
      var inList = window.TVStorage.isStreamInCustomList(_activeAccount.id, cl.id, streamId);
      var btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'ctx-action-btn focusable ctx-list-row' + (inList ? ' in-list' : '');
      btn.setAttribute('data-list-id', cl.id);

      var playlistSvg = (window.TVIcons && window.TVIcons.playlist) || '';
      var checkSvg = inList ? ((window.TVIcons && window.TVIcons.checkboxChecked) || '') : ((window.TVIcons && window.TVIcons.checkboxEmpty) || '');
      var inListText = inList ? ((window.TVI18n && window.TVI18n.t('in_list')) || 'In Liste') : ((window.TVI18n && window.TVI18n.t('add')) || 'Hinzufügen');

      btn.innerHTML =
        '<span class="btn-icon" style="color:' + (inList ? '#B388FF' : 'rgba(255,255,255,0.65)') + ';">' + playlistSvg + '</span>' +
        '<span style="flex:1; text-align:left; overflow:hidden; text-overflow:ellipsis; white-space:nowrap;">' + escapeHtml(cl.name) + '</span>' +
        '<span style="font-size:20px; color:rgba(255,255,255,0.58); margin-right:10px;">' + escapeHtml(inListText) + '</span>' +
        '<span class="btn-icon" style="color:' + (inList ? '#B388FF' : 'rgba(255,255,255,0.35)') + ';">' + checkSvg + '</span>';

      btn.onclick = function() {
        if (Date.now() < _ignoreContextClicksUntil) return;
        if (inList) {
          window.TVStorage.removeStreamFromCustomList(_activeAccount.id, cl.id, streamId);
          showToast((window.TVI18n && window.TVI18n.getLanguage() === 'de') ? 'Aus "' + cl.name + '" entfernt' : 'Removed from "' + cl.name + '"', 'check');
        } else {
          if (typeof window.TVStorage.saveStreamSnapshot === 'function') {
            window.TVStorage.saveStreamSnapshot(_activeAccount.id, _activeContextType, _activeContextStream);
          }
          window.TVStorage.addStreamToCustomList(_activeAccount.id, cl.id, _activeContextStream);
          showToast((window.TVI18n && window.TVI18n.getLanguage() === 'de') ? 'Zu "' + cl.name + '" hinzugefügt' : 'Added to "' + cl.name + '"', 'check');
        }
        renderContextCustomLists();
        var reFocus = box.querySelector('.ctx-list-row[data-list-id="' + cl.id + '"]');
        if (reFocus && window.SpatialNav) window.SpatialNav.setFocus(reFocus);

        if (_activeContextType === 'live' && _selectedLiveCategory && _selectedLiveCategory.category_id === 'custom_list:' + cl.id) {
          selectLiveCustomList(cl);
        } else if (_activeContextType === 'movie' && _selectedMovieCategory && _selectedMovieCategory.category_id === 'custom_list:' + cl.id) {
          selectMovieCustomList(cl);
        } else if (_activeContextType === 'series' && _selectedSeriesCategory && _selectedSeriesCategory.category_id === 'custom_list:' + cl.id) {
          selectSeriesCustomList(cl);
        }
      };

      box.appendChild(btn);
    });
  }

  function onContextCustomListLongPress(itemEl) {
    if (!itemEl) return;
    var listId = itemEl.getAttribute('data-list-id');
    if (!listId) return;
    var customLists = window.TVStorage.getCustomLists(_activeAccount.id, _activeContextType);
    var found = customLists.find(function(cl) { return String(cl.id) === String(listId); });
    if (found) {
      openCustomListOptionsModal(found);
    }
  }

  function openCustomListOptionsModal(cl) {
    if (!cl) return;
    _activeCustomList = cl;
    var modal = document.getElementById('modal-custom-list-options');
    if (!modal) return;

    var titleEl = document.getElementById('custom-list-options-title');
    if (titleEl) titleEl.textContent = cl.name || ((window.TVI18n && window.TVI18n.t('list_options')) || 'Listen-Optionen');

    openModal(modal, document.getElementById('opt-list-move-btn'));
  }

  function openCreateOrRenameListModal(mode, cl, listType) {
    _createListMode = mode || 'create';
    _activeCustomList = cl || null;
    _activeCreateListType = listType || (cl && cl.type) || null;

    var modal = document.getElementById('modal-create-list');
    if (!modal) return;

    var titleEl = document.getElementById('create-list-title');
    var inputEl = document.getElementById('create-list-input');

    if (titleEl) {
      titleEl.textContent = _createListMode === 'rename'
        ? ((window.TVI18n && window.TVI18n.t('rename_list')) || 'Liste umbenennen')
        : ((window.TVI18n && window.TVI18n.t('create_new_list')) || 'Neue Liste erstellen');
    }
    if (inputEl) {
      inputEl.value = (_createListMode === 'rename' && cl) ? cl.name : '';
    }

    openModal(modal, inputEl);
  }

  function openDeleteListModal(cl) {
    if (!cl) return;
    _activeCustomList = cl;
    var modal = document.getElementById('modal-delete-list');
    if (!modal) return;

    var descEl = document.getElementById('delete-list-desc');
    if (descEl) {
      var tmpl = (window.TVI18n && window.TVI18n.t('delete_list_confirm')) || 'Möchtest du diese Liste "{name}" wirklich löschen?';
      descEl.textContent = tmpl.replace('{name}', cl.name || '');
    }

    openModal(modal, document.getElementById('delete-list-cancel-btn'));
  }

  // =========================================================
  // LIVE CHANNEL MOVE MODE (v2.1)
  // =========================================================
  window._channelMoveModeActive = false;
  window._movingLiveStreamId = null;

  window.moveLiveChannelInList = function(dir) {
    if (!window._channelMoveModeActive || !window._movingLiveStreamId || !_liveStreams || _liveStreams.length < 2) return false;

    var streamId = String(window._movingLiveStreamId);
    var fromIdx = _liveStreams.findIndex(function(s) { return String(s.stream_id) === streamId; });
    if (fromIdx === -1) return false;

    var toIdx = fromIdx + dir;
    if (toIdx < 0 || toIdx >= _liveStreams.length) return false;

    // Swap in array
    var temp = _liveStreams[fromIdx];
    _liveStreams[fromIdx] = _liveStreams[toIdx];
    _liveStreams[toIdx] = temp;
    window._liveStreams = _liveStreams;

    // Update VirtualList
    if (_virtualList) {
      _virtualList.setItems(_liveStreams, false);
      if (typeof _virtualList.refreshMovingState === 'function') {
        _virtualList.refreshMovingState(streamId);
      }
      _virtualList.focusIndex(toIdx);
    }

    // Persist new order
    var orderedIds = _liveStreams.map(function(s) { return String(s.stream_id); });
    if (_selectedLiveCategory && _selectedLiveCategory.category_id === 'favorites') {
      window.TVStorage.reorderFavorites(_activeAccount.id, 'live', orderedIds);
    } else if (_selectedLiveCategory && typeof _selectedLiveCategory.category_id === 'string' && _selectedLiveCategory.category_id.indexOf('custom_list:') === 0) {
      var clId = _selectedLiveCategory.category_id.replace('custom_list:', '');
      window.TVStorage.reorderCustomListItems(_activeAccount.id, clId, orderedIds);
    }

    return true;
  };

  window.exitLiveChannelMoveMode = function() {
    window._channelMoveModeActive = false;
    var streamId = window._movingLiveStreamId;
    window._movingLiveStreamId = null;

    if (_virtualList && typeof _virtualList.refreshMovingState === 'function') {
      _virtualList.refreshMovingState(null);
    }

    var toastMsg = (window.TVI18n && window.TVI18n.getLanguage() === 'de') ? 'Senderreihenfolge gespeichert' : 'Channel order saved';
    showToast(toastMsg, 'check');

    if (streamId) {
      var rowEl = document.querySelector('.channel-row[data-stream-id="' + streamId + '"]');
      if (rowEl && window.SpatialNav) window.SpatialNav.setFocus(rowEl);
    }
  };

  window.openCategoryManager = openCategoryManager;
  window.openCategoryManagerForCurrentTab = function() {
    var t = _currentTab === 'movies' ? 'movie' : (_currentTab === 'series' ? 'series' : 'live');
    openCategoryManager(t);
  };
  window.renderCategoryManagerList = renderCategoryManagerList;
  window.moveCategoryInManager = moveCategoryInManager;
  window.exitCategoryMoveMode = exitCategoryMoveMode;
  window.onCategoryManagerItemLongPress = onCategoryManagerItemLongPress;
  window.showStreamContextMenu = showStreamContextMenu;
  window.showStreamContextMenuForCard = showStreamContextMenuForCard;
  window.onContextCustomListLongPress = onContextCustomListLongPress;

  window.TVApp = {
    openModal: openModal,
    closeModal: closeModal,
    loadNextMovieBatch: loadNextMovieBatch,
    loadNextSeriesBatch: loadNextSeriesBatch,
    loadMoreCategoryManagerItems: loadMoreCategoryManagerItems,
    loadMoreCategoriesFor: loadMoreCategoriesFor,
    hasMoreMovies: function() { return _movieLoadedCount < _movieFilteredList.length; },
    hasMoreSeries: function() { return _seriesLoadedCount < _seriesFilteredList.length; }
  };

  if (document.readyState === 'loading') {
    window.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
