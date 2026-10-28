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

/// FocusNode of the active category search field on the visible dashboard page (Live, Movies, Series)
final activeScreenSearchFocusNodeProvider =
    NotifierProvider<ActiveSearchFocusNodeNotifier, FocusNode?>(ActiveSearchFocusNodeNotifier.new);

/// FocusNode of the active/last-focused category item on the visible dashboard page
final activeCategoryFocusNodeProvider =
    NotifierProvider<ActiveCategoryFocusNodeNotifier, FocusNode?>(ActiveCategoryFocusNodeNotifier.new);

/// FocusNode of the Master Search button in the Dashboard header
final headerSearchFocusNodeProvider =
    NotifierProvider<HeaderSearchFocusNodeNotifier, FocusNode?>(HeaderSearchFocusNodeNotifier.new);

/// FocusNode of the active tab button in the TV sidebar
final activeSidebarFocusNodeProvider =
    NotifierProvider<ActiveSidebarFocusNodeNotifier, FocusNode?>(ActiveSidebarFocusNodeNotifier.new);
