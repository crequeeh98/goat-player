import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'core/utils/platform_utils.dart';

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
  final isM3u = account.username.isEmpty || account.serverUrl.contains('.m3u');
  if (isM3u) return null;
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
  final categoryDao = ref.watch(categoryDaoProvider);
  final streamDao = ref.watch(streamDaoProvider);
  final epgDao = ref.watch(epgDaoProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return RemoteSyncService(accountDao, categoryDao, streamDao, epgDao, prefs);
});

void main(List<String> args) {
  if (args.contains('--tv')) {
    GoatPlatform.setForceTvMode(true);
    print('[GOAT] Fire TV emulation mode forced (--tv flag detected).');
  }
  print('[GOAT] main() starting...');
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    print('[GOAT] WidgetsFlutterBinding initialized.');

    PlatformDispatcher.instance.onError = (error, stack) {
      print('[GOAT] Global Unhandled Platform Error: $error\n$stack');
      return true;
    };

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      print('[GOAT] Flutter Error: ${details.exception}');
    };

    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0914),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.deepPurpleAccent, size: 56),
                  const SizedBox(height: 16),
                  const Text(
                    'GOATPlayer - Application Error',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    details.exceptionAsString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    };

    await GoatPlatform.init();

    if (!GoatPlatform.isWeb) {
      MediaKit.ensureInitialized();
    }

    if (GoatPlatform.isTv || GoatPlatform.isMobile) {
      PaintingBinding.instance.imageCache.maximumSizeBytes = 25 * 1024 * 1024; // 25 MB max
      PaintingBinding.instance.imageCache.maximumSize = 100;
    }

    if (GoatPlatform.isDesktop) {
      await windowManager.ensureInitialized();
      WindowOptions windowOptions = const WindowOptions(
        size: Size(1280, 720),
        center: true,
        title: 'GOATPlayer',
      );
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
        await Future.delayed(const Duration(milliseconds: 150));
        await windowManager.maximize();
      });
    }

    // Load SharedPreferences with bulletproof fallback for file:// TV runtimes
    SharedPreferences? prefs;
    try {
      print('[GOAT] Loading SharedPreferences...');
      prefs = await SharedPreferences.getInstance().timeout(const Duration(milliseconds: 1500));
      print('[GOAT] SharedPreferences loaded successfully.');
    } catch (e) {
      print('[GOAT] SharedPreferences warning: $e, using mock initial values');
    }
    if (prefs == null) {
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      print('[GOAT] SharedPreferences in-memory instance ready.');
    }

    // Initialize RemoteSyncService (Supabase) for Web / QR code pairing
    print('[GOAT] Initializing RemoteSyncService (Supabase)...');
    try {
      await RemoteSyncService.initialize();
      print('[GOAT] RemoteSyncService initialized successfully.');
    } catch (e) {
      print('[GOAT] RemoteSyncService initialization warning: $e');
    }

    print('[GOAT] Calling runApp()...');
    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MyApp(),
      ),
    );
    print('[GOAT] runApp() invoked successfully.');
  }, (error, stack) {
    print('[GOAT] ZonedGuarded Unhandled Error: $error\n$stack');
  });
}

class TvDirectionalFocusAction extends Action<DirectionalFocusIntent> {
  @override
  Object? invoke(DirectionalFocusIntent intent) {
    final focus = primaryFocus;
    if (focus != null) {
      final success = focus.focusInDirection(intent.direction);
      if (!success) {
        if (intent.direction == TraversalDirection.down || intent.direction == TraversalDirection.right) {
          focus.nextFocus();
        } else if (intent.direction == TraversalDirection.up || intent.direction == TraversalDirection.left) {
          focus.previousFocus();
        }
      }
    }
    return null;
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    print('[GOAT] MyApp.build() executing');
    final locale = ref.watch(localeControllerProvider);

    return MaterialApp(
      title: 'GOATPlayer',
      debugShowCheckedModeBanner: false,
      locale: locale,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF0D0915),
        canvasColor: const Color(0xFF0D0915),
      ),
      builder: (context, child) {
        if (GoatPlatform.isTv) {
          final mq = MediaQuery.of(context);
          // TV Overscan Insets: Physical TVs often clip outer 2-3% of the display.
          // Inset by 18dp horizontally and 10dp vertically to ensure all buttons,
          // sidebar, headers, and modals are safely within the visible TV glass while maximizing screen area.
          final overscan = EdgeInsets.only(
            left: mq.padding.left > 16 ? mq.padding.left : 18.0,
            right: mq.padding.right > 16 ? mq.padding.right : 18.0,
            top: mq.padding.top > 8 ? mq.padding.top : 10.0,
            bottom: mq.padding.bottom > 8 ? mq.padding.bottom : 10.0,
          );
          return Container(
            color: const Color(0xFF0D0915),
            padding: overscan,
            child: MediaQuery(
              data: mq.copyWith(
                padding: EdgeInsets.zero,
                viewPadding: EdgeInsets.zero,
              ),
              child: child ?? const SizedBox.shrink(),
            ),
          );
        }
        return child ?? const SizedBox.shrink();
      },
      shortcuts: {
        ...WidgetsApp.defaultShortcuts,
        const SingleActivator(LogicalKeyboardKey.arrowUp): const DirectionalFocusIntent(TraversalDirection.up),
        const SingleActivator(LogicalKeyboardKey.arrowDown): const DirectionalFocusIntent(TraversalDirection.down),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): const DirectionalFocusIntent(TraversalDirection.left),
        const SingleActivator(LogicalKeyboardKey.arrowRight): const DirectionalFocusIntent(TraversalDirection.right),
        const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.enter): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowUp): const DirectionalFocusIntent(TraversalDirection.up),
        LogicalKeySet(LogicalKeyboardKey.arrowDown): const DirectionalFocusIntent(TraversalDirection.down),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): const DirectionalFocusIntent(TraversalDirection.left),
        LogicalKeySet(LogicalKeyboardKey.arrowRight): const DirectionalFocusIntent(TraversalDirection.right),
        LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
      },
      actions: {
        ...WidgetsApp.defaultActions,
        DirectionalFocusIntent: TvDirectionalFocusAction(),
      },
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
