import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';

class AccountConnectionInfo {
  final int active;
  final int max;
  final bool isLoading;

  const AccountConnectionInfo({
    this.active = 0,
    this.max = 1,
    this.isLoading = false,
  });

  AccountConnectionInfo copyWith({
    int? active,
    int? max,
    bool? isLoading,
  }) {
    return AccountConnectionInfo(
      active: active ?? this.active,
      max: max ?? this.max,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AccountConnectionNotifier extends Notifier<AccountConnectionInfo> {
  Timer? _pollTimer;

  @override
  AccountConnectionInfo build() {
    ref.watch(activeAccountProvider);
    ref.onDispose(() {
      _pollTimer?.cancel();
    });

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      refresh();
    });

    Future.microtask(refresh);

    return const AccountConnectionInfo(isLoading: true);
  }

  Future<void> refresh() async {
    final client = ref.read(xtreamClientProvider);
    final account = ref.read(activeAccountProvider);
    if (client == null || account == null) {
      state = const AccountConnectionInfo();
      return;
    }

    try {
      final authData = await client.authenticate();
      final userInfo = authData['user_info'];
      if (userInfo != null && userInfo is Map) {
        final activeStr = userInfo['active_cons']?.toString() ?? '0';
        final maxStr = userInfo['max_connections']?.toString() ?? '1';
        final active = int.tryParse(activeStr) ?? 0;
        var max = int.tryParse(maxStr) ?? 1;
        if (max < 1) max = 1;

        state = AccountConnectionInfo(
          active: active,
          max: max,
          isLoading: false,
        );
      }
    } catch (e) {
      debugPrint('AccountConnectionNotifier error: $e');
      if (state.isLoading) {
        state = state.copyWith(isLoading: false);
      }
    }
  }
}

final accountConnectionInfoProvider = NotifierProvider<AccountConnectionNotifier, AccountConnectionInfo>(
  AccountConnectionNotifier.new,
);
