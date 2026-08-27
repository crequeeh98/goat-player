import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

final localeControllerProvider = NotifierProvider<LocaleController, Locale>(LocaleController.new);

class LocaleController extends Notifier<Locale> {
  static const _localeKey = 'app_locale';

  @override
  Locale build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final savedLocale = prefs.getString(_localeKey);
    
    if (savedLocale != null) {
      return Locale(savedLocale);
    }
    return const Locale('en');
  }

  Future<void> setLocale(String languageCode) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_localeKey, languageCode);
    state = Locale(languageCode);
  }
}
