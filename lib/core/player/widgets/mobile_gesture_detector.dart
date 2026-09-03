import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

enum _GestureType { none, brightness, volume, seek }

class MobileGestureDetector extends StatefulWidget {
  final Player player;
  final Widget child;
  final bool enableSeek;
  final VoidCallback? onSingleTap;
  final VoidCallback? onDoubleTap;

  const MobileGestureDetector({
    super.key,
    required this.player,
    required this.child,
    this.enableSeek = true,
    this.onSingleTap,
    this.onDoubleTap,
  });

  @override
  State<MobileGestureDetector> createState() => _MobileGestureDetectorState();
}

class _MobileGestureDetectorState extends State<MobileGestureDetector> with SingleTickerProviderStateMixin {
  _GestureType _activeGesture = _GestureType.none;
  Timer? _hudDismissTimer;

  // Brightness (software overlay 0.0 to 1.0)
  static double _currentBrightness = 0.8;
  double _initialBrightness = 0.8;

  // Volume (0.0 to 100.0)
  double _currentVolume = 100.0;
  double _initialVolume = 100.0;

  // Seek
  Duration _initialPosition = Duration.zero;
  Duration _targetPosition = Duration.zero;
  Duration _seekDelta = Duration.zero;

  // Double tap skip animation
  bool _showSkipLeft = false;
  bool _showSkipRight = false;
  Timer? _skipLeftTimer;
  Timer? _skipRightTimer;

  @override
  void initState() {
    super.initState();
    _currentVolume = widget.player.state.volume;
    widget.player.stream.volume.listen((vol) {
      if (mounted) {
        setState(() => _currentVolume = vol);
      }
    });
  }

  @override
  void dispose() {
    _hudDismissTimer?.cancel();
    _skipLeftTimer?.cancel();
    _skipRightTimer?.cancel();
    super.dispose();
  }

  void _onVerticalDragStart(DragStartDetails details, BoxConstraints constraints) {
    _hudDismissTimer?.cancel();
    final isLeft = details.localPosition.dx < (constraints.maxWidth / 2);
    if (isLeft) {
      _activeGesture = _GestureType.brightness;
      _initialBrightness = _currentBrightness;
    } else {
      _activeGesture = _GestureType.volume;
      _initialVolume = _currentVolume;
    }
    setState(() {});
  }

  void _onVerticalDragUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    final sensitivity = 1.0 / (constraints.maxHeight * 0.75);
    final delta = -details.primaryDelta! * sensitivity;

    if (_activeGesture == _GestureType.brightness) {
      setState(() {
        _currentBrightness = (_currentBrightness + delta).clamp(0.1, 1.0);
      });
    } else if (_activeGesture == _GestureType.volume) {
      setState(() {
        _currentVolume = (_currentVolume + (delta * 100)).clamp(0.0, 100.0);
        widget.player.setVolume(_currentVolume);
      });
    }
  }

  void _onHorizontalDragStart(DragStartDetails details, BoxConstraints constraints) {
    if (!widget.enableSeek) return;
    _hudDismissTimer?.cancel();
    _activeGesture = _GestureType.seek;
    _initialPosition = widget.player.state.position;
    _targetPosition = _initialPosition;
    _seekDelta = Duration.zero;
    setState(() {});
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (!widget.enableSeek || _activeGesture != _GestureType.seek) return;
    final totalDuration = widget.player.state.duration;
    if (totalDuration == Duration.zero) return;

    // Scale scrubbing speed based on total duration (drag across full width = 90s or 5% of duration)
    final scrubSpanSeconds = (totalDuration.inSeconds * 0.1).clamp(60, 600);
    final deltaSeconds = (details.primaryDelta! / constraints.maxWidth) * scrubSpanSeconds;
    
    final newTarget = _targetPosition + Duration(milliseconds: (deltaSeconds * 1000).toInt());
    final clampedSeconds = newTarget.inSeconds.clamp(0, totalDuration.inSeconds);

    setState(() {
      _targetPosition = Duration(seconds: clampedSeconds);
      _seekDelta = _targetPosition - _initialPosition;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_activeGesture == _GestureType.seek && widget.enableSeek) {
      widget.player.seek(_targetPosition);
    }
    _scheduleHudDismiss();
  }

  void _scheduleHudDismiss() {
    _hudDismissTimer?.cancel();
    _hudDismissTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() {
          _activeGesture = _GestureType.none;
        });
      }
    });
  }

  void _triggerSkip(bool isForward) {
    final currentPos = widget.player.state.position;
    final totalDuration = widget.player.state.duration;
    final delta = isForward ? const Duration(seconds: 10) : const Duration(seconds: -10);
    
    final newSeconds = (currentPos + delta).inSeconds.clamp(0, totalDuration.inSeconds > 0 ? totalDuration.inSeconds : 86400);
    widget.player.seek(Duration(seconds: newSeconds));

    if (isForward) {
      setState(() => _showSkipRight = true);
      _skipRightTimer?.cancel();
      _skipRightTimer = Timer(const Duration(milliseconds: 650), () {
        if (mounted) setState(() => _showSkipRight = false);
      });
    } else {
      setState(() => _showSkipLeft = true);
      _skipLeftTimer?.cancel();
      _skipLeftTimer = Timer(const Duration(milliseconds: 650), () {
        if (mounted) setState(() => _showSkipLeft = false);
      });
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            widget.child,

            // Software Brightness Dimmer Overlay
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(alpha: 1.0 - _currentBrightness),
                ),
              ),
            ),

            // Gesture Area
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: widget.onSingleTap,
                onDoubleTapDown: (details) {
                  if (widget.onDoubleTap != null) {
                    widget.onDoubleTap!();
                  } else {
                    widget.player.playOrPause();
                  }
                },
                onVerticalDragStart: (d) => _onVerticalDragStart(d, constraints),
                onVerticalDragUpdate: (d) => _onVerticalDragUpdate(d, constraints),
                onVerticalDragEnd: _onDragEnd,
                onHorizontalDragStart: (d) => _onHorizontalDragStart(d, constraints),
                onHorizontalDragUpdate: (d) => _onHorizontalDragUpdate(d, constraints),
                onHorizontalDragEnd: _onDragEnd,
              ),
            ),

            // Double Tap Visual Ripples
            if (_showSkipLeft)
              Positioned(
                left: 32,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.replay_10, color: Colors.white, size: 28),
                        SizedBox(width: 6),
                        Text('-10s', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ),

            if (_showSkipRight)
              Positioned(
                right: 32,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('+10s', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        SizedBox(width: 6),
                        Icon(Icons.forward_10, color: Colors.white, size: 28),
                      ],
                    ),
                  ),
                ),
              ),

            // Active Gesture HUD (Brightness, Volume, Seek)
            if (_activeGesture != _GestureType.none)
              Center(
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: _buildHudContent(),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildHudContent() {
    switch (_activeGesture) {
      case _GestureType.brightness:
        final pct = (_currentBrightness * 100).toInt();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              pct > 50 ? Icons.brightness_high : (pct > 20 ? Icons.brightness_medium : Icons.brightness_low),
              color: Colors.amber,
              size: 38,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                value: _currentBrightness,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$pct%',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        );

      case _GestureType.volume:
        final pct = _currentVolume.toInt();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              pct == 0 ? Icons.volume_off : (pct < 50 ? Icons.volume_down : Icons.volume_up),
              color: Colors.lightBlueAccent,
              size: 38,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                value: _currentVolume / 100.0,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.lightBlueAccent),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$pct%',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        );

      case _GestureType.seek:
        final sign = _seekDelta.inSeconds >= 0 ? '+' : '';
        final totalStr = _formatDuration(widget.player.state.duration);
        final targetStr = _formatDuration(_targetPosition);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$sign${_seekDelta.inSeconds}s',
              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 22),
            ),
            const SizedBox(height: 8),
            Text(
              '$targetStr / $totalStr',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ],
        );

      case _GestureType.none:
        return const SizedBox.shrink();
    }
  }
}
