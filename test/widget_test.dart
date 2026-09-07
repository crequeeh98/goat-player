import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goat_player/core/widgets/tv_focusable.dart';
import 'package:goat_player/core/widgets/tv_remote_scope.dart';

void main() {
  testWidgets('TvFocusable renders child and gains focus on TV remote interaction', (WidgetTester tester) async {
    bool activated = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvRemoteScope(
            isRoot: false,
            child: TvFocusable(
              autofocus: true,
              onPressed: () => activated = true,
              child: const Text('TV Channel Item'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('TV Channel Item'), findsOneWidget);
    await tester.tap(find.text('TV Channel Item'));
    await tester.pumpAndSettle();

    expect(activated, isTrue);

    // Test remote Select / Enter key activation
    bool remoteActivated = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvRemoteScope(
            isRoot: false,
            child: TvFocusable(
              autofocus: true,
              onPressed: () => remoteActivated = true,
              child: const Text('TV Button'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(remoteActivated, isTrue, reason: 'LogicalKeyboardKey.select should activate TvFocusable');

    remoteActivated = false;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(remoteActivated, isTrue, reason: 'LogicalKeyboardKey.enter should activate TvFocusable');
  });
}
