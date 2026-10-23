// Universal Smart TV Video Player: Seamless Preview & Fullscreen + VOD HUD
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

  function normalizeEpisodeList(eps) {
    if (!eps) return [];
    if (Array.isArray(eps)) return eps;
    if (typeof eps === 'object') {
      var arr = [];
      Object.keys(eps).forEach(function(k) {
        if (eps[k] && typeof eps[k] === 'object') {
          arr.push(eps[k]);
        }
      });
      arr.sort(function(a, b) {
        var aNum = parseInt(a.episode_num, 10);
        var bNum = parseInt(b.episode_num, 10);
        if (!isNaN(aNum) && !isNaN(bNum)) return aNum - bNum;
        return 0;
      });
      return arr;
    }
    return [];
  }
  window.normalizeEpisodeList = normalizeEpisodeList;

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

  var _trackUpdateListeners = [];
  window.onTracksUpdated = function() {
    for (var i = 0; i < _trackUpdateListeners.length; i++) {
      try { _trackUpdateListeners[i](); } catch(e){}
    }
  };
  window.addTrackUpdateListener = function(fn) {
    if (typeof fn === 'function' && _trackUpdateListeners.indexOf(fn) === -1) {
      _trackUpdateListeners.push(fn);
    }
    return function() {
      var idx = _trackUpdateListeners.indexOf(fn);
      if (idx !== -1) _trackUpdateListeners.splice(idx, 1);
    };
  };

  // Lightweight Container Header Demuxer (MKV EBML & MP4 Box Prober)
  var _containerTrackCache = {};

  // Extracts real embedded audio & subtitle tracks directly from the stream container
  var TVContainerProber = {
    probeStream: function(url) {
      if (!url || typeof fetch !== 'function') {
        return Promise.reject(new Error('Fetch not supported or empty URL'));
      }
      var cleanKey = url.split('?')[0];
      if (_containerTrackCache[cleanKey]) {
        console.log('[TrackDebug] TVContainerProber returning cached demuxed tracks for:', cleanKey);
        return Promise.resolve(_containerTrackCache[cleanKey]);
      }
      console.log('[TrackDebug] TVContainerProber: probing container headers for URL:', cleanKey);

      function combineChunks(chunks, totalLength) {
        var combined = new Uint8Array(totalLength);
        var offset = 0;
        for (var i = 0; i < chunks.length; i++) {
          combined.set(chunks[i], offset);
          offset += chunks[i].byteLength;
        }
        return combined.buffer;
      }

      var controller = (typeof AbortController === 'function') ? new AbortController() : null;
      var timeoutId = null;
      if (controller) {
        timeoutId = setTimeout(function() {
          try { controller.abort(); } catch(e){}
        }, 6000);
      }

      var rangeOpts = {
        method: 'GET',
        headers: { 'Range': 'bytes=0-1048575' }
      };
      if (controller) rangeOpts.signal = controller.signal;

      return fetch(url, rangeOpts).then(function(res) {
        if (timeoutId) clearTimeout(timeoutId);
        if (!res.ok && res.status !== 206 && res.status !== 200) {
          throw new Error('HTTP status ' + res.status);
        }
        if (res.status === 206 || !res.body || typeof res.body.getReader !== 'function') {
          return res.arrayBuffer();
        }
        var reader = res.body.getReader();
        var chunks = [];
        var totalBytes = 0;
        function readChunk() {
          return reader.read().then(function(step) {
            if (step.done || !step.value) {
              return combineChunks(chunks, totalBytes);
            }
            chunks.push(step.value);
            totalBytes += step.value.byteLength;
            if (totalBytes >= 1048576) {
              try { reader.cancel(); } catch(e){}
              return combineChunks(chunks, totalBytes);
            }
            return readChunk();
          });
        }
        return readChunk();
      }).then(function(buf) {
        var demuxed = TVContainerProber.parseBuffer(buf);
        _containerTrackCache[cleanKey] = demuxed;
        console.log('[TrackDebug] TVContainerProber demuxed: audios=' + demuxed.audios.length + ', subs=' + demuxed.subs.length);
        return demuxed;
      }).catch(function(err) {
        if (timeoutId) clearTimeout(timeoutId);
        console.log('[TrackDebug] TVContainerProber skipped:', err && err.message ? err.message : err);
        return { audios: [], subs: [] };
      });
    },

    getCachedTracks: function(url) {
      if (!url) return null;
      var cleanKey = url.split('?')[0];
      return _containerTrackCache[cleanKey] || null;
    },

    parseBuffer: function(buf) {
      if (!buf || buf.byteLength < 16) return { audios: [], subs: [] };
      var view = new DataView(buf);
      var result = null;
      // Check MKV EBML signature: 0x1A 0x45 0xDF 0xA3
      if (view.getUint8(0) === 0x1A && view.getUint8(1) === 0x45 && view.getUint8(2) === 0xDF && view.getUint8(3) === 0xA3) {
        result = TVContainerProber.parseMkv(buf);
      } else {
        // Check MP4 signature
        for (var i = 0; i < Math.min(buf.byteLength - 4, 32); i++) {
          var tag = String.fromCharCode(view.getUint8(i), view.getUint8(i+1), view.getUint8(i+2), view.getUint8(i+3));
          if (tag === 'ftyp' || tag === 'moov') {
            result = TVContainerProber.parseMp4(buf);
            break;
          }
        }
      }
      if (!result) {
        result = TVContainerProber.parseMkv(buf);
      }
      if (result && result.audios) {
        result.audios.forEach(function(a, idx) {
          console.log('[AudioState:A-Discovered] Container demuxed audio track #' + idx + ' (codec=' + (a.codec || 'unknown') + ', lang=' + (a.language || a.lang || 'und') + ', title="' + (a.title || a.name || '') + '")');
        });
      }
      return result;
    },

    parseMkv: function(buf) {
      var view = new DataView(buf);
      var len = buf.byteLength;

      function readVint(offset) {
        if (offset >= len) return null;
        var first = view.getUint8(offset);
        var mask = 0x80;
        var length = 1;
        while (mask > 0 && !(first & mask)) {
          mask >>= 1;
          length++;
        }
        if (length > 8 || offset + length > len) return null;
        var value = first & (mask - 1);
        for (var i = 1; i < length; i++) {
          value = (value * 256) + view.getUint8(offset + i);
        }
        return { length: length, value: value };
      }

      function readId(offset) {
        if (offset >= len) return null;
        var first = view.getUint8(offset);
        var mask = 0x80;
        var length = 1;
        while (mask > 0 && !(first & mask)) {
          mask >>= 1;
          length++;
        }
        if (length > 4 || offset + length > len) return null;
        var id = 0;
        for (var i = 0; i < length; i++) {
          id = (id * 256) + view.getUint8(offset + i);
        }
        return { length: length, id: id >>> 0 };
      }

      function readString(offset, strLen) {
        var s = '';
        var end = Math.min(len, offset + strLen);
        for (var i = offset; i < end; i++) s += String.fromCharCode(view.getUint8(i));
        return s;
      }

      function readUtf8(offset, strLen) {
        try {
          var sub = new Uint8Array(buf, offset, Math.min(len - offset, strLen));
          if (typeof TextDecoder !== 'undefined') {
            return new TextDecoder('utf-8').decode(sub);
          }
        } catch(e){}
        return readString(offset, strLen);
      }

      function readUint(offset, sz) {
        if (!sz || sz <= 0) return 0;
        var v = 0;
        var end = Math.min(len, offset + sz);
        for (var u = offset; u < end; u++) {
          v = (v * 256) + view.getUint8(u);
        }
        return v;
      }

      var tracksPos = -1;
      var tracksSize = -1;
      for (var i = 0; i < len - 16; i++) {
        if (view.getUint8(i) === 0x16 && view.getUint8(i+1) === 0x54 && view.getUint8(i+2) === 0xAE && view.getUint8(i+3) === 0x6B) {
          // Reject if inside SeekHead SeekID (preceded by 0x53 0xAB)
          if (i >= 3 && view.getUint8(i - 3) === 0x53 && view.getUint8(i - 2) === 0xAB) {
            continue;
          }
          var sv = readVint(i + 4);
          if (!sv || sv.value <= 0) continue;
          var start = i + 4 + sv.length;
          if (start >= len) continue;
          var firstByte = view.getUint8(start);
          var isValid = false;
          if (firstByte === 0xAE) {
            isValid = true;
          } else if (firstByte === 0xBF) { // CRC-32 element
            var crcSz = readVint(start + 1);
            if (crcSz && start + 1 + crcSz.length + crcSz.value < len && view.getUint8(start + 1 + crcSz.length + crcSz.value) === 0xAE) {
              isValid = true;
            }
          } else if (firstByte === 0xEC) { // Void element
            var voidSz = readVint(start + 1);
            if (voidSz && start + 1 + voidSz.length + voidSz.value < len && view.getUint8(start + 1 + voidSz.length + voidSz.value) === 0xAE) {
              isValid = true;
            }
          }
          if (isValid) {
            tracksPos = start;
            tracksSize = sv.value;
            break;
          }
        }
      }

      if (tracksPos === -1) return { audios: [], subs: [] };

      var tracksEnd = (tracksSize > 0) ? Math.min(len, tracksPos + tracksSize) : len;
      var curr = tracksPos;
      var audioList = [];
      var subList = [];

      while (curr < tracksEnd - 2) {
        var elId = readId(curr);
        if (!elId) break;
        var elSize = readVint(curr + elId.length);
        if (!elSize) break;
        var dataStart = curr + elId.length + elSize.length;
        var nextEl = dataStart + elSize.value;
        if (nextEl <= curr) break;

        if (elId.id === 0xBF || elId.id === 0xEC) {
          curr = nextEl;
          continue;
        }
        if (elId.id !== 0xAE) break; // TrackEntry only
          var tPos = dataStart;
          var tEnd = Math.min(len, nextEl);
          var trackType = null;
          var trackNum = null;
          var lang = '';
          var title = '';
          var codec = '';
          var channels = '';
          var isForcedFlag = false;

          while (tPos < tEnd - 2) {
            var subId = readId(tPos);
            if (!subId) break;
            var subSize = readVint(tPos + subId.length);
            if (!subSize) break;
            var subData = tPos + subId.length + subSize.length;
            var nextSub = subData + subSize.value;
            if (nextSub <= tPos) break;

            if (subId.id === 0x83) { // TrackType
              trackType = readUint(subData, subSize.value);
            } else if (subId.id === 0xD7) { // TrackNumber
              trackNum = readUint(subData, subSize.value);
            } else if (subId.id === 0x22B59C || subId.id === 0x22B59D) { // Language / LanguageIETF
              var lStr = readString(subData, subSize.value).replace(/\0/g, '').trim();
              if (lStr && (!lang || lStr.length > lang.length)) lang = lStr;
            } else if (subId.id === 0x536E) { // Name / Title
              title = readUtf8(subData, subSize.value).replace(/\0/g, '').trim();
            } else if (subId.id === 0x55AA) { // FlagForced
              isForcedFlag = (readUint(subData, subSize.value) === 1);
            } else if (subId.id === 0x86) { // CodecID
              codec = readString(subData, subSize.value).replace(/\0/g, '').trim();
            } else if (subId.id === 0xE1) { // Audio settings
              var aPos = subData;
              var aEnd = Math.min(len, nextSub);
              while (aPos < aEnd - 2) {
                var aId = readId(aPos);
                if (!aId) break;
                var aSz = readVint(aPos + aId.length);
                if (!aSz) break;
                if (aId.id === 0x9F) { // Channels
                  channels = readUint(aPos + aId.length + aSz.length, aSz.value);
                }
                var nextA = aPos + aId.length + aSz.length + aSz.value;
                if (nextA <= aPos) break;
                aPos = nextA;
              }
            }

            tPos = nextSub;
          }

          var cLang = (lang && lang.toLowerCase() !== 'und' && lang.toLowerCase() !== 'unk') ? lang : '';
          var cTitle = (title && title.toLowerCase() !== 'und' && title.toLowerCase() !== 'unk') ? title : (isForcedFlag ? 'Forced' : '');
          var displayLabel = cTitle || cLang || ((trackType === 2 ? 'Audio ' : 'Subtitle ') + ((trackType === 2 ? audioList.length : subList.length) + 1));

          if (trackType === 2) {
            audioList.push({
              index: audioList.length,
              streamIndex: trackNum || audioList.length,
              id: String(trackNum || audioList.length),
              language: lang,
              lang: lang,
              title: displayLabel,
              name: displayLabel,
              codec: codec.replace(/^A_/, '').toLowerCase(),
              channels: String(channels || '')
            });
          } else if (trackType === 17) {
            subList.push({
              index: subList.length,
              streamIndex: trackNum || subList.length,
              id: String(trackNum || subList.length),
              language: lang,
              lang: lang,
              title: displayLabel,
              name: displayLabel,
              codec: codec.replace(/^S_TEXT\//, '').replace(/^S_/, '').toLowerCase()
            });
          }
        curr = nextEl;
      }

      return { audios: audioList, subs: subList };
    },

    parseMp4: function(buf) {
      var view = new DataView(buf);
      var len = buf.byteLength;
      var audioList = [];
      var subList = [];

      function parseBox(offset, end) {
        var boxes = [];
        var p = offset;
        while (p + 8 <= end) {
          var size = view.getUint32(p);
          var type = '';
          for (var i = 0; i < 4; i++) type += String.fromCharCode(view.getUint8(p + 4 + i));
          if (size === 1) {
            if (p + 16 > end) break;
            size = view.getUint32(p + 12);
            boxes.push({ type: type, start: p + 16, end: Math.min(end, p + size) });
            p += size;
          } else if (size === 0) {
            boxes.push({ type: type, start: p + 8, end: end });
            break;
          } else {
            boxes.push({ type: type, start: p + 8, end: Math.min(end, p + size) });
            p += size;
          }
          if (size < 8) break;
        }
        return boxes;
      }

      function decodeIsoLang(val) {
        if (!val || val === 0x55C4) return '';
        var c1 = String.fromCharCode(((val >> 10) & 0x1F) + 0x60);
        var c2 = String.fromCharCode(((val >> 5) & 0x1F) + 0x60);
        var c3 = String.fromCharCode((val & 0x1F) + 0x60);
        var code = c1 + c2 + c3;
        return (code === 'und') ? '' : code;
      }

      var topBoxes = parseBox(0, len);
      var moov = topBoxes.find(function(b) { return b.type === 'moov'; });
      if (!moov) return { audios: [], subs: [] };

      var moovBoxes = parseBox(moov.start, moov.end);
      var mvhd = moovBoxes.find(function(b) { return b.type === 'mvhd'; });
      var containerDuration = 0;
      if (mvhd && mvhd.start + 16 <= mvhd.end) {
        var v = view.getUint8(mvhd.start);
        var timescaleOffset = (v === 1) ? (mvhd.start + 20) : (mvhd.start + 12);
        var durationOffset = (v === 1) ? (mvhd.start + 24) : (mvhd.start + 16);
        if (durationOffset + (v === 1 ? 8 : 4) <= mvhd.end) {
          var timescale = view.getUint32(timescaleOffset);
          var durationVal = (v === 1)
            ? (view.getUint32(durationOffset) * 0x100000000 + view.getUint32(durationOffset + 4))
            : view.getUint32(durationOffset);
          if (timescale > 0 && durationVal > 0) {
            containerDuration = Math.floor(durationVal / timescale);
          }
        }
      }
      var traks = moovBoxes.filter(function(b) { return b.type === 'trak'; });

      traks.forEach(function(trak, tIdx) {
        var trakBoxes = parseBox(trak.start, trak.end);
        var mdia = trakBoxes.find(function(b) { return b.type === 'mdia'; });
        if (!mdia) return;

        var mdiaBoxes = parseBox(mdia.start, mdia.end);
        var hdlr = mdiaBoxes.find(function(b) { return b.type === 'hdlr'; });
        var mdhd = mdiaBoxes.find(function(b) { return b.type === 'mdhd'; });

        var handlerType = '';
        if (hdlr && hdlr.start + 12 <= hdlr.end) {
          for (var h = 0; h < 4; h++) handlerType += String.fromCharCode(view.getUint8(hdlr.start + 8 + h));
        }

        var lang = '';
        if (mdhd && mdhd.start + 4 <= mdhd.end) {
          var version = view.getUint8(mdhd.start);
          var langOffset = (version === 1) ? (mdhd.start + 28) : (mdhd.start + 16);
          if (langOffset + 2 <= mdhd.end) {
            var packedLang = view.getUint16(langOffset);
            lang = decodeIsoLang(packedLang);
          }
        }

        var title = '';
        var udta = trakBoxes.find(function(b) { return b.type === 'udta'; });
        if (udta) {
          var udtaBoxes = parseBox(udta.start, udta.end);
          var nameBox = udtaBoxes.find(function(b) { return b.type === 'name'; });
          if (nameBox) {
            for (var n = nameBox.start; n < nameBox.end; n++) {
              var ch = view.getUint8(n);
              if (ch > 0) title += String.fromCharCode(ch);
            }
          }
        }

        var cLang = (lang && lang.toLowerCase() !== 'und' && lang.toLowerCase() !== 'unk') ? lang : '';
        var cTitle = (title && title.toLowerCase() !== 'und' && title.toLowerCase() !== 'unk') ? title : '';
        var displayLabel = cTitle || cLang || ((handlerType === 'soun' ? 'Audio ' : 'Subtitle ') + ((handlerType === 'soun' ? audioList.length : subList.length) + 1));

        if (handlerType === 'soun') {
          audioList.push({
            index: audioList.length,
            streamIndex: tIdx + 1,
            id: String(tIdx + 1),
            language: lang,
            lang: lang,
            title: displayLabel,
            name: displayLabel,
            codec: 'aac',
            channels: ''
          });
        } else if (handlerType === 'subt' || handlerType === 'text' || handlerType === 'sbtl') {
          subList.push({
            index: subList.length,
            streamIndex: tIdx + 1,
            id: String(tIdx + 1),
            language: lang,
            lang: lang,
            title: displayLabel,
            name: displayLabel,
            codec: 'text'
          });
        }
      });

      return { audios: audioList, subs: subList, duration: containerDuration };
    }
  };
  window.TVContainerProber = TVContainerProber;

  function TVPlayer(options) {
    this.containerEl = options.containerElement;
    this.videoEl = options.videoElement;
    this.liveOsdEl = options.liveOsdElement;
    this.vodHudEl = options.vodHudElement;
    
    this.hls = null;
    this.currentMode = 'preview'; // 'preview' | 'fullscreen'
    this.playbackType = 'live';   // 'live' | 'vod' | 'series'
    this.currentStream = null;
    this.currentChannelList = [];
    this.currentChannelIndex = -1;
    this.osdTimer = null;
    this.onNextEpisode = null;
    this._tracksLoading = false;

    this._initEvents();
  }

  TVPlayer.prototype._initEvents = function() {
    var self = this;

    var logMediaState = function(evtName) {
      if (!self.videoEl) return;
      var err = self.videoEl.error ? (' code=' + self.videoEl.error.code + ' ' + (self.videoEl.error.message || '')) : '';
      var size = (self.videoEl.videoWidth ? (' ' + self.videoEl.videoWidth + 'x' + self.videoEl.videoHeight) : '');
      console.log('[TVPlayer:State] ' + evtName + ': time=' + Math.round(self.videoEl.currentTime || 0) + 's, ready=' + self.videoEl.readyState + ', net=' + self.videoEl.networkState + ', paused=' + self.videoEl.paused + ', muted=' + self.videoEl.muted + size + err);
    };

    this.videoEl.addEventListener('error', function(e) {
      logMediaState('error');
      console.warn('[TVPlayer] videoEl playback error:', e);
    });

    this.videoEl.addEventListener('timeupdate', function() {
      self._updateSubtitles();
      if (!self._audibleLogged && self.videoEl && self.videoEl.currentTime > 0.5) {
        self._audibleLogged = true;
        var bytes = (typeof self.videoEl.webkitAudioDecodedByteCount === 'number') ? self.videoEl.webkitAudioDecodedByteCount : 'N/A';
        console.log('[AudioState:F-Audible] Audio playback verified: vol=' + Math.round((self.videoEl.volume || 1) * 100) + '%, muted=' + self.videoEl.muted + ', webkitAudioDecodedBytes=' + bytes);
      }
      if (self.playbackType === 'vod' || self.playbackType === 'series') {
        self._updateVodProgress();
        var curPos = Math.floor(self.videoEl.currentTime || 0);
        if (curPos >= 2) {
          if (!self._hasInitialSave) {
            self._hasInitialSave = true;
            self._lastProgSave = Date.now();
            self._saveCurrentProgress(false);
          } else if (!self._lastProgSave || Date.now() - self._lastProgSave > 3500) {
            self._lastProgSave = Date.now();
            self._saveCurrentProgress(false);
          }
        }
      }

      // Sample FPS from native playback quality if supported
      if (!self._measuredFps && self.videoEl && typeof self.videoEl.getVideoPlaybackQuality === 'function') {
        try {
          var quality = self.videoEl.getVideoPlaybackQuality();
          var frames = quality ? quality.totalVideoFrames : 0;
          var now = Date.now();
          if (frames > 0) {
            if (!self._fpsSampleStart) {
              self._fpsSampleStart = now;
              self._fpsSampleFrames = frames;
            } else if (now - self._fpsSampleStart >= 1200) {
              var dt = (now - self._fpsSampleStart) / 1000;
              var df = frames - self._fpsSampleFrames;
              if (df > 5 && dt > 0) {
                self._measuredFps = df / dt;
                if (self.playbackType === 'live') {
                  self.updateQualityBadges('infobar-quality-badges');
                } else {
                  self.updateQualityBadges('vod-quality-badges');
                }
              }
            }
          }
        } catch (_) {}
      }
    });

    var unmuteBtn = document.getElementById('player-unmute-btn');
    if (unmuteBtn) {
      unmuteBtn.onclick = function(e) {
        e.stopPropagation();
        self.unmute();
      };
    }

    var handleGlobalUnmute = function() {
      if (self._isResuming) return; // Strict mute protection while resume seek is in progress
      if (self.videoEl && self.videoEl.muted && !self.videoEl.paused) {
        self.unmute();
      }
    };
    window.addEventListener('keydown', handleGlobalUnmute, { capture: true, passive: true });
    window.addEventListener('click', handleGlobalUnmute, { capture: true, passive: true });

    this.videoEl.addEventListener('loadedmetadata', function() {
      logMediaState('loadedmetadata');
      self._setupTrackListeners();
      if (self.playbackType === 'vod' || self.playbackType === 'series') {
        self._updateVodDuration();
        if (self._resumeTime > 0) {
          try {
            var target = self._resumeTime;
            if (!self.videoEl.duration || target < self.videoEl.duration) {
              console.log('[TVPlayer] Performing resume seek in loadedmetadata to:', target);
              self.videoEl.currentTime = target;
            }
          } catch(e){
            console.warn('[TVPlayer] loadedmetadata resume seek error:', e);
          }
        }
      }
      self._applyPreferences();
      self._checkAspectAdjustment();
      self._tracksLoading = false;
      if (self.playbackType === 'live') {
        self.updateQualityBadges('infobar-quality-badges');
      } else {
        self.updateQualityBadges('vod-quality-badges');
      }
      if (window.onTracksUpdated) window.onTracksUpdated();
    });

    this.videoEl.addEventListener('durationchange', function() {
      if (self.playbackType === 'vod' || self.playbackType === 'series') {
        self._updateVodDuration();
      }
    });

    this._setupTrackListeners = function() {
      if (!self.videoEl) return;
      if (self.videoEl.audioTracks && self.videoEl.audioTracks.length > 0) {
        for (var b = 0; b < self.videoEl.audioTracks.length; b++) {
          var atb = self.videoEl.audioTracks[b];
          console.log('[AudioState:B-Recognized] HTML5 video.audioTracks[' + b + ']: id=' + atb.id + ', label="' + atb.label + '", lang=' + atb.language + ', enabled=' + atb.enabled);
        }
      }
      var notify = function() {
        self._tracksLoading = false;
        self._applyPreferences();
        if (window.onTracksUpdated) window.onTracksUpdated();
      };

      if (self.videoEl.audioTracks) {
        try {
          self.videoEl.audioTracks.onaddtrack = notify;
          self.videoEl.audioTracks.onremovetrack = notify;
          self.videoEl.audioTracks.onchange = notify;
          if (self.videoEl.audioTracks.addEventListener) {
            self.videoEl.audioTracks.addEventListener('addtrack', notify);
            self.videoEl.audioTracks.addEventListener('removetrack', notify);
            self.videoEl.audioTracks.addEventListener('change', notify);
          }
        } catch(e){}
      }
      if (self.videoEl.textTracks) {
        try {
          self.videoEl.textTracks.onaddtrack = notify;
          self.videoEl.textTracks.onremovetrack = notify;
          self.videoEl.textTracks.onchange = notify;
          if (self.videoEl.textTracks.addEventListener) {
            self.videoEl.textTracks.addEventListener('addtrack', notify);
            self.videoEl.textTracks.addEventListener('removetrack', notify);
            self.videoEl.textTracks.addEventListener('change', notify);
          }
        } catch(e){}
      }
    };
    this._setupTrackListeners();

    this.videoEl.addEventListener('ended', function() {
      logMediaState('ended');
      if (self.containerEl) self.containerEl.classList.remove('video-playing');
      var liveBadge = document.getElementById('preview-live-badge');
      if (liveBadge) liveBadge.style.display = 'none';
      self._saveCurrentProgress(true);
      if (self.playbackType === 'series' && typeof self.onNextEpisode === 'function') {
        self.onNextEpisode();
      }
    });

    this.videoEl.addEventListener('click', function(e) {
      if (self.currentMode === 'fullscreen') {
        self.togglePlayPause();
      }
    });

    this.videoEl.addEventListener('loadstart', function() {
      logMediaState('loadstart');
      if (self.containerEl) self.containerEl.classList.remove('video-playing');
      var liveBadge = document.getElementById('preview-live-badge');
      if (liveBadge) liveBadge.style.display = 'none';
      if (self.currentStream) self._setBuffering(true);
    });

    this.videoEl.addEventListener('waiting', function() {
      logMediaState('waiting');
      if (self.containerEl) self.containerEl.classList.remove('video-playing');
      var liveBadge = document.getElementById('preview-live-badge');
      if (liveBadge) liveBadge.style.display = 'none';
      if (self.currentStream) self._setBuffering(true);
    });

    this.videoEl.addEventListener('stalled', function() {
      logMediaState('stalled');
    });

    this.videoEl.addEventListener('playing', function() {
      logMediaState('playing');
      if (self.containerEl) self.containerEl.classList.add('video-playing');
      var liveBadge = document.getElementById('preview-live-badge');
      if (liveBadge) liveBadge.style.display = 'inline-block';
      self._setBuffering(false);
      self._clearWatchdog();
      self._updatePreviewPlayBtn(true);
      self._checkAspectAdjustment();
      self._setupTrackListeners();
      self._tracksLoading = false;
      if (window.onTracksUpdated) window.onTracksUpdated();

      // Check if stream relies on Dolby AC-3/E-AC-3 in an environment lacking AC-3 licensing (e.g. desktop webOS simulator)
      if (self.currentVodMeta && self.currentVodMeta.audioTracks) {
        var hasDolby = self.currentVodMeta.audioTracks.some(function(t) {
          var c = (t.codec || '').toLowerCase();
          return c === 'ac3' || c === 'eac3' || c === 'dts';
        });
        if (hasDolby && !window._warnedDolby && self.videoEl) {
          var canAc3 = !!(self.videoEl.canPlayType('audio/mp4; codecs="ac-3"') || self.videoEl.canPlayType('video/x-matroska; codecs="ac-3"') || (window.webapis && window.webapis.avplay));
          if (!canAc3) {
            window._warnedDolby = true;
            console.warn('[TVPlayer] Stream uses Dolby AC-3/E-AC-3 audio. Host environment lacks AC-3 codec licensing (supported natively on real Samsung & LG TVs, and Microsoft Edge).');
            if (typeof showToast === 'function') {
              var isDe = window.TVI18n && window.TVI18n.getLanguage() === 'de';
              showToast(isDe ? 'Hinweis: Dolby AC-3 Audio wird auf echten Smart TVs & Edge nativ decodiert (im Simulator stumm)' : 'Note: Dolby AC-3 Audio is decoded natively on real Smart TVs & Edge (silent in simulator)', '🔊', 5000);
            }
          }
        }
      }
    });

    this.videoEl.addEventListener('pause', function() {
      logMediaState('pause');
      if (self.containerEl) self.containerEl.classList.remove('video-playing');
      var liveBadge = document.getElementById('preview-live-badge');
      if (liveBadge) liveBadge.style.display = 'none';
      self._updatePreviewPlayBtn(false);
      self._saveCurrentProgress(false);
    });

    this.videoEl.addEventListener('canplay', function() {
      logMediaState('canplay');
      self._setBuffering(false);
      self._clearWatchdog();
      self._setupTrackListeners();
      self._tracksLoading = false;
      if (window.onTracksUpdated) window.onTracksUpdated();
      if (self._resumeTime > 0 && Math.abs((self.videoEl.currentTime || 0) - self._resumeTime) > 2) {
        try {
          var target2 = self._resumeTime;
          if (!self.videoEl.duration || target2 < self.videoEl.duration) {
            self.videoEl.currentTime = target2;
          }
        } catch(e){}
      }
    });

    this.videoEl.addEventListener('timeupdate', function() {
      if (self.videoEl.currentTime > 0) {
        self._clearWatchdog();
        self._setBuffering(false);
      }
    });

    this.videoEl.addEventListener('seeked', function() {
      logMediaState('seeked');
      self._setBuffering(false);
      self._clearWatchdog();
      if (typeof self._clearSeekWatchdog === 'function') self._clearSeekWatchdog();
      self._saveCurrentProgress(false);

      if (self._isResuming) {
        self._isResuming = false;
        self._resumeTime = 0;
        if (!self._userMuted && self.videoEl) {
          self.videoEl.muted = false;
          if (typeof self.videoEl.volume === 'number' && self.videoEl.volume === 0) {
            self.videoEl.volume = 1.0;
          }
        }
      }

      // If a seek was requested while this seek was executing, perform it now
      if (self._queuedSeekTarget !== null && self._queuedSeekTarget !== undefined) {
        var queued = self._queuedSeekTarget;
        self._queuedSeekTarget = null;
        self._lastTargetSeekTime = queued;
        try {
          self._setBuffering(true);
          if (typeof self._startSeekWatchdog === 'function') self._startSeekWatchdog(queued);
          self.videoEl.currentTime = queued;
          return;
        } catch(qe) {
          console.warn('[TVPlayer] Queued seek execution error:', qe);
        }
      }

      self._lastTargetSeekTime = null;

      // Guarantee playback resumes after seek if stream was playing
      if (!self._userPaused && self.videoEl && self.videoEl.paused) {
        var sp = self.videoEl.play();
        if (sp && typeof sp.catch === 'function') {
          sp.catch(function(err) {
            console.warn('[TVPlayer] Play after seeked rejected:', err);
          });
        }
      }
    });

    this.videoEl.addEventListener('error', function(err) {
      if (!self.videoEl || !self.videoEl.src || self.videoEl.src === '' || self.videoEl.src === window.location.href) {
        return; // Ignore intentional cleanup / reset when player is stopped
      }
      logMediaState('error_handler');
      var code = self.videoEl && self.videoEl.error ? self.videoEl.error.code : 0;
      var msg = self.videoEl && self.videoEl.error ? (self.videoEl.error.message || '') : '';
      var diagError = 'UNKNOWN_MEDIA_ERROR';
      if (code === 1) diagError = 'MEDIA_ERR_ABORTED';
      else if (code === 2) diagError = 'NETWORK_ERROR';
      else if (code === 3) diagError = 'VIDEO_CODEC_UNSUPPORTED';
      else if (code === 4) diagError = 'MIME_TYPE_INVALID';

      console.warn('[TVPlayer:DiagnosticError] Category: ' + diagError + ' (code=' + code + ', ' + msg + ')');

      // 1. Transient abort event: browser canceled request for new seek/data. Never treat as fatal error!
      if (code === 1) {
        console.log('[TVPlayer] Transient abort event ignored');
        return;
      }

      // 2. Network drop during VOD playback or seek: seamlessly reconnect stream at current position
      var hasPlayed = (self.videoEl.currentTime > 1) || (self._didResumeSeek && self._resumeTime > 0) || (self._lastTargetSeekTime && self._lastTargetSeekTime > 0);
      if (code === 2 && hasPlayed && (self.playbackType === 'vod' || self.playbackType === 'series')) {
        console.warn('[TVPlayer] Network dropped during VOD seek/playback, reconnecting stream at:', self.videoEl.currentTime);
        var recTarget = (self._lastTargetSeekTime && self._lastTargetSeekTime > 0) ? self._lastTargetSeekTime : (self.videoEl.currentTime || 0);
        if (typeof self._recoverSeekStall === 'function') {
          self._recoverSeekStall(recTarget);
        }
        return;
      }

      if (self.playbackType === 'live' && !self._retriedWithHls && window.Hls && window.Hls.isSupported() && self.currentStream) {
        var activeAccount = window.TVStorage ? window.TVStorage.getActiveAccount() : null;
        if (activeAccount) {
          console.log('[TVPlayer] Native playback failed, attempting Hls.js fallback for channel');
          var hlsUrl = window.TVApi.getLiveStreamUrl(activeAccount, self.currentStream.stream_id || self.currentStream.id, true);
          self._playHls(hlsUrl);
          return;
        }
      }

      if (self.playbackType === 'live' && !self._retriedWithTs) {
        self._fallbackToNativeTs();
      } else if ((self.playbackType === 'vod' || self.playbackType === 'series') && !hasPlayed && !self._retriedAltExt && self.currentVodMeta) {
        self._fallbackAltExt();
      } else {
        self._setBuffering(false);
      }
    });
  };

  TVPlayer.prototype.unmute = function() {
    if (this._isResuming) return; // Strict mute protection while resume seek is executing
    if (this.videoEl) {
      this.videoEl.muted = false;
      if (typeof this.videoEl.volume === 'number' && this.videoEl.volume === 0) {
        this.videoEl.volume = 1.0;
      }
    }
    var banner = document.getElementById('player-unmute-banner');
    if (banner) banner.style.display = 'none';
  };

  function formatSubtitleHtml(raw) {
    if (!raw) return '';
    var s = String(raw).trim();
    // 1. Remove ASS override tags like {\i1}, {\an8}, {\pos(x,y)}, etc.
    s = s.replace(/\{[^}]*\}/g, '');
    // 2. Remove metadata/styling tags like <font...>, </font>, <color...>, <v...>, <c...>, <ruby>, <rt>
    s = s.replace(/<\/?(font|color|v|c|ruby|rt)[^>]*>/gi, '');
    // 3. Escape HTML special characters for strict security
    s = s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    // 4. Safely restore allowed typography formatting tags
    s = s.replace(/&lt;i&gt;/gi, '<i>')
         .replace(/&lt;\/i&gt;/gi, '</i>')
         .replace(/&lt;em&gt;/gi, '<em>')
         .replace(/&lt;\/em&gt;/gi, '</em>')
         .replace(/&lt;b&gt;/gi, '<b>')
         .replace(/&lt;\/b&gt;/gi, '</b>')
         .replace(/&lt;strong&gt;/gi, '<strong>')
         .replace(/&lt;\/strong&gt;/gi, '</strong>')
         .replace(/&lt;u&gt;/gi, '<u>')
         .replace(/&lt;\/u&gt;/gi, '</u>');
    // 5. Convert line breaks
    s = s.replace(/\r?\n/g, '<br>');
    return s;
  }

  TVPlayer.prototype.renderSubtitle = function(text) {
    if (this.playbackType === 'live') {
      if (!this._subOverlayEl) this._subOverlayEl = document.getElementById('player-subtitle-overlay');
      if (this._subOverlayEl) this._subOverlayEl.style.display = 'none';
      if (this._subTextEl) this._subTextEl.textContent = '';
      return;
    }
    var str = (text && String(text).trim()) || '';
    if (this._lastRenderedSubtitleText === str) return;
    this._lastRenderedSubtitleText = str;

    if (!this._subOverlayEl) this._subOverlayEl = document.getElementById('player-subtitle-overlay');
    if (!this._subTextEl) this._subTextEl = document.getElementById('player-subtitle-text');
    if (!this._subOverlayEl || !this._subTextEl) return;

    if (!str) {
      this._subOverlayEl.style.display = 'none';
      this._subTextEl.textContent = '';
    } else {
      this._subTextEl.innerHTML = formatSubtitleHtml(str);
      this._subOverlayEl.style.display = 'flex';
    }
  };

  TVPlayer.prototype.addCustomSubtitleTrack = function(trackItem) {
    if (!trackItem) return;
    this._customSubtitles = this._customSubtitles || [];
    var existingIdx = -1;
    for (var i = 0; i < this._customSubtitles.length; i++) {
      if (this._customSubtitles[i].id === trackItem.id) {
        existingIdx = i;
        break;
      }
    }
    if (existingIdx !== -1) {
      this._customSubtitles[existingIdx] = trackItem;
    } else {
      trackItem.index = this._customSubtitles.length;
      this._customSubtitles.push(trackItem);
    }
    this._activeSubtitleCues = trackItem.cues || [];
    this._selectedSubTrackIndex = 'custom_' + (existingIdx !== -1 ? existingIdx : (this._customSubtitles.length - 1));
    console.log('[TVPlayer] Custom subtitle track added and activated:', trackItem.name, 'with', (trackItem.cues ? trackItem.cues.length : 0), 'cues');
    if (window.onTracksUpdated) window.onTracksUpdated();
    this._updateSubtitles();
  };

  TVPlayer.prototype._updateSubtitles = function() {
    if (this._selectedSubTrackIndex === -1 || this._selectedSubTrackIndex === undefined) {
      this.renderSubtitle(null);
      return;
    }
    // Check if HUD is visible to push subtitles upward
    if (this.containerEl) {
      var hudVis = this.vodHudEl && this.vodHudEl.classList.contains('visible');
      if (hudVis !== this._lastHudVisibleState) {
        this._lastHudVisibleState = hudVis;
        if (hudVis) {
          this.containerEl.classList.add('has-hud-visible');
        } else {
          this.containerEl.classList.remove('has-hud-visible');
        }
      }
    }

    // 1. Check custom in-memory WebVTT / SRT cues (High performance, binary search)
    if (this._activeSubtitleCues && this._activeSubtitleCues.length > 0 && this.videoEl) {
      var curTime = this.videoEl.currentTime || 0;
      var matchedCue = window.TVSubtitles && window.TVSubtitles.findCueAtTime
        ? window.TVSubtitles.findCueAtTime(this._activeSubtitleCues, curTime)
        : null;

      if (!matchedCue) {
        for (var k = 0; k < this._activeSubtitleCues.length; k++) {
          var cue = this._activeSubtitleCues[k];
          if (curTime >= cue.start && curTime <= cue.end) {
            matchedCue = cue;
            break;
          }
        }
      }

      if (matchedCue && matchedCue.text) {
        this.renderSubtitle(matchedCue.text);
        return;
      }
    }

    // 2. Check HTMLMediaElement textTracks or HLS cues
    if (this.videoEl && this.videoEl.textTracks && this.videoEl.textTracks.length > 0) {
      for (var i = 0; i < this.videoEl.textTracks.length; i++) {
        var tt = this.videoEl.textTracks[i];
        if ((tt.mode === 'showing' || tt.mode === 'hidden') && tt.activeCues && tt.activeCues.length > 0) {
          var cueText = '';
          for (var c = 0; c < tt.activeCues.length; c++) {
            var raw = tt.activeCues[c].text || '';
            if (raw) cueText += (cueText ? '\n' : '') + raw;
          }
          if (cueText) {
            this.renderSubtitle(cueText);
            return;
          }
        }
      }
    }
    this.renderSubtitle(null);
  };

  TVPlayer.prototype._saveCurrentProgress = function(forceCompleted) {
    if (this.playbackType !== 'vod' && this.playbackType !== 'series') return;
    if (!this.videoEl || !window.TVStorage || !this.currentVodMeta) return;
    var activeAccount = window.TVStorage.getActiveAccount();
    if (!activeAccount) return;

    var curPos = Math.floor(this.videoEl.currentTime || 0);
    var durFromEl = this.videoEl.duration;
    var validElDur = (durFromEl && !isNaN(durFromEl) && isFinite(durFromEl) && durFromEl > 100) ? Math.floor(durFromEl) : 0;
    // Reject bogus video.duration that is just reflecting currentTime
    if (validElDur > 0 && Math.abs(validElDur - curPos) < 2) {
      validElDur = 0;
    }
    var metaDur = parseDurationSecs(this.currentVodMeta.duration);
    var totalDur = (validElDur > 100) ? validElDur : metaDur;
    if (curPos < 2 && !forceCompleted) return;

    this.currentVodMeta.position = curPos;
    if (totalDur > 100) {
      this.currentVodMeta.duration = totalDur;
    }
    this.currentVodMeta.updatedAt = Date.now();
    this.currentVodMeta.isCompleted = forceCompleted || (totalDur > 100 && (curPos / totalDur) >= 0.95);
    window.TVStorage.saveProgress(activeAccount.id, this.currentVodMeta);
  };

  TVPlayer.prototype._checkAspectAdjustment = function() {
    if (!this.videoEl) return;
    var w = this.videoEl.videoWidth || 0;
    var h = this.videoEl.videoHeight || 0;

    // Only apply on Samsung Tizen where WebKit fails to un-squeeze anamorphic SD broadcasts
    var isTizen = !!(window.tizen || (navigator.userAgent && /Tizen/i.test(navigator.userAgent)));
    if (!isTizen) return;

    // PAL SD (720x576 or 704x576) and NTSC SD (720x480 or 704x480)
    // When broadcast in widescreen, Tizen incorrectly renders these as 5:4 or 4:3 instead of 16:9
    var isAnamorphicSd = (w > 0 && h > 0) && (
      (h === 576 && (w === 720 || w === 704 || w === 544)) ||
      (h === 480 && (w === 720 || w === 704))
    );

    if (isAnamorphicSd) {
      if (!this.videoEl.classList.contains('video-aspect-fill')) {
        console.log('[TVPlayer:Aspect] Anamorphic SD broadcast detected on Tizen (' + w + 'x' + h + '). Applying widescreen fill correction.');
        this.videoEl.classList.add('video-aspect-fill');
      }
    } else {
      if (this.videoEl.classList.contains('video-aspect-fill')) {
        this.videoEl.classList.remove('video-aspect-fill');
      }
    }
  };

  TVPlayer.prototype._setBuffering = function(isBuffering) {
    var spinner = document.getElementById('player-loading-spinner');
    if (spinner) {
      spinner.style.display = (isBuffering && this.currentStream) ? 'flex' : 'none';
    }
  };

  TVPlayer.prototype._startWatchdog = function() {
    this._clearWatchdog();
    var self = this;
    // Watchdog: Live streams should start playing within 4.5 seconds.
    // VOD streams can take up to 8 seconds for server seeking / large headers.
    var timeoutMs = (self.playbackType === 'live') ? 4500 : 8000;

    this._bufferWatchdog = setTimeout(function() {
      if (self.playbackType === 'live' && self.currentStream) {
        var activeAccount = window.TVStorage ? window.TVStorage.getActiveAccount() : null;
        if (!activeAccount) {
          self._setBuffering(false);
          return;
        }

        // Recovery Step 1: If we started with native HLS and it stalled without error, try Hls.js
        if (!self._retriedWithHls && window.Hls && window.Hls.isSupported()) {
          console.warn('[TVPlayer] Live stream buffering timeout (4.5s) on native engine. Retrying with Hls.js fallback...');
          var hlsUrl = window.TVApi.getLiveStreamUrl(activeAccount, self.currentStream.stream_id || self.currentStream.id, true);
          self._playHls(hlsUrl);
          return;
        }

        // Recovery Step 2: If HLS stalled or has already been tried, try raw MPEG-TS (.ts)
        if (!self._retriedWithTs) {
          console.warn('[TVPlayer] Live stream buffering timeout on HLS engine. Retrying with direct MPEG-TS (.ts) fallback...');
          self._fallbackToNativeTs();
          return;
        }

        // Recovery Step 3: All fallbacks exhausted -> stop spinner and notify user
        console.warn('[TVPlayer] All live stream recovery strategies timed out (channel offline or server timeout)');
        self._setBuffering(false);
        if (typeof showToast === 'function') {
          var isDe = window.TVI18n && window.TVI18n.getLanguage() === 'de';
          showToast(isDe ? 'Sender antwortet nicht (Server-Timeout)' : 'Channel not responding (Server timeout)', '⚠️', 4000);
        }
      } else if ((self.playbackType === 'vod' || self.playbackType === 'series') && self.currentStream) {
        console.warn('[TVPlayer] VOD buffering timeout');
        if (!self._retriedAltExt && self.currentVodMeta) {
          self._fallbackAltExt();
        } else {
          self._setBuffering(false);
        }
      }
    }, timeoutMs);
  };

  TVPlayer.prototype._clearWatchdog = function() {
    if (this._bufferWatchdog) {
      clearTimeout(this._bufferWatchdog);
      this._bufferWatchdog = null;
    }
  };

  TVPlayer.prototype._fallbackToNativeTs = function() {
    if (this._retriedWithTs || this.playbackType !== 'live' || !this.currentStream) return;
    this._retriedWithTs = true;
    this._clearWatchdog();

    console.log('[TVPlayer] Codec/Audio fallback: switching to direct MPEG-TS (.ts) stream for:', this.currentStream.name);
    if (this.hls) {
      try { this.hls.destroy(); } catch(e){}
      this.hls = null;
    }
    var activeAccount = window.TVStorage ? window.TVStorage.getActiveAccount() : null;
    if (activeAccount) {
      var tsUrl = window.TVApi.getLiveStreamUrl(activeAccount, this.currentStream.stream_id || this.currentStream.id, false);
      try {
        this.videoEl.pause();
        while (this.videoEl.firstChild) {
          this.videoEl.removeChild(this.videoEl.firstChild);
        }
        this.videoEl.removeAttribute('src');
        this.videoEl.src = tsUrl;
        this.videoEl.load();
        this._startWatchdog();
        var playPromise = this.videoEl.play();
        if (playPromise && typeof playPromise.catch === 'function') {
          var self = this;
          playPromise.catch(function(err) {
            console.warn('[TVPlayer] Direct TS fallback play error:', err);
            if (err && err.name === 'NotAllowedError') {
              self.videoEl.muted = true;
              self.videoEl.play().catch(function(){});
            }
          });
        }
      } catch(e) {
        console.warn('[TVPlayer] Error loading TS fallback:', e);
      }
    }
  };

  TVPlayer.prototype._fallbackAltExt = function() {
    if (this._retriedAltExt || !this.currentVodMeta) return;
    this._retriedAltExt = true;
    this._clearWatchdog();
    var activeAccount = window.TVStorage ? window.TVStorage.getActiveAccount() : null;
    if (!activeAccount || !this.currentStream) return;

    var curExt = (this.currentVodMeta.containerExtension || 'mp4').toLowerCase();
    // CRITICAL: If provider file is native MKV, do not fallback to MP4 (returns HTTP 551 on Xtream Codes)
    if (curExt === 'mkv') {
      console.log('[TVPlayer] Stream is native MKV; alternate extension fallback skipped to avoid HTTP 551');
      return;
    }
    var newExt = (curExt === 'mp4') ? 'mkv' : 'mp4';
    this.currentVodMeta.containerExtension = newExt;
    console.log('[TVPlayer] Format fallback: retrying stream with extension:', newExt);

    var url = '';
    var sId = this.currentVodMeta.streamId || this.currentStream.id || this.currentStream.stream_id;
    if (this.playbackType === 'series') {
      url = window.TVApi.getSeriesStreamUrl(activeAccount, sId, newExt);
    } else {
      url = window.TVApi.getVodStreamUrl(activeAccount, sId, newExt);
    }
    this._playMedia(url);
    if (this.currentMode === 'fullscreen') {
      this.setMode('fullscreen');
    }
  };

  TVPlayer.prototype.setChannelList = function(list) {
    this.currentChannelList = list || [];
    if (this.currentStream && this.currentChannelList.length > 0) {
      var self = this;
      var curId = String(self.currentStream.stream_id || self.currentStream.id);
      this.currentChannelIndex = this.currentChannelList.findIndex(function(c) {
        return String(c.stream_id || c.id) === curId;
      });
    }
  };

  // Play Live Stream
  TVPlayer.prototype.playLive = function(channel, categoryOrName, startFullscreen) {
    if (!channel) return;
    this.playbackType = 'live';
    this.currentStream = channel;
    this.currentVodMeta = null;

    if (categoryOrName && typeof categoryOrName === 'object') {
      this.currentCategory = categoryOrName;
      this.currentCategoryId = String(categoryOrName.category_id);
      this.currentCategoryName = categoryOrName.category_name || 'Live TV';
    } else if (typeof categoryOrName === 'string') {
      this.currentCategoryName = categoryOrName;
      if (categoryOrName.toLowerCase().indexOf('fav') !== -1) {
        this.currentCategoryId = 'favorites';
        this.currentCategory = { category_id: 'favorites', category_name: categoryOrName };
      } else if (channel && channel.category_id && window._liveCategories) {
        var found = window._liveCategories.find(function(c) { return String(c.category_id) === String(channel.category_id); });
        if (found) {
          this.currentCategory = found;
          this.currentCategoryId = String(found.category_id);
        } else {
          this.currentCategoryId = String(channel.category_id);
          this.currentCategory = { category_id: channel.category_id, category_name: categoryOrName };
        }
      } else if (window._selectedLiveCategory && String(window._selectedLiveCategory.category_id) !== 'favorites') {
        this.currentCategory = window._selectedLiveCategory;
        this.currentCategoryId = String(window._selectedLiveCategory.category_id);
      } else {
        this.currentCategoryId = '';
        this.currentCategory = { category_id: '', category_name: categoryOrName };
      }
    } else if (window._selectedLiveCategory) {
      this.currentCategory = window._selectedLiveCategory;
      this.currentCategoryId = String(window._selectedLiveCategory.category_id);
      this.currentCategoryName = window._selectedLiveCategory.category_name || 'Live TV';
    } else if (channel && channel.category_id && window._liveCategories) {
      var foundCat = window._liveCategories.find(function(c) { return String(c.category_id) === String(channel.category_id); });
      if (foundCat) {
        this.currentCategory = foundCat;
        this.currentCategoryId = String(foundCat.category_id);
        this.currentCategoryName = foundCat.category_name || 'Live TV';
      }
    }

    if (this.currentCategory) {
      window._selectedLiveCategory = this.currentCategory;
    }

    this._retriedWithTs = false;
    this._retriedWithHls = false;
    this._userPaused = false;
    this._activeSubtitleCues = null;
    this.renderSubtitle(null);
    if (this.videoEl && this.videoEl.textTracks) {
      for (var ti = 0; ti < this.videoEl.textTracks.length; ti++) {
        try { this.videoEl.textTracks[ti].mode = 'disabled'; } catch(e){}
      }
    }
    this._startWatchdog();
    var chId = String(channel.stream_id || channel.id);
    this.currentChannelIndex = this.currentChannelList.findIndex(function(c) {
      return String(c.stream_id || c.id) === chId;
    });

    var activeAccount = window.TVStorage.getActiveAccount();
    if (!activeAccount) return;

    if (this.containerEl) {
      this.containerEl.style.display = 'block';
      this.containerEl.classList.remove('video-playing');
    }
    var liveBadge = document.getElementById('preview-live-badge');
    if (liveBadge) liveBadge.style.display = 'none';
    var placeholder = document.getElementById('preview-placeholder-msg');
    if (placeholder) placeholder.style.display = 'none';

    var previewBox = document.getElementById('preview-player-box');
    if (previewBox) previewBox.classList.add('has-stream');

    var previewTitle = document.getElementById('preview-channel-name');
    if (previewTitle) {
      previewTitle.textContent = channel.name ? channel.name.replace(/^\[.*?\]\s*/, '') : 'Live Channel';
    }

    var url = (channel && channel.url) ? channel.url : window.TVApi.getLiveStreamUrl(activeAccount, channel.stream_id, true);
    this._playMedia(url);

    if (startFullscreen) {
      this.setMode('fullscreen');
      this.showInfobar(4000);
    } else {
      this.setMode('preview', false);
      this._updatePreviewPlayBtn(true);
    }
  };

  // Play VOD Movie or Series Episode
  TVPlayer.prototype.playVod = function(stream, type, title, subtitle, onNextEp, meta) {
    if (!stream) return;
    this.playbackType = type || 'vod'; // 'vod' or 'series'
    this.currentStream = stream;
    this.onNextEpisode = onNextEp;
    this._retriedAltExt = false;
    this._hasInitialSave = false;
    this._lastProgSave = null;
    this._userPaused = false;
    this._lastTargetSeekTime = null;
    this._queuedSeekTarget = null;

    // Explicitly guarantee unmuted audio with full volume for VOD playback only if NOT resuming
    var willResume = meta && typeof meta.startPosition === 'number' && meta.startPosition > 0;
    if (this.videoEl) {
      if (willResume) {
        this.videoEl.muted = true;
      } else {
        this.videoEl.muted = false;
        if (typeof this.videoEl.volume === 'number' && this.videoEl.volume === 0) {
          this.videoEl.volume = 1.0;
        }
      }
    }

    var activeAccount = window.TVStorage ? window.TVStorage.getActiveAccount() : null;
    if (!activeAccount) return;

    var rawDur = (meta && (meta.duration || meta.duration_secs)) ||
      (stream && (stream.duration_secs || stream.duration)) ||
      (stream && stream.info && (stream.info.duration_secs || stream.info.duration)) || 0;
    var knownDur = parseDurationSecs(rawDur);
    var initialPos = willResume ? meta.startPosition : 0;

    // Immediately reset & initialize HUD runtime and current time from metadata so there is zero flicker
    var curEl = document.getElementById('vod-time-current');
    var durEl = document.getElementById('vod-time-total');
    var barEl = document.getElementById('vod-progress-fill');
    if (curEl) curEl.textContent = this._formatTime(initialPos);
    if (durEl) durEl.textContent = (knownDur > 0) ? this._formatTime(knownDur) : '--:--';
    if (barEl) {
      var initialPct = (knownDur > 0) ? Math.min(100, Math.max(0, (initialPos / knownDur) * 100)) : 0;
      barEl.style.width = initialPct + '%';
    }

    var sId = (meta && meta.streamId) || stream.stream_id || stream.id;
    var ext = (meta && (meta.containerExtension || meta.container_extension)) || stream.container_extension || 'mp4';
    this.currentVodMeta = meta || {
      streamId: sId,
      seriesId: stream.series_id || null,
      type: (this.playbackType === 'series' ? 'series' : 'movie'),
      title: title || stream.name || 'Video',
      seriesName: (meta && meta.seriesName) || '',
      season: (meta && meta.season) || 1,
      episode: (meta && meta.episode) || 1,
      posterUrl: stream.stream_icon || stream.cover || (meta && meta.posterUrl) || '',
      isFinale: !!(meta && meta.isFinale),
      containerExtension: ext,
      duration: knownDur,
      audioTracks: (meta && meta.audioTracks) || [],
      subtitleTracks: (meta && meta.subtitleTracks) || []
    };
    if (this.currentVodMeta) {
      if (!this.currentVodMeta.containerExtension) {
        this.currentVodMeta.containerExtension = ext;
      }
      var metaDur = parseDurationSecs(this.currentVodMeta.duration);
      if (metaDur > 0) {
        this.currentVodMeta.duration = metaDur;
      } else if (knownDur > 0) {
        this.currentVodMeta.duration = knownDur;
      }
      if (!this.currentVodMeta.imdbId && (stream.imdb_id || stream.imdbId || (stream.info && (stream.info.imdb_id || stream.info.imdb)))) {
        this.currentVodMeta.imdbId = stream.imdb_id || stream.imdbId || (stream.info && (stream.info.imdb_id || stream.info.imdb));
      }
      if (!this.currentVodMeta.tmdbId && (stream.tmdb_id || stream.tmdbId || (stream.info && stream.info.tmdb_id))) {
        this.currentVodMeta.tmdbId = stream.tmdb_id || stream.tmdbId || (stream.info && stream.info.tmdb_id);
      }
      if (!this.currentVodMeta.kinopoisk_url && (stream.kinopoisk_url || (stream.info && stream.info.kinopoisk_url))) {
        this.currentVodMeta.kinopoisk_url = stream.kinopoisk_url || (stream.info && stream.info.kinopoisk_url);
      }
    }

    // Only seek when explicitly instructed via startPosition (e.g. user confirmed Resume dialog)
    this._resumeTime = 0;
    this._didResumeSeek = false;
    this._isResuming = false;
    this._queuedSeekTarget = null;
    if (willResume) {
      this._resumeTime = meta.startPosition;
      this._didResumeSeek = true;
      this._isResuming = true;
      this._renderScrubProgress(this._resumeTime, knownDur);
    }

    if (this.containerEl) this.containerEl.style.display = 'block';
    var placeholder = document.getElementById('preview-placeholder-msg');
    if (placeholder) placeholder.style.display = 'none';

    // Set fullscreen mode BEFORE loading media so containerEl is already docked in document.body
    this.setMode('fullscreen');

    var url = '';
    if (this.playbackType === 'series') {
      url = window.TVApi.getSeriesStreamUrl(activeAccount, sId, ext);
    } else {
      url = window.TVApi.getVodStreamUrl(activeAccount, sId, ext);
    }

    this._playMedia(url);

    // Asynchronously fetch full VOD or Series metadata in background if tracks aren't preloaded
    var self = this;
    var hasAudioMeta = this.currentVodMeta.audioTracks && this.currentVodMeta.audioTracks.length > 0;
    var hasSubMeta = this.currentVodMeta.subtitleTracks && this.currentVodMeta.subtitleTracks.length > 0;
    console.log('[TrackDebug] playVod: type=' + this.playbackType + ', sId=' + sId + ', hasAudioMeta=' + hasAudioMeta + ' (' + (this.currentVodMeta.audioTracks ? this.currentVodMeta.audioTracks.length : 0) + '), hasSubMeta=' + hasSubMeta + ' (' + (this.currentVodMeta.subtitleTracks ? this.currentVodMeta.subtitleTracks.length : 0) + ')');

    // If container tracks were already demuxed and cached, apply immediately without new socket fetches; otherwise probe in background
    if (url && window.TVContainerProber) {
      var cachedTracks = window.TVContainerProber.getCachedTracks(url);
      if (cachedTracks) {
        if (cachedTracks.duration > 100 && (!self.currentVodMeta.duration || self.currentVodMeta.duration <= 100)) {
          self.currentVodMeta.duration = cachedTracks.duration;
          self._updateVodDuration();
        }
        if (cachedTracks.audios && cachedTracks.audios.length > 0 && (!self.currentVodMeta.audioTracks || cachedTracks.audios.length > self.currentVodMeta.audioTracks.length)) {
          self.currentVodMeta.audioTracks = cachedTracks.audios;
        }
        if (cachedTracks.subs && cachedTracks.subs.length > 0 && (!self.currentVodMeta.subtitleTracks || cachedTracks.subs.length > self.currentVodMeta.subtitleTracks.length)) {
          self.currentVodMeta.subtitleTracks = cachedTracks.subs;
        }
        if (typeof self._applyPreferences === 'function') self._applyPreferences();
        if (window.onTracksUpdated) window.onTracksUpdated();
      } else {
        window.TVContainerProber.probeStream(url).then(function(demuxed) {
          if (!demuxed || !self.currentVodMeta || String(self.currentVodMeta.streamId) !== String(sId)) return;
          if (demuxed.duration > 100 && (!self.currentVodMeta.duration || self.currentVodMeta.duration <= 100)) {
            self.currentVodMeta.duration = demuxed.duration;
            self._updateVodDuration();
          }
          if (demuxed.audios && demuxed.audios.length > 0 && (!self.currentVodMeta.audioTracks || self.currentVodMeta.audioTracks.length === 0 || demuxed.audios.length > self.currentVodMeta.audioTracks.length)) {
            self.currentVodMeta.audioTracks = demuxed.audios;
            if (typeof self._applyPreferences === 'function') self._applyPreferences();
            if (window.onTracksUpdated) window.onTracksUpdated();
          }
          if (demuxed.subs && demuxed.subs.length > 0 && (!self.currentVodMeta.subtitleTracks || self.currentVodMeta.subtitleTracks.length === 0 || demuxed.subs.length > self.currentVodMeta.subtitleTracks.length)) {
            self.currentVodMeta.subtitleTracks = demuxed.subs;
            if (typeof self._applyPreferences === 'function') self._applyPreferences();
            if (window.onTracksUpdated) window.onTracksUpdated();
          }
        }).catch(function(){});
      }
    }

    if ((!hasAudioMeta || !hasSubMeta || !this.currentVodMeta.duration || this.currentVodMeta.duration <= 100) && activeAccount) {
      this._tracksLoading = true;
      if (this.playbackType === 'vod') {
        console.log('[TrackDebug] Background fetch: requesting getVodInfo for sId:', sId);
        window.TVApi.getVodInfo(activeAccount, sId).then(function(info) {
          console.log('[TrackDebug] Background getVodInfo response for sId ' + sId + ':', info);
          if (!info || !self.currentVodMeta || String(self.currentVodMeta.streamId) !== String(sId)) return;
          var aTracks = window.extractAudioTracksFromInfo ? window.extractAudioTracksFromInfo(info) : [];
          var sTracks = window.extractSubtitleTracksFromInfo ? window.extractSubtitleTracksFromInfo(info) : [];
          console.log('[TrackDebug] Background getVodInfo extracted: audio=' + aTracks.length + ', subs=' + sTracks.length);
          var infoDur = (window.extractDurationFromInfo && window.extractDurationFromInfo(info)) || parseDurationSecs((info.info && (info.info.duration_secs || info.info.duration || info.info.runtime)) || (info.movie_data && (info.movie_data.duration_secs || info.movie_data.duration || info.movie_data.runtime)));
          if (infoDur > 100 && (!self.currentVodMeta.duration || self.currentVodMeta.duration <= 100)) {
            self.currentVodMeta.duration = infoDur;
            self._updateVodDuration();
            if (self.videoEl && self.videoEl.currentTime >= 2) {
              self._saveCurrentProgress(false);
            }
          }
          if (aTracks.length > 0 && (!self.currentVodMeta.audioTracks || self.currentVodMeta.audioTracks.length === 0 || aTracks.length > self.currentVodMeta.audioTracks.length)) {
            self.currentVodMeta.audioTracks = aTracks;
          }
          if (sTracks.length > 0 && (!self.currentVodMeta.subtitleTracks || self.currentVodMeta.subtitleTracks.length === 0 || sTracks.length > self.currentVodMeta.subtitleTracks.length)) {
            self.currentVodMeta.subtitleTracks = sTracks;
          }
          var hasAudioNow = self.currentVodMeta.audioTracks && self.currentVodMeta.audioTracks.length > 0;
          var hasSubNow = self.currentVodMeta.subtitleTracks && self.currentVodMeta.subtitleTracks.length > 0;
          if (!hasAudioNow && !hasSubNow) {
            // Keep loading indicator active briefly while container prober resolves
            setTimeout(function() {
              self._tracksLoading = false;
              if (window.onTracksUpdated) window.onTracksUpdated();
            }, 3000);
          } else {
            self._tracksLoading = false;
            self._applyPreferences();
            if (window.onTracksUpdated) window.onTracksUpdated();
          }
        }).catch(function(e) {
          console.warn('[TrackDebug] Background getVodInfo error:', e);
          self._tracksLoading = false;
          if (window.onTracksUpdated) window.onTracksUpdated();
        });
      } else if (this.playbackType === 'series' && this.currentVodMeta.seriesId) {
        var serId = this.currentVodMeta.seriesId;
        console.log('[TrackDebug] Background fetch: requesting getSeriesInfo for serId:', serId);
        window.TVApi.getSeriesInfo(activeAccount, serId).then(function(sInfo) {
          console.log('[TrackDebug] Background getSeriesInfo response for serId ' + serId + ':', sInfo);
          if (!sInfo) {
            self._tracksLoading = false;
            return;
          }
          window._currentSeriesDetails = sInfo;
          if (sInfo.episodes && self.currentVodMeta) {
            var allEps = [];
            Object.keys(sInfo.episodes).forEach(function(sk) {
              allEps = allEps.concat(window.normalizeEpisodeList(sInfo.episodes[sk]));
            });
            var matchedEp = allEps.find(function(ep) {
              return String(ep.id || ep.stream_id) === String(sId);
            });
            if (matchedEp) {
              var epAudio = window.extractAudioTracksFromInfo ? window.extractAudioTracksFromInfo(matchedEp) : [];
              var epSubs = window.extractSubtitleTracksFromInfo ? window.extractSubtitleTracksFromInfo(matchedEp) : [];
              console.log('[TrackDebug] Background getSeriesInfo extracted for ep ' + sId + ': audio=' + epAudio.length + ', subs=' + epSubs.length);
              var epDur = (window.extractDurationFromInfo && window.extractDurationFromInfo(matchedEp)) || parseDurationSecs((matchedEp.info && (matchedEp.info.duration_secs || matchedEp.info.duration || matchedEp.info.runtime)) || (matchedEp.duration_secs || matchedEp.duration));
              if (epDur > 100 && (!self.currentVodMeta.duration || self.currentVodMeta.duration <= 100)) {
                self.currentVodMeta.duration = epDur;
                self._updateVodDuration();
                if (self.videoEl && self.videoEl.currentTime >= 2) {
                  self._saveCurrentProgress(false);
                }
              }
              if (epAudio.length > 0 && (!self.currentVodMeta.audioTracks || self.currentVodMeta.audioTracks.length === 0 || epAudio.length > self.currentVodMeta.audioTracks.length)) {
                self.currentVodMeta.audioTracks = epAudio;
              }
              if (epSubs.length > 0 && (!self.currentVodMeta.subtitleTracks || self.currentVodMeta.subtitleTracks.length === 0 || epSubs.length > self.currentVodMeta.subtitleTracks.length)) {
                self.currentVodMeta.subtitleTracks = epSubs;
              }
              self._applyPreferences();
              if (window.onTracksUpdated) window.onTracksUpdated();
            }
          }
          self._tracksLoading = false;
          if (window.onTracksUpdated) window.onTracksUpdated();
        }).catch(function(e) {
          console.warn('[TrackDebug] Background getSeriesInfo error:', e);
          self._tracksLoading = false;
          if (window.onTracksUpdated) window.onTracksUpdated();
        });
      }
    }

    // Set VOD HUD info
    var titleEl = document.getElementById('vod-hud-title');
    var subEl = document.getElementById('vod-hud-subtitle');
    var badgeEl = document.getElementById('vod-hud-badge');
    if (titleEl) titleEl.textContent = (this.playbackType === 'series' && meta && meta.seriesName) ? meta.seriesName : (title || stream.name || 'Video');
    if (subEl) subEl.textContent = subtitle || '';
    if (badgeEl) {
      if (this.playbackType === 'series' && meta && meta.season != null && meta.episode != null) {
        var sPadded = String(meta.season || 1).padStart(2, '0');
        var ePadded = String(meta.episode || 1).padStart(2, '0');
        badgeEl.textContent = 'S' + sPadded + ' E' + ePadded;
        badgeEl.style.display = 'inline-block';
      } else {
        badgeEl.style.display = 'none';
      }
    }

    // Set VOD Quality Badges
    this.updateQualityBadges('vod-quality-badges', (this.playbackType === 'series' && meta && meta.seriesName) ? meta.seriesName : (title || (stream ? stream.name : '')));

    // Show/hide series drawer button & next episode button + SVG icons
    var playBtn = document.getElementById('vod-play-btn');
    if (playBtn) {
      var pIcon = playBtn.querySelector('.btn-icon') || playBtn;
      pIcon.innerHTML = window.TVIcons ? window.TVIcons.pause : '⏸';
    }
    var seriesBtn = document.getElementById('vod-episodes-btn');
    if (seriesBtn) {
      seriesBtn.style.display = (this.playbackType === 'series') ? 'inline-flex' : 'none';
      var eIcon = seriesBtn.querySelector('.btn-icon');
      if (eIcon && window.TVIcons) eIcon.innerHTML = window.TVIcons.episodesList;
    }
    var nextEpBtn = document.getElementById('vod-next-ep-btn');
    if (nextEpBtn) {
      nextEpBtn.style.display = (this.playbackType === 'series') ? 'inline-flex' : 'none';
      var nIcon = nextEpBtn.querySelector('.btn-icon');
      if (nIcon && window.TVIcons) nIcon.innerHTML = window.TVIcons.nextEpisode;
    }
    var audioBtn = document.getElementById('vod-audio-btn');
    if (audioBtn) {
      var aIcon = audioBtn.querySelector('.btn-icon');
      if (aIcon && window.TVIcons) aIcon.innerHTML = window.TVIcons.audio;
    }
    var subBtn = document.getElementById('vod-sub-btn');
    if (subBtn) {
      var sIcon = subBtn.querySelector('.btn-icon');
      if (sIcon && window.TVIcons) sIcon.innerHTML = window.TVIcons.subtitles;
    }
  };

  TVPlayer.prototype._playMedia = function(url) {
    this.stop(true);
    this._setBuffering(true);
    this._tracksLoading = true;
    this._mediaRecoverCount = 0;
    this._networkRetryCount = 0;
    this._retriedWithHls = false;
    this._audibleLogged = false;
    this._fpsSampleStart = null;
    this._fpsSampleFrames = null;
    this._measuredFps = null;
    this._startWatchdog();
    var self = this;
    setTimeout(function() {
      self._tracksLoading = false;
    }, 4500);

    // Asynchronously collect comprehensive diagnostic stream probe in passive mode (protects IPTV concurrency limits)
    if (window.MediaDiagnostics && typeof window.MediaDiagnostics.probeStream === 'function') {
      window.MediaDiagnostics.probeStream(url, self.currentVodMeta || self.currentStream, { skipNetwork: true }).catch(function(){});
    }

    var isHls = url.indexOf('.m3u8') !== -1 || url.indexOf('/live/') !== -1 || (self.playbackType === 'live' && url.indexOf('.ts') === -1);
    var canNativeHls = !!(self.videoEl && (self.videoEl.canPlayType('application/vnd.apple.mpegurl') || self.videoEl.canPlayType('application/x-mpegURL')));
    var plat = (window.MediaDiagnostics && window.MediaDiagnostics.detectPlatform) ? window.MediaDiagnostics.detectPlatform() : {};
    var isTizen = plat.isTizen || /Tizen/i.test(navigator.userAgent || '') || (typeof window !== 'undefined' && !!window.tizen);

    // Smart TV Live HLS Pipeline Strategy:
    // 1. Samsung Tizen: HTML5 <video> native HLS has severe compatibility problems with AC3/EAC3 audio,
    //    timestamp discontinuities, and IPTV streams, resulting in infinite spinning.
    //    Hls.js using Media Source Extensions (MSE) handles these streams smoothly and feeds clean fMP4
    //    directly into Tizen's hardware video decoder.
    // 2. LG webOS: Real webOS TV uses the native GStreamer pipeline which handles HLS natively.
    // 3. Fallbacks: If native stalls or HLS fails, automatic fallback switches to raw MPEG-TS (.ts) or Hls.js within 4.5s.
    if (isHls) {
      if (isTizen && window.Hls && window.Hls.isSupported()) {
        console.log('[TVPlayer] Samsung Tizen detected: routing Live HLS stream to Hls.js MSE pipeline');
        self._playHls(url);
      } else if (canNativeHls && !isTizen) {
        console.log('[TVPlayer] Playing HLS stream via native Smart TV hardware pipeline (webOS)');
        self._playNative(url, 'application/vnd.apple.mpegurl');
      } else if (window.Hls && window.Hls.isSupported()) {
        console.log('[TVPlayer] Playing HLS stream via Hls.js MSE pipeline');
        self._playHls(url);
      } else {
        self._playNative(url, 'application/vnd.apple.mpegurl');
      }
    } else {
      self._playNative(url, null);
    }

    this.showHud();
  };

  TVPlayer.prototype._playNative = function(url, explicitMime) {
    var self = this;
    try {
      while (self.videoEl.firstChild) {
        self.videoEl.removeChild(self.videoEl.firstChild);
      }
    } catch(e){}

    self.videoEl.src = url;
    self._setupTrackListeners();
    if (self._isResuming || self._resumeTime > 0) {
      self.videoEl.muted = true;
    }
    self.videoEl.load();

    var playPromise = self.videoEl.play();
    if (playPromise && typeof playPromise.catch === 'function') {
      playPromise.catch(function(err) {
        console.warn('[TVPlayer] Native video play rejected:', err);
        if (err && err.name === 'NotAllowedError') {
          console.log('[TVPlayer] Autoplay policy prevented unmuted playback, retrying muted...');
          self.videoEl.muted = true;
          self.videoEl.play().catch(function(e2) {
            console.warn('[TVPlayer] Muted play retry error:', e2);
          });
        } else if (url.indexOf('.m3u8') !== -1 && window.Hls && window.Hls.isSupported() && !self._retriedWithHls) {
          console.log('[TVPlayer] Native HLS play error, falling back to Hls.js...');
          self._playHls(url);
        }
      });
    }
  };

  TVPlayer.prototype._playHls = function(url) {
    var self = this;
    this._retriedWithHls = true;
    this._networkRetryCount = 0;
    this._mediaRecoverCount = 0;
    if (this.hls) {
      try { this.hls.destroy(); } catch(e){}
      this.hls = null;
    }
    console.log('[TVPlayer] Starting Hls.js player engine for:', url);

    self.hls = new window.Hls({
      maxBufferLength: 15,
      maxMaxBufferLength: 30,
      backBufferLength: 5,
      maxBufferSize: 30 * 1000 * 1000,
      liveSyncDurationCount: 2,
      liveMaxLatencyDurationCount: 8,
      maxLiveSyncPlaybackRate: 1, // Stay strictly at 1.0x to avoid audio crackle and stutter
      enableWorker: false,        // Main-thread trans-muxing eliminates worker transfer lag on TV
      lowLatencyMode: false,      // Standard IPTV streams require stable buffering (not LL-HLS)
      progressive: false,         // Disable progressive fetch to prevent chunked transfer hangs on IPTV servers
      nudgeOffset: 0.1,
      nudgeMaxRetry: 5,
      maxFragLookUpTolerance: 0.25,
      manifestLoadingTimeOut: 5000,
      manifestLoadingMaxRetry: 2,
      fragLoadingTimeOut: 7000,
      fragLoadingMaxRetry: 2,
      levelLoadingTimeOut: 5000,
      levelLoadingMaxRetry: 2,
      startFragPrefetch: true,
      fpsDroppedMonitoringPeriod: 0
    });
    self.hls.loadSource(url);
    self.hls.attachMedia(self.videoEl);

    var onHlsTracksReady = function(evtName) {
      if (self.playbackType === 'live') {
        if (self.hls) {
          try {
            self.hls.subtitleDisplay = false;
            self.hls.subtitleTrack = -1;
          } catch(e){}
        }
        if (self.videoEl && self.videoEl.textTracks) {
          for (var ti = 0; ti < self.videoEl.textTracks.length; ti++) {
            try { self.videoEl.textTracks[ti].mode = 'disabled'; } catch(e){}
          }
        }
        self._activeSubtitleCues = null;
        self.renderSubtitle(null);
      }
      var aCount = (self.hls && self.hls.audioTracks) ? self.hls.audioTracks.length : 0;
      var sCount = (self.hls && self.hls.subtitleTracks) ? self.hls.subtitleTracks.length : 0;
      console.log('[TrackDebug] Hls event (' + (evtName || 'trackReady') + '): audioTracks=' + aCount + ', subtitleTracks=' + sCount);
      self._setupTrackListeners();
      self._tracksLoading = false;
      self._applyPreferences();
      if (window.onTracksUpdated) window.onTracksUpdated();
    };

    self.hls.on(window.Hls.Events.FRAG_BUFFERED, function() {
      self._clearWatchdog();
      self._setBuffering(false);
    });

    self.hls.on(window.Hls.Events.MANIFEST_PARSED, function() {
      onHlsTracksReady('MANIFEST_PARSED');
      self.videoEl.play().catch(function(err) {
        console.warn('[TVPlayer] play() rejected on MANIFEST_PARSED:', err);
      });
    });
    self.hls.on(window.Hls.Events.AUDIO_TRACKS_UPDATED, function() { onHlsTracksReady('AUDIO_TRACKS_UPDATED'); });
    self.hls.on(window.Hls.Events.SUBTITLE_TRACKS_UPDATED, function() { onHlsTracksReady('SUBTITLE_TRACKS_UPDATED'); });
    self.hls.on(window.Hls.Events.NON_NATIVE_TEXT_TRACKS_FOUND, function() { onHlsTracksReady('NON_NATIVE_TEXT_TRACKS_FOUND'); });
    self.hls.on(window.Hls.Events.AUDIO_TRACK_LOADED, function() { onHlsTracksReady('AUDIO_TRACK_LOADED'); });
    self.hls.on(window.Hls.Events.SUBTITLE_TRACK_LOADED, function() { onHlsTracksReady('SUBTITLE_TRACK_LOADED'); });
    self.hls.on(window.Hls.Events.AUDIO_TRACK_SWITCHED, function(event, data) {
      console.log('[TrackDebug] Hls AUDIO_TRACK_SWITCHED:', data);
      if (window.onTracksUpdated) window.onTracksUpdated();
    });
    self.hls.on(window.Hls.Events.SUBTITLE_TRACK_SWITCH, function(event, data) {
      console.log('[TrackDebug] Hls SUBTITLE_TRACK_SWITCH:', data);
      if (window.onTracksUpdated) window.onTracksUpdated();
    });
    self.hls.on(window.Hls.Events.ERROR, function(event, data) {
      console.log('[TVPlayer:HLS_ERROR] details=' + data.details + ', type=' + data.type + ', fatal=' + data.fatal);
      if (!data.fatal) {
        if (data.details === 'bufferStalledError') {
          try {
            if (self.videoEl) {
              self.videoEl.currentTime = (self.videoEl.currentTime || 0) + 0.1;
            }
          } catch(e){}
        }
        return;
      }

      switch(data.type) {
        case window.Hls.ErrorTypes.NETWORK_ERROR:
          console.warn('[TVPlayer:DiagnosticError] Category: NETWORK_ERROR (details=' + data.details + ')');
          if (self._networkRetryCount < 1) {
            self._networkRetryCount++;
            self.hls.startLoad();
          } else if (!self._retriedWithTs && self.playbackType === 'live') {
            self._fallbackToNativeTs();
          }
          break;

        case window.Hls.ErrorTypes.MEDIA_ERROR:
          console.warn('[TVPlayer:DiagnosticError] Category: HLS_DECODE_ERROR (details=' + data.details + ')');
          if (self._mediaRecoverCount < 2) {
            self._mediaRecoverCount++;
            self.hls.recoverMediaError();
          } else if (!self._retriedWithTs && self.playbackType === 'live') {
            self._fallbackToNativeTs();
          }
          break;

        default:
          console.warn('[TVPlayer:DiagnosticError] Category: UNKNOWN_MEDIA_ERROR (details=' + data.details + ')');
          if (!self._retriedWithTs && self.playbackType === 'live') {
            self._fallbackToNativeTs();
          } else {
            self.stop(true);
          }
          break;
      }
    });
  };

  TVPlayer.prototype.setMode = function(mode, shouldFocusPreview) {
    this.currentMode = mode;
    var self = this;
    if (mode === 'fullscreen') {
      document.body.classList.add('player-fullscreen');
      if (this.containerEl) {
        this.containerEl.classList.remove('mode-preview');
        this.containerEl.classList.add('mode-fullscreen');
        this.containerEl.style.top = '0px';
        this.containerEl.style.left = '0px';
        this.containerEl.style.right = '0px';
        this.containerEl.style.bottom = '0px';
        this.containerEl.style.width = '100%';
        this.containerEl.style.height = '100%';
        this.containerEl.style.borderRadius = '0px';
      }

      // Clear focus from preview box and blur active element so transform is cleared
      if (window.SpatialNav) {
        window.SpatialNav.setFocus(null);
      }
      if (document.activeElement && typeof document.activeElement.blur === 'function') {
        try { document.activeElement.blur(); } catch(e){}
      }
    } else {
      document.body.classList.remove('player-fullscreen');
      if (this.containerEl) {
        this.containerEl.classList.remove('mode-fullscreen');
        this.containerEl.classList.add('mode-preview');
      }
      this.updatePreviewPosition();
      setTimeout(function() {
        self.updatePreviewPosition();
      }, 40);

      if (shouldFocusPreview) {
        var previewBox = document.getElementById('preview-player-box');
        if (window.SpatialNav && previewBox) {
          window.SpatialNav.setFocus(previewBox);
        }
      }
    }
    this.showHud();
  };

  TVPlayer.prototype.toggleFullscreen = function() {
    if (this.currentMode === 'fullscreen') {
      this.setMode('preview', true);
    } else {
      this.setMode('fullscreen');
    }
  };

  TVPlayer.prototype.updatePreviewPosition = function() {
    var previewBox = document.getElementById('preview-player-box');
    if (previewBox && this.containerEl && this.currentMode === 'preview') {
      var rect = previewBox.getBoundingClientRect();
      if (rect.width > 0 && rect.height > 0) {
        this.containerEl.style.top = Math.round(rect.top) + 'px';
        this.containerEl.style.left = Math.round(rect.left) + 'px';
        this.containerEl.style.width = Math.round(rect.width) + 'px';
        this.containerEl.style.height = Math.round(rect.height) + 'px';
        this.containerEl.style.borderRadius = '12px';
        this.containerEl.style.display = 'block';
      }
    }
  };

  TVPlayer.prototype.showHud = function() {
    var self = this;
    if (this.currentMode === 'fullscreen') {
      if (this.playbackType === 'live') {
        if (this.vodHudEl) this.vodHudEl.classList.remove('visible');
        this.showInfobar(4000);
      } else {
        var infobar = document.getElementById('live-infobar');
        if (infobar) infobar.classList.remove('visible');
        if (this.vodHudEl) this.vodHudEl.classList.add('visible');
      }
    } else {
      var infobar = document.getElementById('live-infobar');
      if (infobar) infobar.classList.remove('visible');
      if (this.vodHudEl) this.vodHudEl.classList.remove('visible');
    }

    var clockEl = document.getElementById('vod-hud-clock');
    if (clockEl) {
      var now = new Date();
      clockEl.textContent = String(now.getHours()).padStart(2, '0') + ':' + String(now.getMinutes()).padStart(2, '0');
    }

    if (this.playbackType !== 'live') {
      if (this.osdTimer) clearTimeout(this.osdTimer);
      this.osdTimer = setTimeout(function() {
        self.hideHud();
      }, 5000);
    }
  };

  TVPlayer.prototype.updateQualityBadges = function(containerId, streamTitle) {
    var container = document.getElementById(containerId);
    if (!container) return;

    var w = (this.videoEl && this.videoEl.videoWidth) ? this.videoEl.videoWidth : 0;
    var h = (this.videoEl && this.videoEl.videoHeight) ? this.videoEl.videoHeight : 0;
    var title = (streamTitle || (this.currentStream ? this.currentStream.name : '') || '').toLowerCase();

    // 1. Resolution
    var res = null;
    if (w >= 3800 || h >= 2000) {
      res = '4K';
    } else if (h >= 1400) {
      res = '1440p';
    } else if (h >= 1000 || w >= 1900) {
      res = '1080p';
    } else if (h >= 700 || w >= 1200) {
      res = '720p';
    } else if (h > 0) {
      res = (h < 600) ? 'SD' : (h + 'p');
    } else {
      if (title.indexOf('4k') !== -1 || title.indexOf('uhd') !== -1 || title.indexOf('2160') !== -1) res = '4K';
      else if (title.indexOf('1080') !== -1 || title.indexOf('fhd') !== -1) res = '1080p';
      else if (title.indexOf('720') !== -1 || title.indexOf('hd') !== -1) res = '720p';
    }

    // 2. FPS
    var fps = null;
    if (this._measuredFps && this._measuredFps >= 15) {
      var f = this._measuredFps;
      if (f >= 23.5 && f <= 24.5) fps = '24 FPS';
      else if (f >= 24.6 && f <= 25.5) fps = '25 FPS';
      else if (f >= 29.4 && f <= 30.5) fps = '30 FPS';
      else if (f >= 49.0 && f <= 51.5) fps = '50 FPS';
      else if (f >= 58.5 && f <= 61.5) fps = '60 FPS';
      else fps = Math.round(f) + ' FPS';
    } else {
      if (title.indexOf('50fps') !== -1 || title.indexOf('50 fps') !== -1 || title.indexOf('50hz') !== -1) fps = '50 FPS';
      else if (title.indexOf('60fps') !== -1 || title.indexOf('60 fps') !== -1 || title.indexOf('60hz') !== -1) fps = '60 FPS';
      else if (title.indexOf('25fps') !== -1 || title.indexOf('25 fps') !== -1) fps = '25 FPS';
    }

    // 3. HDR
    var hdr = null;
    if (title.indexOf('dolby vision') !== -1 || title.indexOf('dovi') !== -1 || /\bdv\b/.test(title)) {
      hdr = 'Vision';
    } else if (title.indexOf('hdr10+') !== -1 || title.indexOf('hdr10') !== -1 || /\bhdr\b/.test(title)) {
      hdr = 'HDR';
    } else if (/\bhlg\b/.test(title)) {
      hdr = 'HLG';
    }

    // 4. Audio
    var audio = null;
    if (this.currentVodMeta && this.currentVodMeta.audioTracks && this.currentVodMeta.audioTracks.length > 0) {
      var actAudio = this.currentVodMeta.audioTracks[this.currentAudioTrackIndex || 0];
      if (actAudio && actAudio.title) {
        var aTitle = actAudio.title.toLowerCase();
        if (aTitle.indexOf('atmos') !== -1) audio = 'Atmos';
        else if (aTitle.indexOf('7.1') !== -1) audio = '7.1';
        else if (aTitle.indexOf('5.1') !== -1 || aTitle.indexOf('ac3') !== -1 || aTitle.indexOf('eac3') !== -1 || aTitle.indexOf('surround') !== -1) audio = '5.1';
      }
    }
    if (!audio) {
      if (title.indexOf('atmos') !== -1) audio = 'Atmos';
      else if (title.indexOf('7.1') !== -1) audio = '7.1';
      else if (title.indexOf('5.1') !== -1 || title.indexOf('surround') !== -1) audio = '5.1';
    }

    var html = '';
    if (res) html += '<span class="quality-badge' + (res === '4K' ? ' badge-4k' : '') + '">' + res + '</span>';
    if (fps) html += '<span class="quality-badge badge-fps">' + fps + '</span>';
    if (hdr) html += '<span class="quality-badge badge-hdr">' + hdr + '</span>';
    if (audio) html += '<span class="quality-badge badge-audio">' + audio + '</span>';

    container.innerHTML = html;
  };

  TVPlayer.prototype.showInfobar = function(duration) {
    var self = this;
    var infobar = document.getElementById('live-infobar');
    if (!infobar) return;

    var isFullscreen = (this.currentMode === 'fullscreen') || document.body.classList.contains('player-fullscreen');
    if (!isFullscreen || this.playbackType !== 'live') {
      infobar.classList.remove('visible');
      return;
    }

    var ch = this.currentStream;
    if (ch) {
      // 1. Channel Number, Logo & Name
      var numEl = document.getElementById('infobar-channel-num');
      var logoEl = document.getElementById('infobar-channel-logo');
      var nameEl = document.getElementById('infobar-channel-name');
      var favEl = document.getElementById('infobar-fav-icon');

      if (this.currentChannelIndex < 0 && this.currentChannelList && this.currentChannelList.length > 0) {
        this.currentChannelIndex = this.currentChannelList.findIndex(function(c) {
          return String(c.stream_id) === String(ch.stream_id);
        });
      }
      var chNum = (this.currentChannelIndex >= 0) ? (this.currentChannelIndex + 1) : 1;
      if (numEl) numEl.textContent = chNum;

      if (nameEl) {
        nameEl.textContent = ch.name ? ch.name.replace(/^\[.*?\]\s*/, '') : 'Live Channel';
      }

      // Quality Badges
      this.updateQualityBadges('infobar-quality-badges', ch.name);

      if (logoEl) {
        if (ch.stream_icon) {
          logoEl.src = ch.stream_icon;
          logoEl.style.display = 'block';
        } else {
          logoEl.style.display = 'none';
        }
      }

      var activeAccount = window.TVStorage ? window.TVStorage.getActiveAccount() : null;
      if (favEl && activeAccount) {
        var isFav = window.TVStorage.isFavorite(activeAccount.id, ch.stream_id, 'live');
        favEl.style.display = isFav ? 'inline-block' : 'none';
      }

      // 2. Current Clock
      var clockEl = document.getElementById('infobar-clock');
      if (clockEl) {
        var now = new Date();
        clockEl.textContent = String(now.getHours()).padStart(2, '0') + ':' + String(now.getMinutes()).padStart(2, '0');
      }

      // 3. EPG Listings
      if (activeAccount && window.TVApi) {
        window.TVApi.getShortEpg(activeAccount, ch.stream_id)
          .then(function(listings) {
            self._updateInfobarEpg(listings);
          })
          .catch(function() {
            self._updateInfobarEpg([]);
          });
      } else {
        self._updateInfobarEpg([]);
      }
    }

    infobar.classList.add('visible');

    if (this.infobarTimer) clearTimeout(this.infobarTimer);
    this.infobarTimer = setTimeout(function() {
      infobar.classList.remove('visible');
    }, duration || 4000);
  };

  function calcEpgItemTiming(item) {
    if (!item) return { durationMin: 0, remainingMin: 0, percent: 0, durationLabel: '', remainingLabel: '' };
    var now = new Date();
    var nowSec = Math.floor(now.getTime() / 1000);

    var durMin = 0;
    if (item.start_timestamp && item.stop_timestamp) {
      var dSec = Number(item.stop_timestamp) - Number(item.start_timestamp);
      if (dSec > 0) durMin = Math.round(dSec / 60);
    }

    var remMin = 0;
    var pct = 0;

    function parseDate(s) {
      if (!s || typeof s !== 'string') return null;
      var m = s.match(/(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2})(?::(\d{2}))?/);
      if (m) {
        return new Date(parseInt(m[1], 10), parseInt(m[2], 10) - 1, parseInt(m[3], 10), parseInt(m[4], 10), parseInt(m[5], 10), m[6] ? parseInt(m[6], 10) : 0);
      }
      return null;
    }

    var dStart = parseDate(item.start);
    var dEnd = parseDate(item.end);

    if (dStart && dEnd) {
      var totalMs = dEnd.getTime() - dStart.getTime();
      if (totalMs > 0) {
        durMin = Math.round(totalMs / 60000);
        var elapsedMs = now.getTime() - dStart.getTime();
        var leftMs = dEnd.getTime() - now.getTime();
        remMin = Math.max(0, Math.round(leftMs / 60000));
        pct = Math.max(0, Math.min(100, Math.round((elapsedMs / totalMs) * 100)));
      }
    } else if (item.start_timestamp && item.stop_timestamp) {
      var sSec = Number(item.start_timestamp);
      var eSec = Number(item.stop_timestamp);
      var tot = eSec - sSec;
      if (tot > 0) {
        durMin = Math.round(tot / 60);
        if (nowSec >= sSec && nowSec <= eSec) {
          remMin = Math.max(0, Math.round((eSec - nowSec) / 60));
          pct = Math.max(0, Math.min(100, Math.round(((nowSec - sSec) / tot) * 100)));
        } else {
          remMin = durMin;
          pct = 0;
        }
      }
    }

    var isDe = window.TVI18n && window.TVI18n.getLanguage() === 'de';
    var remLabel = remMin > 0 ? (isDe ? ('noch ' + remMin + ' min') : (remMin + ' min left')) : (durMin > 0 ? (durMin + ' min') : '');
    var durLabel = durMin > 0 ? (durMin + ' min') : '';

    return {
      durationMin: durMin,
      remainingMin: remMin,
      percent: pct,
      remainingLabel: remLabel,
      durationLabel: durLabel
    };
  }
  window.calcEpgItemTiming = calcEpgItemTiming;

  TVPlayer.prototype._updateInfobarEpg = function(listings) {
    var curTimeEl = document.getElementById('infobar-cur-time');
    var curTitleEl = document.getElementById('infobar-cur-title');
    var curDurEl = document.getElementById('infobar-cur-duration');
    var fillEl = document.getElementById('infobar-progress-fill');

    var nextTimeEl = document.getElementById('infobar-next-time');
    var nextTitleEl = document.getElementById('infobar-next-title');
    var nextDurEl = document.getElementById('infobar-next-duration');

    var noEpg = window.TVI18n ? window.TVI18n.t('no_epg_available') : 'No upcoming programs';

    if (!listings || listings.length === 0) {
      if (curTimeEl) curTimeEl.textContent = '--:--';
      if (curTitleEl) curTitleEl.textContent = noEpg;
      if (curDurEl) curDurEl.textContent = '';
      if (fillEl) fillEl.style.width = '0%';

      if (nextTimeEl) nextTimeEl.textContent = '--:--';
      if (nextTitleEl) nextTitleEl.textContent = '--';
      if (nextDurEl) nextDurEl.textContent = '';
      return;
    }

    var cur = listings[0];
    if (cur) {
      var sTime = cur.start ? cur.start.substring(11, 16) : '--:--';
      if (curTimeEl) curTimeEl.textContent = sTime;
      if (curTitleEl) curTitleEl.textContent = cur.title || 'Live Program';

      var curTiming = calcEpgItemTiming(cur);
      if (curDurEl) curDurEl.textContent = curTiming.remainingLabel || curTiming.durationLabel;
      if (fillEl) fillEl.style.width = curTiming.percent + '%';
    }

    var next = listings[1];
    if (next) {
      var nTime = next.start ? next.start.substring(11, 16) : '--:--';
      if (nextTimeEl) nextTimeEl.textContent = nTime;
      if (nextTitleEl) nextTitleEl.textContent = next.title || '--';

      var nextTiming = calcEpgItemTiming(next);
      if (nextDurEl) nextDurEl.textContent = nextTiming.durationLabel;
    } else {
      if (nextTimeEl) nextTimeEl.textContent = '--:--';
      if (nextTitleEl) nextTitleEl.textContent = '--';
      if (nextDurEl) nextDurEl.textContent = '';
    }
  };

  TVPlayer.prototype.hideHud = function() {
    var infobar = document.getElementById('live-infobar');
    if (infobar) infobar.classList.remove('visible');
    if (this.vodHudEl) this.vodHudEl.classList.remove('visible');
  };

  TVPlayer.prototype.togglePlayPause = function() {
    var self = this;
    if (this.playbackType === 'live') {
      if (this.videoEl.paused) {
        this._userPaused = false;
        // Re-tune to live edge so user never falls behind
        var activeAccount = window.TVStorage ? window.TVStorage.getActiveAccount() : null;
        if (activeAccount && this.currentStream) {
          var url = window.TVApi.getLiveStreamUrl(activeAccount, this.currentStream.stream_id, !this._retriedWithTs);
          this._playMedia(url);
        } else {
          this.videoEl.play().catch(function(){});
        }
        this._updatePreviewPlayBtn(true);
      } else {
        this._userPaused = true;
        this.videoEl.pause();
        this._updatePreviewPlayBtn(false);
      }
      return;
    }

    var btn = document.getElementById('vod-play-btn');

    // If video is stuck in seeking state, user pressing play/pause is attempting to revive it
    if (this.videoEl && this.videoEl.seeking && (this._pendingSeekTime === null || this._pendingSeekTime === undefined)) {
      console.warn('[TVPlayer] Play/Pause clicked while video.seeking is stuck; initiating seek stall recovery');
      this._userPaused = false;
      var recTarget = (typeof this._lastTargetSeekTime === 'number' && this._lastTargetSeekTime >= 0) ? this._lastTargetSeekTime : (this.videoEl.currentTime || 0);
      this._recoverSeekStall(recTarget);
      if (btn) {
        var iconSpan = btn.querySelector('.btn-icon') || btn;
        iconSpan.innerHTML = window.TVIcons ? window.TVIcons.pause : '⏸';
      }
      this.showHud();
      return;
    }

    if (this.videoEl.paused) {
      this._userPaused = false;
      this.videoEl.play().catch(function(){});
      if (btn) {
        var iconSpan = btn.querySelector('.btn-icon') || btn;
        iconSpan.innerHTML = window.TVIcons ? window.TVIcons.pause : '⏸';
      }
    } else {
      this._userPaused = true;
      this.videoEl.pause();
      if (btn) {
        var iconSpan = btn.querySelector('.btn-icon') || btn;
        iconSpan.innerHTML = window.TVIcons ? window.TVIcons.play : '▶';
      }
    }
    this.showHud();
  };

  TVPlayer.prototype._updatePreviewPlayBtn = function(isPlaying) {
    var pauseIcon = document.getElementById('preview-icon-pause');
    var playIcon = document.getElementById('preview-icon-play');
    if (pauseIcon && playIcon) {
      pauseIcon.style.display = isPlaying ? 'block' : 'none';
      playIcon.style.display = isPlaying ? 'none' : 'block';
    }
  };

  TVPlayer.prototype._renderScrubProgress = function(cur, dur) {
    if (!this._vodTimeCurEl) this._vodTimeCurEl = document.getElementById('vod-time-current');
    if (!this._vodTimeDurEl) this._vodTimeDurEl = document.getElementById('vod-time-total');
    if (!this._vodProgFillEl) this._vodProgFillEl = document.getElementById('vod-progress-fill');

    if (this._vodTimeCurEl) this._vodTimeCurEl.textContent = this._formatTime(cur);
    if (dur && !isNaN(dur) && isFinite(dur) && dur > 0) {
      if (this._vodProgFillEl) this._vodProgFillEl.style.width = Math.min(100, Math.max(0, (cur / dur) * 100)) + '%';
      if (this._vodTimeDurEl && (this._vodTimeDurEl.textContent === '--:--' || !this._vodTimeDurEl.textContent)) {
        this._vodTimeDurEl.textContent = this._formatTime(dur);
      }
    }
  };

  TVPlayer.prototype.seekBy = function(seconds) {
    if (!this.videoEl) return;
    var dur = this.videoEl.duration;
    if ((!dur || isNaN(dur) || !isFinite(dur) || dur <= 0) && this.currentVodMeta && typeof this.currentVodMeta.duration === 'number' && this.currentVodMeta.duration > 0) {
      dur = this.currentVodMeta.duration;
    }
    if (!dur || isNaN(dur) || !isFinite(dur) || dur <= 0) return;

    var now = Date.now();
    if (this._lastSeekPressTime && (now - this._lastSeekPressTime) < 450) {
      this._consecutiveSeekCount = (this._consecutiveSeekCount || 0) + 1;
    } else {
      this._consecutiveSeekCount = 0;
    }
    this._lastSeekPressTime = now;

    var sign = seconds >= 0 ? 1 : -1;
    var step = Math.abs(seconds);
    // Dynamic progressive acceleration:
    // 0-3 presses: 10s step
    // 4-8 presses: 30s step
    // 9-15 presses: 60s step (1 min)
    // 16+ presses: 180s step (3 min)
    if (this._consecutiveSeekCount >= 16) {
      step = 180;
    } else if (this._consecutiveSeekCount >= 9) {
      step = 60;
    } else if (this._consecutiveSeekCount >= 4) {
      step = 30;
    }

    var effectiveDelta = sign * step;
    var current = (this._pendingSeekTime !== null && this._pendingSeekTime !== undefined)
      ? this._pendingSeekTime
      : (this.videoEl.currentTime || 0);

    var target = Math.max(0, Math.min(dur, current + effectiveDelta));
    this._pendingSeekTime = target;

    this._renderScrubProgress(target, dur);
    this.showHud();

    if (this._seekDebounceTimer) {
      clearTimeout(this._seekDebounceTimer);
    }

    var self = this;
    this._seekDebounceTimer = setTimeout(function() {
      self._commitPendingSeek();
    }, 400);
  };

  TVPlayer.prototype.seekToRatio = function(ratio) {
    if (!this.videoEl) return;
    var dur = this.videoEl.duration;
    if ((!dur || isNaN(dur) || !isFinite(dur) || dur <= 0) && this.currentVodMeta && typeof this.currentVodMeta.duration === 'number' && this.currentVodMeta.duration > 0) {
      dur = this.currentVodMeta.duration;
    }
    if (!dur || isNaN(dur) || !isFinite(dur) || dur <= 0) return;

    var target = Math.max(0, Math.min(dur, dur * ratio));
    this._pendingSeekTime = target;
    this._renderScrubProgress(target, dur);
    this.showHud();

    if (this._seekDebounceTimer) {
      clearTimeout(this._seekDebounceTimer);
    }

    var self = this;
    this._seekDebounceTimer = setTimeout(function() {
      self._commitPendingSeek();
    }, 400);
  };

  TVPlayer.prototype._commitPendingSeek = function() {
    if (this._seekDebounceTimer) {
      clearTimeout(this._seekDebounceTimer);
      this._seekDebounceTimer = null;
    }
    this._consecutiveSeekCount = 0;
    if (this._pendingSeekTime === null || this._pendingSeekTime === undefined) return;
    var target = this._pendingSeekTime;
    this._pendingSeekTime = null;

    if (!this.videoEl) return;

    this._lastTargetSeekTime = target;

    // If an active seek is already executing on the hardware decoder, queue this seek
    if (this.videoEl.seeking) {
      this._queuedSeekTarget = target;
      return;
    }

    try {
      this._setBuffering(true);
      this._clearWatchdog();
      this._startSeekWatchdog(target);
      this.videoEl.currentTime = target;
    } catch(e) {
      console.warn('[TVPlayer] Seek commit error:', e);
      this._setBuffering(false);
      this._clearSeekWatchdog();
    }
  };

  TVPlayer.prototype._recoverSeekStall = function(targetTime) {
    if (!this.videoEl || !this.videoEl.src) return;
    var self = this;
    var target = (typeof targetTime === 'number' && !isNaN(targetTime) && targetTime >= 0)
      ? targetTime
      : ((typeof this._lastTargetSeekTime === 'number' && this._lastTargetSeekTime >= 0) ? this._lastTargetSeekTime : (this.videoEl.currentTime || 0));

    console.warn('[TVPlayer] _recoverSeekStall executing for target position:', target);
    this._clearSeekWatchdog();
    this._setBuffering(true);

    var currentSrc = this.videoEl.src;
    this._isResuming = true;
    this._resumeTime = target;
    this._lastTargetSeekTime = target;

    try {
      this.videoEl.pause();
    } catch(e){}

    var onLoadedMeta = function() {
      self.videoEl.removeEventListener('loadedmetadata', onLoadedMeta);
      console.log('[TVPlayer] _recoverSeekStall: loadedmetadata received, restoring target currentTime:', target);
      try {
        if (target > 0) {
          self.videoEl.currentTime = target;
        }
        if (!self._userPaused) {
          self.videoEl.play().catch(function(err){
            console.warn('[TVPlayer] Recovery play rejected:', err);
          });
        }
      } catch(e) {
        console.warn('[TVPlayer] Recovery seek failed:', e);
      }
    };

    this.videoEl.addEventListener('loadedmetadata', onLoadedMeta);

    try {
      this.videoEl.src = currentSrc;
      this.videoEl.load();
    } catch(e) {
      console.warn('[TVPlayer] Failed to reload src in _recoverSeekStall:', e);
    }
  };

  TVPlayer.prototype._startSeekWatchdog = function(targetTime) {
    this._clearSeekWatchdog();
    var self = this;
    var target = (typeof targetTime === 'number') ? targetTime : this._lastTargetSeekTime;
    this._seekWatchdogTimer = setTimeout(function() {
      if (self.videoEl && self.videoEl.seeking) {
        console.warn('[TVPlayer] Seek watchdog triggered (4s stall), recovering playback via _recoverSeekStall at:', target);
        self._recoverSeekStall(target);
      }
    }, 4000);
  };

  TVPlayer.prototype._clearSeekWatchdog = function() {
    if (this._seekWatchdogTimer) {
      clearTimeout(this._seekWatchdogTimer);
      this._seekWatchdogTimer = null;
    }
  };

  TVPlayer.prototype._updateVodProgress = function() {
    if (this._pendingSeekTime !== null && this._pendingSeekTime !== undefined) {
      return; // Keep user active scrub position intact
    }
    var cur = this.videoEl.currentTime || 0;
    var dur = this.videoEl.duration;
    if (!dur || isNaN(dur) || !isFinite(dur) || dur <= 30) {
      dur = (this.currentVodMeta && this.currentVodMeta.duration > 0) ? parseDurationSecs(this.currentVodMeta.duration) : 0;
    }
    var curSec = Math.floor(cur);

    // If HUD is not visible, skip heavy DOM updates unless 1 full second has passed
    var hudVisible = this.vodHudEl && this.vodHudEl.classList.contains('visible');
    if (!hudVisible && this._lastProgressSec === curSec) return;
    this._lastProgressSec = curSec;

    this._renderScrubProgress(cur, dur);
  };

  TVPlayer.prototype._updateVodDuration = function() {
    var dur = this.videoEl ? this.videoEl.duration : 0;
    var durEl = document.getElementById('vod-time-total');
    var curPos = this.videoEl ? Math.floor(this.videoEl.currentTime || 0) : 0;
    var validDur = 0;
    if (dur && !isNaN(dur) && isFinite(dur) && dur > 100 && (curPos < 2 || Math.abs(dur - curPos) > 2)) {
      validDur = Math.floor(dur);
      if (this.currentVodMeta) {
        this.currentVodMeta.duration = validDur;
      }
    } else if (this.currentVodMeta && this.currentVodMeta.duration > 0) {
      validDur = parseDurationSecs(this.currentVodMeta.duration);
      if (validDur > 100) {
        this.currentVodMeta.duration = validDur;
      } else {
        validDur = 0;
      }
    }
    if (durEl) {
      durEl.textContent = (validDur > 0) ? this._formatTime(validDur) : '--:--';
    }
  };

  TVPlayer.prototype._formatTime = function(sec) {
    if (isNaN(sec) || sec < 0) return '00:00';
    var totalSec = Math.floor(sec);
    var h = Math.floor(totalSec / 3600);
    var m = Math.floor((totalSec % 3600) / 60);
    var s = totalSec % 60;
    if (h > 0) {
      return h + ':' + String(m).padStart(2, '0') + ':' + String(s).padStart(2, '0');
    }
    return String(m).padStart(2, '0') + ':' + String(s).padStart(2, '0');
  };

  TVPlayer.prototype.zapNext = function() {
    var list = (this.currentChannelList && this.currentChannelList.length > 0)
      ? this.currentChannelList
      : ((window._liveStreams && window._liveStreams.length > 0)
          ? window._liveStreams
          : ((window._goatVirtualList && window._goatVirtualList.items) ? window._goatVirtualList.items : []));
    if (list.length === 0) return;
    this.currentChannelList = list;
    if (this.currentChannelIndex < 0 && this.currentStream) {
      var self = this;
      this.currentChannelIndex = list.findIndex(function(c) {
        return String(c.stream_id) === String(self.currentStream.stream_id);
      });
    }
    if (this.currentChannelIndex < 0) this.currentChannelIndex = 0;
    var nextIdx = (this.currentChannelIndex + 1) % list.length;
    this.currentChannelIndex = nextIdx;
    this.playLive(list[nextIdx], this.currentCategory || this.currentCategoryName, true);
  };

  TVPlayer.prototype.zapPrev = function() {
    var list = (this.currentChannelList && this.currentChannelList.length > 0)
      ? this.currentChannelList
      : ((window._liveStreams && window._liveStreams.length > 0)
          ? window._liveStreams
          : ((window._goatVirtualList && window._goatVirtualList.items) ? window._goatVirtualList.items : []));
    if (list.length === 0) return;
    this.currentChannelList = list;
    if (this.currentChannelIndex < 0 && this.currentStream) {
      var self = this;
      this.currentChannelIndex = list.findIndex(function(c) {
        return String(c.stream_id || c.id) === String(self.currentStream.stream_id || self.currentStream.id);
      });
    }
    if (this.currentChannelIndex < 0) this.currentChannelIndex = 0;
    var prevIdx = (this.currentChannelIndex - 1 + list.length) % list.length;
    this.currentChannelIndex = prevIdx;
    this.playLive(list[prevIdx], this.currentCategory || this.currentCategoryName, true);
  };

  TVPlayer.prototype.stop = function(keepOsd) {
    if (this.playbackType === 'vod' || this.playbackType === 'series') {
      try {
        this._saveCurrentProgress(false);
      } catch(e){}
    }
    if (this._seekDebounceTimer) {
      clearTimeout(this._seekDebounceTimer);
      this._seekDebounceTimer = null;
    }
    if (typeof this._clearSeekWatchdog === 'function') {
      this._clearSeekWatchdog();
    }
    this._pendingSeekTime = null;
    this._queuedSeekTarget = null;
    this._lastTargetSeekTime = null;
    this._consecutiveSeekCount = 0;
    this._clearWatchdog();
    this._retriedWithTs = false;
    this._retriedWithHls = false;
    this._audibleLogged = false;
    this._setBuffering(false);
    this._updatePreviewPlayBtn(false);
    if (!keepOsd) {
      document.body.classList.remove('player-fullscreen');
      if (this.currentMode === 'fullscreen') {
        if (this.containerEl) {
          this.containerEl.classList.remove('mode-fullscreen');
          this.containerEl.classList.add('mode-preview');
        }
        this.currentMode = 'preview';
      }
      this.updatePreviewPosition();
    }
    if (this.hls) {
      try { this.hls.destroy(); } catch(e){}
      this.hls = null;
    }
    if (this.videoEl) {
      try {
        this.videoEl.pause();
        this.videoEl.removeAttribute('src');
        if (!keepOsd) {
          this.videoEl.src = '';
          this.videoEl.load();
        }
        this.videoEl.classList.remove('video-aspect-fill');
      } catch(e){}
    }
    this._selectedAudioTrackIndex = undefined;
    this._selectedSubTrackIndex = undefined;
    this._customSubtitles = [];
    this._activeSubtitleCues = null;
    this._tracksLoading = false;
    this.renderSubtitle(null);
    var unmuteBanner = document.getElementById('player-unmute-banner');
    if (unmuteBanner) unmuteBanner.style.display = 'none';
    if (!keepOsd) {
      this.hideHud();
      this.currentStream = null;
      var curEl = document.getElementById('vod-time-current');
      var durEl = document.getElementById('vod-time-total');
      var barEl = document.getElementById('vod-progress-fill');
      if (curEl) curEl.textContent = '00:00';
      if (durEl) durEl.textContent = '--:--';
      if (barEl) barEl.style.width = '0%';
      if (this.containerEl) {
        this.containerEl.style.display = 'none';
        this.containerEl.classList.remove('video-playing');
      }
      var liveBadge = document.getElementById('preview-live-badge');
      if (liveBadge) liveBadge.style.display = 'none';
      var placeholder = document.getElementById('preview-placeholder-msg');
      if (placeholder) placeholder.style.display = 'flex';
      var previewBox = document.getElementById('preview-player-box');
      if (previewBox) previewBox.classList.remove('has-stream');
      var previewTitle = document.getElementById('preview-channel-name');
      if (previewTitle) previewTitle.textContent = '';
      if (typeof window.clearLiveEpg === 'function') {
        window.clearLiveEpg();
      }
    }
  };

  // Track Language Matcher (1:1 parity with Windows app lib/core/player/track_language_matcher.dart)
  var TrackLanguageMatcher = {
    _languageAliases: {
      'de': [
        'de', 'ger', 'deu', 'deutsch', 'german', 'allemand', 'tedesco', 
        'deutsche', 'ger-de', 'de-de'
      ],
      'en': [
        'en', 'eng', 'english', 'englisch', 'anglais', 'ingles', 'inglés', 
        'en-us', 'en-gb', 'orig', 'original'
      ],
      'es': [
        'es', 'spa', 'spanish', 'spanisch', 'espanol', 'español', 'castellano', 'es-es', 'es-la'
      ],
      'fr': [
        'fr', 'fre', 'fra', 'french', 'französisch', 'francais', 'français', 'fr-fr'
      ],
      'it': [
        'it', 'ita', 'italian', 'italienisch', 'italiano', 'it-it'
      ],
      'tr': [
        'tr', 'tur', 'turkish', 'türkisch', 'turkce', 'türkçe', 'tr-tr'
      ],
      'ru': [
        'ru', 'rus', 'russian', 'russisch', 'ru-ru'
      ],
      'ar': [
        'ar', 'ara', 'arabic', 'arabisch', 'ar-sa'
      ],
      'pt': [
        'pt', 'por', 'portuguese', 'portugiesisch', 'português', 'pt-br', 'pt-pt'
      ],
      'nl': [
        'nl', 'dut', 'nla', 'dutch', 'niederländisch', 'nederlands'
      ],
      'pl': [
        'pl', 'pol', 'polish', 'polnisch', 'polski'
      ],
      'no': [
        'no', 'nor', 'norwegian', 'norwegisch', 'norsk', 'nb', 'nn'
      ],
      'hi': [
        'hi', 'hin', 'hindi'
      ],
      'sv': [
        'sv', 'swe', 'swedish', 'schwedisch', 'svenska'
      ],
      'da': [
        'da', 'dan', 'danish', 'dänisch', 'dansk'
      ],
      'fi': [
        'fi', 'fin', 'finnish', 'finnisch', 'suomi'
      ],
      'cs': [
        'cs', 'ces', 'cze', 'czech', 'tschechisch'
      ],
      'hu': [
        'hu', 'hun', 'hungarian', 'ungarisch'
      ],
      'ro': [
        'ro', 'ron', 'rum', 'romanian', 'rumänisch'
      ],
      'el': [
        'el', 'ell', 'gre', 'greek', 'griechisch'
      ],
      'ja': [
        'ja', 'jpn', 'japanese', 'japanisch'
      ],
      'ko': [
        'ko', 'kor', 'korean', 'koreanisch'
      ],
      'zh': [
        'zh', 'zho', 'chi', 'chinese', 'chinesisch'
      ]
    },

    getLanguageDisplayName: function(codeOrName) {
      if (!codeOrName || typeof codeOrName !== 'string') return '';
      var clean = codeOrName.trim().toLowerCase().replace(/[^a-z0-9]/g, '');
      if (clean === 'und' || clean === 'unk' || clean === 'mis' || clean === 'mul' || clean === 'zxx' || clean === 'null' || clean === 'undefined') {
        return '';
      }
      var map = {
        'de': 'Deutsch', 'ger': 'Deutsch', 'deu': 'Deutsch', 'german': 'Deutsch',
        'en': 'English', 'eng': 'English', 'english': 'English',
        'fr': 'Français', 'fre': 'Français', 'fra': 'Français', 'french': 'Français',
        'es': 'Español', 'spa': 'Español', 'spanish': 'Español',
        'it': 'Italiano', 'ita': 'Italiano', 'italian': 'Italiano',
        'tr': 'Türkçe', 'tur': 'Türkçe', 'turkish': 'Türkçe',
        'ru': 'Русский', 'rus': 'Русский', 'russian': 'Русский',
        'ar': 'العربية', 'ara': 'العربية', 'arabic': 'العربية',
        'pt': 'Português', 'por': 'Português', 'portuguese': 'Português',
        'nl': 'Nederlands', 'dut': 'Nederlands', 'nla': 'Nederlands', 'dutch': 'Nederlands',
        'pl': 'Polski', 'pol': 'Polski', 'polish': 'Polski',
        'no': 'Norsk', 'nor': 'Norsk', 'norwegian': 'Norsk',
        'hi': 'Hindi', 'hin': 'Hindi',
        'sv': 'Svenska', 'swe': 'Svenska', 'swedish': 'Svenska',
        'da': 'Dansk', 'dan': 'Dansk', 'danish': 'Dansk',
        'fi': 'Suomi', 'fin': 'Suomi', 'finnish': 'Suomi',
        'cs': 'Čeština', 'ces': 'Čeština', 'cze': 'Čeština', 'czech': 'Čeština',
        'hu': 'Magyar', 'hun': 'Magyar', 'hungarian': 'Magyar',
        'ro': 'Română', 'ron': 'Română', 'rum': 'Română', 'romanian': 'Română',
        'el': 'Ελληνικά', 'ell': 'Ελληνικά', 'gre': 'Ελληνικά', 'greek': 'Ελληνικά',
        'ja': '日本語', 'jpn': '日本語', 'japanese': '日本語',
        'ko': '한국어', 'kor': '한국어', 'korean': '한국어',
        'zh': '中文', 'zho': '中文', 'chi': '中文', 'chinese': '中文'
      };
      if (map[clean]) return map[clean];
      return codeOrName.trim();
    },

    normalizeLanguageCode: function(raw) {
      if (!raw || !String(raw).trim()) return null;
      var cleaned = String(raw).trim().toLowerCase().replace(/[^a-z0-9]/g, '');
      for (var key in this._languageAliases) {
        if (this._languageAliases.hasOwnProperty(key)) {
          if (key === cleaned || this._languageAliases[key].indexOf(cleaned) !== -1) {
            return key;
          }
        }
      }
      return cleaned.length <= 3 ? cleaned : null;
    },

    _tokenize: function(text) {
      if (!text) return [];
      var parts = String(text).toLowerCase().split(/[^a-zA-Z0-9äöüÄÖÜßáéíóúÁÉÍÓÚ]/);
      var tokens = [];
      for (var i = 0; i < parts.length; i++) {
        var p = parts[i].trim();
        if (p && tokens.indexOf(p) === -1) {
          tokens.push(p);
        }
      }
      return tokens;
    },

    matchesLanguage: function(trackLang, trackTitle, targetLang) {
      var targetNormalized = this.normalizeLanguageCode(targetLang);
      if (!targetNormalized) return false;

      // Check language code first
      var langNormalized = this.normalizeLanguageCode(trackLang);
      if (langNormalized && langNormalized === targetNormalized) {
        return true;
      }

      // Check title if present
      if (trackTitle && String(trackTitle).trim()) {
        var titleTokens = this._tokenize(trackTitle);
        var aliases = this._languageAliases[targetNormalized] || [targetNormalized];
        for (var i = 0; i < aliases.length; i++) {
          var alias = aliases[i].toLowerCase();
          if (titleTokens.indexOf(alias) !== -1) {
            return true;
          }
        }
      }
      return false;
    },

    isForced: function(text) {
      if (!text) return false;
      var lower = String(text).toLowerCase();
      return lower.indexOf('forced') !== -1 || lower.indexOf('erzwungen') !== -1;
    },

    isCommentary: function(text) {
      if (!text) return false;
      var lower = String(text).toLowerCase();
      return lower.indexOf('commentary') !== -1 || lower.indexOf('kommentar') !== -1 || lower.indexOf('director') !== -1;
    },

    isSurround: function(text) {
      if (!text) return false;
      var lower = String(text).toLowerCase();
      return lower.indexOf('5.1') !== -1 || lower.indexOf('7.1') !== -1 || lower.indexOf('surround') !== -1 || lower.indexOf('atmos') !== -1;
    },

    findBestAudioTrack: function(tracks, preferredLanguage, targetTitle) {
      if (!tracks || tracks.length === 0) return null;
      if (tracks.length === 1) return tracks[0];

      // 1. If an exact title match was remembered, check for it
      if (targetTitle && String(targetTitle).trim()) {
        var targetLower = String(targetTitle).toLowerCase().trim();
        for (var i = 0; i < tracks.length; i++) {
          var t = tracks[i];
          var titleStr = (t.title || t.name || t.label || t.language || '').toLowerCase().trim();
          if (titleStr === targetLower) {
            return t;
          }
        }
      }

      if (!preferredLanguage || preferredLanguage === 'default' || preferredLanguage === 'original') {
        return null; // Keep player default
      }

      var self = this;
      var matching = tracks.filter(function(t) {
        var tTitle = t.title || t.name || t.label || '';
        if (self.isCommentary(tTitle)) return false;
        var tLang = t.language || t.lang || '';
        return self.matchesLanguage(tLang, tTitle, preferredLanguage);
      });

      if (matching.length === 0) return null;
      if (matching.length === 1) return matching[0];

      // Prefer surround sound (5.1) over stereo
      for (var j = 0; j < matching.length; j++) {
        var m = matching[j];
        var mTitle = m.title || m.name || m.label || '';
        var mChannels = m.channels ? parseInt(String(m.channels).replace(/[^0-9]/g, ''), 10) : 0;
        if (self.isSurround(mTitle) || mChannels > 2) {
          return m;
        }
      }
      return matching[0];
    },

    findBestSubtitleTrack: function(tracks, preferredLanguage, options) {
      if (!tracks || tracks.length === 0) return null;
      options = options || {};
      var isAudioSameLanguage = !!options.isAudioSameLanguage;
      var targetTitle = options.targetTitle;

      if (!preferredLanguage || preferredLanguage.toLowerCase() === 'off' || preferredLanguage.toLowerCase() === 'no') {
        for (var z = 0; z < tracks.length; z++) {
          if (tracks[z].id === 'no') return tracks[z];
        }
        return { id: 'no', label: 'Off / Deaktiviert', title: 'Off', name: 'Off' };
      }

      if (preferredLanguage.toLowerCase() === 'auto') {
        for (var a = 0; a < tracks.length; a++) {
          if (tracks[a].id === 'auto') return tracks[a];
        }
        return { id: 'auto', label: 'Auto / Automatisch', title: 'Auto', name: 'Auto' };
      }

      // 1. If an exact title match was remembered
      if (targetTitle && String(targetTitle).trim()) {
        var targetLower = String(targetTitle).toLowerCase().trim();
        for (var i = 0; i < tracks.length; i++) {
          var t = tracks[i];
          var titleStr = (t.title || t.name || t.label || t.language || '').toLowerCase().trim();
          if (titleStr === targetLower) {
            return t;
          }
        }
      }

      var self = this;
      var matching = tracks.filter(function(t) {
        if (t.id === 'no' || t.id === 'auto') return false;
        var tLang = t.language || t.lang || '';
        var tTitle = t.title || t.name || t.label || '';
        return self.matchesLanguage(tLang, tTitle, preferredLanguage);
      });

      if (matching.length === 0) return null;

      // If current audio is in the same language as user preferred language (e.g. Audio is German):
      // Prioritize forced subtitles if available, otherwise select the full matching subtitles
      if (isAudioSameLanguage) {
        var forced = matching.filter(function(t) {
          return self.isForced(t.title || t.name || t.label);
        });
        if (forced.length > 0) return forced[0];
      }

      // Otherwise, prefer non-forced full subtitles
      var regular = matching.filter(function(t) {
        return !self.isForced(t.title || t.name || t.label);
      });
      if (regular.length > 0) return regular[0];

      return matching[0];
    }
  };
  window.TrackLanguageMatcher = TrackLanguageMatcher;

  TVPlayer.prototype._applyPreferences = function() {
    if (this.videoEl && !this._isResuming && !this._userMuted) {
      this.videoEl.muted = false;
      if (typeof this.videoEl.volume === 'number' && this.videoEl.volume === 0) {
        this.videoEl.volume = 1.0;
      }
    }

    var prefs = window.TVStorage ? window.TVStorage.getPreferences() : { audioLanguage: 'de', subtitleLanguage: 'off' };
    var mediaId = (this.currentVodMeta && (this.currentVodMeta.seriesId || this.currentVodMeta.streamId)) || '';

    // 1. Audio track selection via TrackLanguageMatcher
    var rememberedAudio = (mediaId && window.TVStorage) ? window.TVStorage.getMediaAudioChoice(mediaId) : null;
    var targetAudio = rememberedAudio || prefs.audioLanguage || 'de';

    var audioTracks = this.getAudioTracks();
    var bestAudio = TrackLanguageMatcher.findBestAudioTrack(audioTracks, targetAudio, rememberedAudio);
    console.log('[TrackDebug] _applyPreferences: targetAudio=' + targetAudio + ', rememberedAudio=' + rememberedAudio + ', bestAudio=', bestAudio);

    if (bestAudio && bestAudio.index !== undefined) {
      this.setAudioTrack(bestAudio.index);
    } else if (this.videoEl && this.videoEl.audioTracks && this.videoEl.audioTracks.length > 0) {
      // Ensure at least one track is enabled so sound is never silent
      var hasEnabled = false;
      for (var k = 0; k < this.videoEl.audioTracks.length; k++) {
        if (this.videoEl.audioTracks[k].enabled) {
          hasEnabled = true;
          break;
        }
      }
      if (!hasEnabled && this.videoEl.audioTracks[0]) {
        this.videoEl.audioTracks[0].enabled = true;
      }
    } else if (audioTracks.length > 0 && this._selectedAudioTrackIndex === undefined) {
      this.setAudioTrack(0);
    }

    // 2. Subtitle track selection via TrackLanguageMatcher (Strictly VOD only)
    if (this.playbackType === 'live') {
      this.setSubtitleTrack('off');
      return;
    }

    var rememberedSub = (mediaId && window.TVStorage) ? window.TVStorage.getMediaSubtitleChoice(mediaId) : null;
    var prefSub = (prefs && prefs.subtitleLanguage) ? prefs.subtitleLanguage : 'off';
    var targetSub = rememberedSub || prefSub;

    var subResult = this.getSubtitleTracks();
    var availableSubs = (subResult && subResult.tracks) ? subResult.tracks.filter(function(t) { return t.id !== 'no' && t.id !== 'auto'; }) : [];

    if (availableSubs.length === 0) {
      this.setSubtitleTrack('off');
    } else if (rememberedSub && rememberedSub.toLowerCase() !== 'off' && rememberedSub.toLowerCase() !== 'no' && rememberedSub.toLowerCase() !== 'auto') {
      var matchedRemembered = TrackLanguageMatcher.findBestSubtitleTrack(subResult.tracks, rememberedSub, { targetTitle: rememberedSub });
      if (matchedRemembered && matchedRemembered.id !== 'no' && matchedRemembered.index !== undefined) {
        this.setSubtitleTrack(matchedRemembered.index);
      } else {
        this.setSubtitleTrack('off');
      }
    } else if (prefSub && prefSub.toLowerCase() !== 'off' && prefSub.toLowerCase() !== 'no' && prefSub.toLowerCase() !== 'auto') {
      var activeAudioTrack = bestAudio || audioTracks.find(function(t) { return t.active; }) || audioTracks[0];
      var activeAudioLang = activeAudioTrack ? (activeAudioTrack.language || activeAudioTrack.title) : null;
      var isAudioSame = TrackLanguageMatcher.matchesLanguage(activeAudioLang, null, prefSub);

      var bestSub = TrackLanguageMatcher.findBestSubtitleTrack(subResult.tracks, prefSub, {
        isAudioSameLanguage: isAudioSame
      });
      console.log('[TrackDebug] _applyPreferences: prefSub=' + prefSub + ', isAudioSame=' + isAudioSame + ', bestSub=', bestSub);

      if (bestSub && bestSub.id !== 'no' && bestSub.index !== undefined) {
        this.setSubtitleTrack(bestSub.index);
      } else {
        this.setSubtitleTrack('off');
      }
    } else if (rememberedSub === 'auto' || prefSub === 'auto') {
      // Auto:
      // If audio is foreign vs user language (default 'de'), auto-select full subtitles in user language
      // If audio is in user language, auto-select forced subtitles in user language (if any), else off
      var userLang = (prefs && prefs.audioLanguage && prefs.audioLanguage !== 'original') ? prefs.audioLanguage : ((prefs && prefs.uiLanguage) ? prefs.uiLanguage : 'de');
      var curAudio = bestAudio || audioTracks.find(function(t) { return t.active; }) || audioTracks[0];
      var curAudioLang = curAudio ? (curAudio.language || curAudio.title) : null;
      var isSameAsUser = TrackLanguageMatcher.matchesLanguage(curAudioLang, null, userLang);

      if (!isSameAsUser) {
        var autoSub = TrackLanguageMatcher.findBestSubtitleTrack(subResult.tracks, userLang, { isAudioSameLanguage: false });
        if (autoSub && autoSub.index !== undefined) {
          console.log('[TrackDebug] Auto-activated subtitles for foreign audio:', autoSub);
          this.setSubtitleTrack(autoSub.index);
        } else {
          this.setSubtitleTrack('off');
        }
      } else {
        var forcedSub = availableSubs.find(function(s) {
          var sTitle = s.title || s.name || s.label || '';
          var sLang = s.language || s.lang || '';
          return TrackLanguageMatcher.matchesLanguage(sLang, sTitle, userLang) && TrackLanguageMatcher.isForced(sTitle);
        });
        if (forcedSub && forcedSub.index !== undefined) {
          console.log('[TrackDebug] Auto-activated forced subtitles for native audio:', forcedSub);
          this.setSubtitleTrack(forcedSub.index);
        } else {
          this.setSubtitleTrack('off');
        }
      }
    } else {
      this.setSubtitleTrack('off');
    }
  };

  // Raw Audio & Subtitle Track Queries & Switchers (Matches Windows MediaKit implementation)
  TVPlayer.prototype.getAudioTracks = function() {
    var list = [];
    var metaTracks = (this.currentVodMeta && this.currentVodMeta.audioTracks) ? this.currentVodMeta.audioTracks : [];

    var hasHlsTracks = this.hls && this.hls.audioTracks && this.hls.audioTracks.length > 0;
    // If HLS only has 1 dummy main track, but metadata has multiple real tracks, prefer metadata
    var isHlsDummyOnly = hasHlsTracks && this.hls.audioTracks.length === 1 &&
      (this.hls.audioTracks[0].name === 'main' || this.hls.audioTracks[0].id === -1) &&
      metaTracks.length > 1;

    function cleanAudioField(s) {
      if (!s || typeof s !== 'string') return '';
      var low = s.trim().toLowerCase();
      if (low === 'und' || low === 'unk' || low === 'mis' || low === 'mul' || low === 'zxx' || low === 'null' || low === 'undefined') return '';
      return s.trim();
    }

    function buildAudioLabel(title, lang, fallbackIndex) {
      var cTitle = cleanAudioField(title);
      var cLang = cleanAudioField(lang);
      if (cTitle) return cTitle;
      if (cLang) return cLang;
      return 'Audio ' + (fallbackIndex + 1);
    }

    if (hasHlsTracks && !isHlsDummyOnly) {
      for (var i = 0; i < this.hls.audioTracks.length; i++) {
        var at = this.hls.audioTracks[i];
        var lang = cleanAudioField(at.lang);
        var rawName = cleanAudioField(at.name);
        var displayLabel = buildAudioLabel(rawName, lang, i);
        list.push({
          index: i,
          id: at.id !== undefined ? String(at.id) : String(i),
          name: displayLabel,
          title: displayLabel,
          language: lang,
          lang: lang,
          active: (this.hls.audioTrack === i)
        });
      }
    } else if (this.videoEl && this.videoEl.audioTracks && this.videoEl.audioTracks.length > 0) {
      for (var j = 0; j < this.videoEl.audioTracks.length; j++) {
        var track = this.videoEl.audioTracks[j];
        var mt = metaTracks[j] || null;
        var lang = cleanAudioField(track.language) || (mt && cleanAudioField((mt.tags && mt.tags.language) || mt.language || mt.lang)) || '';
        var rawLabel = cleanAudioField(track.label) || (mt && cleanAudioField((mt.tags && mt.tags.title) || mt.title || mt.name)) || '';
        var displayLabel = buildAudioLabel(rawLabel, lang, j);
        var codec = (mt && (mt.codec_name || mt.codec)) || '';
        var ch = (mt && (mt.channels || mt.channel_layout)) || '';

        list.push({
          index: j,
          id: track.id || String(j),
          name: displayLabel,
          title: displayLabel,
          language: lang,
          lang: lang,
          channels: ch,
          codec: codec,
          active: !!track.enabled
        });
      }
    } else if (metaTracks.length > 0) {
      for (var m = 0; m < metaTracks.length; m++) {
        var mtItem = metaTracks[m];
        var mLang = cleanAudioField((mtItem.tags && mtItem.tags.language) || mtItem.language || mtItem.lang);
        var mTitle = cleanAudioField((mtItem.tags && mtItem.tags.title) || mtItem.title || mtItem.name);
        var displayLabel = buildAudioLabel(mTitle, mLang, m);
        var mCodec = mtItem.codec_name || mtItem.codec || '';
        var mCh = mtItem.channels || mtItem.channel_layout || '';
        var isAct = (this._selectedAudioTrackIndex !== undefined)
          ? (this._selectedAudioTrackIndex === m)
          : (m === 0);

        list.push({
          index: m,
          id: mtItem.id !== undefined ? String(mtItem.id) : String(m),
          name: displayLabel,
          title: displayLabel,
          language: mLang,
          lang: mLang,
          channels: mCh,
          codec: mCodec,
          active: isAct
        });
      }
    }
    list.forEach(function(item, idx) {
      console.log('[AudioState:C-Selectable] Track #' + idx + ' "' + item.title + '" (' + (item.codec || 'audio') + ') selectable in UI (active=' + item.active + ')');
    });
    console.log('[TrackDebug] getAudioTracks: total=' + list.length + ' (source=' + (hasHlsTracks && !isHlsDummyOnly ? 'HLS' : (this.videoEl && this.videoEl.audioTracks && this.videoEl.audioTracks.length > 0 ? 'videoEl' : (metaTracks.length > 0 ? 'metaTracks' : 'none'))) + '):', list);
    return list;
  };

  TVPlayer.prototype.setAudioTrack = function(index) {
    console.log('[AudioState:D-Activated] setAudioTrack requested for index:', index);
    this._selectedAudioTrackIndex = index;
    if (this.videoEl) {
      this.videoEl.muted = false;
      if (typeof this.videoEl.volume === 'number' && this.videoEl.volume === 0) {
        this.videoEl.volume = 1.0;
      }
    }
    var banner = document.getElementById('player-unmute-banner');
    if (banner) banner.style.display = 'none';

    // State E: Decodability Verification
    var audioList = this.getAudioTracks();
    var selectedTrack = audioList[index] || null;
    var codec = (selectedTrack && (selectedTrack.codec || selectedTrack.codec_name)) || 'unknown';
    var platform = (window.MediaDiagnostics && window.MediaDiagnostics.detectPlatform) ? window.MediaDiagnostics.detectPlatform() : {};
    var isDecodable = true;
    var decodableReason = 'Native/Hardware supported';
    if (/ac-?3|dolby/i.test(codec)) {
      if (platform.isRealTv || platform.isEdge) {
        isDecodable = true;
        decodableReason = 'Hardware DSP active (LG webOS / Tizen / Edge MFT)';
      } else {
        isDecodable = false;
        decodableReason = 'Patent-restricted in Desktop Chromium Simulator (video decodes, audio is silent)';
      }
    }
    console.log('[AudioState:E-Decodable] Track #' + index + ' (' + codec + ') -> ' + (isDecodable ? 'DECODABLE' : 'LIMITED') + ' (' + decodableReason + ')');

    if (this.hls && this.hls.audioTracks && this.hls.audioTracks[index]) {
      console.log('[TrackDebug] Setting Hls audioTrack =', index, this.hls.audioTracks[index]);
      this.hls.audioTrack = index;
    } else if (this.videoEl && this.videoEl.audioTracks && this.videoEl.audioTracks.length > 0) {
      if (this.videoEl.audioTracks[index]) {
        for (var i = 0; i < this.videoEl.audioTracks.length; i++) {
          this.videoEl.audioTracks[i].enabled = (i === index);
        }
      } else {
        // Safe fallback: guarantee at least primary audioTrack remains enabled
        this.videoEl.audioTracks[0].enabled = true;
      }
    }
    if (window.webapis && window.webapis.avplay && typeof window.webapis.avplay.setSelectTrack === 'function') {
      try {
        window.webapis.avplay.setSelectTrack('AUDIO', index);
      } catch(e){}
    }
  };

  TVPlayer.prototype.getSubtitleTracks = function() {
    if (this.playbackType === 'live') {
      return { current: null, tracks: [], isOff: true };
    }
    var list = [];
    var hasActive = false;
    var metaSubs = (this.currentVodMeta && this.currentVodMeta.subtitleTracks) ? this.currentVodMeta.subtitleTracks : [];

    function cleanSubField(s) {
      if (!s || typeof s !== 'string') return '';
      var low = s.trim().toLowerCase();
      if (low === 'und' || low === 'unk' || low === 'mis' || low === 'mul' || low === 'zxx' || low === 'null' || low === 'undefined') return '';
      return s.trim();
    }

    function buildSubLabel(title, lang, fallbackIndex) {
      var cTitle = cleanSubField(title);
      var cLang = cleanSubField(lang);
      if (cTitle) return cTitle;
      if (cLang) return cLang;
      return 'Subtitle ' + (fallbackIndex + 1);
    }

    // 0. Custom loaded WebVTT / SRT subtitle tracks (High reliability on Smart TVs)
    if (this._customSubtitles && this._customSubtitles.length > 0) {
      for (var c = 0; c < this._customSubtitles.length; c++) {
        var cust = this._customSubtitles[c];
        var isCustAct = (this._selectedSubTrackIndex === ('custom_' + c));
        if (isCustAct) hasActive = true;
        var sLabel = buildSubLabel(cust.title || cust.name, cust.lang || cust.language, c);
        list.push({
          index: 'custom_' + c,
          id: cust.id || ('custom_' + c),
          name: sLabel,
          title: sLabel,
          language: cleanSubField(cust.lang || cust.language),
          lang: cleanSubField(cust.lang || cust.language),
          isExternal: true,
          active: isCustAct,
          cues: cust.cues
        });
      }
    }

    var hasHlsSubs = this.hls && this.hls.subtitleTracks && this.hls.subtitleTracks.length > 0;
    var hasVideoElSubs = this.videoEl && this.videoEl.textTracks && this.videoEl.textTracks.length > 0;

    if (hasHlsSubs) {
      for (var i = 0; i < this.hls.subtitleTracks.length; i++) {
        var st = this.hls.subtitleTracks[i];
        var isAct = (this.hls.subtitleTrack === i);
        if (isAct) hasActive = true;
        var sLang = cleanSubField(st.lang);
        var sDisplay = buildSubLabel(st.name || st.title || st.label, sLang, i);
        list.push({
          index: i,
          id: st.id !== undefined ? String(st.id) : String(i),
          name: sDisplay,
          title: sDisplay,
          language: sLang,
          lang: sLang,
          active: isAct
        });
      }
    } else if (metaSubs && metaSubs.length > 0) {
      // Prioritize demuxed/API metadata subtitle tracks over empty/dummy videoEl.textTracks
      for (var s = 0; s < metaSubs.length; s++) {
        var smtItem = metaSubs[s];
        var sTitle = (typeof smtItem === 'string') ? smtItem : ((smtItem.tags && smtItem.tags.title) || smtItem.title || smtItem.name || '');
        var sLang = (typeof smtItem === 'string') ? '' : ((smtItem.tags && smtItem.tags.language) || smtItem.language || smtItem.lang || '');
        var sId = (typeof smtItem === 'object' && smtItem.id !== undefined) ? String(smtItem.id) : String(s);
        var displayTitle = buildSubLabel(sTitle, sLang, s);
        var isSubAct = (this._selectedSubTrackIndex !== undefined && (this._selectedSubTrackIndex === s || this._selectedSubTrackIndex === sId));
        if (isSubAct) hasActive = true;
        var sUrl = (typeof smtItem === 'object' && smtItem) ? (smtItem.url || smtItem.link || smtItem.file || smtItem.src || smtItem.path || '') : '';

        list.push({
          index: s,
          streamIndex: (typeof smtItem === 'object' && smtItem.streamIndex !== undefined) ? smtItem.streamIndex : s,
          id: sId,
          name: displayTitle,
          title: displayTitle,
          language: cleanSubField(sLang),
          lang: cleanSubField(sLang),
          url: sUrl,
          isExternal: !!sUrl,
          isEmbedded: !sUrl,
          cues: (smtItem && smtItem.cues) || null,
          active: isSubAct
        });
      }
    } else if (hasVideoElSubs) {
      for (var j = 0; j < this.videoEl.textTracks.length; j++) {
        var tt = this.videoEl.textTracks[j];
        var isShowing = (tt.mode === 'showing' || tt.mode === 'hidden');
        if (isShowing) hasActive = true;
        var lang = cleanSubField(tt.language) || '';
        var rawLabel = cleanSubField(tt.label) || '';
        var displayLabel = buildSubLabel(rawLabel, lang, j);
        list.push({
          index: j,
          id: tt.id || String(j),
          name: displayLabel,
          title: displayLabel,
          language: lang,
          lang: lang,
          active: isShowing
        });
      }
    }

    console.log('[TrackDebug] getSubtitleTracks: total=' + list.length + ' (source=' + (hasHlsSubs ? 'HLS' : (hasVideoElSubs ? 'videoEl' : (metaSubs.length > 0 ? 'metaSubs' : 'none'))) + ', isOff=' + (!hasActive) + '):', list);
    return { tracks: list, isOff: !hasActive };
  };

  TVPlayer.prototype.setSubtitleTrack = function(index) {
    console.log('[TrackDebug] setSubtitleTrack to index:', index);
    if (index === -1 || index === 'off' || index === 'no') {
      this._selectedSubTrackIndex = -1;
      this._activeSubtitleCues = null;
      this.renderSubtitle(null);
      if (this.hls) {
        this.hls.subtitleDisplay = false;
        this.hls.subtitleTrack = -1;
      }
      if (this.videoEl && this.videoEl.textTracks) {
        for (var k = 0; k < this.videoEl.textTracks.length; k++) {
          this.videoEl.textTracks[k].mode = 'disabled';
        }
      }
    } else if (typeof index === 'string' && index.indexOf('custom_') === 0) {
      var cIdx = parseInt(index.replace('custom_', ''), 10);
      var cTrack = (this._customSubtitles && this._customSubtitles[cIdx]) ? this._customSubtitles[cIdx] : null;
      this._selectedSubTrackIndex = index;
      if (cTrack && cTrack.cues) {
        this._activeSubtitleCues = cTrack.cues;
        console.log('[SubtitlePipeline] Activated custom external subtitle track:', cTrack.name, 'with', cTrack.cues.length, 'cues');
      }
      this._updateSubtitles();
    } else {
      this._selectedSubTrackIndex = index;
      var subInfo = this.getSubtitleTracks();
      var trackObj = null;
      if (subInfo && subInfo.tracks) {
        if (typeof index === 'number' && subInfo.tracks[index]) {
          trackObj = subInfo.tracks[index];
        } else {
          trackObj = subInfo.tracks.find(function(t) { return t.index === index || t.id === index; });
        }
      }

      // Auto-fetch if track has an external URL
      if (trackObj && trackObj.url && window.TVSubtitles) {
        console.log('[SubtitlePipeline] Subtitle track has URL, fetching and activating:', trackObj.url);
        window.TVSubtitles.loadSubtitle(trackObj.url, trackObj.lang, trackObj.title, this).catch(function(e) {
          console.warn('[SubtitlePipeline] Failed to load subtitle URL:', e);
        });
      }

      var isForced = trackObj && window.TrackLanguageMatcher && window.TrackLanguageMatcher.isForced(trackObj.title || trackObj.name);

      if (isForced) {
        console.log('[SubtitlePipeline] Active subtitle track is FORCED: Dialogue subtitles only display during foreign-language scenes.');
        if (typeof showToast === 'function') {
          var isDe = window.TVI18n && window.TVI18n.getLanguage() === 'de';
          showToast(isDe ? 'Untertitel: Forced (nur bei Fremdsprachen aktiv)' : 'Subtitles: Forced (displays only during foreign-language dialogue)', '💬', 3500);
        }
      }

      if (trackObj && trackObj.cues && trackObj.cues.length > 0) {
        this._activeSubtitleCues = trackObj.cues;
        console.log('[SubtitlePipeline] Activated cached cues for track:', trackObj.title, 'count=', trackObj.cues.length);
        this._updateSubtitles();
      } else if (this.hls && this.hls.subtitleTracks && this.hls.subtitleTracks[index]) {
        console.log('[SubtitlePipeline:Tier1] Setting Hls subtitleTrack =', index, this.hls.subtitleTracks[index]);
        this.hls.subtitleDisplay = true;
        this.hls.subtitleTrack = index;
      } else if (this.videoEl && this.videoEl.textTracks && this.videoEl.textTracks.length > 0) {
        console.log('[SubtitlePipeline:Tier1/2] Activating native textTrack =', index);
        var self = this;
        var hasMatchedTextTrack = false;
        for (var l = 0; l < this.videoEl.textTracks.length; l++) {
          var tt = this.videoEl.textTracks[l];
          var matchesIdx = (l === index);
          var matchesLang = (trackObj && trackObj.lang && tt.language && tt.language.toLowerCase() === trackObj.lang.toLowerCase());
          if (matchesIdx || (!hasMatchedTextTrack && matchesLang)) {
            tt.mode = 'showing';
            tt.oncuechange = function() { self._updateSubtitles(); };
            hasMatchedTextTrack = true;
          } else {
            tt.mode = 'disabled';
          }
        }
        if (!hasMatchedTextTrack && trackObj && trackObj.url && window.TVSubtitles && typeof window.TVSubtitles.loadSubtitle === 'function') {
          window.TVSubtitles.loadSubtitle(trackObj.url, trackObj.lang || trackObj.language, trackObj.title || trackObj.name, self).catch(function(e){});
        }
      } else if (trackObj && trackObj.url && window.TVSubtitles && typeof window.TVSubtitles.loadSubtitle === 'function') {
        var self2 = this;
        window.TVSubtitles.loadSubtitle(trackObj.url, trackObj.lang || trackObj.language, trackObj.title || trackObj.name, self2).then(function(loaded) {
          if (loaded && loaded.cues) {
            trackObj.cues = loaded.cues;
            if (self2.currentVodMeta && self2.currentVodMeta.subtitleTracks && self2.currentVodMeta.subtitleTracks[index]) {
              self2.currentVodMeta.subtitleTracks[index].cues = loaded.cues;
            }
            self2._activeSubtitleCues = loaded.cues;
            self2._updateSubtitles();
          }
        }).catch(function(e) {
          console.warn('[SubtitlePipeline] Subtitle load failed:', e);
        });
      } else if (trackObj && window.TVSubtitles && typeof window.TVSubtitles.fetchTrackSubtitle === 'function') {
        var self3 = this;
        var curMeta = this.currentVodMeta || this.currentStream;
        console.log('[SubtitlePipeline:Tier3] On-demand fetching cues for embedded track:', trackObj.title, trackObj.lang);
        window.TVSubtitles.fetchTrackSubtitle(curMeta, trackObj).then(function(subRes) {
          if (subRes && subRes.cues && subRes.cues.length > 0) {
            trackObj.cues = subRes.cues;
            if (self3.currentVodMeta && self3.currentVodMeta.subtitleTracks && self3.currentVodMeta.subtitleTracks[index]) {
              self3.currentVodMeta.subtitleTracks[index].cues = subRes.cues;
            }
            if (self3._selectedSubTrackIndex === index) {
              self3._activeSubtitleCues = subRes.cues;
              self3._updateSubtitles();
              console.log('[SubtitlePipeline] Activated on-demand cues for track:', trackObj.title, 'count=', subRes.cues.length);
            }
          }
        }).catch(function(err) {
          console.warn('[SubtitlePipeline] On-demand subtitle fetch error:', err);
        });
      }
      this._updateSubtitles();
    }
    if (window.webapis && window.webapis.avplay && typeof window.webapis.avplay.setSelectTrack === 'function') {
      try {
        if (index === -1 || index === 'off' || index === 'no') {
          // Off
        } else if (typeof index === 'number') {
          window.webapis.avplay.setSelectTrack('TEXT', index);
        }
      } catch(e){}
    }
  };

  // Volume & Audio Controls
  TVPlayer.prototype.getVolume = function() {
    return this.videoEl ? this.videoEl.volume : 1;
  };

  TVPlayer.prototype.setVolume = function(level) {
    if (!this.videoEl) return;
    var v = Math.max(0, Math.min(1, level));
    this.videoEl.volume = v;
    if (v > 0) this.videoEl.muted = false;
  };

  TVPlayer.prototype.volumeUp = function() {
    if (!this.videoEl) return;
    this.setVolume(this.videoEl.volume + 0.05);
  };

  TVPlayer.prototype.volumeDown = function() {
    if (!this.videoEl) return;
    this.setVolume(this.videoEl.volume - 0.05);
  };

  TVPlayer.prototype.toggleMute = function() {
    if (!this.videoEl) return;
    this.videoEl.muted = !this.videoEl.muted;
  };

  TVPlayer.prototype.showVolumeIndicator = function() {
    // Volume bar removed for all platforms - native TV hardware handles volume HUD
    return;
  };

  window.getLanguageDisplayName = function(c) {
    return TrackLanguageMatcher.getLanguageDisplayName(c);
  };
  window.TVPlayer = TVPlayer;
})();
