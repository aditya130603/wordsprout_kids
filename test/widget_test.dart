import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:wordsprout_kids/main.dart';

void main() {
  test('every starter word contains exactly three facts', () {
    expect(words.length, 5);
    for (final word in words) {
      expect(word.facts.length, 3);
      expect(word.facts.every((fact) => fact.trim().isNotEmpty), isTrue);
    }
  });

  testWidgets('home presents alphabet adventure', (tester) async {
    await tester.pumpWidget(const WordSprout());
    await tester.pump();
    expect(find.text('Your Alphabet Trail'), findsOneWidget);
    expect(find.text('Continue Learning  ➜'), findsOneWidget);
  });

  testWidgets('all picture choices have individual vector illustrations', (tester) async {
    await tester.pumpWidget(const WordSprout());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue Learning  ➜'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next ➜'));
    await tester.pumpAndSettle();
    for (final letter in ['A', 'N', 'T']) {
      await tester.tap(find.text(letter).last);
      await tester.pump();
    }
    await tester.tap(find.text('✓ Check'));
    await tester.pumpAndSettle();
    final images = tester.widgetList<SvgPicture>(find.byType(SvgPicture)).toList();
    expect(images.length, 4);
    expect(images.map((image) => image.semanticsLabel).toSet(),
        containsAll(<String>{'ANT', 'APPLE', 'ARM', 'AXE'}));
  });

  testWidgets('first word presents exactly three facts', (tester) async {
    await tester.pumpWidget(const WordSprout());
    await tester.pump();
    await tester.tap(find.text('Continue Learning  ➜'));
    await tester.pump();
    expect(find.text('An ant is tiny.'), findsOneWidget);
    expect(find.text('Some ants can bite.'), findsOneWidget);
    expect(find.text('Ants live together in colonies.'), findsOneWidget);
  });
}
