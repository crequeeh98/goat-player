import 'package:flutter/foundation.dart';

import '../../utils/platform_utils.dart';
import 'goat_player_engine.dart';
import 'media_kit_player_engine.dart';
import 'tizen_player_engine.dart';

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

    if (kIsWeb) {
      return MediaKitPlayerEngine();
    }

    if (GoatPlatform.isTizen) {
      return TizenPlayerEngine();
    }

    // Default to MediaKitPlayerEngine (Windows, Android, macOS, Linux)
    return MediaKitPlayerEngine();
  }
}
