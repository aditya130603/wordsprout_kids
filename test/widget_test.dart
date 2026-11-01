import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordsprout_kids/curriculum.dart';
import 'package:wordsprout_kids/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (call) async => 1);
  });
  Future<void> launch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const WordSprout());
    await tester.pumpAndSettle();
  }
  test('130 words cover A to Z; each has three facts and unique artwork', () async {
    final data = await Curriculum.load();
    expect(data.words.length, 130);
    expect(data.words.map((w) => w.id).toSet().length, 130);
    expect(data.words.map((w) => w.image).toSet().length, 130);
    for (var i = 0; i < 26; i++) {
      expect(data.forLetter(i).length, 5);
      for (final w in data.forLetter(i)) {
        expect(w.letter, String.fromCharCode(65 + i));
        expect(w.facts.length, 3);
        expect(w.facts.every((f) => f.trim().isNotEmpty), isTrue);
      }
    }
    expect(data.forLetter(23).every((w) => w.spelling.contains('X')), isTrue);
  });

  testWidgets('home shows an alphabet adventure and full progress', (tester) async {
    await launch(tester);
    expect(find.text('Your Alphabet Trail'), findsOneWidget);
    expect(find.text('Continue Learning  ➜'), findsOneWidget);
    expect(find.text('0/130'), findsOneWidget);
  });

  testWidgets('three facts are readable for the first word', (tester) async {
    await launch(tester);
    await tester.tap(find.text('Continue Learning  ➜'));
    await tester.pumpAndSettle();
    expect(find.text('An ant is tiny.'), findsOneWidget);
    expect(find.text('Some ants can bite.'), findsOneWidget);
    expect(find.text('Ants live together in colonies.'), findsOneWidget);
  });

  testWidgets('recognition uses four unique bundled illustrations', (tester) async {
    await launch(tester);
    await tester.tap(find.text('Continue Learning  ➜'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next ➜'));
    await tester.pumpAndSettle();
    for (final ch in ['A', 'N', 'T']) {
      await tester.tap(find.text(ch).last);
      await tester.pump();
    }
    await tester.tap(find.text('✓ Check'));
    await tester.pumpAndSettle();
    final illustrations = tester.widgetList<SvgPicture>(find.byType(SvgPicture))
        .map((w) => w.semanticsLabel).toList();
    expect(illustrations, hasLength(4));
    expect(illustrations.toSet(), <String>{'ANT', 'APPLE', 'ARM', 'AXE'});
  });

  testWidgets('all 26 letters are visible in the learning library', (tester) async {
    await launch(tester);
    await tester.tap(find.text('Learn').last);
    await tester.pumpAndSettle();
    expect(find.text('Alphabet A–Z'), findsOneWidget);
    expect(find.text('Z'), findsWidgets);
  });
}
