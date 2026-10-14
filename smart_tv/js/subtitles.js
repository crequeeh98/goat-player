// Universal Subtitle Engine for LG webOS TV & Samsung Tizen
// Provides pure JavaScript WebVTT & SRT parsing, cue synchronization, native <track> injection, and external subtitle management
(function() {
  'use strict';

  function parseTimestamp(ts) {
    if (!ts) return 0;
    var cleaned = ts.trim().replace(',', '.');
    var parts = cleaned.split(':');
    if (parts.length === 3) {
      return parseFloat(parts[0]) * 3600 + parseFloat(parts[1]) * 60 + parseFloat(parts[2]);
    } else if (parts.length === 2) {
      return parseFloat(parts[0]) * 60 + parseFloat(parts[1]);
    }
    return parseFloat(cleaned) || 0;
  }

  var TVSubtitles = {
    // Parse standard SubRip (.srt) text into array of timed cues
    parseSrt: function(srtText) {
      if (!srtText || typeof srtText !== 'string') return [];
      var cues = [];
      var normalized = srtText.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
      var blocks = normalized.split(/\n\s*\n/);

      for (var i = 0; i < blocks.length; i++) {
        var block = blocks[i].trim();
        if (!block) continue;

        var lines = block.split('\n');
        if (lines.length < 2) continue;

        var timeLineIdx = 0;
        // Check if first line is a numeric sequence identifier
        if (/^\d+$/.test(lines[0].trim()) && lines.length >= 2) {
          timeLineIdx = 1;
        }

        var timeLine = lines[timeLineIdx];
        if (!timeLine || timeLine.indexOf('-->') === -1) continue;

        var timeParts = timeLine.split('-->');
        if (timeParts.length < 2) continue;

        var startTime = parseTimestamp(timeParts[0]);
        var endTime = parseTimestamp(timeParts[1].trim().split(/\s+/)[0]);

        var textLines = lines.slice(timeLineIdx + 1);
        var cueText = textLines.join('\n').trim();

        if (cueText && endTime > startTime) {
          cues.push({
            start: startTime,
            end: endTime,
            text: cueText
          });
        }
      }

      // Sort chronologically
      cues.sort(function(a, b) { return a.start - b.start; });
      return cues;
    },

    // Parse WebVTT (.vtt) text into array of timed cues
    parseVtt: function(vttText) {
      if (!vttText || typeof vttText !== 'string') return [];
      var cues = [];
      var normalized = vttText.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
      var blocks = normalized.split(/\n\s*\n/);

      for (var i = 0; i < blocks.length; i++) {
        var block = blocks[i].trim();
        if (!block || block.indexOf('WEBVTT') === 0 || block.indexOf('NOTE') === 0 || block.indexOf('STYLE') === 0) {
          continue;
        }

        var lines = block.split('\n');
        var timeLineIdx = 0;
        if (lines[0].indexOf('-->') === -1 && lines.length > 1) {
          timeLineIdx = 1;
        }

        var timeLine = lines[timeLineIdx];
        if (!timeLine || timeLine.indexOf('-->') === -1) continue;

        var timeParts = timeLine.split('-->');
        if (timeParts.length < 2) continue;

        var startTime = parseTimestamp(timeParts[0]);
        var endTime = parseTimestamp(timeParts[1].trim().split(/\s+/)[0]);

        var textLines = lines.slice(timeLineIdx + 1);
        var cueText = textLines.join('\n').trim();

        if (cueText && endTime > startTime) {
          cues.push({
            start: startTime,
            end: endTime,
            text: cueText
          });
        }
      }

      cues.sort(function(a, b) { return a.start - b.start; });
      return cues;
    },

    // Convert SRT to WebVTT string
    // Fast binary search to find active cue at given timestamp (O(log N))
    findCueAtTime: function(cues, curTime) {
      if (!cues || cues.length === 0 || typeof curTime !== 'number') return null;
      var low = 0;
      var high = cues.length - 1;

      while (low <= high) {
        var mid = (low + high) >> 1;
        var cue = cues[mid];
        if (curTime >= cue.start && curTime <= cue.end) {
          return cue;
        } else if (curTime < cue.start) {
          high = mid - 1;
        } else {
          low = mid + 1;
        }
      }
      return null;
    },

    srtToVtt: function(srtText) {
      if (!srtText) return 'WEBVTT\n\n';
      var vtt = 'WEBVTT\n\n';
      var normalized = srtText.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
      normalized = normalized.replace(/(\d{2}:\d{2}:\d{2}),(\d{3})/g, '$1.$2');
      return vtt + normalized;
    },

    // Cache for resolved external subtitle lists
    _subResolveCache: {},

    getCachedSubtitles: function(meta) {
      if (!meta) return [];
      var isSeries = (meta.type === 'series' || !!meta.seriesId || !!meta.season);
      var title = meta.seriesName || meta.title || '';
      var cleanTitle = title.replace(/^[0-9]+\.\s*/, '').replace(/\s*\([^)]*\)/g, '').replace(/\s*\[[^\]]*\]/g, '').trim();
      var sId = meta.streamId || meta.id || cleanTitle;
      var season = meta.season || 1;
      var episode = meta.episode || 1;
      var cacheKey = (isSeries ? 's_' + sId + '_' + season + '_' + episode : 'm_' + sId);
      return this._subResolveCache[cacheKey] || [];
    },

    // Resolve external WebVTT / SRT subtitle tracks for Movie or Series
    // Disabled: external scraping from OpenSubtitles/Stremio causes severe audio/video desync
    // and duplicate generic tracks ("Deutsch", "Deutsch #2") on IPTV streams. Only provider/stream tracks are used.
    resolveExternalSubtitles: function(meta) {
      return Promise.resolve([]);
    },

    // Load and register a subtitle track on the player
    loadSubtitle: function(textOrUrl, lang, label, playerInstance) {
      var player = playerInstance || window._player;
      if (!player) return Promise.reject(new Error('Player not available'));

      var isUrl = typeof textOrUrl === 'string' && (/^https?:\/\//i.test(textOrUrl) || textOrUrl.indexOf('blob:') === 0);

      if (isUrl) {
        return fetch(textOrUrl).then(function(res) {
          if (!res.ok) throw new Error('HTTP status ' + res.status);
          return res.text();
        }).then(function(content) {
          return TVSubtitles._applySubtitleContent(content, lang, label, player);
        });
      } else {
        return Promise.resolve(TVSubtitles._applySubtitleContent(textOrUrl, lang, label, player));
      }
    },

    _applySubtitleContent: function(content, lang, label, player) {
      if (!content || !player) return null;
      var isVtt = content.indexOf('WEBVTT') !== -1;
      var cues = isVtt ? this.parseVtt(content) : this.parseSrt(content);

      if (!cues || cues.length === 0) {
        console.warn('[TVSubtitles] No valid cues parsed from subtitle text');
        return null;
      }

      console.log('[TVSubtitles] Successfully parsed ' + cues.length + ' cues for: ' + (label || lang || 'Subtitle'));

      var trackItem = {
        id: 'ext_' + Date.now(),
        name: label || (window.TrackLanguageMatcher ? window.TrackLanguageMatcher.getLanguageDisplayName(lang) : (lang || 'External Subtitles')),
        title: label || (window.TrackLanguageMatcher ? window.TrackLanguageMatcher.getLanguageDisplayName(lang) : (lang || 'External Subtitles')),
        lang: lang || 'und',
        language: lang || 'und',
        cues: cues,
        isExternal: true,
        active: true
      };

      if (typeof player.addCustomSubtitleTrack === 'function') {
        player.addCustomSubtitleTrack(trackItem);
      }

      return trackItem;
    }
  };

  window.TVSubtitles = TVSubtitles;
})();
