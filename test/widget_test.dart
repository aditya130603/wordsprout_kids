import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    expect(find.text('Alphabet Adventure'), findsOneWidget);
    expect(find.text('Continue ➜'), findsOneWidget);
  });

  testWidgets('first word presents exactly three facts', (tester) async {
    await tester.pumpWidget(const WordSprout());
    await tester.pump();
    await tester.tap(find.text('Continue ➜'));
    await tester.pump();
    expect(find.text('An ant is tiny.'), findsOneWidget);
    expect(find.text('Some ants can bite.'), findsOneWidget);
    expect(find.text('Ants live together in colonies.'), findsOneWidget);
  });
}
