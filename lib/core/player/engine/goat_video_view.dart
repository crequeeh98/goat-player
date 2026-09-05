import 'package:flutter/widgets.dart';
import 'goat_player_engine.dart';

/// Platform-agnostic video rendering widget that delegates video surface drawing
/// to the underlying GoatPlayerEngine (MediaKit, Tizen, webOS).
class GoatVideoView extends StatelessWidget {
  final GoatPlayerEngine engine;
  final BoxFit fit;
  final Widget? subtitleView;

  const GoatVideoView({
    super.key,
    required this.engine,
    this.fit = BoxFit.contain,
    this.subtitleView,
  });

  @override
  Widget build(BuildContext context) {
    return engine.buildVideoView(
      fit: fit,
      subtitleView: subtitleView,
    );
  }
}
