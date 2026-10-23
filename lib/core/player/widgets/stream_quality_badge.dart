import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

/// Clean, subtle stream quality badges (Resolution, FPS, HDR, Audio)
/// following Apple TV & TiviMate design principles.
class StreamQualityBadges extends StatefulWidget {
  final Player? player;
  final String? streamTitle;
  final bool isCompact;

  const StreamQualityBadges({
    super.key,
    this.player,
    this.streamTitle,
    this.isCompact = false,
  });

  @override
  State<StreamQualityBadges> createState() => _StreamQualityBadgesState();
}

class _StreamQualityBadgesState extends State<StreamQualityBadges> {
  StreamSubscription? _videoParamsSub;
  StreamSubscription? _tracksSub;
  Timer? _fpsPollTimer1;
  Timer? _fpsPollTimer2;

  int? _width;
  int? _height;
  double? _fps;
  String? _hdr;
  String? _audio;

  @override
  void initState() {
    super.initState();
    _initQualityFromPlayer();
  }

  @override
  void didUpdateWidget(covariant StreamQualityBadges oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player != widget.player || oldWidget.streamTitle != widget.streamTitle) {
      _cancelSubscriptions();
      _initQualityFromPlayer();
    }
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }

  void _cancelSubscriptions() {
    _videoParamsSub?.cancel();
    _tracksSub?.cancel();
    _fpsPollTimer1?.cancel();
    _fpsPollTimer2?.cancel();
  }

  void _initQualityFromPlayer() {
    final player = widget.player;
    if (player == null) {
      _parseFromTitle();
      return;
    }

    // 1. Initial values from player state
    final vp = player.state.videoParams;
    _width = vp.w;
    _height = vp.h;

    _updateAudioFromTracks(player.state.tracks);
    _updateFpsFromTracks(player.state.tracks);
    _queryMpvProperties();

    // 2. Listen to dynamic changes
    _videoParamsSub = player.stream.videoParams.listen((vp) {
      if (mounted && (vp.w != _width || vp.h != _height)) {
        setState(() {
          _width = vp.w;
          _height = vp.h;
        });
        _queryMpvProperties();
      }
    });

    _tracksSub = player.stream.tracks.listen((tracks) {
      if (mounted) {
        _updateAudioFromTracks(tracks);
        _updateFpsFromTracks(tracks);
        _queryMpvProperties();
      }
    });

    // 3. Poll asynchronous MPV properties after demuxing settles (600ms and 1800ms)
    _fpsPollTimer1 = Timer(const Duration(milliseconds: 600), () {
      if (mounted) _queryMpvProperties();
    });
    _fpsPollTimer2 = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) _queryMpvProperties();
    });

    // Fallback parsing from title if player hasn't resolved stream details yet
    _parseFromTitle();
  }

  void _updateFpsFromTracks(Tracks tracks) {
    if (_fps != null && _fps! >= 15.0) return;
    final realVideo = tracks.video.where((t) => t.id != 'auto' && t.id != 'no').toList();
    final selectedId = widget.player?.state.track.video.id;
    final activeVideo = realVideo.firstWhereOrNull((t) => t.id == selectedId) ?? realVideo.firstOrNull;
    if (activeVideo != null && activeVideo.fps != null && activeVideo.fps! >= 15.0) {
      setState(() => _fps = activeVideo.fps);
    }
  }

  void _updateAudioFromTracks(Tracks tracks) {
    final realAudio = tracks.audio.where((t) => t.id != 'auto' && t.id != 'no').toList();
    final selectedId = widget.player?.state.track.audio.id;
    final activeAudio = realAudio.firstWhereOrNull((t) => t.id == selectedId) ?? realAudio.firstOrNull;
    if (activeAudio == null) return;

    _detectAudio(
      codec: activeAudio.codec,
      channelsStr: activeAudio.channels,
      title: activeAudio.title,
      channelCount: activeAudio.channelscount ?? activeAudio.audiochannels,
    );
  }

  void _detectAudio({String? codec, String? channelsStr, String? title, int? channelCount}) {
    final c = (codec ?? '').toLowerCase();
    final ch = (channelsStr ?? '').toLowerCase();
    final t = (title ?? '').toLowerCase();

    String? label;
    final isAtmos = c.contains('atmos') || t.contains('atmos') || ch.contains('atmos');
    final isDolby = c.contains('ac3') ||
        c.contains('eac3') ||
        c.contains('truehd') ||
        c.contains('dolby') ||
        t.contains('dolby') ||
        t.contains('ac3') ||
        t.contains('dd+');
    final isDts = c.contains('dts') || t.contains('dts');

    final isSurround = (channelCount != null && channelCount >= 6) ||
        ch.contains('5.1') ||
        ch.contains('7.1') ||
        ch.contains('surround') ||
        ch.contains('6ch') ||
        t.contains('5.1') ||
        t.contains('7.1') ||
        t.contains('surround');

    if (isAtmos) {
      label = 'Atmos';
    } else if (isDolby) {
      if (ch.contains('7.1') || (channelCount != null && channelCount >= 8)) {
        label = 'Dolby 7.1';
      } else if (isSurround) {
        label = 'Dolby 5.1';
      } else {
        label = 'Dolby';
      }
    } else if (isDts) {
      label = isSurround ? 'DTS 5.1' : 'DTS';
    } else if (isSurround) {
      label = (channelCount != null && channelCount >= 8) || ch.contains('7.1') ? '7.1' : '5.1';
    }

    if (label != null && label != _audio && mounted) {
      setState(() => _audio = label);
    }
  }

  Future<void> _queryMpvProperties() async {
    final player = widget.player;
    if (player == null) return;

    try {
      final dynamic platform = player.platform;
      if (platform != null) {
        // 1. Live FPS from mpv properties
        if (_fps == null || _fps! < 15.0) {
          final dynamic rawVfFps = await platform.getProperty('estimated-vf-fps');
          final dynamic rawContFps = await platform.getProperty('container-fps');
          final rawFpsStr = rawVfFps?.toString() ?? rawContFps?.toString();
          if (rawFpsStr != null) {
            final val = double.tryParse(rawFpsStr);
            if (val != null && val >= 15.0 && val <= 240.0 && mounted) {
              setState(() => _fps = val);
            }
          }
        }

        // 2. Audio codec & channels from mpv
        final dynamic audioCodec = await platform.getProperty('audio-codec-name');
        final dynamic audioChannels = await platform.getProperty('audio-params/channels');
        if (audioCodec != null || audioChannels != null) {
          _detectAudio(codec: audioCodec?.toString(), channelsStr: audioChannels?.toString());
        }

        // 3. HDR from mpv
        if (_hdr == null) {
          final dynamic gamma = await platform.getProperty('video-params/gamma');
          final dynamic primaries = await platform.getProperty('video-params/primaries');
          if (gamma != null) {
            final g = gamma.toString().toLowerCase();
            if (g.contains('pq') && mounted) {
              setState(() => _hdr = 'HDR10');
            } else if (g.contains('hlg') && mounted) {
              setState(() => _hdr = 'HLG');
            }
          } else if (primaries != null && primaries.toString().toLowerCase().contains('bt.2020') && mounted) {
            setState(() => _hdr = 'HDR');
          }
        }
      }
    } catch (_) {}
  }

  void _parseFromTitle() {
    final title = widget.streamTitle;
    if (title == null || title.isEmpty) return;
    final lower = title.toLowerCase();

    // Resolution fallback
    if (_width == null || _height == null) {
      if (lower.contains('4k') || lower.contains('uhd') || lower.contains('2160')) {
        _width = 3840;
        _height = 2160;
      } else if (lower.contains('1080') || lower.contains('fhd')) {
        _width = 1920;
        _height = 1080;
      } else if (lower.contains('720') || lower.contains('hd')) {
        _width = 1280;
        _height = 720;
      }
    }

    // FPS fallback
    if (_fps == null) {
      if (lower.contains('50fps') || lower.contains('50 fps') || lower.contains('50hz')) {
        _fps = 50.0;
      } else if (lower.contains('60fps') || lower.contains('60 fps') || lower.contains('60hz')) {
        _fps = 60.0;
      }
    }

    // HDR fallback
    if (_hdr == null) {
      if (lower.contains('dolby vision') || lower.contains('dovi') || RegExp(r'\bdv\b').hasMatch(lower)) {
        _hdr = 'Vision';
      } else if (lower.contains('hdr10+') || lower.contains('hdr10') || RegExp(r'\bhdr\b').hasMatch(lower)) {
        _hdr = 'HDR';
      } else if (RegExp(r'\bhlg\b').hasMatch(lower)) {
        _hdr = 'HLG';
      }
    }

    // Audio fallback
    if (_audio == null) {
      if (lower.contains('atmos')) {
        _audio = 'Atmos';
      } else if (lower.contains('dolby 5.1') || lower.contains('dd 5.1') || lower.contains('ac3 5.1')) {
        _audio = 'Dolby 5.1';
      } else if (lower.contains('dolby') || lower.contains('ac3') || lower.contains('dd+')) {
        _audio = 'Dolby';
      } else if (lower.contains('5.1') || lower.contains('surround')) {
        _audio = '5.1';
      } else if (lower.contains('7.1')) {
        _audio = '7.1';
      }
    }
  }

  String? get _resolutionLabel {
    final w = _width;
    final h = _height;
    if (w == null && h == null) return null;

    if ((w != null && w >= 3800) || (h != null && h >= 2000)) {
      return '4K';
    } else if (h != null && h >= 1400) {
      return '1440p';
    } else if ((h != null && h >= 1000) || (w != null && w >= 1900)) {
      return '1080p';
    } else if ((h != null && h >= 700) || (w != null && w >= 1200)) {
      return '720p';
    } else if (h != null && h > 0) {
      return h < 600 ? 'SD' : '${h}p';
    }
    return null;
  }

  String? get _fpsLabel {
    final f = _fps;
    if (f == null || f < 15) return null;

    if (f >= 23.5 && f <= 24.5) return '24 FPS';
    if (f >= 24.6 && f <= 25.5) return '25 FPS';
    if (f >= 29.4 && f <= 30.5) return '30 FPS';
    if (f >= 49.0 && f <= 51.5) return '50 FPS';
    if (f >= 58.5 && f <= 61.5) return '60 FPS';
    return '${f.round()} FPS';
  }

  @override
  Widget build(BuildContext context) {
    final res = _resolutionLabel;
    final fps = _fpsLabel;
    final hdr = _hdr;
    final audio = _audio;

    if (res == null && fps == null && hdr == null && audio == null) {
      return const SizedBox.shrink();
    }

    final isCompact = widget.isCompact;
    final fontSize = isCompact ? 9.5 : 11.0;
    final padH = isCompact ? 5.0 : 7.0;
    final padV = isCompact ? 1.5 : 2.5;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (res != null) ...[
          _buildBadge(
            text: res,
            fontSize: fontSize,
            padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
            isPrimary: res == '4K',
            primaryColor: const Color(0xFF00E5FF), // Cyan accent for 4K
          ),
          const SizedBox(width: 4),
        ],
        if (fps != null) ...[
          _buildBadge(
            text: fps,
            fontSize: fontSize,
            padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          ),
          const SizedBox(width: 4),
        ],
        if (hdr != null) ...[
          _buildBadge(
            text: hdr,
            fontSize: fontSize,
            padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
            isPrimary: true,
            primaryColor: const Color(0xFFFFB800), // Gold accent for HDR/Vision
          ),
          const SizedBox(width: 4),
        ],
        if (audio != null) ...[
          _buildBadge(
            text: audio,
            fontSize: fontSize,
            padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
            isPrimary: audio == 'Atmos' || audio.startsWith('Dolby'),
            primaryColor: const Color(0xFF64B5F6),
          ),
        ],
      ],
    );
  }

  Widget _buildBadge({
    required String text,
    required double fontSize,
    required EdgeInsets padding,
    bool isPrimary = false,
    Color? primaryColor,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isPrimary && primaryColor != null
            ? primaryColor.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isPrimary && primaryColor != null
              ? primaryColor.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.22),
          width: 0.8,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isPrimary && primaryColor != null ? primaryColor : Colors.white.withValues(alpha: 0.95),
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
