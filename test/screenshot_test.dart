import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordsprout_kids/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (call) async => 1);
  });

  Future<void> openApp(WidgetTester tester) async {
    await tester.view.resetPhysicalSize();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const WordSprout());
    await tester.pumpAndSettle();
  }

  testWidgets('capture actual Flutter home screen', (tester) async {
    await openApp(tester);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('screenshots/01-home.png'));
  });

  testWidgets('capture actual Flutter word discovery screen', (tester) async {
    await openApp(tester);
    await tester.tap(find.text('Continue ➜'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(Scaffold), matchesGoldenFile('screenshots/02-word.png'));
  });

  testWidgets('capture actual Flutter spelling screen', (tester) async {
    await openApp(tester);
    await tester.tap(find.text('Continue ➜'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next ➜'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(Scaffold), matchesGoldenFile('screenshots/03-spelling.png'));
  });

  testWidgets('capture actual Flutter picture selection screen', (tester) async {
    await openApp(tester);
    await tester.tap(find.text('Continue ➜'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next ➜'));
    await tester.pumpAndSettle();
    for (final letter in ['A', 'N', 'T']) {
      await tester.tap(find.text(letter).last);
      await tester.pump();
    }
    await tester.tap(find.text('✓ Check'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(Scaffold), matchesGoldenFile('screenshots/04-pictures.png'));
  });
}
