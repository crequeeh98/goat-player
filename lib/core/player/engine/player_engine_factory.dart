import 'goat_player_engine.dart';
import 'media_kit_player_engine.dart';

/// Factory responsible for instantiating the appropriate GoatPlayerEngine
/// based on the runtime operating system and platform target.
class PlayerEngineFactory {
  static GoatPlayerEngine? _engineOverride;

  /// Allows unit and integration tests to inject mock engines
  static void setMockEngine(GoatPlayerEngine? mockEngine) {
    _engineOverride = mockEngine;
  }

  /// Creates and returns the target platform engine
  static GoatPlayerEngine create() {
    if (_engineOverride != null) {
      return _engineOverride!;
    }

    // Flutter app uses MediaKitPlayerEngine on all supported platforms (Windows, Android, etc.)
    return MediaKitPlayerEngine();
  }
}
