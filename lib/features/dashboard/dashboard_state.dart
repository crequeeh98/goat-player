import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardTabReset extends Notifier<int> {
  @override
  int build() => 0;

  void reset() => state++;
}

/// Provider incremented whenever dashboard tabs switch or search resets,
/// notifying individual tab views to reset their search query and category filters.
final dashboardTabResetProvider = NotifierProvider<DashboardTabReset, int>(DashboardTabReset.new);
