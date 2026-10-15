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
    // Disabled: external scraping from OpenSubtitles/Stremio causes duplicate generic tracks ("Deutsch #2").
    // Only provider/stream tracks are displayed in the track list.
    resolveExternalSubtitles: function(meta) {
      return Promise.resolve([]);
    },

    // On-demand fetch of cues for an embedded/provider subtitle track selected by the user
    fetchTrackSubtitle: function(meta, trackObj) {
      if (!meta || !trackObj) return Promise.resolve(null);
      var isSeries = (meta.type === 'series' || !!meta.seriesId || !!meta.season);
      var rawTitle = meta.seriesName || meta.title || '';
      var cleanTitle = rawTitle
        .replace(/^[A-Za-z0-9\+\#\-\s]+\s*-\s*/, '')
        .replace(/^[0-9]+\.\s*/, '')
        .replace(/\s*\([0-9]{4}\)/g, '')
        .replace(/\s*\[[^\]]*\]/g, '')
        .trim();
      if (!cleanTitle) cleanTitle = rawTitle;

      var targetLang = (trackObj.lang || trackObj.language || '').toLowerCase().trim();
      var isForced = /forced/i.test(trackObj.title || trackObj.name || '');
      var isSdh = /sdh/i.test(trackObj.title || trackObj.name || '');

      var cacheKey = (isSeries ? 's_' + (meta.seriesId || meta.streamId) + '_' + (meta.season || 1) + '_' + (meta.episode || 1) : 'm_' + (meta.streamId || cleanTitle)) + '_' + targetLang + (isForced ? '_forced' : (isSdh ? '_sdh' : ''));
      if (this._subResolveCache[cacheKey]) {
        return Promise.resolve(this._subResolveCache[cacheKey]);
      }

      var self = this;
      var imdbId = meta.imdb_id || meta.imdbId || meta.imdb || '';
      if (!imdbId && meta.kinopoisk_url && typeof meta.kinopoisk_url === 'string') {
        var m = meta.kinopoisk_url.match(/tt\d{6,9}/i);
        if (m) imdbId = m[0];
      }

      function resolveImdb() {
        if (imdbId) return Promise.resolve(imdbId);
        var cat = isSeries ? 'series' : 'movie';
        var sUrl = 'https://v3-cinemeta.strem.io/catalog/' + cat + '/top/search=' + encodeURIComponent(cleanTitle) + '.json';
        return fetch(sUrl, { method: 'GET', cache: 'force-cache' })
          .then(function(r) { return r.json(); })
          .then(function(data) {
            if (data && data.metas && data.metas.length > 0) {
              var list = data.metas;
              var yearMatch = rawTitle.match(/\b(19\d\d|20\d\d)\b/);
              var relYear = yearMatch ? yearMatch[1] : null;
              if (relYear) {
                var byYear = list.find(function(m) { return (m.year == relYear || m.releaseInfo == relYear); });
                if (byYear && byYear.id) return byYear.id;
              }
              var exactName = list.find(function(m) { return m.name && m.name.toLowerCase() === cleanTitle.toLowerCase(); });
              if (exactName && exactName.id) return exactName.id;
              if (list[0].id) return list[0].id;
            }
            return null;
          }).catch(function() { return null; });
      }

      return resolveImdb().then(function(id) {
        if (!id) return null;
        var season = meta.season || 1;
        var episode = meta.episode || 1;
        var subQueryUrl = isSeries
          ? 'https://opensubtitles-v3.strem.io/subtitles/series/' + encodeURIComponent(id) + ':' + season + ':' + episode + '.json'
          : 'https://opensubtitles-v3.strem.io/subtitles/movie/' + encodeURIComponent(id) + '.json';

        return fetch(subQueryUrl, { method: 'GET', cache: 'force-cache' })
          .then(function(res) {
            if (!res.ok) throw new Error('Status ' + res.status);
            return res.json();
          })
          .then(function(data) {
            var rawList = (data && Array.isArray(data.subtitles)) ? data.subtitles : [];
            if (rawList.length === 0) return null;

            var langAliases = {
              'deu': ['ger', 'deu', 'de'], 'ger': ['ger', 'deu', 'de'], 'de': ['ger', 'deu', 'de'],
              'eng': ['eng', 'en'], 'en': ['eng', 'en'],
              'spa': ['spa', 'es', 'spl'], 'es': ['spa', 'es', 'spl'],
              'fre': ['fre', 'fra', 'fr'], 'fra': ['fre', 'fra', 'fr'], 'fr': ['fre', 'fra', 'fr'],
              'ita': ['ita', 'it'], 'it': ['ita', 'it'],
              'por': ['por', 'pt', 'pob'], 'pt': ['por', 'pt', 'pob'],
              'tur': ['tur', 'tr'], 'tr': ['tur', 'tr'],
              'rus': ['rus', 'ru'], 'ru': ['rus', 'ru'],
              'pol': ['pol', 'pl'], 'pl': ['pol', 'pl'],
              'dut': ['nld', 'dut', 'nl'], 'nld': ['nld', 'dut', 'nl'], 'nl': ['nld', 'dut', 'nl'],
              'ara': ['ara', 'ar'], 'ar': ['ara', 'ar'],
              'dan': ['dan', 'da'], 'da': ['dan', 'da'],
              'nor': ['nor', 'no'], 'no': ['nor', 'no'],
              'swe': ['swe', 'sv'], 'sv': ['swe', 'sv'],
              'fin': ['fin', 'fi'], 'fi': ['fin', 'fi'],
              'gre': ['ell', 'gre', 'el'], 'ell': ['ell', 'gre', 'el'], 'el': ['ell', 'gre', 'el'],
              'chi': ['zho', 'chi', 'zh', 'zht'], 'zho': ['zho', 'chi', 'zh', 'zht'], 'zh': ['zho', 'chi', 'zh', 'zht'],
              'cze': ['cze', 'ces', 'cs'], 'ces': ['cze', 'ces', 'cs'], 'cs': ['cze', 'ces', 'cs'],
              'bul': ['bul', 'bg'], 'bg': ['bul', 'bg'],
              'rum': ['ron', 'rum', 'ro'], 'ron': ['ron', 'rum', 'ro'], 'ro': ['ron', 'rum', 'ro'],
              'hun': ['hun', 'hu'], 'hu': ['hun', 'hu'],
              'ukr': ['ukr', 'uk'], 'uk': ['ukr', 'uk'],
              'heb': ['heb', 'he'], 'he': ['heb', 'he'],
              'jpn': ['jpn', 'ja'], 'ja': ['jpn', 'ja'],
              'kor': ['kor', 'ko'], 'ko': ['kor', 'ko']
            };

            var allowed = langAliases[targetLang] || [targetLang];
            var matched = rawList.filter(function(s) {
              if (!s || !s.url) return false;
              var l = (s.lang || '').toLowerCase();
              return allowed.indexOf(l) !== -1;
            });

            if (matched.length === 0) return null;

            var chosen = null;
            if (isForced) {
              chosen = matched.find(function(s) { return /forced/i.test(s.subtitleFileName || s.movieReleaseName || s.releaseGroup || ''); });
            } else if (isSdh) {
              chosen = matched.find(function(s) { return /sdh/i.test(s.subtitleFileName || s.movieReleaseName || s.releaseGroup || ''); });
            }
            if (!chosen) {
              chosen = matched.find(function(s) { return !/forced/i.test(s.subtitleFileName || s.movieReleaseName || s.releaseGroup || ''); }) || matched[0];
            }

            return fetch(chosen.url).then(function(tRes) {
              if (!tRes.ok) throw new Error('Failed to download subtitle file: ' + tRes.status);
              return tRes.text();
            }).then(function(text) {
              var isVtt = text.indexOf('WEBVTT') !== -1;
              var parsedCues = isVtt ? self.parseVtt(text) : self.parseSrt(text);
              var resultObj = { cues: parsedCues, url: chosen.url };
              self._subResolveCache[cacheKey] = resultObj;
              return resultObj;
            });
          });
      }).catch(function(err) {
        console.warn('[TVSubtitles] fetchTrackSubtitle notice:', err && err.message ? err.message : err);
        return null;
      });
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
