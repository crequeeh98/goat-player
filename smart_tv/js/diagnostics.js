// Media Diagnostic Layer & Compatibility Checker for LG webOS TV & Samsung Tizen
// Provides comprehensive stream analysis, HLS manifest parsing, container sniffing, and hardware compatibility checking
(function() {
  'use strict';

  var MediaDiagnostics = {
    // Detect host environment
    detectPlatform: function() {
      var ua = navigator.userAgent || '';
      var isWebOS = /webOS|Web0S|NetCast/i.test(ua) || !!window.webOS;
      var isTizen = /Tizen/i.test(ua) || !!window.tizen;
      // webOS Simulator runs desktop Chromium (e.g. x86_64, Windows/Linux/Mac) without webOS hardware DSPs
      var isSimulator = isWebOS && (/Windows|Macintosh|Linux x86_64/i.test(ua) && !/SmartTV|LG NetCast/i.test(ua));
      var isEdge = /Edg\//i.test(ua);

      return {
        isWebOS: isWebOS,
        isTizen: isTizen,
        isSimulator: isSimulator,
        isRealTv: (isWebOS || isTizen) && !isSimulator,
        isEdge: isEdge,
        userAgent: ua
      };
    },

    // Check codec compatibility against HTML5 video element and platform capabilities
    checkCompatibility: function(streamMeta, videoEl) {
      var platform = this.detectPlatform();
      var el = videoEl || document.createElement('video');
      var container = (streamMeta.container || '').toLowerCase();
      var protocol = (streamMeta.protocol || '').toLowerCase();
      var vCodec = (streamMeta.videoCodec || '').toLowerCase();
      var aCodec = (streamMeta.audioCodec || '').toLowerCase();

      var reasons = [];
      var status = 'SUPPORTED'; // 'SUPPORTED' | 'LIMITED' | 'UNSUPPORTED' | 'UNKNOWN'

      // 1. Container & Protocol Checks
      if (protocol === 'hls' || container === 'm3u8') {
        var canNativeHls = !!(el.canPlayType('application/vnd.apple.mpegurl') || el.canPlayType('application/x-mpegURL'));
        if (!canNativeHls && !window.Hls) {
          status = 'UNSUPPORTED';
          reasons.push('HLS protocol not supported natively and no Hls.js fallback available');
        } else if (!canNativeHls && window.Hls && platform.isSimulator) {
          // Simulator running MSE HLS
          status = 'LIMITED';
          reasons.push('Simulator plays HLS via MSE/Hls.js; real webOS TV uses native hardware pipeline');
        }
      } else if (container === 'ts' || container === 'mpegts') {
        var canNativeTs = !!(el.canPlayType('video/mp2t') || el.canPlayType('video/ts'));
        if (!canNativeTs) {
          if (platform.isRealTv) {
            // Real webOS & Tizen play MPEG-TS via media pipeline
            status = 'SUPPORTED';
          } else {
            status = 'UNSUPPORTED';
            reasons.push('MPEG-TS container unsupported in desktop Chromium simulator without transmuxing');
          }
        }
      } else if (container === 'mkv') {
        var canMkv = !!(el.canPlayType('video/x-matroska') || el.canPlayType('video/mkv'));
        if (!canMkv && !platform.isRealTv) {
          status = 'LIMITED';
          reasons.push('MKV container canPlayType returned empty; playback depends on underlying Chromium ffmpeg build');
        }
      }

      // 2. Video Codec Checks
      if (vCodec) {
        if (vCodec.indexOf('hevc') !== -1 || vCodec.indexOf('hvc1') !== -1 || vCodec.indexOf('hev1') !== -1 || vCodec.indexOf('h265') !== -1) {
          var canHevc = !!(el.canPlayType('video/mp4; codecs="hvc1.1.6.L93.B0"') || el.canPlayType('video/mp4; codecs="hevc"'));
          if (!canHevc && !platform.isRealTv) {
            status = 'LIMITED';
            reasons.push('HEVC/H.265 not supported by simulator browser (requires GPU HEVC decoder or real TV hardware)');
          }
        } else if (vCodec.indexOf('avc') !== -1 || vCodec.indexOf('h264') !== -1) {
          // AVC is universally supported
        } else if (vCodec.indexOf('mpeg2') !== -1 || vCodec.indexOf('mp2v') !== -1) {
          if (!platform.isRealTv) {
            status = 'LIMITED';
            reasons.push('MPEG-2 video supported in hardware on real webOS TV; may not decode in simulator browser');
          }
        } else if (vCodec.indexOf('av1') !== -1 || vCodec.indexOf('vp9') !== -1) {
          // Modern codecs
        } else {
          status = 'LIMITED';
          reasons.push('Unknown or uncommon video codec: ' + vCodec);
        }
      }

      // 3. Audio Codec Checks
      if (aCodec) {
        if (aCodec.indexOf('ac3') !== -1 || aCodec.indexOf('ac-3') !== -1 || aCodec.indexOf('dolby') !== -1) {
          var canAc3 = !!(el.canPlayType('audio/mp4; codecs="ac-3"') || el.canPlayType('video/x-matroska; codecs="ac-3"'));
          if (!canAc3) {
            if (platform.isRealTv) {
              // Real TV hardware decodes AC-3
              status = status === 'UNSUPPORTED' ? 'UNSUPPORTED' : 'SUPPORTED';
            } else if (platform.isEdge) {
              // Edge uses Windows Media Foundation Dolby decoders
              status = status === 'UNSUPPORTED' ? 'UNSUPPORTED' : 'SUPPORTED';
            } else {
              // Desktop Chromium simulator: video decodes, audio is silent!
              if (status !== 'UNSUPPORTED') status = 'LIMITED';
              reasons.push('Dolby AC-3 audio lacks patent licenses in desktop Chromium simulator (audio silent; works on real TV & Edge)');
            }
          }
        } else if (aCodec.indexOf('eac3') !== -1 || aCodec.indexOf('ec-3') !== -1 || aCodec.indexOf('ddp') !== -1) {
          var canEac3 = !!(el.canPlayType('audio/mp4; codecs="ec-3"'));
          if (!canEac3) {
            if (platform.isRealTv || platform.isEdge) {
              status = status === 'UNSUPPORTED' ? 'UNSUPPORTED' : 'SUPPORTED';
            } else {
              if (status !== 'UNSUPPORTED') status = 'LIMITED';
              reasons.push('Dolby Digital Plus (E-AC-3) not licensed in simulator (silent; works on real TV & Edge)');
            }
          }
        } else if (aCodec.indexOf('dts') !== -1) {
          status = 'LIMITED';
          reasons.push('DTS audio is model-dependent on LG webOS TVs (supported on webOS 23+ OLEDs, absent on older models)');
        }
      }

      // 4. Subtitle Checks
      if (streamMeta.subtitles && streamMeta.subtitles.length > 0) {
        var hasEmbeddedSub = streamMeta.subtitles.some(function(s) {
          return s.format === 'subrip' || s.codec === 'subrip' || s.codec === 'text' || s.type === 'embedded';
        });
        if (hasEmbeddedSub && container === 'mkv') {
          reasons.push('Embedded MKV SubRip subtitles require cue extraction fallback (browser native <video> does not populate textTracks from MKV text streams)');
        }
      }

      return {
        status: status,
        reasons: reasons,
        isSupported: status === 'SUPPORTED',
        isLimited: status === 'LIMITED',
        isUnsupported: status === 'UNSUPPORTED',
        platform: platform
      };
    },

    // Probe an HTTP URL to extract headers, MIME type, redirects, CORS
    probeUrlHeaders: function(url) {
      if (!url || typeof fetch !== 'function') {
        return Promise.resolve({ error: 'Fetch unavailable' });
      }

      var controller = (typeof AbortController === 'function') ? new AbortController() : null;
      var timeout = setTimeout(function() {
        if (controller) { try { controller.abort(); } catch(e){} }
      }, 5000);

      var fetchOpts = {
        method: 'HEAD',
        headers: { 'Range': 'bytes=0-1' }
      };
      if (controller) fetchOpts.signal = controller.signal;

      return fetch(url, fetchOpts).then(function(res) {
        clearTimeout(timeout);
        var headers = {};
        if (res.headers && typeof res.headers.forEach === 'function') {
          res.headers.forEach(function(val, key) {
            headers[key.toLowerCase()] = val;
          });
        }
        return {
          status: res.status,
          statusText: res.statusText,
          ok: res.ok || res.status === 206 || res.status === 200,
          redirected: res.redirected,
          finalUrl: res.url || url,
          contentType: headers['content-type'] || '',
          contentLength: headers['content-length'] || '',
          server: headers['server'] || '',
          acceptRanges: headers['accept-ranges'] || '',
          cors: headers['access-control-allow-origin'] || '',
          headers: headers
        };
      }).catch(function(err) {
        clearTimeout(timeout);
        // Fallback: try GET with 1 byte range if HEAD returned 405 Method Not Allowed
        var getController = (typeof AbortController === 'function') ? new AbortController() : null;
        var getTimeout = setTimeout(function() {
          if (getController) { try { getController.abort(); } catch(e){} }
        }, 5000);
        var getOpts = { method: 'GET', headers: { 'Range': 'bytes=0-1' } };
        if (getController) getOpts.signal = getController.signal;

        return fetch(url, getOpts).then(function(res) {
          clearTimeout(getTimeout);
          var headers = {};
          if (res.headers && typeof res.headers.forEach === 'function') {
            res.headers.forEach(function(val, key) { headers[key.toLowerCase()] = val; });
          }
          return {
            status: res.status,
            statusText: res.statusText,
            ok: res.ok || res.status === 206,
            redirected: res.redirected,
            finalUrl: res.url || url,
            contentType: headers['content-type'] || '',
            contentLength: headers['content-length'] || '',
            server: headers['server'] || '',
            acceptRanges: headers['accept-ranges'] || '',
            cors: headers['access-control-allow-origin'] || '',
            headers: headers
          };
        }).catch(function(err2) {
          clearTimeout(getTimeout);
          return {
            status: 0,
            statusText: 'Network Error',
            ok: false,
            error: err2 && err2.message ? err2.message : String(err2)
          };
        });
      });
    },

    // Parse HLS M3U8 manifest content into structured inspection object
    parseHlsManifest: function(manifestText, baseUrl) {
      if (!manifestText || typeof manifestText !== 'string') {
        return { isMaster: false, isMedia: false, variants: [], mediaGroups: [], segments: [] };
      }

      var lines = manifestText.split(/\r?\n/);
      var isMaster = false;
      var variants = [];
      var audioGroups = [];
      var subtitleGroups = [];
      var segments = [];
      var targetDuration = 0;

      for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (!line) continue;

        if (line.indexOf('#EXT-X-STREAM-INF:') === 0) {
          isMaster = true;
          var attrs = line.substring(18);
          var variant = {
            raw: line,
            bandwidth: 0,
            resolution: '',
            codecs: '',
            audioGroup: '',
            subtitleGroup: '',
            url: ''
          };

          var bwMatch = attrs.match(/BANDWIDTH=(\d+)/i);
          if (bwMatch) variant.bandwidth = parseInt(bwMatch[1], 10);

          var resMatch = attrs.match(/RESOLUTION=([0-9x]+)/i);
          if (resMatch) variant.resolution = resMatch[1];

          var codeMatch = attrs.match(/CODECS="([^"]+)"/i);
          if (codeMatch) variant.codecs = codeMatch[1];

          var aMatch = attrs.match(/AUDIO="([^"]+)"/i);
          if (aMatch) variant.audioGroup = aMatch[1];

          var sMatch = attrs.match(/SUBTITLES="([^"]+)"/i);
          if (sMatch) variant.subtitleGroup = sMatch[1];

          // Next line is the variant URL
          if (i + 1 < lines.length && lines[i + 1].trim() && lines[i + 1].trim()[0] !== '#') {
            variant.url = lines[i + 1].trim();
            if (baseUrl && variant.url.indexOf('://') === -1) {
              try {
                variant.url = new URL(variant.url, baseUrl).href;
              } catch(e){}
            }
            i++;
          }
          variants.push(variant);

        } else if (line.indexOf('#EXT-X-MEDIA:') === 0) {
          var mAttrs = line.substring(13);
          var media = { raw: line, type: '', groupId: '', name: '', lang: '', isDefault: false, isAutoselect: false, uri: '' };

          var typeMatch = mAttrs.match(/TYPE=([A-Z]+)/i);
          if (typeMatch) media.type = typeMatch[1].toUpperCase();

          var gMatch = mAttrs.match(/GROUP-ID="([^"]+)"/i);
          if (gMatch) media.groupId = gMatch[1];

          var nMatch = mAttrs.match(/NAME="([^"]+)"/i);
          if (nMatch) media.name = nMatch[1];

          var lMatch = mAttrs.match(/LANGUAGE="([^"]+)"/i);
          if (lMatch) media.lang = lMatch[1];

          var dMatch = mAttrs.match(/DEFAULT=(YES|NO)/i);
          if (dMatch) media.isDefault = (dMatch[1].toUpperCase() === 'YES');

          var uMatch = mAttrs.match(/URI="([^"]+)"/i);
          if (uMatch) {
            media.uri = uMatch[1];
            if (baseUrl && media.uri.indexOf('://') === -1) {
              try { media.uri = new URL(media.uri, baseUrl).href; } catch(e){}
            }
          }

          if (media.type === 'AUDIO') {
            audioGroups.push(media);
          } else if (media.type === 'SUBTITLES') {
            subtitleGroups.push(media);
          }

        } else if (line.indexOf('#EXT-X-TARGETDURATION:') === 0) {
          targetDuration = parseFloat(line.substring(22)) || 0;
        } else if (line.indexOf('#EXTINF:') === 0) {
          var durMatch = line.match(/#EXTINF:([0-9.]+)/i);
          var segDur = durMatch ? parseFloat(durMatch[1]) : 0;
          var segUrl = '';
          if (i + 1 < lines.length && lines[i + 1].trim() && lines[i + 1].trim()[0] !== '#') {
            segUrl = lines[i + 1].trim();
            if (baseUrl && segUrl.indexOf('://') === -1) {
              try { segUrl = new URL(segUrl, baseUrl).href; } catch(e){}
            }
            i++;
          }
          segments.push({ duration: segDur, url: segUrl });
        }
      }

      return {
        isMaster: isMaster,
        isMedia: !isMaster && segments.length > 0,
        targetDuration: targetDuration,
        variants: variants,
        audioGroups: audioGroups,
        subtitleGroups: subtitleGroups,
        segmentsCount: segments.length,
        sampleSegments: segments.slice(0, 5)
      };
    },

    // Comprehensive stream probe (Extracts 25+ parameters requested by specification)
    probeStream: function(url, streamMeta, options) {
      var self = this;
      var meta = streamMeta || {};
      var opts = options || {};
      // Default to passive mode (skipNetwork: true) during playback to protect max_connections: 1 IPTV accounts
      var skipNetwork = (opts.skipNetwork !== undefined) ? !!opts.skipNetwork : true;
      var cleanUrl = (url || '').split('?')[0];
      var ext = '';
      var extMatch = cleanUrl.match(/\.([a-z0-9]+)$/i);
      if (extMatch) ext = extMatch[1].toLowerCase();

      var isHls = ext === 'm3u8' || (url && url.indexOf('.m3u8') !== -1);
      var isMkv = ext === 'mkv';
      var isMp4 = ext === 'mp4';
      var isTs = ext === 'ts';

      var diagnosticData = {
        timestamp: new Date().toISOString(),
        url: url,
        cleanUrl: cleanUrl,
        container: isHls ? 'm3u8' : (isMkv ? 'mkv' : (isMp4 ? 'mp4' : (isTs ? 'ts' : (ext || 'unknown')))),
        protocol: isHls ? 'hls' : ((url && url.indexOf('https:') === 0) ? 'https' : 'http'),
        mimeType: isHls ? 'application/vnd.apple.mpegurl' : (isMkv ? 'video/x-matroska' : (isMp4 ? 'video/mp4' : (isTs ? 'video/mp2t' : 'video/*'))),
        videoCodec: meta.videoCodec || meta.codec_name || '',
        videoProfile: meta.profile || '',
        videoLevel: meta.level || '',
        resolution: (meta.width && meta.height) ? (meta.width + 'x' + meta.height) : (meta.resolution || ''),
        fps: meta.fps || meta.r_frame_rate || '',
        bitrate: meta.bitrate || meta.bit_rate || '',
        audioCodec: meta.audioCodec || (meta.audioTracks && meta.audioTracks[0] && meta.audioTracks[0].codec) || '',
        audioChannels: (meta.audioTracks && meta.audioTracks[0] && (meta.audioTracks[0].channels || meta.audioTracks[0].channel_layout)) || '',
        sampleRate: meta.sample_rate || '',
        language: (meta.audioTracks && meta.audioTracks[0] && (meta.audioTracks[0].lang || meta.audioTracks[0].language)) || '',
        numberOfAudioTracks: meta.audioTracks ? meta.audioTracks.length : 0,
        numberOfSubtitleTracks: meta.subtitleTracks ? meta.subtitleTracks.length : 0,
        subtitleFormat: (meta.subtitleTracks && meta.subtitleTracks[0] && (meta.subtitleTracks[0].codec || meta.subtitleTracks[0].format)) || '',
        hlsMaster: null,
        hlsVariants: [],
        extXMedia: [],
        extXStreamInf: [],
        codecs: '',
        bandwidth: '',
        audioGroups: [],
        subtitleGroups: [],
        segmentDuration: 0,
        segmentAlignment: 'unknown',
        httpHeaders: null,
        compatibility: null
      };

      // Probe HTTP headers only if explicitly enabled
      var headerPromise = Promise.resolve();
      if (!skipNetwork) {
        headerPromise = self.probeUrlHeaders(url).then(function(headerResult) {
          diagnosticData.httpHeaders = headerResult;
          if (headerResult.contentType) {
            diagnosticData.mimeType = headerResult.contentType.split(';')[0].trim();
          }
        });
      }

      // If HLS, fetch and parse master/variant playlist only if explicitly enabled
      var hlsPromise = Promise.resolve();
      if (!skipNetwork && isHls && typeof fetch === 'function') {
        hlsPromise = fetch(url).then(function(res) {
          if (!res.ok) throw new Error('HTTP ' + res.status);
          return res.text();
        }).then(function(text) {
          var parsed = self.parseHlsManifest(text, url);
          diagnosticData.hlsMaster = parsed.isMaster;
          diagnosticData.hlsVariants = parsed.variants;
          diagnosticData.audioGroups = parsed.audioGroups;
          diagnosticData.subtitleGroups = parsed.subtitleGroups;
          diagnosticData.segmentDuration = parsed.targetDuration;
          if (parsed.variants.length > 0) {
            diagnosticData.codecs = parsed.variants.map(function(v){ return v.codecs; }).filter(Boolean).join(', ');
            diagnosticData.bandwidth = parsed.variants.map(function(v){ return v.bandwidth; }).filter(Boolean).join(', ');
            if (parsed.variants[0].resolution && !diagnosticData.resolution) {
              diagnosticData.resolution = parsed.variants[0].resolution;
            }
          }
          if (parsed.audioGroups.length > 0 && diagnosticData.numberOfAudioTracks === 0) {
            diagnosticData.numberOfAudioTracks = parsed.audioGroups.length;
          }
          if (parsed.subtitleGroups.length > 0 && diagnosticData.numberOfSubtitleTracks === 0) {
            diagnosticData.numberOfSubtitleTracks = parsed.subtitleGroups.length;
          }
        }).catch(function(err) {
          diagnosticData.hlsParseError = err && err.message ? err.message : String(err);
        });
      }

      // If Container Prober is available and tracks aren't in meta, check container cache
      if (window.TVContainerProber && (isMkv || isMp4)) {
        var cachedTracks = window.TVContainerProber.getCachedTracks ? window.TVContainerProber.getCachedTracks(url) : null;
        if (cachedTracks) {
          if (cachedTracks.audios && cachedTracks.audios.length > 0) {
            diagnosticData.numberOfAudioTracks = cachedTracks.audios.length;
            diagnosticData.audioCodec = cachedTracks.audios[0].codec || diagnosticData.audioCodec;
          }
          if (cachedTracks.subs && cachedTracks.subs.length > 0) {
            diagnosticData.numberOfSubtitleTracks = cachedTracks.subs.length;
            diagnosticData.subtitleFormat = cachedTracks.subs[0].codec || diagnosticData.subtitleFormat;
          }
        }
      }

      return Promise.all([headerPromise, hlsPromise]).then(function() {
        diagnosticData.compatibility = self.checkCompatibility(diagnosticData);
        console.log('[MediaDiagnostics] Stream Probe Report:', diagnosticData);
        return diagnosticData;
      });
    },

    // Inspect live runtime metrics directly from HTML5 video element
    probeVideoElement: function(videoEl) {
      if (!videoEl) return null;
      var err = videoEl.error ? {
        code: videoEl.error.code,
        message: videoEl.error.message || ''
      } : null;

      var audioTracks = [];
      if (videoEl.audioTracks) {
        for (var a = 0; a < videoEl.audioTracks.length; a++) {
          var at = videoEl.audioTracks[a];
          audioTracks.push({
            id: at.id,
            kind: at.kind,
            label: at.label,
            language: at.language,
            enabled: at.enabled
          });
        }
      }

      var textTracks = [];
      if (videoEl.textTracks) {
        for (var t = 0; t < videoEl.textTracks.length; t++) {
          var tt = videoEl.textTracks[t];
          textTracks.push({
            id: tt.id,
            kind: tt.kind,
            label: tt.label,
            language: tt.language,
            mode: tt.mode,
            cuesCount: tt.cues ? tt.cues.length : 0
          });
        }
      }

      var audioBytes = (typeof videoEl.webkitAudioDecodedByteCount === 'number') ? videoEl.webkitAudioDecodedByteCount : null;
      var videoBytes = (typeof videoEl.webkitVideoDecodedByteCount === 'number') ? videoEl.webkitVideoDecodedByteCount : null;
      var droppedFrames = (typeof videoEl.webkitDroppedFrameCount === 'number') ? videoEl.webkitDroppedFrameCount : null;
      var decodedFrames = (typeof videoEl.webkitDecodedFrameCount === 'number') ? videoEl.webkitDecodedFrameCount : null;

      return {
        currentTime: videoEl.currentTime || 0,
        duration: videoEl.duration || 0,
        paused: videoEl.paused,
        muted: videoEl.muted,
        volume: videoEl.volume,
        readyState: videoEl.readyState,
        networkState: videoEl.networkState,
        videoWidth: videoEl.videoWidth || 0,
        videoHeight: videoEl.videoHeight || 0,
        audioTracks: audioTracks,
        textTracks: textTracks,
        audioDecodedByteCount: audioBytes,
        videoDecodedByteCount: videoBytes,
        droppedFrames: droppedFrames,
        decodedFrames: decodedFrames,
        error: err
      };
    },

    // Format diagnostic data as readable summary string for UI or console
    formatSummary: function(data) {
      if (!data) return 'No diagnostic data';
      var lines = [
        '=== MEDIA DIAGNOSTIC REPORT ===',
        'Target URL: ' + data.cleanUrl,
        'Protocol: ' + data.protocol.toUpperCase() + ' | Container: ' + data.container.toUpperCase() + ' | MIME: ' + data.mimeType,
        'Resolution: ' + (data.resolution || 'N/A') + ' | FPS: ' + (data.fps || 'N/A') + ' | Bitrate: ' + (data.bitrate || 'N/A'),
        'Video Codec: ' + (data.videoCodec || 'N/A') + ' (Profile: ' + (data.videoProfile || 'N/A') + ')',
        'Audio Codec: ' + (data.audioCodec || 'N/A') + ' (' + (data.audioChannels || '2') + ' ch, ' + (data.language || 'und') + ')',
        'Tracks: ' + data.numberOfAudioTracks + ' Audio, ' + data.numberOfSubtitleTracks + ' Subtitle (' + (data.subtitleFormat || 'none') + ')',
        'Compatibility: ' + (data.compatibility ? data.compatibility.status : 'UNKNOWN')
      ];
      if (data.compatibility && data.compatibility.reasons && data.compatibility.reasons.length > 0) {
        lines.push('Compatibility Notes:');
        data.compatibility.reasons.forEach(function(r) { lines.push(' - ' + r); });
      }
      return lines.join('\n');
    }
  };

  window.MediaDiagnostics = MediaDiagnostics;
})();
