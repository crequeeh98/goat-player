import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Platform utility providing safe, cross-platform checks across Desktop, Mobile, Web, and Smart TVs
/// without throwing unsupported operation errors on Web or TV runtimes.
class GoatPlatform {
  static const MethodChannel _channel = MethodChannel('com.goatplayer/updater');

  static bool _isTvInitialized = false;
  static bool _isNativeTv = false;

  static Future<void> init() async {
    if (_isTvInitialized || kIsWeb) return;
    _isTvInitialized = true;
    if (Platform.isAndroid) {
      try {
        final res = await _channel.invokeMethod<bool>('isTvDevice');
        if (res != null) {
          _isNativeTv = res;
        }
      } catch (_) {}
    }
  }

  static bool get isWeb => kIsWeb;
  static bool get isWindows => !kIsWeb && Platform.isWindows;
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  static bool get isLinux => !kIsWeb && Platform.isLinux;
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;
  static bool get isDesktop => isWindows || isLinux || isMacOS;

  /// True on Android TV, Fire TV, Beamer, or large landscape TV displays
  static bool get isTv {
    if (_isNativeTv) return true;
    if (kIsWeb) return false;
    try {
      final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
      if (view != null && (Platform.isAndroid || Platform.isIOS)) {
        final size = view.physicalSize / view.devicePixelRatio;
        // Television panels (720p, 1080p, 4K) in landscape
        if (size.width >= 800 && size.width > size.height) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// True on phones (Xiaomi, Samsung Galaxy, iPhone, etc.)
  static bool get isPhone => (isAndroid || isIOS) && !isTv;

  /// Legacy helper for mobile (phone + tablet)
  static bool get isMobile => isAndroid || isIOS;

  static bool get isTizen => false; // Smart TV is purely in /smart_tv web app
  static bool get isWebOS => false;
}
