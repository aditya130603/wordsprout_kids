import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordsprout_kids/curriculum.dart';
import 'package:wordsprout_kids/main.dart';
import 'package:wordsprout_kids/grammar/tiny_grammar_course.dart';
import 'package:wordsprout_kids/grammar/tiny_grammar_home.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  final grammar=TinyGrammarCourse.fromJson(jsonDecode(
    File('assets/content/grammar_4_6_v1.json').readAsStringSync())
      as Map<String,dynamic>);
  final alphabet=Curriculum.fromJson(jsonDecode(
    File('assets/content/words_v1.json').readAsStringSync())
      as Map<String,dynamic>);

  setUp((){
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('flutter_tts'),(call)async=>1);
  });

  test('26 grammar lessons have three meaningful exercises each',(){
    expect(grammar.lessons.length,26);
    expect(grammar.groups.length,5);
    expect(grammar.lessons.map((x)=>x.id).toSet().length,26);
    expect(grammar.lessons.map((x)=>x.visual).toSet().length,
      greaterThanOrEqualTo(14));
    final basics=grammar.lessons.map((l)=>l.id).toSet();
    for(final key in ['what','who','where','when','why','how','in','on',
      'under','above','below','next_to','between','behind','in_front',
      'here','there','at','before','after','now','a','an']){
      expect(basics.contains(key),isTrue,reason:key);
    }
    for(final lesson in grammar.lessons){
      expect(lesson.challenge.options.length,4);
      expect(lesson.transfer.options.length,4);
      expect(lesson.challenge.options.toSet().length,4);
      expect(lesson.transfer.options.toSet().length,4);
      expect(lesson.challenge.explain,isNotEmpty);
      expect(lesson.transfer.explain,isNotEmpty);
      expect(lesson.sentenceTokens.length,greaterThanOrEqualTo(4));
      expect(lesson.acceptsSentence(lesson.sentence),isTrue);
      expect(lesson.acceptsSentence(lesson.sentence.toLowerCase()),isTrue);
      expect(lesson.acceptsSentence('This is nonsense'),isFalse);
    }
  });

  test('invalid answer keys and duplicate lessons fail safe',(){
    final data=jsonDecode(File('assets/content/grammar_4_6_v1.json')
      .readAsStringSync()) as Map<String,dynamic>;
    final duplicate=jsonDecode(jsonEncode(data)) as Map<String,dynamic>;
    final duplicateLessons=duplicate['lessons'] as List;
    (duplicateLessons[1] as Map<String,dynamic>)['id']='what';
    expect(()=>TinyGrammarCourse.fromJson(duplicate),throwsFormatException);
    final invalid=jsonDecode(jsonEncode(data)) as Map<String,dynamic>;
    final options=((invalid['lessons'] as List)[0]
      as Map<String,dynamic>)['challenge'] as Map<String,dynamic>;
    options['answer']=5;
    expect(()=>TinyGrammarCourse.fromJson(invalid),throwsFormatException);
  });

  testWidgets('four-to-six home opens Grammar Garden',(tester)async{
    tester.view.physicalSize=const Size(390,844);
    tester.view.devicePixelRatio=1;
    addTearDown((){
      tester.view.resetPhysicalSize();tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(WordSprout(initialCatalog:alphabet));
    await tester.pumpAndSettle();
    final entry=find.byKey(const ValueKey('grammar_entry'));
    expect(entry,findsOneWidget);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.text('Grammar Garden'),findsOneWidget);
    expect(find.text('26 little lessons: what, why, where, above, below and more!'),findsNothing);
    expect(find.text('What'),findsWidgets);
  });

  testWidgets('picture quiz offers feedback and sentence-building', (tester)async{
    tester.view.physicalSize=const Size(390,844);
    tester.view.devicePixelRatio=1;
    addTearDown((){
      tester.view.resetPhysicalSize();tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(home:TinyGrammarHome(initialCourse:grammar)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('grammar_lesson_what')));
    await tester.pumpAndSettle();
    expect(find.text('We use WHAT to ask about a thing.'),findsOneWidget);
    await tester.tap(find.text('Let’s play!'));
    await tester.pumpAndSettle();
    expect(find.text('QUESTION 1 OF 3'),findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('grammar_answer_2')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Try again!'),findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('grammar_answer_0')));
    await tester.pumpAndSettle();
    expect(find.text('WHAT asks about things.'),findsOneWidget);
    await tester.tap(find.text('Continue ➜'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('grammar_answer_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue ➜'));
    await tester.pumpAndSettle();
    expect(find.text('SENTENCE BUILDER'),findsOneWidget);
    final play=grammar.lessons.first;
    for(final term in play.sentenceTokens){
      final tileIndex=play.sentenceTokens.indexOf(term);
      // Tile positions use a fixed word shuffle. Locate a visible tile by label.
      final option=find.widgetWithText(ActionChip,term);
      if(option.evaluate().isNotEmpty){
        await tester.ensureVisible(option.last);
        await tester.tap(option.last);
        await tester.pump();
      }else{
        // Explicitly report an inaccessible spelling tile rather than skip.
        fail('Missing sentence tile: '+term+' (#'+tileIndex.toString()+')');
      }
    }
    await tester.ensureVisible(find.text('Check my sentence'));
    await tester.tap(find.text('Check my sentence'));
    await tester.pumpAndSettle();
    expect(find.textContaining('You did it!'),findsOneWidget);
    await tester.tap(find.text('Continue ➜'));
    await tester.pumpAndSettle();
    expect(find.text('Wonderful work!'),findsOneWidget);
    await tester.tap(find.text('Back to Grammar Garden'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 26 lessons'),findsOneWidget);
    expect((await SharedPreferences.getInstance())
      .getStringList('grammar_4_6_stars_v1'),contains('what:2'));
  });
}
