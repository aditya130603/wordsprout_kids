import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordsprout_kids/older/older_course.dart';
import 'package:wordsprout_kids/older/older_home.dart';
import 'package:wordsprout_kids/older/rewards.dart';
import 'package:wordsprout_kids/older/rewards_hub.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture=OlderCourse.fromJson(jsonDecode(
    File('assets/content/older_missions_v1.json').readAsStringSync())
      as Map<String,dynamic>);
  setUpAll(() async {
    final path='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf';
    if(await File(path).exists()){
      final bytes=await File(path).readAsBytes();
      final loader=FontLoader('Roboto');
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
    final command=await Process.run('which',['flutter']);
    final executable=command.stdout.toString().trim();
    if(executable.isNotEmpty){
      final sdk=File(executable).resolveSymbolicLinksSync();
      final file=File(File(sdk).parent.parent.path+
        '/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
      if(await file.exists()){
        final loader=FontLoader('MaterialIcons');
        loader.addFont(Future.value(ByteData.sublistView(
          await file.readAsBytes())));
        await loader.load();
      }
    }
  });
  setUp((){
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('flutter_tts'),(call) async=>1);
  });
  Future<void> openHome(WidgetTester tester) async {
    tester.view.physicalSize=const Size(390,844);
    tester.view.devicePixelRatio=1;
    addTearDown((){
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(home:OlderHome(initialCourse:fixture)));
    await tester.pumpAndSettle();
  }
  testWidgets('capture older adventure track selection', (tester) async {
    await openHome(tester);
    await expectLater(find.byType(Scaffold).first,
      matchesGoldenFile('screenshots/05-older-adventure.png'));
  });
  testWidgets('capture first mission story', (tester) async {
    await openHome(tester);
    final mission=find.byKey(const ValueKey('older_mission_ex_lantern'));
    await tester.scrollUntilVisible(mission, 180,
      scrollable:find.byType(Scrollable).first, maxScrolls:20);
    await tester.pumpAndSettle();
    await tester.tap(mission);
    await tester.pumpAndSettle();
    await expectLater(find.byType(Scaffold).last,
      matchesGoldenFile('screenshots/06-story-introduction.png'));
  });
  testWidgets('capture word detective challenge', (tester) async {
    await openHome(tester);
    final mission=find.byKey(const ValueKey('older_mission_ex_lantern'));
    await tester.scrollUntilVisible(mission, 180,
      scrollable:find.byType(Scrollable).first, maxScrolls:20);
    await tester.pumpAndSettle();
    await tester.tap(mission);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start the adventure'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(Scaffold).last,
      matchesGoldenFile('screenshots/07-word-detective.png'));
  });
  testWidgets('capture XP and achievement badges', (tester) async {
    await openHome(tester);
    final button=find.byKey(const ValueKey('older_rewards_entry'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('My Rewards'),findsOneWidget);
    await expectLater(find.byType(Scaffold).last,
      matchesGoldenFile('screenshots/08-achievements.png'));
  });

  testWidgets('capture private friends league without fake users',(tester) async{
    await openHome(tester);
    final button=find.byKey(const ValueKey('older_rewards_entry'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Friends League'));
    await tester.pumpAndSettle();
    expect(find.text('Parent setup required'),findsOneWidget);
    await expectLater(find.byType(Scaffold).last,
      matchesGoldenFile('screenshots/09-friends-league.png'));
  });

  testWidgets('capture earned achievement badges and XP', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final ledger=await RewardLedger.load();
    await ledger.answer(missionId:'ex_lantern',
      stage:'detective',index:0,wrongAttempts:0);
    await ledger.finish('ex_lantern');
    await ledger.perfect('ex_lantern');
    tester.view.physicalSize=const Size(390,844);
    tester.view.devicePixelRatio=1;
    addTearDown((){
      tester.view.resetPhysicalSize();tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(home:RewardsHub(
      ledger:ledger,missionStars:const {'ex_lantern':3})));
    await tester.pumpAndSettle();
    expect(find.text('40 XP'),findsOneWidget);
    await expectLater(find.byType(Scaffold),
      matchesGoldenFile('screenshots/10-earned-badges.png'));
  });

}
