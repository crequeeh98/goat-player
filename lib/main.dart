import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:media_kit/media_kit.dart';
import 'package:goat_player/l10n/app_localizations.dart';

import 'core/database/app_database.dart';
import 'core/database/daos/account_dao.dart';
import 'core/database/daos/category_dao.dart';
import 'core/database/daos/stream_dao.dart';
import 'core/database/daos/epg_dao.dart';
import 'core/network/xtream_client.dart';
import 'core/settings/locale_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/account/account_list_screen.dart';
import 'package:dio/dio.dart';
import 'core/player/playback_controller.dart';
import 'features/live_tv/live_tv_controller.dart';
import 'core/remote_sync/remote_sync_service.dart';

// Global providers
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final accountDaoProvider = Provider<AccountDao>((ref) {
  final db = ref.watch(databaseProvider);
  return AccountDao(db);
});

final categoryDaoProvider = Provider<CategoryDao>((ref) {
  final db = ref.watch(databaseProvider);
  return CategoryDao(db);
});

final streamDaoProvider = Provider<StreamDao>((ref) {
  final db = ref.watch(databaseProvider);
  return StreamDao(db);
});

final epgDaoProvider = Provider<EpgDao>((ref) {
  final db = ref.watch(databaseProvider);
  return EpgDao(db);
});

class ActiveAccount extends Notifier<Account?> {
  @override
  Account? build() => null;
  void set(Account? account) {
    if (state?.id != account?.id) {
      ref.read(playbackControllerProvider.notifier).stop();
      ref.read(selectedLiveCategoryProvider.notifier).set(null);
      ref.read(selectedLiveStreamProvider.notifier).set(null);
      ref.read(isLiveFullWidthProvider.notifier).set(false);
    }
    state = account;
  }
}

final activeAccountProvider = NotifierProvider<ActiveAccount, Account?>(ActiveAccount.new);

final xtreamClientProvider = Provider<XtreamClient?>((ref) {
  final account = ref.watch(activeAccountProvider);
  if (account == null) return null;
  return XtreamClient(
    Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    ),
    baseUrl: account.serverUrl,
    username: account.username,
    password: account.password,
  );
});

final remoteSyncServiceProvider = Provider<RemoteSyncService>((ref) {
  final accountDao = ref.watch(accountDaoProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return RemoteSyncService(accountDao, prefs);
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await RemoteSyncService.initialize();
  
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 720),
      center: true,
      title: 'GOATPlayer',
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      // Add a tiny delay to ensure Windows finishes the show animation before maximizing.
      // This prevents the viewport duplication bug and ensures maximize always works.
      await Future.delayed(const Duration(milliseconds: 150));
      await windowManager.maximize();
    });
  }
  
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeControllerProvider);

    return MaterialApp(
      title: 'GOATPlayer',
      debugShowCheckedModeBanner: false,
      locale: locale,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.deepPurple,
        fontFamily: 'Inter',
      ),
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        Locale('en', ''),
        Locale('de', ''),
      ],
      home: const AccountListScreen(),
    );
  }
}
