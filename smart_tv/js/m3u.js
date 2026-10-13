// smart_tv/js/m3u.js - High-performance M3U / M3U8 Playlist Parser for Smart TVs
(function() {
  'use strict';

  function extractAttr(line, attr) {
    if (!line) return '';
    // Match attr="value" or attr='value'
    var regex = new RegExp(attr + '=["\']([^"\']*)["\']', 'i');
    var match = line.match(regex);
    if (match) return match[1].trim();

    // Match unquoted attr=value (stopping at whitespace or next attribute)
    var regexNoQuote = new RegExp(attr + '=([^\\s,]+)', 'i');
    var matchNoQuote = line.match(regexNoQuote);
    return matchNoQuote ? matchNoQuote[1].trim() : '';
  }

  function parseM3u(content) {
    if (!content || typeof content !== 'string') {
      return { categories: [], streams: [], epgUrl: null };
    }

    var lines = content.split(/\r?\n/);
    var categoriesMap = {};
    var streams = [];
    var epgUrl = null;

    var currentItem = null;
    var streamIndex = 0;

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim();
      if (!line) continue;

      if (line.indexOf('#EXTM3U') === 0) {
        var tvgUrl = extractAttr(line, 'x-tvg-url') || extractAttr(line, 'url-tvg');
        if (tvgUrl) {
          epgUrl = tvgUrl.split(',')[0].trim();
        }
        continue;
      }

      if (line.indexOf('#EXTINF:') === 0) {
        var commaIdx = line.lastIndexOf(',');
        var title = commaIdx !== -1 ? line.substring(commaIdx + 1).trim() : 'Unknown Channel';
        var group = extractAttr(line, 'group-title') || 'General';
        var logo = extractAttr(line, 'tvg-logo') || '';
        var tvgId = extractAttr(line, 'tvg-id') || '';
        var tvgName = extractAttr(line, 'tvg-name') || title;

        currentItem = {
          name: title || tvgName,
          group: group,
          logo: logo,
          tvgId: tvgId
        };
        continue;
      }

      // If it's a stream URL (not a comment line)
      if (line.indexOf('#') !== 0 && currentItem) {
        streamIndex++;
        var catName = currentItem.group || 'General';
        var catId = 'cat_' + catName.toLowerCase().replace(/[^a-z0-9_-]/g, '_');

        if (!categoriesMap[catId]) {
          categoriesMap[catId] = {
            category_id: catId,
            category_name: catName
          };
        }

        streams.push({
          num: streamIndex,
          name: currentItem.name,
          stream_type: 'live',
          stream_id: 'm3u_' + streamIndex,
          stream_icon: currentItem.logo,
          epg_channel_id: currentItem.tvgId,
          added: '0',
          category_id: catId,
          category_name: catName,
          url: line,
          direct_source: line
        });

        currentItem = null;
      }
    }

    var categories = Object.keys(categoriesMap).map(function(k) {
      return categoriesMap[k];
    }).sort(function(a, b) {
      return a.category_name.localeCompare(b.category_name);
    });

    return {
      categories: categories,
      streams: streams,
      epgUrl: epgUrl
    };
  }

  window.TVM3U = {
    parse: parseM3u
  };
})();
