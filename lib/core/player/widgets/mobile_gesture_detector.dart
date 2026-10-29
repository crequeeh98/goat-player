import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

enum _GestureType { none, seek }

class MobileGestureDetector extends StatefulWidget {
  final Player player;
  final Widget child;
  final bool enableSeek;
  final VoidCallback? onSingleTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onPullDown;

  const MobileGestureDetector({
    super.key,
    required this.player,
    required this.child,
    this.enableSeek = true,
    this.onSingleTap,
    this.onDoubleTap,
    this.onPullDown,
  });

  @override
  State<MobileGestureDetector> createState() => _MobileGestureDetectorState();
}

class _MobileGestureDetectorState extends State<MobileGestureDetector> with SingleTickerProviderStateMixin {
  _GestureType _activeGesture = _GestureType.none;
  Timer? _hudDismissTimer;

  // Pull-down tracking
  double _verticalDragDistance = 0.0;

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
  void dispose() {
    _hudDismissTimer?.cancel();
    _skipLeftTimer?.cancel();
    _skipRightTimer?.cancel();
    super.dispose();
  }

  void _onVerticalDragStart(DragStartDetails details) {
    _verticalDragDistance = 0.0;
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    _verticalDragDistance += details.primaryDelta ?? 0.0;
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0.0;
    if (_verticalDragDistance > 40 || velocity > 250) {
      if (widget.onPullDown != null) {
        widget.onPullDown!();
      }
    }
    _verticalDragDistance = 0.0;
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

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  void _triggerSkipLeft() {
    final current = widget.player.state.position;
    final target = current - const Duration(seconds: 10);
    widget.player.seek(target < Duration.zero ? Duration.zero : target);
    _skipLeftTimer?.cancel();
    setState(() => _showSkipLeft = true);
    _skipLeftTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _showSkipLeft = false);
    });
  }

  void _triggerSkipRight() {
    final current = widget.player.state.position;
    final duration = widget.player.state.duration;
    final target = current + const Duration(seconds: 10);
    widget.player.seek(duration > Duration.zero && target > duration ? duration : target);
    _skipRightTimer?.cancel();
    setState(() => _showSkipRight = true);
    _skipRightTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _showSkipRight = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            widget.child,

            // Gesture Area (only intercepts vertical pull-down when configured, or double-tap left/right seek in VOD)
            if (widget.onPullDown != null || widget.enableSeek || widget.onSingleTap != null || widget.onDoubleTap != null)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: widget.onSingleTap,
                  onDoubleTapDown: (widget.enableSeek || widget.onDoubleTap != null)
                      ? (details) {
                          if (widget.enableSeek) {
                            final dx = details.localPosition.dx;
                            final w = constraints.maxWidth;
                            if (dx < w * 0.45) {
                              _triggerSkipLeft();
                            } else if (dx > w * 0.55) {
                              _triggerSkipRight();
                            } else {
                              widget.player.playOrPause();
                            }
                          } else if (widget.onDoubleTap != null) {
                            widget.onDoubleTap!();
                          }
                        }
                      : null,
                  onDoubleTap: (widget.enableSeek || widget.onDoubleTap != null) ? () {} : null,
                  onVerticalDragStart: widget.onPullDown != null ? _onVerticalDragStart : null,
                  onVerticalDragUpdate: widget.onPullDown != null ? _onVerticalDragUpdate : null,
                  onVerticalDragEnd: widget.onPullDown != null ? _onVerticalDragEnd : null,
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

            // Active Gesture HUD (Seek)
            if (_activeGesture == _GestureType.seek)
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
