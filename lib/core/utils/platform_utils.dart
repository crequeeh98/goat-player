import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

/// Platform utility providing safe, cross-platform checks across Desktop, Mobile, Web, and Smart TVs
/// without throwing unsupported operation errors on Web or TV runtimes.
class GoatPlatform {
  static bool get isWeb => kIsWeb;
  static bool get isWindows => !kIsWeb && Platform.isWindows;
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  static bool get isLinux => !kIsWeb && Platform.isLinux;
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;
  static bool get isDesktop => isWindows || isLinux || isMacOS;
  static bool get isMobile => isAndroid || isIOS;
  static bool get isTizen => !kIsWeb && (Platform.environment.containsKey('TIZEN_SDK') || Platform.operatingSystem == 'tizen');
  static bool get isWebOS => kIsWeb;
}
