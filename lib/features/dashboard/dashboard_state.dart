import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardTabReset extends Notifier<int> {
  @override
  int build() => 0;

  void reset() => state++;
}

/// Provider incremented whenever dashboard tabs switch or search resets,
/// notifying individual tab views to reset their search query and category filters.
final dashboardTabResetProvider = NotifierProvider<DashboardTabReset, int>(DashboardTabReset.new);

class ActiveSearchFocusNodeNotifier extends Notifier<FocusNode?> {
  @override
  FocusNode? build() => null;
  void set(FocusNode? node) => state = node;
}

class HeaderSearchFocusNodeNotifier extends Notifier<FocusNode?> {
  @override
  FocusNode? build() => null;
  void set(FocusNode? node) => state = node;
}

class ActiveSidebarFocusNodeNotifier extends Notifier<FocusNode?> {
  @override
  FocusNode? build() => null;
  void set(FocusNode? node) => state = node;
}

class ActiveCategoryFocusNodeNotifier extends Notifier<FocusNode?> {
  @override
  FocusNode? build() => null;
  void set(FocusNode? node) => state = node;
}

class TabCategoryFocusNodesNotifier extends Notifier<Map<int, FocusNode?>> {
  @override
  Map<int, FocusNode?> build() => <int, FocusNode?>{};

  void setForTab(int tab, FocusNode? node) {
    final updated = Map<int, FocusNode?>.from(state);
    if (node == null) {
      updated.remove(tab);
    } else {
      updated[tab] = node;
    }
    state = updated;
  }
}

class ActiveDashboardTabNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void set(int tab) => state = tab;
}

/// Active tab index in the TV sidebar / dashboard: 0 = Live, 1 = Movies, 2 = Series
final activeDashboardTabProvider =
    NotifierProvider<ActiveDashboardTabNotifier, int>(ActiveDashboardTabNotifier.new);

/// FocusNode of the active category search field on the visible dashboard page (Live, Movies, Series)
final activeScreenSearchFocusNodeProvider =
    NotifierProvider<ActiveSearchFocusNodeNotifier, FocusNode?>(ActiveSearchFocusNodeNotifier.new);

/// FocusNode of the active/last-focused category item on the visible dashboard page
final activeCategoryFocusNodeProvider =
    NotifierProvider<ActiveCategoryFocusNodeNotifier, FocusNode?>(ActiveCategoryFocusNodeNotifier.new);

/// Per-tab category FocusNodes (0 = Live, 1 = Movies, 2 = Series) preventing cross-tab disposal race conditions
final tabCategoryFocusNodesProvider =
    NotifierProvider<TabCategoryFocusNodesNotifier, Map<int, FocusNode?>>(
  TabCategoryFocusNodesNotifier.new,
);

/// FocusNode of the Master Search button in the Dashboard header
final headerSearchFocusNodeProvider =
    NotifierProvider<HeaderSearchFocusNodeNotifier, FocusNode?>(HeaderSearchFocusNodeNotifier.new);

/// FocusNode of the active tab button in the TV sidebar
final activeSidebarFocusNodeProvider =
    NotifierProvider<ActiveSidebarFocusNodeNotifier, FocusNode?>(ActiveSidebarFocusNodeNotifier.new);
