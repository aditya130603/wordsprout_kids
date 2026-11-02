import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordsprout_kids/app_v2.dart';
import 'package:wordsprout_kids/curriculum.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final catalog=Curriculum.fromJson(
    jsonDecode(File('assets/content/words_v1.json').readAsStringSync())
      as Map<String,dynamic>);
  setUp((){
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('flutter_tts'),
        (call)async=>1);
  });

  Future<void> render(WidgetTester tester,{
    Set<int> learned=const {},Set<int> checkpoints=const {},
    int seed=3,int? wordIndex
  })async{
    tester.view.physicalSize=const Size(390,844);
    tester.view.devicePixelRatio=1;
    addTearDown((){
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(
      home:Home(key:ValueKey('preschool_test_$seed'),
        initialCatalog:catalog,initialCompleted:learned,
        initialCheckpoints:checkpoints,previewWordIndex:wordIndex,
        quizSeed:seed)));
    await tester.pumpAndSettle();
  }

  testWidgets('after five A words, move straight to B; no separate A quiz',
    (tester)async {
    await render(tester,learned:{0,1,2,3,4});
    expect(find.textContaining('Letter B • 0 / 5 words'),findsOneWidget);
    expect(find.text('Take Letter A Test'),findsNothing);
    await tester.tap(find.text('Continue Learning  ➜'));
    await tester.pumpAndSettle();
    expect(find.text('Learn Letter B'),findsOneWidget);
  });

  testWidgets('one mixed 15-question assessment follows five letters A–E',
    (tester)async {
    await render(tester,learned:{for(var i=0;i<25;i++)i});
    expect(find.text('Five-letter checkpoint!'),findsOneWidget);
    await tester.tap(find.text('Play checkpoint ➜'));
    await tester.pumpAndSettle();
    expect(find.text('Mixed alphabet checkpoint • 1/15'),findsOneWidget);
    expect(find.textContaining('Letter E test'),findsNothing);
  });

  testWidgets('final U–Z set uses six letters and 18 varied questions',
    (tester)async {
    await render(tester,
      learned:{for(var i=0;i<130;i++)i},
      checkpoints:{4,9,14,19});
    expect(find.text('Five-letter checkpoint!'),findsOneWidget);
    await tester.tap(find.text('Play checkpoint ➜'));
    await tester.pumpAndSettle();
    expect(find.text('Mixed alphabet checkpoint • 1/18'),findsOneWidget);
  });

  testWidgets('picture and true fact answers move across positions and persist',
    (tester)async {
    final picturePositions=<int>{};
    final factPositions=<int>{};
    for(var seed=0;seed<12;seed++) {
      await render(tester,wordIndex:0,seed:seed);
      await tester.tap(find.text('Next ➜'));
      await tester.pumpAndSettle();
      for(final ch in ['A','N','T']){
        final matching=find.widgetWithText(FilledButton,ch);
        expect(matching,findsWidgets);
        await tester.tap(matching.last);
        await tester.pump();
      }
      await tester.tap(find.text('✓ Check'));
      await tester.pumpAndSettle();
      final choices=tester.widgetList<SvgPicture>(
        find.byType(SvgPicture)).map((w)=>w.semanticsLabel).toList();
      expect(choices.length,4);
      final pictureIndex=choices.indexOf('ANT');
      picturePositions.add(pictureIndex);
      expect(pictureIndex,greaterThanOrEqualTo(0));
      // Choosing the wrong picture must not advance.
      final wrongIndex=choices.indexWhere((x)=>x!='ANT');
      final wrongName=choices[wrongIndex]!;
      final wrongWord=catalog.words.indexWhere((w)=>w.name==wrongName);
      await tester.tap(find.byKey(ValueKey('picture_option_$wrongWord')));
      await tester.pumpAndSettle();
      expect(find.text('Look closely and try again!'),findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('picture_option_0')));
      await tester.pumpAndSettle();
      final facts=<String>[];
      for(var i=0;i<3;i++){
        final tile=tester.widget<ListTile>(
          find.byKey(ValueKey('fact_option_$i')));
        facts.add((tile.title! as Text).data!);
      }
      final factIndex=facts.indexOf(catalog.words[0].facts.first);
      factPositions.add(factIndex);
      expect(factIndex,greaterThanOrEqualTo(0));
      final wrongFact=facts.indexWhere((v)=>v!=catalog.words[0].facts.first);
      await tester.tap(find.byKey(ValueKey('fact_option_$wrongFact')));
      await tester.pumpAndSettle();
      expect(find.text('Listen again and try!'),findsOneWidget);
      await tester.tap(find.byKey(ValueKey('fact_option_$factIndex')));
      await tester.pumpAndSettle();
      expect(find.text('Great job!'),findsOneWidget);
    }
    expect(picturePositions.length,greaterThan(1),
      reason:'Picture correct location must not always be slot zero');
    expect(factPositions.length,greaterThan(1),
      reason:'True fact correct location must not always be slot zero');
  });
}
