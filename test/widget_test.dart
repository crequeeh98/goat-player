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

    // Test onLongPress with remote key hold and contextMenu
    bool pressed = false;
    bool longPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TvRemoteScope(
            isRoot: false,
            child: TvFocusable(
              autofocus: true,
              onPressed: () => pressed = true,
              onLongPress: () => longPressed = true,
              child: const Text('TV Long Press Item'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. ContextMenu / Menu button should trigger onLongPress immediately
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await tester.pumpAndSettle();
    expect(longPressed, isTrue, reason: 'LogicalKeyboardKey.contextMenu should trigger onLongPress');
    expect(pressed, isFalse, reason: 'contextMenu should not trigger onPressed');

    // 2. Short press (<500ms) triggers onPressed, not onLongPress
    pressed = false;
    longPressed = false;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(pressed, isTrue, reason: 'Short press should trigger onPressed');
    expect(longPressed, isFalse, reason: 'Short press should not trigger onLongPress');

    // 3. Long press (>=500ms) triggers onLongPress, not onPressed
    pressed = false;
    longPressed = false;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 550));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(longPressed, isTrue, reason: 'Held press >=500ms should trigger onLongPress');
    expect(pressed, isFalse, reason: 'Held press should not trigger onPressed on release');
  });
}
