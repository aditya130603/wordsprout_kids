import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordsprout_kids/main.dart';
import 'package:wordsprout_kids/curriculum.dart';
import 'package:wordsprout_kids/older/older_course.dart';
import 'package:wordsprout_kids/older/older_home.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  final data=jsonDecode(File('assets/content/older_missions_v1.json').readAsStringSync()) as Map<String,dynamic>;
  final course=OlderCourse.fromJson(data);
  final firstCatalog=Curriculum.fromJson(
    jsonDecode(File('assets/content/words_v1.json').readAsStringSync()) as Map<String,dynamic>);

  setUp((){
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('flutter_tts'),(call) async=>1);
  });

  test('twelve authored story missions, four per track, 48 unique words',(){
    expect(course.tracks.map((t)=>t.id),['explorer','adventurer','master']);
    expect(course.missions.length,12);
    final all=course.missions.expand((m)=>m.words).toList();
    expect(all.length,48);
    expect(all.map((w)=>w.term).toSet().length,48);
    for(final track in course.tracks) {
      expect(course.forTrack(track.id).length,4);
    }
    for(final m in course.missions){
      expect(m.words.length,4);
      expect(m.pattern.options.length,4);
      expect(m.transfer.options.length,4);
      expect(m.pattern.explain,isNotEmpty);
      expect(m.transfer.explain,isNotEmpty);
      expect(m.story.length,greaterThan(65));
      expect(m.scene,isNotEmpty);
      expect(m.sentencePrompt,isNotEmpty);
    }
  });

  test('sentence puzzles accept canonical and reviewed natural alternatives',(){
    for(final m in course.missions){
      expect(m.acceptsSentence(m.sentence),isTrue,reason:m.id);
      expect(m.acceptsSentence(m.sentence.toLowerCase()),isTrue);
      expect(m.acceptsSentence('Unrelated random words.'),isFalse);
      for(final alternative in m.sentenceAlternatives){
        expect(m.acceptsSentence(alternative),isTrue,reason:m.id);
      }
    }
  });

  test('invalid mission order and word entries are rejected',(){
    final bad=jsonDecode(jsonEncode(data)) as Map<String,dynamic>;
    ((bad['missions'] as List)[0] as Map<String,dynamic>)['level']='master';
    expect(()=>OlderCourse.fromJson(bad),throwsFormatException);
    final bad2=jsonDecode(jsonEncode(data)) as Map<String,dynamic>;
    (((bad2['missions'] as List)[0] as Map<String,dynamic>)['words'] as List)
      .removeLast();
    expect(()=>OlderCourse.fromJson(bad2),throwsFormatException);
  });

  testWidgets('older adventure is reachable from preschool home', (tester) async {
    tester.view.physicalSize=const Size(390,844);
    tester.view.devicePixelRatio=1;
    addTearDown((){
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(WordSprout(initialCatalog:firstCatalog));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('older_entry')));
    await tester.pumpAndSettle();
    expect(find.text('ADVENTURE CLUB'),findsOneWidget);
    expect(find.text('Choose your quest'),findsOneWidget);
    expect(find.text('Explorer'),findsOneWidget);
    expect(find.text('Adventurer'),findsOneWidget);
    expect(find.text('Word Master'),findsOneWidget);
  });

  testWidgets('first story mission opens and clues are playable',(tester) async{
    tester.view.physicalSize=const Size(390,844);
    tester.view.devicePixelRatio=1;
    addTearDown((){
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(home:OlderHome(initialCourse:course)));
    await tester.pumpAndSettle();
    final tile=find.byKey(const ValueKey('older_mission_ex_lantern'));
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.text('The Lantern Trail'),findsWidgets);
    expect(find.text('Start the adventure'),findsOneWidget);
    await tester.tap(find.text('Start the adventure'));
    await tester.pumpAndSettle();
    expect(find.text('Which word fits this situation?'),findsOneWidget);
    expect(find.text('curious'),findsOneWidget);
    await tester.tap(find.text('curious'));
    await tester.pumpAndSettle();
    expect(find.text('Continue'),findsOneWidget);
  });
}
