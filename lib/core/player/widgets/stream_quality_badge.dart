import 'dart:async';
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
  Timer? _fpsPollTimer;

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
    _fpsPollTimer?.cancel();
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
      }
    });

    // 3. Poll FPS & HDR properties 1s and 2s after playback starts
    _fpsPollTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        _queryMpvProperties();
      }
    });

    // Fallback parsing from title if player hasn't resolved stream details yet
    _parseFromTitle();
  }

  void _updateAudioFromTracks(Tracks tracks) {
    final activeAudio = widget.player?.state.track.audio ?? tracks.audio.firstOrNull;
    if (activeAudio == null) return;

    final chStr = activeAudio.channels?.toString();
    final channels = int.tryParse(chStr ?? '');
    final title = (activeAudio.title ?? '').toLowerCase();

    String? detectedAudio;
    if (title.contains('atmos')) {
      detectedAudio = 'Atmos';
    } else if (channels != null && channels >= 8) {
      detectedAudio = '7.1';
    } else if (channels != null && channels >= 6) {
      detectedAudio = '5.1';
    } else if (title.contains('5.1') || title.contains('surround') || title.contains('ac3') || title.contains('eac3')) {
      detectedAudio = '5.1';
    }

    if (detectedAudio != null && detectedAudio != _audio) {
      setState(() => _audio = detectedAudio);
    }
  }

  void _queryMpvProperties() {
    final player = widget.player;
    if (player == null) return;

    try {
      final dynamic platform = player.platform;
      if (platform != null) {
        // Query FPS
        final dynamic rawFps = platform.getProperty('estimated-vf-fps') ?? platform.getProperty('container-fps');
        if (rawFps != null) {
          final val = double.tryParse(rawFps.toString());
          if (val != null && val >= 15.0 && val <= 240.0) {
            _fps = val;
          }
        }

        // Query HDR (gamma & primaries)
        final dynamic gamma = platform.getProperty('video-params/gamma');
        final dynamic primaries = platform.getProperty('video-params/primaries');
        if (gamma != null) {
          final g = gamma.toString().toLowerCase();
          if (g.contains('pq')) {
            _hdr = 'HDR10';
          } else if (g.contains('hlg')) {
            _hdr = 'HLG';
          }
        } else if (primaries != null && primaries.toString().toLowerCase().contains('bt.2020')) {
          _hdr = 'HDR';
        }
      }
    } catch (_) {}

    if (mounted) setState(() {});
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
            isPrimary: audio == 'Atmos',
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
