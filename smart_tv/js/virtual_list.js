// High-Performance Chunked Infinite Scroll for 10,000+ Channels with D-Pad & Mouse
(function() {
  function ChannelList(options) {
    this.container = options.container;
    this.renderRow = options.renderRow;
    this.onSelect = options.onSelect;
    this.batchSize = options.batchSize || 40;
    this.items = [];
    this.loadedCount = 0;
    this.selectedIndex = 0;

    this._initDom();
  }

  ChannelList.prototype._initDom = function() {
    this.container.innerHTML = '';
    this.container.style.position = 'relative';
    this.container.style.overflowY = 'auto';
    this.container.style.height = '100%';

    this.listEl = document.createElement('div');
    this.listEl.className = 'channel-items-container';
    this.listEl.style.display = 'flex';
    this.listEl.style.flexDirection = 'column';
    this.listEl.style.gap = '6px';
    this.container.appendChild(this.listEl);

    this.emptyMsg = document.createElement('div');
    this.emptyMsg.className = 'col-placeholder';
    this.emptyMsg.style.display = 'none';
    this.emptyMsg.style.padding = '0';
    this.container.appendChild(this.emptyMsg);

    var self = this;
    this.container.addEventListener('scroll', function() {
      if (self.container.scrollTop + self.container.clientHeight >= self.container.scrollHeight - 300) {
        self.loadNextBatch();
      }
    });
  };

  ChannelList.prototype.updateEmptyMsg = function(isFavorites) {
    var isDe = (window.TVI18n && window.TVI18n.getLanguage() === 'de');
    var icon = isFavorites
      ? '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>'
      : '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="7" width="20" height="15" rx="2" ry="2"/><polyline points="17 2 12 7 7 2"/></svg>';
    var title = isFavorites
      ? (isDe ? 'Keine Favoriten vorhanden' : 'No Favorites Added')
      : (isDe ? 'Keine Sender gefunden' : 'No Channels Found');
    var sub = isFavorites
      ? (isDe ? 'Wähle das Stern-Symbol auf einem Sender, um ihn zu deinen Favoriten hinzuzufügen.' : 'Select the star icon on any channel to add it to your Favorites.')
      : (isDe ? 'In dieser Kategorie wurden keine Sender gefunden.' : 'No channels found in this category.');

    this.emptyMsg.innerHTML = 
      '<div class="vod-empty-state" style="padding: 60px 16px;">' +
        '<div class="vod-empty-icon-wrap" style="width: 76px; height: 76px; margin-bottom: 18px;">' + icon + '</div>' +
        '<div class="vod-empty-title" style="font-size: 20px;">' + title + '</div>' +
        '<div class="vod-empty-subtitle" style="font-size: 14px;">' + sub + '</div>' +
      '</div>';
  };

  ChannelList.prototype.setItems = function(items, isFavorites) {
    this.items = items || [];
    this.loadedCount = 0;
    this.selectedIndex = 0;
    this.listEl.innerHTML = '';
    this.container.scrollTop = 0;

    if (this.items.length === 0) {
      this.updateEmptyMsg(isFavorites);
      this.emptyMsg.style.display = 'block';
      return;
    }

    this.emptyMsg.style.display = 'none';
    this.loadNextBatch();
  };

  ChannelList.prototype.loadNextBatch = function() {
    if (this.loadedCount >= this.items.length) return;

    var start = this.loadedCount;
    var end = Math.min(this.items.length, start + this.batchSize);
    var self = this;

    for (var i = start; i < end; i++) {
      var item = this.items[i];
      var row = document.createElement('div');
      row.className = 'channel-row-wrap';
      row.setAttribute('data-index', i);

      this.renderRow(row, item, i, i === this.selectedIndex);

      (function(idx, el) {
        el.addEventListener('click', function() {
          self.selectedIndex = idx;
          if (self.onSelect && self.items[idx]) {
            self.onSelect(self.items[idx], idx);
          }
          var channelRow = el.querySelector('.channel-row') || el;
          if (window.SpatialNav) {
            window.SpatialNav.setFocus(channelRow, true);
          }
        });
      })(i, row);

      this.listEl.appendChild(row);
    }

    this.loadedCount = end;
  };

  ChannelList.prototype.focusIndex = function(index) {
    if (index < 0 || !this.items || index >= this.items.length) return;
    this.selectedIndex = index;
    while (index >= this.loadedCount && this.loadedCount < this.items.length) {
      this.loadNextBatch();
    }
    if (index >= this.loadedCount - 5 && this.loadedCount < this.items.length) {
      this.loadNextBatch();
    }
    var targetEl = this.listEl.querySelector('.channel-row-wrap[data-index="' + index + '"]');
    if (targetEl && window.SpatialNav) {
      var focusableChild = targetEl.querySelector('.channel-row') || targetEl.querySelector('.focusable') || targetEl;
      window.SpatialNav.setFocus(focusableChild, true);

      var container = this.container;
      if (container) {
        var rowTop = targetEl.offsetTop;
        var rowHeight = targetEl.offsetHeight || 64;
        var viewTop = container.scrollTop;
        var viewHeight = container.clientHeight;
        if (rowTop < viewTop) {
          container.scrollTop = rowTop;
        } else if (rowTop + rowHeight > viewTop + viewHeight) {
          container.scrollTop = rowTop + rowHeight - viewHeight;
        }
      }
    }
  };

  ChannelList.prototype.focusActive = function() {
    this.focusIndex(this.selectedIndex);
  };

  ChannelList.prototype.getSelectedIndex = function() {
    return this.selectedIndex;
  };

  ChannelList.prototype.getItemCount = function() {
    return this.items ? this.items.length : 0;
  };

  ChannelList.prototype.getSelectedItem = function() {
    return (this.items && this.items[this.selectedIndex]) ? this.items[this.selectedIndex] : null;
  };

  ChannelList.prototype.refreshPlayingState = function(activeStreamId) {
    var rows = this.listEl.querySelectorAll('.channel-row');
    rows.forEach(function(r) {
      r.classList.remove('active-playing');
    });
    if (!activeStreamId) return;
    for (var i = 0; i < this.loadedCount; i++) {
      if (this.items[i] && String(this.items[i].stream_id) === String(activeStreamId)) {
        var rowEl = this.listEl.querySelector('.channel-row-wrap[data-index="' + i + '"] .channel-row');
        if (rowEl) rowEl.classList.add('active-playing');
        break;
      }
    }
  };

  window.ChannelList = ChannelList;
})();
