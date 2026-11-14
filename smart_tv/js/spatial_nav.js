// 2D Spatial Navigation Engine for LG webOS & Samsung Tizen Smart TVs
(function() {
  if (window.SpatialNav && typeof window.SpatialNav.destroy === 'function') {
    try { window.SpatialNav.destroy(); } catch (_) {}
  }

  var _currentFocused = null;
  var _backCallbacks = [];
  var _enterHoldTimer = null;
  var _enterHoldTriggered = false;
  var _enterFocusedElement = null;
  var _suppressNextClick = false;
  var _lastYellowActionAt = 0;
  var _lastLongPressAt = 0;
  var _isVirtualKeyboardVisible = false;

  var KEY_CODES = {
    LEFT: 37,
    UP: 38,
    RIGHT: 39,
    DOWN: 40,
    ENTER: 13,
    RETURN_ESC: 27,
    WEBOS_BACK: 461,
    TIZEN_BACK: 10009,
    RED: 403,
    GREEN: 404,
    YELLOW: 405,
    BLUE: 406
  };

  // Register Samsung Tizen remote control keys (Color keys, Media keys, etc.)
  function registerTizenKeys() {
    try {
      if (typeof window !== 'undefined' && window.tizen && window.tizen.tvinputdevice && typeof window.tizen.tvinputdevice.registerKey === 'function') {
        var keysToRegister = [
          'ColorF0Red',
          'ColorF1Green',
          'ColorF2Yellow',
          'ColorF3Blue',
          'MediaPlay',
          'MediaPause',
          'MediaPlayPause',
          'MediaStop',
          'MediaFastForward',
          'MediaRewind',
          'Info',
          'Guide',
          'ChannelUp',
          'ChannelDown'
        ];
        for (var i = 0; i < keysToRegister.length; i++) {
          try {
            window.tizen.tvinputdevice.registerKey(keysToRegister[i]);
          } catch(e) {}
        }
      }
    } catch(err) {
      console.warn('[Tizen] Key registration error:', err);
    }
  }

  // Register Tizen remote keys immediately and on window load
  registerTizenKeys();
  if (typeof document !== 'undefined') {
    document.addEventListener('DOMContentLoaded', registerTizenKeys);
  }
  if (typeof window !== 'undefined') {
    window.addEventListener('load', registerTizenKeys);
    window.registerTizenKeys = registerTizenKeys;
  }

  function isYellowKey(e, code) {
    if (code === 405 || code === 70 || code === 89) return true;
    var k = (e.key || '').toLowerCase();
    return k === 'colorf2yellow' || k === 'yellow' || k === 'f' || k === 'y';
  }

  function isGreenKey(e, code) {
    if (code === 404 || code === 71) return true;
    var k = (e.key || '').toLowerCase();
    return k === 'colorf1green' || k === 'green' || k === 'g';
  }

  function isBlueKey(e, code) {
    if (code === 406 || code === 66) return true;
    var k = (e.key || '').toLowerCase();
    return k === 'colorf3blue' || k === 'blue' || k === 'b';
  }

  function isRedKey(e, code) {
    if (code === 403 || code === 82) return true;
    var k = (e.key || '').toLowerCase();
    return k === 'colorf0red' || k === 'red' || k === 'r';
  }

  function isInput(el) {
    if (!el) return false;
    var tag = el.tagName ? el.tagName.toUpperCase() : '';
    return tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT';
  }

  function getClearButtonForInput(inputEl) {
    if (!inputEl) return null;
    var id = inputEl.id;
    if (id === 'live-cat-search') return document.getElementById('live-cat-clear-btn');
    if (id === 'movies-cat-search') return document.getElementById('movies-cat-clear-btn');
    if (id === 'movies-search-input') return document.getElementById('movies-search-clear-btn');
    if (id === 'series-cat-search') return document.getElementById('series-cat-clear-btn');
    if (id === 'series-search-input') return document.getElementById('series-search-clear-btn');
    if (id === 'master-search-input') return document.getElementById('master-search-clear-btn');
    var parent = inputEl.parentElement;
    return parent ? parent.querySelector('.search-clear-btn') : null;
  }

  function isPreviewActive() {
    var p = window._goatPlayer;
    if (!p || !p.currentStream || p.playbackType !== 'live') return false;
    var msg = document.getElementById('preview-placeholder-msg');
    if (msg && window.getComputedStyle(msg).display !== 'none') return false;
    return true;
  }

  var LARGE_SCROLL_IDS = {
    'live-categories-list': true,
    'movies-categories-list': true,
    'series-categories-list': true,
    'channels-virtual-container': true,
    'movies-grid-container': true,
    'series-grid-container': true,
    'cat-mgr-list': true
  };

  function getFocusableElements(container) {
    var root = container || document;
    var elements = root.querySelectorAll('.focusable, button:not([disabled]), input:not([disabled]), [tabindex="0"]');
    var total = elements.length;
    var pruneOffscreen = total > 60;
    var scrollBounds = pruneOffscreen ? {} : null;
    var result = [];
    for (var i = 0; i < total; i++) {
      var el = elements[i];
      if (el.id === 'preview-player-box' && !isPreviewActive()) continue;
      if (pruneOffscreen && el !== _currentFocused) {
        var rowItem = el;
        var scroller = el.parentElement;
        if (scroller && scroller.classList && scroller.classList.contains('channel-row-wrap')) {
          rowItem = scroller;
          scroller = scroller.parentElement;
        }
        if (scroller && scroller.id && LARGE_SCROLL_IDS[scroller.id]) {
          var bounds = scrollBounds[scroller.id];
          if (!bounds) {
            bounds = scrollBounds[scroller.id] = {
              top: scroller.scrollTop - 220,
              bottom: scroller.scrollTop + (scroller.clientHeight || 800) + 220
            };
          }
          var top = rowItem.offsetTop;
          if (top + 120 < bounds.top || top > bounds.bottom) {
            continue;
          }
        }
      }
      // Element must be visible and attached to the layout tree (offsetParent !== null)
      if (el.offsetParent !== null) {
        result.push(el);
      }
    }
    return result;
  }

  function getCenter(rect) {
    return {
      x: rect.left + rect.width / 2,
      y: rect.top + rect.height / 2
    };
  }

  function getActiveScope() {
    var epgOverlay = document.getElementById('live-epg-overlay');
    if (epgOverlay && epgOverlay.style.display !== 'none') return epgOverlay;

    var catMenu = document.getElementById('live-category-menu');
    if (catMenu && catMenu.style.display !== 'none') return catMenu;

    var channelMenu = document.getElementById('live-channel-menu');
    if (channelMenu && channelMenu.style.display !== 'none') return channelMenu;

    // If focus is currently inside an active modal, that modal is strictly the scope
    if (_currentFocused) {
      var currentModal = _currentFocused.closest ? _currentFocused.closest('.modal-overlay.active') : null;
      if (currentModal) return currentModal;
    }

    var activeModals = document.querySelectorAll('.modal-overlay.active');
    if (activeModals.length > 0) return activeModals[activeModals.length - 1];

    var openDrawer = document.querySelector('.slide-drawer.open');
    if (openDrawer) return openDrawer;

    var vodHud = document.getElementById('player-hud-vod');
    if (vodHud && vodHud.classList.contains('visible')) return vodHud;

    var activeScreen = document.querySelector('.screen-view.active');
    if (activeScreen) return activeScreen;

    return document;
  }

  function findNextInDirection(current, direction) {
    if (!current) return null;

    // 1. Explicit override via data-nav-* attribute
    var explicitAttr = 'data-nav-' + direction;
    var explicitSelector = current.getAttribute(explicitAttr);
    if (explicitSelector) {
      var target = document.querySelector(explicitSelector);
      if (target && target.offsetParent !== null) return target;
    }

    // 1b. Fast-path: Sibling navigation in vertical lists & grids (0ms instant D-pad response)
    var isGridCard = current.classList.contains('poster-card') || current.classList.contains('cw-card');
    if (isGridCard && current.parentElement) {
      if (direction === 'left' && current.previousElementSibling && current.previousElementSibling.classList.contains('focusable')) {
        var prevTop = current.previousElementSibling.offsetTop;
        var curTopL = current.offsetTop;
        if (Math.abs(prevTop - curTopL) < 20) {
          return current.previousElementSibling;
        }
        return null;
      }
      if (direction === 'right' && current.nextElementSibling && current.nextElementSibling.classList.contains('focusable')) {
        var nextTop = current.nextElementSibling.offsetTop;
        var curTopR = current.offsetTop;
        if (Math.abs(nextTop - curTopR) < 20) {
          return current.nextElementSibling;
        }
        return null;
      }
      if (direction === 'down' || direction === 'up') {
        var parent = current.parentElement;
        var siblings = parent.children;
        var curIdx = -1;
        for (var s = 0; s < siblings.length; s++) {
          if (siblings[s] === current) { curIdx = s; break; }
        }
        if (curIdx !== -1) {
          var curTop = current.offsetTop;
          var curLeft = current.offsetLeft;
          var nextRowSibling = null;
          var minLeftDiff = Infinity;

          if (direction === 'down') {
            for (var d = curIdx + 1; d < siblings.length; d++) {
              var sib = siblings[d];
              if (!sib.classList.contains('focusable') || sib.offsetParent === null) continue;
              if (sib.offsetTop > curTop + 20) {
                var diff = Math.abs(sib.offsetLeft - curLeft);
                if (diff < minLeftDiff) {
                  minLeftDiff = diff;
                  nextRowSibling = sib;
                } else if (diff > minLeftDiff) {
                  break;
                }
              }
            }
          } else if (direction === 'up') {
            for (var u = curIdx - 1; u >= 0; u--) {
              var sibU = siblings[u];
              if (!sibU.classList.contains('focusable') || sibU.offsetParent === null) continue;
              if (sibU.offsetTop < curTop - 20) {
                var diffU = Math.abs(sibU.offsetLeft - curLeft);
                if (diffU < minLeftDiff) {
                  minLeftDiff = diffU;
                  nextRowSibling = sibU;
                } else if (diffU > minLeftDiff) {
                  break;
                }
              }
            }
          }
          if (nextRowSibling) return nextRowSibling;
        }
      }
    }

    // Fast-path: Vertical list navigation (Categories, Channels, Episode drawers, Settings, Category Manager, Context Menu)
    var isListRow = current.classList.contains('category-menu-item') ||
                    current.classList.contains('channel-menu-item') ||
                    current.classList.contains('channel-row') ||
                    current.classList.contains('category-item') ||
                    current.classList.contains('track-opt-btn') ||
                    current.classList.contains('episode-card') ||
                    current.classList.contains('sort-opt-btn') ||
                    current.classList.contains('cat-mgr-item') ||
                    current.classList.contains('ctx-action-btn') ||
                    current.classList.contains('ctx-list-row') ||
                    current.classList.contains('ctx-custom-list-btn');

    if (isListRow && current.parentElement) {
      if (direction === 'down') {
        var next = current.nextElementSibling;
        while (next) {
          if (next.classList.contains('focusable') && next.offsetParent !== null) return next;
          var inner = next.querySelector('.focusable');
          if (inner && inner.offsetParent !== null) return inner;
          next = next.nextElementSibling;
        }
      } else if (direction === 'up') {
        var prev = current.previousElementSibling;
        while (prev) {
          if (prev.classList.contains('focusable') && prev.offsetParent !== null) return prev;
          var innerPrev = prev.querySelector('.focusable');
          if (innerPrev && innerPrev.offsetParent !== null) return innerPrev;
          prev = prev.previousElementSibling;
        }
      }
    }

    // 2. Active container or modal scope
    var insideModal = current.closest ? current.closest('.modal-overlay.active') : null;
    var scope = insideModal || getActiveScope();
    var candidates = getFocusableElements(scope);
    if (candidates.length <= 1) return null;

    var curRect = current.getBoundingClientRect();
    var curCenter = getCenter(curRect);

    var bestCandidate = null;
    var minDistance = Infinity;

    for (var i = 0; i < candidates.length; i++) {
      var candidate = candidates[i];
      if (candidate === current) continue;

      // When navigating from or between account cards, ignore child icon buttons in candidate search
      if (current.classList.contains('account-card') && candidate.classList.contains('account-icon-btn')) {
        continue;
      }

      // Never navigate to fav buttons via D-pad arrows
      if (candidate.classList.contains('fav-btn')) {
        continue;
      }

      var candRect = candidate.getBoundingClientRect();
      var candCenter = getCenter(candRect);

      var dx = candCenter.x - curCenter.x;
      var dy = candCenter.y - curCenter.y;

      var inBeam = false;

      switch (direction) {
        case 'up':
          if (candRect.bottom <= curRect.top + 6) {
            isValidDirection = true;
            primaryDist = curRect.top - candRect.bottom;
            inBeam = (candRect.right > curRect.left && candRect.left < curRect.right);
            secondaryDist = inBeam ? 0 : Math.min(Math.abs(candRect.left - curRect.right), Math.abs(curRect.left - candRect.right));
          }
          break;
        case 'down':
          if (candRect.top >= curRect.bottom - 6) {
            isValidDirection = true;
            primaryDist = candRect.top - curRect.bottom;
            inBeam = (candRect.right > curRect.left && candRect.left < curRect.right);
            secondaryDist = inBeam ? 0 : Math.min(Math.abs(candRect.left - curRect.right), Math.abs(curRect.left - candRect.right));
          }
          break;
        case 'left':
          if (candRect.right <= curRect.left + 6) {
            isValidDirection = true;
            primaryDist = curRect.left - candRect.right;
            inBeam = (candRect.bottom > curRect.top && candRect.top < curRect.bottom);
            secondaryDist = inBeam ? 0 : Math.min(Math.abs(candRect.top - curRect.bottom), Math.abs(curRect.top - candRect.bottom));
          }
          break;
        case 'right':
          if (candRect.left >= curRect.right - 6) {
            isValidDirection = true;
            primaryDist = candRect.left - curRect.right;
            inBeam = (candRect.bottom > curRect.top && candRect.top < curRect.bottom);
            secondaryDist = inBeam ? 0 : Math.min(Math.abs(candRect.top - curRect.bottom), Math.abs(curRect.top - candRect.bottom));
          }
          break;
      }

      if (isValidDirection) {
        // Elements directly in the projection beam (same row for left/right, same column for up/down)
        // are strongly favored. Elements outside the beam receive a massive penalty.
        var score = primaryDist + (secondaryDist * 2.5) + (inBeam ? 0 : 3000);
        if (score < minDistance) {
          minDistance = score;
          bestCandidate = candidate;
        }
      }
    }

    return bestCandidate;
  }

  function setFocus(el, skipScroll) {
    if (el && el.id === 'preview-player-box' && !isPreviewActive()) return;
    if (!el) {
      document.body.classList.remove('preview-focused');
      if (_currentFocused) {
        _currentFocused.classList.remove('focused');
        var prevWrap = _currentFocused.closest ? _currentFocused.closest('.input-wrapper, .search-input-wrapper, .vod-search-wrapper, .search-box-container, .col-search-box') : null;
        if (prevWrap) prevWrap.classList.remove('input-focused');
        if (isInput(_currentFocused) && document.activeElement === _currentFocused) {
          try { _currentFocused.blur(); } catch(e){}
        }
        _currentFocused = null;
      }
      return;
    }
    if (_currentFocused && _currentFocused !== el) {
      _currentFocused.classList.remove('focused');
      var oldWrap = _currentFocused.closest ? _currentFocused.closest('.input-wrapper, .search-input-wrapper, .vod-search-wrapper, .search-box-container, .col-search-box') : null;
      if (oldWrap) oldWrap.classList.remove('input-focused');
      if (isInput(_currentFocused) && document.activeElement === _currentFocused) {
        try { _currentFocused.blur(); } catch(e){}
      }
    }

    _currentFocused = el;
    el.classList.add('focused');
    var newWrap = el.closest ? el.closest('.input-wrapper, .search-input-wrapper, .vod-search-wrapper, .search-box-container, .col-search-box') : null;
    if (newWrap) newWrap.classList.add('input-focused');

    if (el && (el.id === 'preview-player-box' || el.id === 'player-container')) {
      document.body.classList.add('preview-focused');
    } else {
      document.body.classList.remove('preview-focused');
    }

    // Do NOT call el.focus() on INPUT elements during navigation!
    // Calling focus() on webOS/Tizen immediately triggers the on-screen virtual keyboard.
    if (!isInput(el)) {
      try {
        el.focus();
      } catch(e){}
    } else if (document.activeElement && document.activeElement !== el && typeof document.activeElement.blur === 'function') {
      try {
        document.activeElement.blur();
      } catch(e){}
    }

    if (!skipScroll) {
      try {
        el.scrollIntoView({ behavior: 'auto', block: 'nearest', inline: 'nearest' });
      } catch(e) {
        try { el.scrollIntoView(false); } catch(err){}
      }
    }

    if (typeof el._onFocus === 'function') {
      el._onFocus(el);
    }
  }

  function escapeFromSearchInput(inputEl) {
    if (!inputEl) return false;
    try {
      if (document.activeElement && isInput(document.activeElement)) {
        document.activeElement.blur();
      }
      if (isInput(inputEl)) {
        inputEl.blur();
      }
    } catch(e){}

    var id = inputEl.id || '';
    if (id === 'live-cat-search' || id === 'live-cat-clear-btn') {
      var firstCat = document.querySelector('#live-categories-list .category-item.active') ||
                     document.querySelector('#live-categories-list .category-item');
      if (firstCat) { setFocus(firstCat); return true; }
    } else if (id === 'movies-cat-search' || id === 'movies-cat-clear-btn') {
      var firstCatM = document.querySelector('#movies-categories-list .category-item.active') ||
                      document.querySelector('#movies-categories-list .category-item');
      if (firstCatM) { setFocus(firstCatM); return true; }
    } else if (id === 'movies-search-input' || id === 'movies-search-clear-btn') {
      var firstPosterM = document.querySelector('#movies-grid-container .poster-card');
      if (firstPosterM) { setFocus(firstPosterM); return true; }
      var activeCatM = document.querySelector('#movies-categories-list .category-item.active');
      if (activeCatM) { setFocus(activeCatM); return true; }
    } else if (id === 'series-cat-search' || id === 'series-cat-clear-btn') {
      var firstCatS = document.querySelector('#series-categories-list .category-item.active') ||
                      document.querySelector('#series-categories-list .category-item');
      if (firstCatS) { setFocus(firstCatS); return true; }
    } else if (id === 'series-search-input' || id === 'series-search-clear-btn') {
      var firstPosterS = document.querySelector('#series-grid-container .poster-card');
      if (firstPosterS) { setFocus(firstPosterS); return true; }
      var activeCatS = document.querySelector('#series-categories-list .category-item.active');
      if (activeCatS) { setFocus(activeCatS); return true; }
    } else if (id === 'master-search-input' || id === 'master-search-clear-btn') {
      var firstRow = document.querySelector('#master-search-results .search-result-row') ||
                     document.getElementById('search-tab-live') ||
                     document.getElementById('master-search-close-btn');
      if (firstRow) { setFocus(firstRow); return true; }
    } else if (inputEl.classList && (inputEl.classList.contains('col-search-input') || inputEl.classList.contains('vod-search-input') || inputEl.classList.contains('search-input'))) {
      var activePage = document.querySelector('.page-view.active');
      var item = activePage ? (activePage.querySelector('.category-item.active') || activePage.querySelector('.category-item') || activePage.querySelector('.poster-card')) : null;
      if (item) { setFocus(item); return true; }
    }
    return false;
  }

  function handleKeyDown(e) {
    var splashEl = document.getElementById('app-splash');
    if (splashEl && !splashEl.classList.contains('dismissed')) {
      e.preventDefault();
      e.stopPropagation();
      return;
    }

    var code = e.keyCode || e.which;
    var isBackKey = (code === KEY_CODES.RETURN_ESC || code === KEY_CODES.WEBOS_BACK || code === KEY_CODES.TIZEN_BACK || (e.key && (e.key === 'Back' || e.key === 'GoBack' || e.key === 'Escape')));
    var isActivelyEditing = isInput(document.activeElement);

    if (isActivelyEditing) {
      if (isBackKey) {
        var inActiveModal = document.activeElement && document.activeElement.closest && document.activeElement.closest('.modal-overlay.active');
        if (_isVirtualKeyboardVisible) {
          e.preventDefault();
          e.stopPropagation();
          _isVirtualKeyboardVisible = false;
          try { document.activeElement.blur(); } catch(err){}
          return;
        }
        var escaped = escapeFromSearchInput(document.activeElement || _currentFocused);
        if (escaped) {
          e.preventDefault();
          e.stopPropagation();
          return;
        }
        try { document.activeElement.blur(); } catch(err){}
        if (!inActiveModal) {
          e.preventDefault();
          e.stopPropagation();
          return;
        }
        isActivelyEditing = false;
      } else {
      if (code === KEY_CODES.ENTER) {
        e.preventDefault();
        e.stopPropagation();
        try { document.activeElement.blur(); } catch(err){}
        return;
      }
      // Red button on TV remote clears the active search field immediately!
      var isRemoteRed = (code === 403 || (e.key && (e.key.toLowerCase().indexOf('red') !== -1 || e.key.toLowerCase() === 'colorf0red')));
      if (isRemoteRed) {
        e.preventDefault();
        e.stopPropagation();
        var cBtn = getClearButtonForInput(document.activeElement);
        if (cBtn) {
          cBtn.click();
        } else {
          document.activeElement.value = '';
          document.activeElement.dispatchEvent(new Event('input', { bubbles: true }));
        }
        return;
      }
      // When user is in an input and presses navigation arrows (DOWN, UP, LEFT, RIGHT),
      // blur the input and allow spatial navigation to immediately navigate away!
      if (code === KEY_CODES.DOWN || code === KEY_CODES.UP || code === KEY_CODES.LEFT || code === KEY_CODES.RIGHT) {
        _isVirtualKeyboardVisible = false;
        try { document.activeElement.blur(); } catch(err){}
        isActivelyEditing = false;
        // Fall through to spatial navigation below
      } else {
        return;
      }
      }
    }

    // Check Back / Return key
    if (isBackKey) {
      e.preventDefault();

      // Exit Category Manager Move Mode on Back key first (without closing modal)
      if (window._moveModeActive && typeof window.exitCategoryMoveMode === 'function') {
        e.stopPropagation();
        window.exitCategoryMoveMode();
        return;
      }

      // Exit Live Channel Move Mode on Back key first
      if (window._channelMoveModeActive && typeof window.exitLiveChannelMoveMode === 'function') {
        e.stopPropagation();
        window.exitLiveChannelMoveMode();
        return;
      }

      // If a search input or clear button is focused, escape to content below instead of exiting dashboard!
      if (_currentFocused && (isInput(_currentFocused) || (_currentFocused.id && _currentFocused.id.indexOf('-clear-btn') !== -1))) {
        var escapedFromSearch = escapeFromSearchInput(_currentFocused);
        if (escapedFromSearch) {
          e.stopPropagation();
          return;
        }
      }

      // If a VOD sort dropdown is open, close it and return focus to its sort button
      var movieSortDropdown = document.getElementById('movies-sort-dropdown');
      if (movieSortDropdown && movieSortDropdown.style.display !== 'none') {
        movieSortDropdown.style.display = 'none';
        var mBtn = document.getElementById('movies-sort-btn');
        if (mBtn) setFocus(mBtn);
        return;
      }
      var seriesSortDropdown = document.getElementById('series-sort-dropdown');
      if (seriesSortDropdown && seriesSortDropdown.style.display !== 'none') {
        seriesSortDropdown.style.display = 'none';
        var sBtn = document.getElementById('series-sort-btn');
        if (sBtn) setFocus(sBtn);
        return;
      }

      for (var b = _backCallbacks.length - 1; b >= 0; b--) {
        var callback = _backCallbacks[b];
        if (typeof callback === 'function' && callback()) {
          return;
        }
      }
      return;
    }

    // Fullscreen Player key bypass:
    // If player is fullscreen and neither modal nor Smart IPTV overlay is open, let video controls handle D-Pad
    var isModalOpen = !!document.querySelector('.modal-overlay.active');
    var isDrawerOpen = !!document.querySelector('.slide-drawer.open');
    var cmEl = document.getElementById('live-channel-menu');
    var isChannelMenuOpen = cmEl && cmEl.style.display !== 'none';
    var catEl = document.getElementById('live-category-menu');
    var isCatMenuOpen = catEl && catEl.style.display !== 'none';
    var epgEl = document.getElementById('live-epg-overlay');
    var isEpgOverlayOpen = epgEl && epgEl.style.display !== 'none';
    var vodHudEl = document.getElementById('player-hud-vod');
    var isVodHudOpen = vodHudEl && vodHudEl.classList.contains('visible');

    var isFullscreen = document.body.classList.contains('player-fullscreen') || (window._goatPlayer && window._goatPlayer.currentMode === 'fullscreen');
    if (isFullscreen && !isModalOpen && !isDrawerOpen && !isChannelMenuOpen && !isCatMenuOpen && !isEpgOverlayOpen && !isVodHudOpen) {
      return;
    }

    // STRICT FOCUS TRAP FOR FULL EPG OVERLAY
    if (isEpgOverlayOpen) {
      if (_currentFocused && _currentFocused.id === 'epg-overlay-close-btn') {
        if (code === KEY_CODES.ENTER) {
          e.preventDefault();
          e.stopPropagation();
          _currentFocused.click();
          return;
        }
        if (code === KEY_CODES.DOWN) {
          var firstEpg = document.querySelector('#epg-overlay-list .epg-overlay-item');
          if (firstEpg) {
            e.preventDefault();
            e.stopPropagation();
            setFocus(firstEpg);
            return;
          }
        }
        e.preventDefault();
        e.stopPropagation();
        return;
      }
      if (_currentFocused && _currentFocused.classList.contains('epg-overlay-item')) {
        if (code === KEY_CODES.UP) {
          e.preventDefault();
          e.stopPropagation();
          var prevEpg = _currentFocused.previousElementSibling;
          if (prevEpg && prevEpg.classList.contains('epg-overlay-item')) {
            setFocus(prevEpg);
          } else {
            var closeBtn = document.getElementById('epg-overlay-close-btn');
            if (closeBtn) setFocus(closeBtn);
          }
          return;
        } else if (code === KEY_CODES.DOWN) {
          e.preventDefault();
          e.stopPropagation();
          var nextEpg = _currentFocused.nextElementSibling;
          if (nextEpg && nextEpg.classList.contains('epg-overlay-item')) {
            setFocus(nextEpg);
          }
          return;
        } else if (code === KEY_CODES.LEFT || code === KEY_CODES.RIGHT) {
          e.preventDefault();
          e.stopPropagation();
          return;
        }
      }
      // If focus is somehow outside EPG overlay, force it into the overlay
      if (!_currentFocused || !_currentFocused.closest('#live-epg-overlay')) {
        var epgClose = document.getElementById('epg-overlay-close-btn');
        if (epgClose) {
          e.preventDefault();
          e.stopPropagation();
          setFocus(epgClose);
          return;
        }
      }
      if (code === KEY_CODES.LEFT || code === KEY_CODES.RIGHT) {
        e.preventDefault();
        e.stopPropagation();
        return;
      }
    }

    // If nothing currently focused or focus drifted outside an active modal, focus first candidate in active scope
    var activeModalOverlay = document.querySelector('.modal-overlay.active');
    if (!_currentFocused || _currentFocused.offsetParent === null || (activeModalOverlay && !activeModalOverlay.contains(_currentFocused))) {
      var scope = activeModalOverlay || getActiveScope();
      if (scope && scope.id === 'modal-category-manager') {
        var mgrFallback = scope.querySelector('#cat-mgr-list .cat-mgr-item') ||
                          document.getElementById('cat-mgr-toggle-hidden');
        if (mgrFallback) {
          setFocus(mgrFallback);
          return;
        }
      }
      var candidates = getFocusableElements(scope);
      if (candidates.length > 0) {
        setFocus(candidates[0]);
      }
      return;
    }

    // Handle ENTER
    if (code === KEY_CODES.ENTER) {
      if (_enterHoldTriggered) {
        if (e.repeat || (Date.now() - _lastLongPressAt < 450)) {
          e.preventDefault();
          e.stopPropagation();
          return;
        }
        // Recover cleanly if a previous keyup was dropped after modal/focus transition
        _enterHoldTriggered = false;
      }

      // Category Manager Move Mode: short ENTER cleanly exits move mode
      if (window._moveModeActive && _currentFocused && _currentFocused.closest && _currentFocused.closest('.cat-mgr-item')) {
        e.preventDefault();
        e.stopPropagation();
        if (!e.repeat && (Date.now() - _lastLongPressAt >= 450)) {
          if (_enterHoldTimer) {
            clearTimeout(_enterHoldTimer);
            _enterHoldTimer = null;
          }
          _enterFocusedElement = null;
          _suppressNextClick = true;
          setTimeout(function() { _suppressNextClick = false; }, 350);
          if (typeof window.exitCategoryMoveMode === 'function') {
            window.exitCategoryMoveMode();
          }
        }
        return;
      }

      if (isInput(_currentFocused)) {
        e.preventDefault();
        try {
          _currentFocused.focus();
          if (typeof _currentFocused.select === 'function') {
            _currentFocused.select();
          }
        } catch(err){}
        return;
      }

      // Live Channel Move Mode: exit move mode on ENTER
      if (window._channelMoveModeActive && typeof window.exitLiveChannelMoveMode === 'function') {
        e.preventDefault();
        e.stopPropagation();
        window.exitLiveChannelMoveMode();
        return;
      }

      // Handle long-press (500ms hold) for Stream Context Menu, Category Manager & Custom Lists
      var longPressTarget = null;
      var longPressAction = null;

      if (_currentFocused) {
        var inFullscreen = document.body.classList.contains('player-fullscreen');
        var channelWrap = !inFullscreen ? _currentFocused.closest('.channel-row-wrap') : null;
        var movieCard = !inFullscreen ? (_currentFocused.closest('.movie-card, .poster-card[data-type="movie"]') ||
                        (_currentFocused.closest('#movies-grid-container') ? _currentFocused.closest('.poster-card') : null)) : null;
        var seriesCard = !inFullscreen ? (_currentFocused.closest('.series-card, .poster-card[data-type="series"]') ||
                         (_currentFocused.closest('#series-grid-container') ? _currentFocused.closest('.poster-card') : null)) : null;
        var catItem = _currentFocused.closest('.category-item');
        var catMgrItem = _currentFocused.closest('.cat-mgr-item');
        var ctxListRow = _currentFocused.closest('.ctx-list-row, .ctx-custom-list-btn');
        var accCard = _currentFocused.closest('.account-card');

        if (channelWrap) {
          longPressTarget = channelWrap;
          longPressAction = function() {
            var idx = parseInt(channelWrap.getAttribute('data-index'), 10);
            var stream = (window._goatVirtualList && window._goatVirtualList.items) ? window._goatVirtualList.items[idx] : null;
            if (stream) {
              if (typeof window.showStreamContextMenu === 'function') {
                window.showStreamContextMenu(stream, 'live');
              } else if (typeof window.toggleChannelFavorite === 'function') {
                window.toggleChannelFavorite(stream, channelWrap);
              }
            }
          };
        } else if (movieCard) {
          longPressTarget = movieCard;
          longPressAction = function() {
            if (typeof window.showStreamContextMenuForCard === 'function') {
              window.showStreamContextMenuForCard(movieCard, 'movie');
            }
          };
        } else if (seriesCard) {
          longPressTarget = seriesCard;
          longPressAction = function() {
            if (typeof window.showStreamContextMenuForCard === 'function') {
              window.showStreamContextMenuForCard(seriesCard, 'series');
            }
          };
        } else if (catItem) {
          longPressTarget = catItem;
          longPressAction = function() {
            if (typeof window.openCategoryManagerForCurrentTab === 'function') {
              window.openCategoryManagerForCurrentTab();
            }
          };
        } else if (catMgrItem) {
          longPressTarget = catMgrItem;
          longPressAction = function() {
            if (typeof window.onCategoryManagerItemLongPress === 'function') {
              window.onCategoryManagerItemLongPress(catMgrItem);
            }
          };
        } else if (ctxListRow) {
          longPressTarget = ctxListRow;
          longPressAction = function() {
            if (typeof window.onContextCustomListLongPress === 'function') {
              window.onContextCustomListLongPress(ctxListRow);
            }
          };
        } else if (accCard) {
          longPressTarget = accCard;
          longPressAction = function() {
            var editBtn = accCard.querySelector('.account-icon-btn.edit');
            if (editBtn) editBtn.click();
          };
        }
      }

      if (longPressTarget && longPressAction) {
        e.preventDefault();
        e.stopPropagation();
        if (_enterHoldTriggered) return;
        if (!e.repeat && (!_enterHoldTimer || _enterFocusedElement !== _currentFocused)) {
          _enterHoldTriggered = false;
          _enterFocusedElement = _currentFocused;
          if (_enterHoldTimer) clearTimeout(_enterHoldTimer);
          _enterHoldTimer = setTimeout(function() {
            _enterHoldTriggered = true;
            _lastLongPressAt = Date.now();
            _enterHoldTimer = null;
            _enterFocusedElement = null;
            longPressAction();
            _suppressNextClick = true;
            setTimeout(function() { _suppressNextClick = false; }, 500);
          }, 550);
        }
        return;
      }

      // Scrubber progress bar: commit pending seek and continue playing (never click to 0:00)
      if (_currentFocused && _currentFocused.id === 'vod-progress-bar') {
        e.preventDefault();
        e.stopPropagation();
        var p = window._goatPlayer || window._player;
        if (p) {
          if (typeof p._commitPendingSeek === 'function') {
            p._commitPendingSeek();
          }
          if (p.videoEl && p.videoEl.paused) {
            p.play();
          }
        }
        return;
      }

      e.preventDefault();
      e.stopPropagation();
      _currentFocused.click();
      return;
    }

    // Red Key (code 403 on Smart TV, or 'R' Key):
    // 1. Remove focused Continue Watching card
    // 2. Clear focused search input field
    if (!isEpgOverlayOpen && isRedKey(e, code)) {
      var actEl = document.activeElement;
      var curInput = (actEl && isInput(actEl)) ? actEl : (_currentFocused && isInput(_currentFocused) ? _currentFocused : null);
      if (curInput) {
        var clearBtn = getClearButtonForInput(curInput);
        if (clearBtn) {
          e.preventDefault();
          e.stopPropagation();
          clearBtn.click();
          return;
        }
      }

      var cwCard = _currentFocused ? _currentFocused.closest('.cw-card') : null;
      if (cwCard) {
        e.preventDefault();
        e.stopPropagation();
        var remBtn = cwCard.querySelector('.cw-remove-btn');
        if (remBtn) {
          remBtn.click();
        }
        return;
      }

      var redAccCard = _currentFocused ? _currentFocused.closest('.account-card') : null;
      if (redAccCard) {
        var delBtn = redAccCard.querySelector('.account-icon-btn.delete');
        if (delBtn) {
          e.preventDefault();
          e.stopPropagation();
          delBtn.click();
          return;
        }
      }
    }

    // Yellow Key (code 405 on Smart TV), 'F' or 'Y' Key:
    if (!isEpgOverlayOpen && isYellowKey(e, code)) {
      var yellowAccCard = _currentFocused ? _currentFocused.closest('.account-card') : null;
      if (yellowAccCard) {
        var editBtn = yellowAccCard.querySelector('.account-icon-btn.edit');
        if (editBtn) {
          e.preventDefault();
          e.stopPropagation();
          editBtn.click();
          return;
        }
      }
      // 1. Inside Category Manager Modal: Reorder / Options on focused category item
      var catMgrModal = document.getElementById('modal-category-manager');
      if (catMgrModal && catMgrModal.classList.contains('active')) {
        e.preventDefault();
        e.stopPropagation();
        if (e.repeat) return;
        var nowY1 = Date.now();
        if (nowY1 - _lastYellowActionAt < 350) return;
        _lastYellowActionAt = nowY1;
        var catMgrTarget = _currentFocused ? _currentFocused.closest('.cat-mgr-item') : null;
        if (catMgrTarget && typeof window.onCategoryManagerItemLongPress === 'function') {
          window.onCategoryManagerItemLongPress(catMgrTarget);
        }
        return;
      }

      // 2. Focused on category item on dashboard: Open Category Manager for current tab
      if (_currentFocused && _currentFocused.closest('.category-item')) {
        if (typeof window.openCategoryManagerForCurrentTab === 'function') {
          e.preventDefault();
          e.stopPropagation();
          if (e.repeat) return;
          var nowY2 = Date.now();
          if (nowY2 - _lastYellowActionAt < 350) return;
          _lastYellowActionAt = nowY2;
          window.openCategoryManagerForCurrentTab();
          return;
        }
      }

      // 3. Smart IPTV Channel Menu: toggle favorite
      var chMenu = document.getElementById('live-channel-menu');
      if (chMenu && chMenu.style.display !== 'none') {
        var menuItem = (_currentFocused && _currentFocused.closest('.channel-menu-item')) ||
                       chMenu.querySelector('.channel-menu-item.focused') ||
                       chMenu.querySelector('.channel-menu-item.active-stream') ||
                       chMenu.querySelector('.channel-menu-item');
        if (menuItem && typeof window.toggleChannelMenuFavorite === 'function') {
          e.preventDefault();
          e.stopPropagation();
          window.toggleChannelMenuFavorite(menuItem);
          return;
        }
      }

      // 4. Focused on channel row in dashboard: toggle favorite
      if (_currentFocused && !document.body.classList.contains('player-fullscreen')) {
        var channelWrap = _currentFocused.closest('.channel-row-wrap');
        if (channelWrap) {
          e.preventDefault();
          e.stopPropagation();
          var idx = parseInt(channelWrap.getAttribute('data-index'), 10);
          var stream = (window._goatVirtualList && window._goatVirtualList.items) ? window._goatVirtualList.items[idx] : null;
          if (stream && typeof window.toggleChannelFavorite === 'function') {
            window.toggleChannelFavorite(stream, channelWrap);
          }
          return;
        }
      }
    }

    // Green Key (code 404 on Smart TV) or 'G' Key: Open EPG
    if (!isEpgOverlayOpen && isGreenKey(e, code)) {
      var chMenu = document.getElementById('live-channel-menu');
      if (chMenu && chMenu.style.display !== 'none') {
        var menuItem = (_currentFocused && _currentFocused.closest('.channel-menu-item')) ||
                       chMenu.querySelector('.channel-menu-item.focused') ||
                       chMenu.querySelector('.channel-menu-item.active-stream') ||
                       chMenu.querySelector('.channel-menu-item');
        if (menuItem && typeof window.openChannelMenuEpg === 'function') {
          e.preventDefault();
          e.stopPropagation();
          window.openChannelMenuEpg(menuItem);
          return;
        }
      }
      if (_currentFocused) {
        var channelWrap = _currentFocused.closest('.channel-row-wrap');
        if (channelWrap) {
          e.preventDefault();
          e.stopPropagation();
          var idx = parseInt(channelWrap.getAttribute('data-index'), 10);
          var stream = (window._goatVirtualList && window._goatVirtualList.items) ? window._goatVirtualList.items[idx] : null;
          if (stream && typeof window.openLiveEpgOverlay === 'function') {
            window.openLiveEpgOverlay(stream);
          }
          return;
        }
      }
    }

    // Blue Key (code 406 on Smart TV) or 'B' Key: Open Category Menu / Toggle
    if (!isEpgOverlayOpen && isBlueKey(e, code)) {
      var cmEl = document.getElementById('live-channel-menu');
      var catEl = document.getElementById('live-category-menu');
      if (catEl && catEl.style.display !== 'none') {
        // Already in category menu -> Blue toggles back to channel menu
        e.preventDefault();
        e.stopPropagation();
        if (typeof window.closeLiveCategoryMenu === 'function') window.closeLiveCategoryMenu();
        if (typeof window.openLiveChannelMenu === 'function') window.openLiveChannelMenu();
        return;
      }
      var isFullscreenLive = (window._goatPlayer && window._goatPlayer.currentMode === 'fullscreen' && window._goatPlayer.playbackType === 'live') ||
                             (window._player && window._player.currentMode === 'fullscreen' && window._player.playbackType === 'live');
      if ((cmEl && cmEl.style.display !== 'none') || isFullscreenLive) {
        if (typeof window.openLiveCategoryMenu === 'function') {
          e.preventDefault();
          e.stopPropagation();
          window.openLiveCategoryMenu();
          return;
        }
      }
    }

    // Navigation overrides for smooth columns and panels
    if (_currentFocused) {
      // Category Manager Move Mode: UP / DOWN moves category in list, lock LEFT / RIGHT
      if (window._moveModeActive && document.getElementById('modal-category-manager') && document.getElementById('modal-category-manager').classList.contains('active')) {
        if (code === KEY_CODES.UP || code === KEY_CODES.DOWN) {
          e.preventDefault();
          e.stopPropagation();
          if (typeof window.moveCategoryInManager === 'function') {
            window.moveCategoryInManager(code === KEY_CODES.UP ? -1 : 1);
          }
          return;
        }
        if (code === KEY_CODES.LEFT || code === KEY_CODES.RIGHT) {
          e.preventDefault();
          e.stopPropagation();
          return;
        }
      }

      // Category Manager Toolbar & List Navigation
      if (_currentFocused.classList.contains('cat-mgr-btn')) {
        if (code === KEY_CODES.DOWN) {
          e.preventDefault();
          e.stopPropagation();
          var mgrList = document.getElementById('cat-mgr-list');
          if (mgrList) mgrList.scrollTop = 0;
          var firstMgrItem = document.querySelector('#cat-mgr-list .cat-mgr-item');
          if (firstMgrItem) setFocus(firstMgrItem);
          return;
        } else if (code === KEY_CODES.UP) {
          e.preventDefault();
          e.stopPropagation();
          var closeMgrBtn = document.getElementById('cat-mgr-close-btn');
          if (closeMgrBtn) setFocus(closeMgrBtn);
          return;
        }
      }

      if (_currentFocused.classList.contains('cat-mgr-item')) {
        if (code === KEY_CODES.LEFT || code === KEY_CODES.RIGHT) {
          e.preventDefault();
          e.stopPropagation();
          return;
        } else if (code === KEY_CODES.UP) {
          var prevMgr = _currentFocused.previousElementSibling;
          if (!prevMgr || !prevMgr.classList.contains('cat-mgr-item')) {
            e.preventDefault();
            e.stopPropagation();
            var toggleHiddenToolbarBtn = document.getElementById('cat-mgr-toggle-hidden');
            if (toggleHiddenToolbarBtn) setFocus(toggleHiddenToolbarBtn);
            return;
          }
        } else if (code === KEY_CODES.DOWN) {
          var nextMgr = _currentFocused.nextElementSibling;
          if (!nextMgr || !nextMgr.classList.contains('cat-mgr-item')) {
            if (window.TVApp && typeof window.TVApp.loadMoreCategoryManagerItems === 'function') {
              window.TVApp.loadMoreCategoryManagerItems();
            }
            nextMgr = _currentFocused.nextElementSibling;
            e.preventDefault();
            e.stopPropagation();
            if (nextMgr && nextMgr.classList.contains('cat-mgr-item')) {
              setFocus(nextMgr);
            }
            return;
          }
        }
      }

      // Live Channel List Move Mode: UP / DOWN moves live channel in list
      if (window._channelMoveModeActive && (_currentFocused.closest('.channel-row') || _currentFocused.closest('.channel-row-wrap') || _currentFocused.closest('#live-channels-list'))) {
        if (code === KEY_CODES.UP || code === KEY_CODES.DOWN) {
          e.preventDefault();
          e.stopPropagation();
          if (typeof window.moveLiveChannelInList === 'function') {
            window.moveLiveChannelInList(code === KEY_CODES.UP ? -1 : 1);
          }
          return;
        }
      }
      // Smart IPTV Channel Menu Item: UP/DOWN inside page or flip page, LEFT/RIGHT flip page
      if (_currentFocused.classList.contains('channel-menu-item')) {
        if (code === KEY_CODES.UP) {
          e.preventDefault();
          e.stopPropagation();
          var prevCh = _currentFocused.previousElementSibling;
          if (prevCh && prevCh.classList.contains('channel-menu-item')) {
            setFocus(prevCh);
          } else if (typeof window.prevChannelMenuPage === 'function') {
            window.prevChannelMenuPage(true);
          }
          return;
        } else if (code === KEY_CODES.DOWN) {
          e.preventDefault();
          e.stopPropagation();
          var nextCh = _currentFocused.nextElementSibling;
          if (nextCh && nextCh.classList.contains('channel-menu-item')) {
            setFocus(nextCh);
          } else if (typeof window.nextChannelMenuPage === 'function') {
            window.nextChannelMenuPage(false);
          }
          return;
        } else if (code === KEY_CODES.LEFT || code === 428 || code === 34 || (e.key && e.key === 'ChannelDown')) {
          e.preventDefault();
          e.stopPropagation();
          if (typeof window.prevChannelMenuPage === 'function') {
            window.prevChannelMenuPage(false);
          }
          return;
        } else if (code === KEY_CODES.RIGHT || code === 427 || code === 33 || (e.key && e.key === 'ChannelUp')) {
          e.preventDefault();
          e.stopPropagation();
          if (typeof window.nextChannelMenuPage === 'function') {
            window.nextChannelMenuPage(false);
          }
          return;
        }
      }

      // Smart IPTV Category Menu Item: UP/DOWN inside page or flip page, LEFT/RIGHT flip page
      if (_currentFocused.classList.contains('category-menu-item')) {
        if (code === KEY_CODES.UP) {
          e.preventDefault();
          e.stopPropagation();
          var prevCat = _currentFocused.previousElementSibling;
          if (prevCat && prevCat.classList.contains('category-menu-item')) {
            setFocus(prevCat);
          } else if (typeof window.prevCategoryMenuPage === 'function') {
            window.prevCategoryMenuPage(true);
          }
          return;
        } else if (code === KEY_CODES.DOWN) {
          e.preventDefault();
          e.stopPropagation();
          var nextCat = _currentFocused.nextElementSibling;
          if (nextCat && nextCat.classList.contains('category-menu-item')) {
            setFocus(nextCat);
          } else if (typeof window.nextCategoryMenuPage === 'function') {
            window.nextCategoryMenuPage(false);
          }
          return;
        } else if (code === KEY_CODES.LEFT || code === 428 || code === 34 || (e.key && e.key === 'ChannelDown')) {
          e.preventDefault();
          e.stopPropagation();
          if (typeof window.prevCategoryMenuPage === 'function') {
            window.prevCategoryMenuPage(false);
          }
          return;
        } else if (code === KEY_CODES.RIGHT || code === 427 || code === 33 || (e.key && e.key === 'ChannelUp')) {
          e.preventDefault();
          e.stopPropagation();
          if (typeof window.nextCategoryMenuPage === 'function') {
            window.nextCategoryMenuPage(false);
          }
          return;
        }
      }

      // App Update Notification Modal: strict horizontal and vertical trapping (Modes A & B)
      var updateModalEl = document.getElementById('modal-update');
      if (updateModalEl && updateModalEl.classList.contains('active')) {
        var cfBtn = document.getElementById('update-now-btn') || document.getElementById('update-confirm-btn');
        var ltBtn = document.getElementById('update-later-btn');
        var clBtn = document.getElementById('update-close-btn');
        var clBox = document.getElementById('update-changelog-box');
        var hasConfirm = cfBtn && cfBtn.offsetParent !== null && cfBtn.style.display !== 'none';
        var hasChangelogFocusable = clBox && clBox.offsetParent !== null && clBox.classList.contains('focusable');

        if (!_currentFocused || !_currentFocused.closest || !_currentFocused.closest('#modal-update')) {
          var initialTarget = hasConfirm ? cfBtn : (ltBtn || clBtn);
          if (initialTarget) {
            e.preventDefault();
            e.stopPropagation();
            setFocus(initialTarget);
            return;
          }
        } else {
          if (_currentFocused === cfBtn) {
            if (code === KEY_CODES.RIGHT && ltBtn && ltBtn.offsetParent !== null) {
              e.preventDefault(); e.stopPropagation(); setFocus(ltBtn); return;
            } else if (code === KEY_CODES.UP) {
              var targetUp = hasChangelogFocusable ? clBox : clBtn;
              if (targetUp) { e.preventDefault(); e.stopPropagation(); setFocus(targetUp); return; }
            }
          } else if (_currentFocused === ltBtn) {
            if (code === KEY_CODES.LEFT && hasConfirm) {
              e.preventDefault(); e.stopPropagation(); setFocus(cfBtn); return;
            } else if (code === KEY_CODES.UP) {
              var targetUp2 = hasChangelogFocusable ? clBox : clBtn;
              if (targetUp2) { e.preventDefault(); e.stopPropagation(); setFocus(targetUp2); return; }
            }
          } else if (_currentFocused === clBox) {
            if (code === KEY_CODES.DOWN) {
              e.preventDefault(); e.stopPropagation();
              if (clBox.scrollHeight > clBox.clientHeight + 4 && (clBox.scrollTop + clBox.clientHeight) < (clBox.scrollHeight - 8)) {
                clBox.scrollTop += 120;
                return;
              }
              var targetDown = hasConfirm ? cfBtn : ltBtn;
              if (targetDown) { setFocus(targetDown); return; }
            } else if (code === KEY_CODES.UP) {
              e.preventDefault(); e.stopPropagation();
              if (clBox.scrollTop > 8) {
                clBox.scrollTop = Math.max(0, clBox.scrollTop - 120);
                return;
              }
              if (clBtn) { setFocus(clBtn); return; }
            }
          } else if (_currentFocused === clBtn) {
            if (code === KEY_CODES.DOWN) {
              var downTarget = hasChangelogFocusable ? clBox : (hasConfirm ? cfBtn : ltBtn);
              if (downTarget) { e.preventDefault(); e.stopPropagation(); setFocus(downTarget); return; }
            }
          }
          if (code === KEY_CODES.LEFT || code === KEY_CODES.RIGHT || code === KEY_CODES.UP || code === KEY_CODES.DOWN) {
            e.preventDefault();
            e.stopPropagation();
            return;
          }
        }
      }

      // Resume Playback Modal: strict horizontal and vertical trapping
      if (_currentFocused && _currentFocused.closest && _currentFocused.closest('#modal-resume-playback')) {
        if (_currentFocused.id === 'resume-confirm-btn') {
          if (code === KEY_CODES.RIGHT) {
            var stBtn = document.getElementById('resume-startover-btn');
            if (stBtn) { e.preventDefault(); e.stopPropagation(); setFocus(stBtn); return; }
          } else if (code === KEY_CODES.UP) {
            var clBtn = document.getElementById('resume-close-btn');
            if (clBtn) { e.preventDefault(); e.stopPropagation(); setFocus(clBtn); return; }
          }
        } else if (_currentFocused.id === 'resume-startover-btn') {
          if (code === KEY_CODES.LEFT) {
            var cfBtn = document.getElementById('resume-confirm-btn');
            if (cfBtn) { e.preventDefault(); e.stopPropagation(); setFocus(cfBtn); return; }
          } else if (code === KEY_CODES.UP) {
            var clBtn2 = document.getElementById('resume-close-btn');
            if (clBtn2) { e.preventDefault(); e.stopPropagation(); setFocus(clBtn2); return; }
          }
        } else if (_currentFocused.id === 'resume-close-btn') {
          if (code === KEY_CODES.DOWN) {
            var cfBtn2 = document.getElementById('resume-confirm-btn');
            if (cfBtn2) { e.preventDefault(); e.stopPropagation(); setFocus(cfBtn2); return; }
          }
        }
        if (code === KEY_CODES.LEFT || code === KEY_CODES.RIGHT || code === KEY_CODES.UP || code === KEY_CODES.DOWN) {
          e.preventDefault();
          e.stopPropagation();
          return;
        }
      }

      // Playback Preferences Modal: Natural 2D 3-column grid & exit navigation
      if (_currentFocused && _currentFocused.closest && _currentFocused.closest('#modal-preferences')) {
        if (_currentFocused.id === 'pref-close-btn') {
          if (code === KEY_CODES.DOWN) {
            e.preventDefault(); e.stopPropagation();
            var audioTarget = document.querySelector('#pref-audio-group .pref-option-btn:nth-child(3)') ||
                              document.querySelector('#pref-audio-group .pref-option-btn');
            if (audioTarget) setFocus(audioTarget);
            return;
          }
          if (code === KEY_CODES.LEFT) {
            e.preventDefault(); e.stopPropagation();
            var audioTarget2 = document.querySelector('#pref-audio-group .pref-option-btn:nth-child(2)') ||
                               document.querySelector('#pref-audio-group .pref-option-btn');
            if (audioTarget2) setFocus(audioTarget2);
            return;
          }
          if (code === KEY_CODES.UP || code === KEY_CODES.RIGHT) {
            e.preventDefault(); e.stopPropagation();
            return;
          }
        } else if (_currentFocused.id === 'pref-save-btn') {
          if (code === KEY_CODES.UP) {
            e.preventDefault(); e.stopPropagation();
            var subBtns = Array.from(document.querySelectorAll('#pref-sub-group .pref-option-btn'));
            var targetSub = subBtns[6] || subBtns[subBtns.length - 1];
            if (targetSub) setFocus(targetSub);
            return;
          }
          if (code === KEY_CODES.DOWN || code === KEY_CODES.LEFT || code === KEY_CODES.RIGHT) {
            e.preventDefault(); e.stopPropagation();
            return;
          }
        } else if (_currentFocused.classList.contains('pref-option-btn')) {
          var group = _currentFocused.parentElement;
          var isAudio = group && group.id === 'pref-audio-group';
          var isSub = group && group.id === 'pref-sub-group';
          var buttons = group ? Array.from(group.children) : [];
          var idx = buttons.indexOf(_currentFocused);
          var col = (idx !== -1) ? (idx % 3) : 0;
          var row = (idx !== -1) ? Math.floor(idx / 3) : 0;

          if (code === KEY_CODES.LEFT) {
            e.preventDefault(); e.stopPropagation();
            if (col > 0 && idx - 1 >= 0) {
              setFocus(buttons[idx - 1]);
            }
            return;
          }
          if (code === KEY_CODES.RIGHT) {
            e.preventDefault(); e.stopPropagation();
            if (col < 2 && idx + 1 < buttons.length) {
              setFocus(buttons[idx + 1]);
            }
            return;
          }
          if (code === KEY_CODES.DOWN) {
            e.preventDefault(); e.stopPropagation();
            var nextRowIdx = idx + 3;
            if (nextRowIdx < buttons.length) {
              setFocus(buttons[nextRowIdx]);
              return;
            }
            if (isAudio) {
              var subBtns = Array.from(document.querySelectorAll('#pref-sub-group .pref-option-btn'));
              var targetSub = subBtns[col] || subBtns[subBtns.length - 1];
              if (targetSub) setFocus(targetSub);
              return;
            }
            if (isSub) {
              var saveBtn = document.getElementById('pref-save-btn');
              if (saveBtn) setFocus(saveBtn);
              return;
            }
          }
          if (code === KEY_CODES.UP) {
            e.preventDefault(); e.stopPropagation();
            var prevRowIdx = idx - 3;
            if (prevRowIdx >= 0) {
              setFocus(buttons[prevRowIdx]);
              return;
            }
            if (isAudio) {
              var closeBtn = document.getElementById('pref-close-btn');
              if (closeBtn) setFocus(closeBtn);
              return;
            }
            if (isSub) {
              var audioBtns = Array.from(document.querySelectorAll('#pref-audio-group .pref-option-btn'));
              var audioTarget = audioBtns[3 + col] || audioBtns[audioBtns.length - 1];
              if (audioTarget) setFocus(audioTarget);
              return;
            }
          }
        }
      }

      // VOD HUD NAVIGATION & TIMELINE SCRUBBING
      if (_currentFocused && _currentFocused.closest('#player-hud-vod')) {
        // 1. Scrubber bar focused: LEFT/RIGHT seeks, DOWN moves to Play button
        if (_currentFocused.id === 'vod-progress-bar') {
          if (code === KEY_CODES.LEFT) {
            e.preventDefault();
            e.stopPropagation();
            if (window._goatPlayer) window._goatPlayer.seekBy(-10, e.repeat);
            return;
          }
          if (code === KEY_CODES.RIGHT) {
            e.preventDefault();
            e.stopPropagation();
            if (window._goatPlayer) window._goatPlayer.seekBy(10, e.repeat);
            return;
          }
          if (code === KEY_CODES.DOWN) {
            e.preventDefault();
            e.stopPropagation();
            var playBtn = document.getElementById('vod-play-btn');
            if (playBtn) setFocus(playBtn);
            return;
          }
          if (code === KEY_CODES.UP) {
            e.preventDefault();
            e.stopPropagation();
            return;
          }
          if (code === KEY_CODES.ENTER) {
            e.preventDefault();
            e.stopPropagation();
            var pl = window._goatPlayer || window._player;
            if (pl) {
              if (typeof pl._commitPendingSeek === 'function') pl._commitPendingSeek();
              if (pl.videoEl && pl.videoEl.paused) pl.play();
            }
            return;
          }
        }

        // 2. Controls row buttons: UP moves to scrubber, LEFT/RIGHT moves between all visible buttons in row
        if (_currentFocused.closest('.vod-controls-row')) {
          if (code === KEY_CODES.UP) {
            e.preventDefault();
            e.stopPropagation();
            var scrubber = document.getElementById('vod-progress-bar');
            if (scrubber) setFocus(scrubber);
            return;
          }
          var rowEl = _currentFocused.closest('.vod-controls-row');
          var allBtns = Array.prototype.slice.call(rowEl.querySelectorAll('.focusable')).filter(function(b) {
            return b.offsetWidth > 0 && b.offsetHeight > 0 && window.getComputedStyle(b).display !== 'none';
          });
          var curIdx = allBtns.indexOf(_currentFocused);
          if (code === KEY_CODES.LEFT) {
            e.preventDefault();
            e.stopPropagation();
            if (curIdx > 0) {
              setFocus(allBtns[curIdx - 1]);
            }
            return;
          }
          if (code === KEY_CODES.RIGHT) {
            e.preventDefault();
            e.stopPropagation();
            if (curIdx >= 0 && curIdx < allBtns.length - 1) {
              setFocus(allBtns[curIdx + 1]);
            }
            return;
          }
        }
      }

      // 00. From Top Add Account Button or Version Badge -> DOWN moves to account cards
      if (_currentFocused.id === 'accounts-add-btn' || _currentFocused.id === 'accounts-version-badge') {
        var allCards = Array.from(document.querySelectorAll('.accounts-grid .account-card'));
        if (code === KEY_CODES.DOWN) {
          if (_currentFocused.id === 'accounts-add-btn') {
            var targetCard = (allCards.length > 1) ? allCards[1] : allCards[0];
            if (targetCard) { e.preventDefault(); setFocus(targetCard); return; }
          } else {
            if (allCards.length > 0) { e.preventDefault(); setFocus(allCards[0]); return; }
          }
        } else if (code === KEY_CODES.LEFT && _currentFocused.id === 'accounts-add-btn') {
          var vBadge = document.getElementById('accounts-version-badge');
          if (vBadge && vBadge.offsetParent !== null) {
            e.preventDefault();
            setFocus(vBadge);
            return;
          }
        } else if (code === KEY_CODES.RIGHT && _currentFocused.id === 'accounts-version-badge') {
          var addBtn = document.getElementById('accounts-add-btn');
          if (addBtn && addBtn.offsetParent !== null) {
            e.preventDefault();
            setFocus(addBtn);
            return;
          }
        }
      }

      // 01. From Account Card -> deterministic traversal (Card -> Edit -> Delete -> Next Card)
      if (_currentFocused.classList.contains('account-card')) {
        var allCards = Array.from(document.querySelectorAll('.accounts-grid .account-card'));
        var idx = allCards.indexOf(_currentFocused);
        if (idx >= 0) {
          if (code === KEY_CODES.RIGHT) {
            e.preventDefault();
            var editBtn = _currentFocused.querySelector('.account-icon-btn.edit');
            if (editBtn) {
              setFocus(editBtn);
            } else if (idx + 1 < allCards.length) {
              setFocus(allCards[idx + 1]);
            }
            return;
          } else if (code === KEY_CODES.LEFT) {
            e.preventDefault();
            if (idx > 0) {
              var prevCard = allCards[idx - 1];
              var prevDel = prevCard.querySelector('.account-icon-btn.delete') || prevCard;
              setFocus(prevDel);
            }
            return;
          } else if (code === KEY_CODES.DOWN) {
            e.preventDefault();
            if (idx + 2 < allCards.length) {
              setFocus(allCards[idx + 2]);
            } else if (idx % 2 === 0 && idx + 1 < allCards.length) {
              setFocus(allCards[idx + 1]);
            }
            return;
          } else if (code === KEY_CODES.UP) {
            e.preventDefault();
            if (idx - 2 >= 0) {
              setFocus(allCards[idx - 2]);
            } else if (idx === 1) {
              var addBtn = document.getElementById('accounts-add-btn');
              if (addBtn && addBtn.offsetParent !== null) setFocus(addBtn);
            } else if (idx === 0) {
              var vBadge = document.getElementById('accounts-version-badge') || document.getElementById('accounts-add-btn');
              if (vBadge && vBadge.offsetParent !== null) setFocus(vBadge);
            }
            return;
          }
        }
      }

      // 02. From Account Edit Button -> LEFT back to card, RIGHT to delete button
      if (_currentFocused.classList.contains('account-icon-btn') && _currentFocused.classList.contains('edit')) {
        var parentCard = _currentFocused.closest('.account-card');
        var allCards = Array.from(document.querySelectorAll('.accounts-grid .account-card'));
        var idx = parentCard ? allCards.indexOf(parentCard) : -1;

        if (code === KEY_CODES.LEFT) {
          if (parentCard) { e.preventDefault(); setFocus(parentCard); return; }
        } else if (code === KEY_CODES.RIGHT) {
          var delBtn = _currentFocused.parentElement ? _currentFocused.parentElement.querySelector('.account-icon-btn.delete') : null;
          if (delBtn) { e.preventDefault(); setFocus(delBtn); return; }
          else if (idx >= 0 && idx + 1 < allCards.length) { e.preventDefault(); setFocus(allCards[idx + 1]); return; }
        } else if (code === KEY_CODES.UP) {
          e.preventDefault();
          if (idx - 2 >= 0) setFocus(allCards[idx - 2]);
          else {
            var addBtn = document.getElementById('accounts-add-btn');
            if (addBtn) setFocus(addBtn);
          }
          return;
        } else if (code === KEY_CODES.DOWN) {
          e.preventDefault();
          if (idx >= 0 && idx + 2 < allCards.length) setFocus(allCards[idx + 2]);
          return;
        }
      }

      // 03. From Account Delete Button -> LEFT to edit button, RIGHT to next column card
      if (_currentFocused.classList.contains('account-icon-btn') && _currentFocused.classList.contains('delete')) {
        var parentCard = _currentFocused.closest('.account-card');
        var allCards = Array.from(document.querySelectorAll('.accounts-grid .account-card'));
        var idx = parentCard ? allCards.indexOf(parentCard) : -1;

        if (code === KEY_CODES.LEFT) {
          var editBtn = _currentFocused.parentElement ? _currentFocused.parentElement.querySelector('.account-icon-btn.edit') : null;
          if (editBtn) { e.preventDefault(); setFocus(editBtn); return; }
          else if (parentCard) { e.preventDefault(); setFocus(parentCard); return; }
        } else if (code === KEY_CODES.RIGHT) {
          e.preventDefault();
          if (idx >= 0 && idx + 1 < allCards.length) {
            setFocus(allCards[idx + 1]);
          }
          return;
        } else if (code === KEY_CODES.UP) {
          e.preventDefault();
          if (idx - 2 >= 0) setFocus(allCards[idx - 2]);
          else {
            var addBtn = document.getElementById('accounts-add-btn');
            if (addBtn) setFocus(addBtn);
          }
          return;
        } else if (code === KEY_CODES.DOWN) {
          e.preventDefault();
          if (idx >= 0 && idx + 2 < allCards.length) setFocus(allCards[idx + 2]);
          return;
        }
      }

      // 03b. Stream Context Menu Navigation (modal-stream-context)
      if (_currentFocused && _currentFocused.closest('#modal-stream-context')) {
        if (code === KEY_CODES.LEFT || code === KEY_CODES.RIGHT) {
          e.preventDefault();
          return;
        }
        if (_currentFocused.id === 'ctx-fav-btn') {
          if (code === KEY_CODES.DOWN) {
            var firstList = document.querySelector('#ctx-custom-lists-container .ctx-list-row');
            var target = firstList || document.getElementById('ctx-create-list-btn');
            if (target) { e.preventDefault(); setFocus(target); return; }
          } else if (code === KEY_CODES.UP) {
            var moveBtn = document.getElementById('ctx-move-btn');
            if (moveBtn && moveBtn.style.display !== 'none' && moveBtn.offsetParent !== null) {
              e.preventDefault(); setFocus(moveBtn); return;
            }
            var closeBtn = document.getElementById('ctx-close-btn');
            if (closeBtn) { e.preventDefault(); setFocus(closeBtn); return; }
          }
        } else if (_currentFocused.id === 'ctx-move-btn') {
          if (code === KEY_CODES.DOWN) {
            var favBtn = document.getElementById('ctx-fav-btn');
            if (favBtn) { e.preventDefault(); setFocus(favBtn); return; }
          } else if (code === KEY_CODES.UP) {
            var closeBtn = document.getElementById('ctx-close-btn');
            if (closeBtn) { e.preventDefault(); setFocus(closeBtn); return; }
          }
        } else if (_currentFocused.classList.contains('ctx-list-row')) {
          if (code === KEY_CODES.DOWN) {
            var nextRow = _currentFocused.nextElementSibling;
            if (nextRow && nextRow.classList.contains('ctx-list-row')) {
              e.preventDefault(); setFocus(nextRow); return;
            }
            var createBtn = document.getElementById('ctx-create-list-btn');
            if (createBtn) { e.preventDefault(); setFocus(createBtn); return; }
          } else if (code === KEY_CODES.UP) {
            var prevRow = _currentFocused.previousElementSibling;
            if (prevRow && prevRow.classList.contains('ctx-list-row')) {
              e.preventDefault(); setFocus(prevRow); return;
            }
            var favBtn = document.getElementById('ctx-fav-btn');
            if (favBtn) { e.preventDefault(); setFocus(favBtn); return; }
          }
        } else if (_currentFocused.id === 'ctx-create-list-btn') {
          if (code === KEY_CODES.UP) {
            var listRows = document.querySelectorAll('#ctx-custom-lists-container .ctx-list-row');
            var target = listRows.length > 0 ? listRows[listRows.length - 1] : document.getElementById('ctx-fav-btn');
            if (target) { e.preventDefault(); setFocus(target); return; }
          } else if (code === KEY_CODES.DOWN) {
            e.preventDefault();
            return;
          }
        } else if (_currentFocused.id === 'ctx-close-btn') {
          if (code === KEY_CODES.DOWN) {
            var moveBtn = document.getElementById('ctx-move-btn');
            var target = (moveBtn && moveBtn.style.display !== 'none' && moveBtn.offsetParent !== null) ? moveBtn : document.getElementById('ctx-fav-btn');
            if (target) { e.preventDefault(); setFocus(target); return; }
          } else if (code === KEY_CODES.UP) {
            e.preventDefault();
            return;
          }
        }
      }

      // 0. Header buttons navigation
      if (_currentFocused.classList.contains('header-icon-btn')) {
        if (code === KEY_CODES.DOWN) {
          e.preventDefault();
          var activePage = document.querySelector('.dashboard-page.active');
          if (activePage) {
            if (activePage.id === 'page-movies') {
              if (_currentFocused.id === 'header-switch-btn' || _currentFocused.id === 'header-lang-btn') {
                var movSearch = document.getElementById('movies-search-input');
                if (movSearch) { setFocus(movSearch); return; }
              }
              var catSearch = document.getElementById('movies-cat-search');
              if (catSearch) { setFocus(catSearch); return; }
            } else if (activePage.id === 'page-series') {
              if (_currentFocused.id === 'header-switch-btn' || _currentFocused.id === 'header-lang-btn') {
                var serSearch = document.getElementById('series-search-input');
                if (serSearch) { setFocus(serSearch); return; }
              }
              var catSearch = document.getElementById('series-cat-search');
              if (catSearch) { setFocus(catSearch); return; }
            } else {
              // Live TV: all header buttons go down to category search
              var catSearch = document.getElementById('live-cat-search');
              if (catSearch) { setFocus(catSearch); return; }
            }
          }
        } else if (_currentFocused.id === 'header-search-btn' && code === KEY_CODES.LEFT) {
          // Left from Master Search button goes directly to active tab category search field
          e.preventDefault();
          var activePage = document.querySelector('.dashboard-page.active');
          if (activePage) {
            if (activePage.id === 'page-movies') {
              var mcs = document.getElementById('movies-cat-search');
              if (mcs) { setFocus(mcs); return; }
            } else if (activePage.id === 'page-series') {
              var scs = document.getElementById('series-cat-search');
              if (scs) { setFocus(scs); return; }
            } else {
              var lcs = document.getElementById('live-cat-search');
              if (lcs) { setFocus(lcs); return; }
            }
          }
          var lcsDefault = document.getElementById('live-cat-search');
          if (lcsDefault) { setFocus(lcsDefault); return; }
        }
      }

      // 0a. Search input fields navigation
      if (_currentFocused.id === 'live-cat-search') {
        if (code === KEY_CODES.DOWN) {
          e.preventDefault();
          var firstCat = document.querySelector('#live-categories-list .category-item');
          if (firstCat) { setFocus(firstCat); return; }
        } else if (code === KEY_CODES.UP) {
          e.preventDefault();
          var searchBtn = document.getElementById('header-search-btn') || document.getElementById('header-pref-btn');
          if (searchBtn) { setFocus(searchBtn); return; }
        } else if (code === KEY_CODES.RIGHT) {
          e.preventDefault();
          var catMgrBtn = document.getElementById('live-cat-manage-btn');
          if (catMgrBtn && catMgrBtn.offsetParent !== null) {
            setFocus(catMgrBtn);
            return;
          }
          if (window._goatVirtualList && window._goatVirtualList.getItemCount() > 0) {
            window._goatVirtualList.focusActive();
            return;
          }
          return;
        } else if (code === KEY_CODES.LEFT) {
          e.preventDefault();
          var railBtn = document.getElementById('nav-btn-live');
          if (railBtn) { setFocus(railBtn); return; }
        }
      }

      if (_currentFocused.id === 'live-cat-manage-btn') {
        if (code === KEY_CODES.LEFT) {
          e.preventDefault();
          var liveSearch = document.getElementById('live-cat-search');
          if (liveSearch) { setFocus(liveSearch); return; }
        } else if (code === KEY_CODES.DOWN) {
          e.preventDefault();
          var firstCat = document.querySelector('#live-categories-list .category-item');
          if (firstCat) { setFocus(firstCat); return; }
        } else if (code === KEY_CODES.UP) {
          e.preventDefault();
          var searchBtn = document.getElementById('header-search-btn') || document.getElementById('header-pref-btn');
          if (searchBtn) { setFocus(searchBtn); return; }
        } else if (code === KEY_CODES.RIGHT) {
          e.preventDefault();
          if (window._goatVirtualList && window._goatVirtualList.getItemCount() > 0) {
            window._goatVirtualList.focusActive();
            return;
          }
        }
      }

      if (_currentFocused.id === 'movies-cat-search') {
        if (code === KEY_CODES.DOWN) {
          e.preventDefault();
          var firstCat = document.querySelector('#movies-categories-list .category-item');
          if (firstCat) { setFocus(firstCat); return; }
        } else if (code === KEY_CODES.UP) {
          e.preventDefault();
          var searchBtn = document.getElementById('header-search-btn') || document.getElementById('header-pref-btn');
          if (searchBtn) { setFocus(searchBtn); return; }
        } else if (code === KEY_CODES.RIGHT) {
          e.preventDefault();
          var catMgrBtnM = document.getElementById('movies-cat-manage-btn');
          if (catMgrBtnM && catMgrBtnM.offsetParent !== null) {
            setFocus(catMgrBtnM);
            return;
          }
          var movInput = document.getElementById('movies-search-input');
          if (movInput) { setFocus(movInput); return; }
        } else if (code === KEY_CODES.LEFT) {
          e.preventDefault();
          var railBtn = document.getElementById('nav-btn-movies');
          if (railBtn) { setFocus(railBtn); return; }
        }
      }

      if (_currentFocused.id === 'movies-cat-manage-btn') {
        if (code === KEY_CODES.LEFT) {
          e.preventDefault();
          var movCatSearch = document.getElementById('movies-cat-search');
          if (movCatSearch) { setFocus(movCatSearch); return; }
        } else if (code === KEY_CODES.DOWN) {
          e.preventDefault();
          var firstCatM = document.querySelector('#movies-categories-list .category-item');
          if (firstCatM) { setFocus(firstCatM); return; }
        } else if (code === KEY_CODES.UP) {
          e.preventDefault();
          var searchBtnM = document.getElementById('header-search-btn') || document.getElementById('header-pref-btn');
          if (searchBtnM) { setFocus(searchBtnM); return; }
        } else if (code === KEY_CODES.RIGHT) {
          e.preventDefault();
          var movInputM = document.getElementById('movies-search-input');
          if (movInputM) { setFocus(movInputM); return; }
        }
      }

      if (_currentFocused.id === 'movies-search-input') {
        if (code === KEY_CODES.DOWN) {
          e.preventDefault();
          var mCw = document.getElementById('movies-continue-watching');
          if (mCw && mCw.style.display !== 'none') {
            var firstCw = mCw.querySelector('.cw-card');
            if (firstCw) { setFocus(firstCw); return; }
          }
          var firstPoster = document.querySelector('#movies-grid-container .poster-card');
          if (firstPoster) { setFocus(firstPoster); return; }
        } else if (code === KEY_CODES.UP) {
          e.preventDefault();
          var targetBtn = document.getElementById('header-lang-btn') || document.getElementById('header-switch-btn');
          if (targetBtn) { setFocus(targetBtn); return; }
        } else if (code === KEY_CODES.LEFT) {
          e.preventDefault();
          var catMgrBtnM2 = document.getElementById('movies-cat-manage-btn');
          if (catMgrBtnM2 && catMgrBtnM2.offsetParent !== null) {
            setFocus(catMgrBtnM2);
            return;
          }
          var catSearch = document.getElementById('movies-cat-search');
          if (catSearch) { setFocus(catSearch); return; }
        } else if (code === KEY_CODES.RIGHT) {
          e.preventDefault();
          var sortBtn = document.getElementById('movies-sort-btn');
          if (sortBtn) { setFocus(sortBtn); return; }
        }
      }

      if (_currentFocused.id === 'movies-sort-btn') {
        if (code === KEY_CODES.LEFT) {
          e.preventDefault();
          var movInput = document.getElementById('movies-search-input');
          if (movInput) { setFocus(movInput); return; }
        } else if (code === KEY_CODES.DOWN) {
          e.preventDefault();
          var mCw = document.getElementById('movies-continue-watching');
          if (mCw && mCw.style.display !== 'none') {
            var firstCw = mCw.querySelector('.cw-card');
            if (firstCw) { setFocus(firstCw); return; }
          }
          var firstPoster = document.querySelector('#movies-grid-container .poster-card');
          if (firstPoster) { setFocus(firstPoster); return; }
        } else if (code === KEY_CODES.UP) {
          e.preventDefault();
          var targetBtn = document.getElementById('header-lang-btn') || document.getElementById('header-switch-btn');
          if (targetBtn) { setFocus(targetBtn); return; }
        }
      }

      if (_currentFocused.id === 'series-cat-search') {
        if (code === KEY_CODES.DOWN) {
          e.preventDefault();
          var firstCat = document.querySelector('#series-categories-list .category-item');
          if (firstCat) { setFocus(firstCat); return; }
        } else if (code === KEY_CODES.UP) {
          e.preventDefault();
          var searchBtn = document.getElementById('header-search-btn') || document.getElementById('header-pref-btn');
          if (searchBtn) { setFocus(searchBtn); return; }
        } else if (code === KEY_CODES.RIGHT) {
          e.preventDefault();
          var catMgrBtnS = document.getElementById('series-cat-manage-btn');
          if (catMgrBtnS && catMgrBtnS.offsetParent !== null) {
            setFocus(catMgrBtnS);
            return;
          }
          var serInput = document.getElementById('series-search-input');
          if (serInput) { setFocus(serInput); return; }
        } else if (code === KEY_CODES.LEFT) {
          e.preventDefault();
          var railBtn = document.getElementById('nav-btn-series');
          if (railBtn) { setFocus(railBtn); return; }
        }
      }

      if (_currentFocused.id === 'series-cat-manage-btn') {
        if (code === KEY_CODES.LEFT) {
          e.preventDefault();
          var serCatSearch = document.getElementById('series-cat-search');
          if (serCatSearch) { setFocus(serCatSearch); return; }
        } else if (code === KEY_CODES.DOWN) {
          e.preventDefault();
          var firstCatS = document.querySelector('#series-categories-list .category-item');
          if (firstCatS) { setFocus(firstCatS); return; }
        } else if (code === KEY_CODES.UP) {
          e.preventDefault();
          var searchBtnS = document.getElementById('header-search-btn') || document.getElementById('header-pref-btn');
          if (searchBtnS) { setFocus(searchBtnS); return; }
        } else if (code === KEY_CODES.RIGHT) {
          e.preventDefault();
          var serInputS = document.getElementById('series-search-input');
          if (serInputS) { setFocus(serInputS); return; }
        }
      }

      if (_currentFocused.id === 'series-search-input') {
        if (code === KEY_CODES.DOWN) {
          e.preventDefault();
          var sCw = document.getElementById('series-continue-watching');
          if (sCw && sCw.style.display !== 'none') {
            var firstCw = sCw.querySelector('.cw-card');
            if (firstCw) { setFocus(firstCw); return; }
          }
          var firstPoster = document.querySelector('#series-grid-container .poster-card');
          if (firstPoster) { setFocus(firstPoster); return; }
        } else if (code === KEY_CODES.UP) {
          e.preventDefault();
          var targetBtn = document.getElementById('header-lang-btn') || document.getElementById('header-switch-btn');
          if (targetBtn) { setFocus(targetBtn); return; }
        } else if (code === KEY_CODES.LEFT) {
          e.preventDefault();
          var catMgrBtnS2 = document.getElementById('series-cat-manage-btn');
          if (catMgrBtnS2 && catMgrBtnS2.offsetParent !== null) {
            setFocus(catMgrBtnS2);
            return;
          }
          var catSearch = document.getElementById('series-cat-search');
          if (catSearch) { setFocus(catSearch); return; }
        } else if (code === KEY_CODES.RIGHT) {
          e.preventDefault();
          var sortBtn = document.getElementById('series-sort-btn');
          if (sortBtn) { setFocus(sortBtn); return; }
        }
      }

      if (_currentFocused.id === 'series-sort-btn') {
        if (code === KEY_CODES.LEFT) {
          e.preventDefault();
          var serInput = document.getElementById('series-search-input');
          if (serInput) { setFocus(serInput); return; }
        } else if (code === KEY_CODES.DOWN) {
          e.preventDefault();
          var sCw = document.getElementById('series-continue-watching');
          if (sCw && sCw.style.display !== 'none') {
            var firstCw = sCw.querySelector('.cw-card');
            if (firstCw) { setFocus(firstCw); return; }
          }
          var firstPoster = document.querySelector('#series-grid-container .poster-card');
          if (firstPoster) { setFocus(firstPoster); return; }
        } else if (code === KEY_CODES.UP) {
          e.preventDefault();
          var targetBtn = document.getElementById('header-lang-btn') || document.getElementById('header-switch-btn');
          if (targetBtn) { setFocus(targetBtn); return; }
        }
      }

      if (_currentFocused.classList.contains('sort-opt-btn')) {
        if (code === KEY_CODES.DOWN) {
          e.preventDefault();
          var nextOpt = _currentFocused.nextElementSibling;
          if (nextOpt && nextOpt.classList.contains('sort-opt-btn')) {
            setFocus(nextOpt);
          }
          return;
        } else if (code === KEY_CODES.UP) {
          e.preventDefault();
          var prevOpt = _currentFocused.previousElementSibling;
          if (prevOpt && prevOpt.classList.contains('sort-opt-btn')) {
            setFocus(prevOpt);
          }
          return;
        } else if (code === KEY_CODES.LEFT || code === KEY_CODES.RIGHT) {
          e.preventDefault();
          var parentDropdown = _currentFocused.closest('.vod-sort-dropdown');
          if (parentDropdown) parentDropdown.style.display = 'none';
          var parentGroup = _currentFocused.closest('.vod-sort-group');
          var returnBtn = parentGroup ? parentGroup.querySelector('.btn-sort') : null;
          if (returnBtn) setFocus(returnBtn);
          return;
        }
      }

      if (_currentFocused.id === 'master-search-input') {
        if (code === KEY_CODES.DOWN) {
          e.preventDefault();
          var firstRes = document.querySelector('#master-search-results .search-result-row') ||
                         document.getElementById('search-tab-live');
          if (firstRes) { setFocus(firstRes); return; }
        } else if (code === KEY_CODES.UP) {
          e.preventDefault();
          var closeBtn = document.getElementById('master-search-close-btn');
          if (closeBtn) { setFocus(closeBtn); return; }
        } else if (code === KEY_CODES.RIGHT) {
          e.preventDefault();
          var clearBtn = document.getElementById('master-search-clear-btn');
          if (clearBtn && clearBtn.style.display !== 'none') {
            setFocus(clearBtn);
            return;
          }
          var closeBtnR = document.getElementById('master-search-close-btn');
          if (closeBtnR) { setFocus(closeBtnR); return; }
        }
      }

      if (_currentFocused.id === 'master-search-clear-btn') {
        if (code === KEY_CODES.LEFT) {
          e.preventDefault();
          var mInput = document.getElementById('master-search-input');
          if (mInput) { setFocus(mInput); return; }
        } else if (code === KEY_CODES.RIGHT) {
          e.preventDefault();
          var closeBtnC = document.getElementById('master-search-close-btn');
          if (closeBtnC) { setFocus(closeBtnC); return; }
        } else if (code === KEY_CODES.DOWN) {
          e.preventDefault();
          var firstResC = document.querySelector('#master-search-results .search-result-row') ||
                          document.getElementById('search-tab-live');
          if (firstResC) { setFocus(firstResC); return; }
        }
      }

      if (_currentFocused.id === 'master-search-close-btn') {
        if (code === KEY_CODES.LEFT) {
          e.preventDefault();
          var mClear = document.getElementById('master-search-clear-btn');
          if (mClear && mClear.style.display !== 'none') {
            setFocus(mClear);
            return;
          }
          var mIn = document.getElementById('master-search-input');
          if (mIn) { setFocus(mIn); return; }
        } else if (code === KEY_CODES.DOWN) {
          e.preventDefault();
          var mInD = document.getElementById('master-search-input');
          if (mInD) { setFocus(mInD); return; }
        }
      }

      // 0b. From Sidebar Navigation Rail -> pressing RIGHT moves to active Category, UP/DOWN navigates rail with circular wrap
      if (_currentFocused.classList.contains('nav-rail-btn')) {
        if (code === KEY_CODES.RIGHT) {
          var activePage = document.querySelector('.dashboard-page.active');
          var activeCat = activePage ? (activePage.querySelector('.category-item.active') || activePage.querySelector('.category-item')) : null;
          if (activeCat) {
            e.preventDefault();
            setFocus(activeCat);
            return;
          }
        } else if (code === KEY_CODES.UP) {
          e.preventDefault();
          var railBtns = [
            document.getElementById('nav-btn-live'),
            document.getElementById('nav-btn-movies'),
            document.getElementById('nav-btn-series')
          ].filter(function(b) { return b && b.offsetParent !== null; });
          var idx = railBtns.indexOf(_currentFocused);
          if (idx <= 0) {
            setFocus(railBtns[railBtns.length - 1]);
          } else {
            setFocus(railBtns[idx - 1]);
          }
          return;
        } else if (code === KEY_CODES.DOWN) {
          e.preventDefault();
          var railBtns = [
            document.getElementById('nav-btn-live'),
            document.getElementById('nav-btn-movies'),
            document.getElementById('nav-btn-series')
          ].filter(function(b) { return b && b.offsetParent !== null; });
          var idx = railBtns.indexOf(_currentFocused);
          if (idx >= railBtns.length - 1) {
            setFocus(railBtns[0]);
          } else if (idx >= 0) {
            setFocus(railBtns[idx + 1]);
          } else {
            setFocus(railBtns[0]);
          }
          return;
        }
      }

      // 1. In Categories list -> UP/DOWN instant direct sibling navigation, UP on first jumps to search, LEFT to rail, RIGHT to channels/grid
      if (_currentFocused.classList.contains('category-item')) {
        if (code === KEY_CODES.UP) {
          e.preventDefault();
          var prev = _currentFocused.previousElementSibling;
          while (prev && (!prev.classList.contains('category-item') || prev.offsetParent === null)) {
            prev = prev.previousElementSibling;
          }
          if (prev) {
            setFocus(prev);
            return;
          }
          var activePage = document.querySelector('.dashboard-page.active');
          var catSearchInput = activePage ? activePage.querySelector('.col-search-input') : null;
          if (catSearchInput) {
            setFocus(catSearchInput);
            return;
          }
        } else if (code === KEY_CODES.DOWN) {
          e.preventDefault();
          var next = _currentFocused.nextElementSibling;
          while (next && (!next.classList.contains('category-item') || next.offsetParent === null)) {
            next = next.nextElementSibling;
          }
          if (!next && window.TVApp && typeof window.TVApp.loadMoreCategoriesFor === 'function') {
            var catParent = _currentFocused.parentElement;
            if (catParent && window.TVApp.loadMoreCategoriesFor(catParent.id)) {
              next = _currentFocused.nextElementSibling;
              while (next && (!next.classList.contains('category-item') || next.offsetParent === null)) {
                next = next.nextElementSibling;
              }
            }
          }
          if (next) {
            setFocus(next);
            return;
          }
          return;
        } else if (code === KEY_CODES.RIGHT) {
          e.preventDefault();
          var activePage = document.querySelector('.dashboard-page.active');
          if (activePage && activePage.id === 'page-live') {
            if (window._goatVirtualList) {
              window._goatVirtualList.focusActive();
              return;
            }
          } else {
            var firstPoster = activePage ? activePage.querySelector('.poster-card') : null;
            if (firstPoster) {
              setFocus(firstPoster);
              return;
            }
          }
        } else if (code === KEY_CODES.LEFT) {
          var activeNav = document.querySelector('.nav-rail-btn.active') || document.querySelector('.nav-rail-btn');
          if (activeNav) {
            e.preventDefault();
            setFocus(activeNav);
            return;
          }
        }
      }

      // 2. In Channel Row -> UP/DOWN inside virtual list, LEFT to category, RIGHT to preview ONLY if channel is playing
      if (_currentFocused.classList.contains('virtual-row') || _currentFocused.classList.contains('channel-row') || _currentFocused.closest('.channel-row-wrap')) {
        var wrap = _currentFocused.closest('.channel-row-wrap');
        var curIdx = wrap ? parseInt(wrap.getAttribute('data-index'), 10) : (window._goatVirtualList ? window._goatVirtualList.getSelectedIndex() : 0);

        if (code === KEY_CODES.UP) {
          e.preventDefault();
          if (curIdx <= 0) {
            var searchBtn = document.getElementById('header-search-btn');
            if (searchBtn) {
              setFocus(searchBtn);
              return;
            }
          } else if (window._goatVirtualList) {
            window._goatVirtualList.focusIndex(curIdx - 1);
            return;
          }
        } else if (code === KEY_CODES.DOWN) {
          e.preventDefault();
          if (window._goatVirtualList) {
            var total = window._goatVirtualList.getItemCount();
            if (curIdx < total - 1) {
              window._goatVirtualList.focusIndex(curIdx + 1);
              return;
            } else if (total > 0 && curIdx >= total - 1) {
              // Wrap around back to the first channel entry (index 0)
              window._goatVirtualList.focusIndex(0);
              return;
            }
          }
          return;
        } else if (code === KEY_CODES.LEFT) {
          e.preventDefault();
          var activeCat = document.querySelector('#live-categories-list .category-item.active') ||
                          document.querySelector('#live-categories-list .category-item');
          if (activeCat) {
            setFocus(activeCat);
            return;
          }
        } else if (code === KEY_CODES.RIGHT) {
          e.preventDefault();
          if (isPreviewActive()) {
            var preview = document.getElementById('preview-player-box');
            if (preview) {
              setFocus(preview);
              return;
            }
          }
          return;
        }
      }

      // 3. In Preview Player -> pressing LEFT moves back to Channel List, UP to header
      if (_currentFocused.id === 'preview-player-box' || _currentFocused.id === 'preview-fullscreen-btn') {
        if (code === KEY_CODES.LEFT) {
          e.preventDefault();
          if (window._goatVirtualList) {
            window._goatVirtualList.focusActive();
            return;
          }
        } else if (code === KEY_CODES.UP) {
          e.preventDefault();
          var targetBtn = document.getElementById('header-lang-btn') || document.getElementById('header-switch-btn');
          if (targetBtn) {
            setFocus(targetBtn);
            return;
          }
        }
      }

      // Continue Watching Card Navigation
      if (_currentFocused.classList.contains('cw-card')) {
        if (code === KEY_CODES.DOWN) {
          e.preventDefault();
          var activePage = document.querySelector('.dashboard-page.active');
          var firstPoster = activePage ? activePage.querySelector('.poster-grid .poster-card') : null;
          if (firstPoster) setFocus(firstPoster);
          return;
        } else if (code === KEY_CODES.UP) {
          e.preventDefault();
          var activePage = document.querySelector('.dashboard-page.active');
          var sInput = activePage ? activePage.querySelector('.vod-search-input') : null;
          if (sInput) setFocus(sInput);
          return;
        } else if (code === KEY_CODES.LEFT) {
          var prevCw = _currentFocused.previousElementSibling;
          if (prevCw && prevCw.classList.contains('cw-card')) {
            e.preventDefault();
            setFocus(prevCw);
            prevCw.scrollIntoView({ behavior: 'smooth', inline: 'center', block: 'nearest' });
            return;
          }
          var activePage = document.querySelector('.dashboard-page.active');
          var activeCat = activePage ? (activePage.querySelector('.category-item.active') || activePage.querySelector('.category-item')) : null;
          if (activeCat) {
            e.preventDefault();
            setFocus(activeCat);
            return;
          }
        } else if (code === KEY_CODES.RIGHT) {
          var nextCw = _currentFocused.nextElementSibling;
          if (nextCw && nextCw.classList.contains('cw-card')) {
            e.preventDefault();
            setFocus(nextCw);
            nextCw.scrollIntoView({ behavior: 'smooth', inline: 'center', block: 'nearest' });
            return;
          }
        }
      }

      // 4. In VOD Poster Card -> UP in first row goes to search or Continue Watching; LEFT in first column goes to Category;
      // DOWN / RIGHT at the end of the list wraps to the first entry (card 0)
      if (_currentFocused.classList.contains('poster-card')) {
        if (code === KEY_CODES.UP) {
          var upCand = findNextInDirection(_currentFocused, 'up');
          if (upCand && (upCand.classList.contains('poster-card') || upCand.classList.contains('cw-card'))) {
            e.preventDefault();
            setFocus(upCand);
            return;
          }
          var activePage = document.querySelector('.dashboard-page.active');
          var cwSec = activePage ? activePage.querySelector('.continue-watching-section') : null;
          if (cwSec && cwSec.style.display !== 'none') {
            var firstCw = cwSec.querySelector('.cw-card');
            if (firstCw) {
              e.preventDefault();
              setFocus(firstCw);
              return;
            }
          }
          e.preventDefault();
          var searchInput = activePage ? activePage.querySelector('.vod-search-input') : null;
          if (searchInput) {
            setFocus(searchInput);
          }
          return;
        } else if (code === KEY_CODES.LEFT) {
          var leftCand = findNextInDirection(_currentFocused, 'left');
          if (leftCand && leftCand.classList.contains('poster-card')) {
            e.preventDefault();
            setFocus(leftCand);
            return;
          }
          var activePage = document.querySelector('.dashboard-page.active') || _currentFocused.closest('.dashboard-page');
          var isMovies = activePage && activePage.id === 'page-movies';
          var isSeries = activePage && activePage.id === 'page-series';
          var catSelector = isMovies ? '#movies-categories-list' : (isSeries ? '#series-categories-list' : '.category-menu-list');
          var activeCat = document.querySelector(catSelector + ' .category-item.active') ||
                          document.querySelector(catSelector + ' .category-item') ||
                          (activePage ? (activePage.querySelector('.category-item.active') || activePage.querySelector('.category-item')) : null);
          if (activeCat) {
            e.preventDefault();
            setFocus(activeCat);
            return;
          }
          return;
        } else if (code === KEY_CODES.DOWN) {
          var downCand = findNextInDirection(_currentFocused, 'down');
          if (downCand && downCand.classList.contains('poster-card')) {
            e.preventDefault();
            setFocus(downCand);
            return;
          }

          var grid = _currentFocused.closest('.poster-grid');
          var isMovies = grid && grid.id === 'movies-grid-container';
          var isSeries = grid && grid.id === 'series-grid-container';

          if (isMovies && window.TVApp && window.TVApp.hasMoreMovies()) {
            e.preventDefault();
            window.TVApp.loadNextMovieBatch();
            setTimeout(function() {
              var nextDown = findNextInDirection(_currentFocused, 'down');
              if (nextDown && nextDown.classList.contains('poster-card')) {
                setFocus(nextDown);
              } else if (_currentFocused.nextElementSibling && _currentFocused.nextElementSibling.classList.contains('poster-card')) {
                setFocus(_currentFocused.nextElementSibling);
              }
            }, 30);
            return;
          }

          if (isSeries && window.TVApp && window.TVApp.hasMoreSeries()) {
            e.preventDefault();
            window.TVApp.loadNextSeriesBatch();
            setTimeout(function() {
              var nextDown = findNextInDirection(_currentFocused, 'down');
              if (nextDown && nextDown.classList.contains('poster-card')) {
                setFocus(nextDown);
              } else if (_currentFocused.nextElementSibling && _currentFocused.nextElementSibling.classList.contains('poster-card')) {
                setFocus(_currentFocused.nextElementSibling);
              }
            }, 30);
            return;
          }

          // At the end of the list: wrap back to the first entry
          if (grid) {
            var firstCard = grid.querySelector('.poster-card');
            if (firstCard) {
              e.preventDefault();
              grid.scrollTop = 0;
              setFocus(firstCard);
              return;
            }
          }
          return;
        } else if (code === KEY_CODES.RIGHT) {
          var rightCand = findNextInDirection(_currentFocused, 'right');
          if (rightCand && rightCand.classList.contains('poster-card')) {
            e.preventDefault();
            setFocus(rightCand);
            return;
          }

          // Try wrapping to start of next row
          var nextSib = _currentFocused.nextElementSibling;
          if (nextSib && nextSib.classList.contains('poster-card')) {
            e.preventDefault();
            setFocus(nextSib);
            return;
          }

          var grid = _currentFocused.closest('.poster-grid');
          var isMovies = grid && grid.id === 'movies-grid-container';
          var isSeries = grid && grid.id === 'series-grid-container';

          if (isMovies && window.TVApp && window.TVApp.hasMoreMovies()) {
            e.preventDefault();
            window.TVApp.loadNextMovieBatch();
            setTimeout(function() {
              var nextCard = _currentFocused.nextElementSibling;
              if (nextCard && nextCard.classList.contains('poster-card')) {
                setFocus(nextCard);
              }
            }, 30);
            return;
          }

          if (isSeries && window.TVApp && window.TVApp.hasMoreSeries()) {
            e.preventDefault();
            window.TVApp.loadNextSeriesBatch();
            setTimeout(function() {
              var nextCard = _currentFocused.nextElementSibling;
              if (nextCard && nextCard.classList.contains('poster-card')) {
                setFocus(nextCard);
              }
            }, 30);
            return;
          }

          // At the very end of the list: wrap back to the first entry
          if (grid) {
            var firstCard = grid.querySelector('.poster-card');
            if (firstCard) {
              e.preventDefault();
              grid.scrollTop = 0;
              setFocus(firstCard);
              return;
            }
          }
          return;
        }
      }
    }

    // Standard 4-direction candidate search
    var next = null;
    if (code === KEY_CODES.UP) {
      next = findNextInDirection(_currentFocused, 'up');
      if (!next && _currentFocused) {
        var drawerListUp = _currentFocused.closest('#drawer-series-list');
        if (drawerListUp) {
          var seasonTab = document.querySelector('#drawer-season-tabs .season-tab-btn.active') ||
                          document.querySelector('#drawer-season-tabs .season-tab-btn');
          if (seasonTab) next = seasonTab;
        }
      }
    } else if (code === KEY_CODES.DOWN) {
      next = findNextInDirection(_currentFocused, 'down');
      // Wrap-around for episode lists: if at end of season, jump back to Episode 1
      if (!next && _currentFocused) {
        var drawerList = _currentFocused.closest('#drawer-series-list');
        if (drawerList) {
          var firstEp = drawerList.querySelector('.episode-card');
          if (firstEp && firstEp !== _currentFocused) {
            drawerList.scrollTop = 0;
            next = firstEp;
          }
        }
        var modalEpList = _currentFocused.closest('.episodes-list');
        if (modalEpList) {
          var mFirstEp = modalEpList.querySelector('.episode-card');
          if (mFirstEp && mFirstEp !== _currentFocused) {
            modalEpList.scrollTop = 0;
            next = mFirstEp;
          }
        }
      }
    } else if (code === KEY_CODES.LEFT) {
      next = findNextInDirection(_currentFocused, 'left');
    } else if (code === KEY_CODES.RIGHT) {
      next = findNextInDirection(_currentFocused, 'right');
    }

    if (next) {
      e.preventDefault();
      setFocus(next);
    }
  }

  // Pointer hover support for Magic Remote / mouse
  function handleMouseOver(e) {
    if (document.body.classList.contains('player-fullscreen')) {
      var isModalOpen = !!document.querySelector('.modal-overlay.active');
      var isDrawerOpen = !!document.querySelector('.slide-drawer.open');
      var cmEl = document.getElementById('live-channel-menu');
      var isChannelMenuOpen = cmEl && cmEl.style.display !== 'none';
      var catEl = document.getElementById('live-category-menu');
      var isCatMenuOpen = catEl && catEl.style.display !== 'none';
      var epgEl = document.getElementById('live-epg-overlay');
      var isEpgOverlayOpen = epgEl && epgEl.style.display !== 'none';
      if (!isModalOpen && !isDrawerOpen && !isChannelMenuOpen && !isCatMenuOpen && !isEpgOverlayOpen) return;
    }
    var target = e.target ? e.target.closest('.focusable') : null;
    if (!target || target === _currentFocused) return;
    var activeModals = document.querySelectorAll('.modal-overlay.active');
    if (activeModals.length > 0 && !activeModals[activeModals.length - 1].contains(target)) {
      return;
    }
    setFocus(target, true);
  }

  // Direct click on inputs focuses natively
  function handleClick(e) {
    if (_suppressNextClick) {
      e.preventDefault();
      e.stopPropagation();
      return;
    }
    if (document.body.classList.contains('player-fullscreen')) {
      var isModalOpen = !!document.querySelector('.modal-overlay.active');
      var isDrawerOpen = !!document.querySelector('.slide-drawer.open');
      var cmEl = document.getElementById('live-channel-menu');
      var isChannelMenuOpen = cmEl && cmEl.style.display !== 'none';
      var catEl = document.getElementById('live-category-menu');
      var isCatMenuOpen = catEl && catEl.style.display !== 'none';
      var epgEl = document.getElementById('live-epg-overlay');
      var isEpgOverlayOpen = epgEl && epgEl.style.display !== 'none';
      if (!isModalOpen && !isDrawerOpen && !isChannelMenuOpen && !isCatMenuOpen && !isEpgOverlayOpen) return;
    }
    var target = e.target ? e.target.closest('input, textarea') : null;
    if (target) {
      setFocus(target, true);
      try { target.focus(); } catch(err){}
    }
  }

  function handleKeyUp(e) {
    var code = e.keyCode || e.which;
    if (code === KEY_CODES.LEFT || code === KEY_CODES.RIGHT || code === 412 || code === 417) {
      if (window._goatPlayer && typeof window._goatPlayer.resetSeekRepeat === 'function') {
        window._goatPlayer.resetSeekRepeat();
      }
    }
    if (code === KEY_CODES.ENTER) {
      if (_enterHoldTimer) {
        clearTimeout(_enterHoldTimer);
        _enterHoldTimer = null;
      }
      if (_enterHoldTriggered) {
        _enterHoldTriggered = false;
        _enterFocusedElement = null;
        _suppressNextClick = true;
        setTimeout(function() { _suppressNextClick = false; }, 400);
        e.preventDefault();
        e.stopPropagation();
        return;
      }
      if (_enterFocusedElement) {
        var elToClick = _enterFocusedElement;
        _enterFocusedElement = null;
        elToClick.click();
      }
    }
  }

  // Automatically blur input and restore D-pad navigation when webOS virtual keyboard is dismissed
  function handleKeyboardStateChange(e) {
    _isVirtualKeyboardVisible = !!(e && e.detail && e.detail.visibility);
    if (!_isVirtualKeyboardVisible) {
      if (document.activeElement && isInput(document.activeElement)) {
        try { document.activeElement.blur(); } catch(err){}
      }
    }
  }

  function handleWindowBlur() {
    _isVirtualKeyboardVisible = false;
    if (_enterHoldTimer) {
      clearTimeout(_enterHoldTimer);
      _enterHoldTimer = null;
    }
    _enterHoldTriggered = false;
    _enterFocusedElement = null;
  }

  function destroy() {
    window.removeEventListener('keydown', handleKeyDown, true);
    window.removeEventListener('keyup', handleKeyUp, true);
    window.removeEventListener('blur', handleWindowBlur);
    document.removeEventListener('mouseover', handleMouseOver, true);
    document.removeEventListener('click', handleClick, true);
    document.removeEventListener('keyboardStateChange', handleKeyboardStateChange);
    handleWindowBlur();
    _currentFocused = null;
    _backCallbacks = [];
    var focusedEls = document.querySelectorAll('.focused');
    for (var i = 0; i < focusedEls.length; i++) {
      focusedEls[i].classList.remove('focused');
    }
  }

  document.addEventListener('mouseover', handleMouseOver, true);
  document.addEventListener('click', handleClick, true);
  window.addEventListener('keyup', handleKeyUp, true);
  window.addEventListener('keydown', handleKeyDown, true);
  window.addEventListener('blur', handleWindowBlur);
  document.addEventListener('keyboardStateChange', handleKeyboardStateChange);

  window.SpatialNav = {
    setFocus: setFocus,
    getCurrent: function() { return _currentFocused; },
    focusFirst: function(container) {
      var list = getFocusableElements(container);
      if (list.length > 0) {
        setFocus(list[0]);
        return list[0];
      }
      return null;
    },
    pushBackHandler: function(cb) {
      if (typeof cb === 'function' && _backCallbacks.indexOf(cb) === -1) {
        _backCallbacks.push(cb);
      }
    },
    removeBackHandler: function(cb) {
      var idx = _backCallbacks.indexOf(cb);
      if (idx !== -1) _backCallbacks.splice(idx, 1);
    },
    popBackHandler: function() {
      return _backCallbacks.pop();
    },
    registerTizenKeys: registerTizenKeys,
    destroy: destroy
  };
  window.TVSpatialNav = window.SpatialNav;
})();
