import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordsprout_kids/app_v2.dart';
import 'package:wordsprout_kids/older/older_course.dart';
import 'package:wordsprout_kids/onboarding/learner_profile.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  final olderFixture=OlderCourse.fromJson(jsonDecode(
    File('assets/content/older_missions_v1.json').readAsStringSync())
      as Map<String,dynamic>);
  setUp((){
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('flutter_tts'),
        (call)async=>1);
  });

  test('profiles persist locally and reject missing age or nickname',()async{
    expect(LearnerProfile.validateName(' '),isNotNull);
    expect(LearnerProfile.validateName('Mira'),isNull);
    const original=LearnerProfile(
      name:'Mira',ageGroup:'6-12',track:'adventurer');
    await original.save();
    final loaded=await LearnerProfile.load();
    expect(loaded?.name,'Mira');
    expect(loaded?.older,isTrue);
    expect(loaded?.track,'adventurer');
    final prefs=await SharedPreferences.getInstance();
    expect(prefs.getString('older_selected_track'),'adventurer');
    expect(prefs.getBool(LearnerProfile.doneKey),isTrue);
  });

  test('upgrading existing preschool progress does not erase it',()async{
    SharedPreferences.setMockInitialValues({'done':['0','1','2']});
    final old=await LearnerProfile.load();
    expect(old?.ageGroup,'4-6');
    expect(old?.name,'Explorer');
    expect((await SharedPreferences.getInstance())
      .getStringList('done'),['0','1','2']);
  });

  Future<void> launch(WidgetTester tester)async{
    tester.view.physicalSize=const Size(390,844);
    tester.view.devicePixelRatio=1;
    addTearDown((){
      tester.view.resetPhysicalSize();tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(WordSprout(initialOlderCourse:olderFixture));
    await tester.pumpAndSettle();
  }

  testWidgets('new users see welcome before any lessons',(tester)async{
    await launch(tester);
    expect(find.text('Welcome to\nWordSprout!'),findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding_name')),findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding_age_4-6')),findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding_age_6-12')),findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding_continue')));
    await tester.pumpAndSettle();
    expect(find.text('Add your name or a fun nickname to begin.'),findsOneWidget);
  });

  testWidgets('age 6-12 path selection stores actual adventurer curriculum',(tester)async{
    await launch(tester);
    await tester.enterText(find.byKey(const ValueKey('onboarding_name')),'Mira');
    await tester.ensureVisible(find.byKey(const ValueKey('onboarding_age_6-12')));
    await tester.tap(find.byKey(const ValueKey('onboarding_age_6-12')));
    await tester.tap(find.byKey(const ValueKey('onboarding_continue')));
    await tester.pumpAndSettle();
    expect(find.text('Explorer'),findsOneWidget);
    expect(find.text('Adventurer'),findsOneWidget);
    expect(find.text('Word Master'),findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding_track_adventurer')));
    await tester.tap(find.byKey(const ValueKey('onboarding_start')));
    await tester.pumpAndSettle();
    final prefs=await SharedPreferences.getInstance();
    expect(prefs.getString(LearnerProfile.nameKey),'Mira');
    expect(prefs.getString(LearnerProfile.ageKey),'6-12');
    expect(prefs.getString(LearnerProfile.trackKey),'adventurer');
    expect(find.text('Words have\nsuperpowers.'),findsOneWidget);
    expect(find.text('Welcome to\nWordSprout!'),findsNothing);
  });

  testWidgets('age 4-6 begins alphabet journey directly',(tester)async{
    await launch(tester);
    await tester.enterText(find.byKey(const ValueKey('onboarding_name')),'Ari');
    await tester.ensureVisible(find.byKey(const ValueKey('onboarding_age_4-6')));
    await tester.tap(find.byKey(const ValueKey('onboarding_age_4-6')));
    await tester.tap(find.byKey(const ValueKey('onboarding_continue')));
    await tester.pumpAndSettle();
    expect((await SharedPreferences.getInstance())
      .getString(LearnerProfile.ageKey),'4-6');
    expect(find.text('Your Alphabet Trail'),findsOneWidget);
    expect(find.text('Welcome to\nWordSprout!'),findsNothing);
  });

  testWidgets('returning child bypasses onboarding',(tester)async{
    SharedPreferences.setMockInitialValues({
      LearnerProfile.doneKey:true,
      LearnerProfile.nameKey:'Ari',
      LearnerProfile.ageKey:'6-12',
      LearnerProfile.trackKey:'master',
    });
    await launch(tester);
    expect(find.text('Words have\nsuperpowers.'),findsOneWidget);
    expect(find.text('Welcome to\nWordSprout!'),findsNothing);
  });

  testWidgets('back arrow keeps nickname while choosing an older track',
    (tester)async{
    await launch(tester);
    await tester.enterText(find.byKey(const ValueKey('onboarding_name')),'Ria');
    await tester.ensureVisible(find.byKey(const ValueKey('onboarding_age_6-12')));
    await tester.tap(find.byKey(const ValueKey('onboarding_age_6-12')));
    await tester.tap(find.byKey(const ValueKey('onboarding_continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding_back')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(
      find.byKey(const ValueKey('onboarding_name'))).controller?.text,'Ria');
  });
}
