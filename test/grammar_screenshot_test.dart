import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordsprout_kids/grammar/tiny_grammar_course.dart';
import 'package:wordsprout_kids/grammar/tiny_grammar_home.dart';
import 'package:wordsprout_kids/family_settings.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  final course=TinyGrammarCourse.fromJson(
    jsonDecode(File('assets/content/grammar_4_6_v1.json')
      .readAsStringSync()) as Map<String,dynamic>);

  setUpAll(() async{
    final font=File('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf');
    if(await font.exists()){
      final loader=FontLoader('Roboto');
      loader.addFont(Future.value(ByteData.sublistView(await font.readAsBytes())));
      await loader.load();
    }
    final path=(await Process.run('which',['flutter'])).stdout.toString().trim();
    if(path.isNotEmpty){
      final resolved=File(path).resolveSymbolicLinksSync();
      final material=File(File(resolved).parent.parent.path+
        '/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
      if(await material.exists()){
        final loader=FontLoader('MaterialIcons');
        loader.addFont(Future.value(ByteData.sublistView(await material.readAsBytes())));
        await loader.load();
      }
    }
  });
  setUp((){
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('flutter_tts'),(call) async=>1);
  });
  Future<void> launch(WidgetTester tester) async{
    tester.view.physicalSize=const Size(390,844);
    tester.view.devicePixelRatio=1;
    addTearDown((){
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(home:TinyGrammarHome(initialCourse:course)));
    await tester.pumpAndSettle();
  }
  testWidgets('Grammar Garden 4–6 five categories', (tester)async{
    await launch(tester);
    expect(find.text('Little words. Big ideas!'),findsOneWidget);
    expect(find.text('26 / 26 lessons'),findsNothing);
    await expectLater(find.byType(Scaffold).last,
      matchesGoldenFile('screenshots/13-grammar-garden.png'));
  });
  testWidgets('Question words lesson illustration', (tester)async{
    await launch(tester);
    await tester.tap(find.byKey(const ValueKey('grammar_lesson_what')));
    await tester.pumpAndSettle();
    expect(find.text('We use WHAT to ask about a thing.'),findsOneWidget);
    await expectLater(find.byType(Scaffold).last,
      matchesGoldenFile('screenshots/14-grammar-what.png'));
  });
  testWidgets('Under spatial picture and answer', (tester)async{
    await launch(tester);
    await tester.tap(find.byKey(const ValueKey('grammar_group_positions')));
    await tester.pumpAndSettle();
    final under=find.byKey(const ValueKey('grammar_lesson_under'));
    await tester.ensureVisible(under);
    await tester.pumpAndSettle();
    await tester.tap(under);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Let’s play!'));
    await tester.pumpAndSettle();
    expect(find.text('Under the table'),findsOneWidget);
    await expectLater(find.byType(Scaffold).last,
      matchesGoldenFile('screenshots/15-grammar-under.png'));
  });
  testWidgets('Family settings default league toggle', (tester)async{
    tester.view.physicalSize=const Size(390,844);
    tester.view.devicePixelRatio=1;
    addTearDown((){
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const MaterialApp(home:FamilySettings()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('family_friends_toggle')),findsOneWidget);
    await expectLater(find.byType(Scaffold).last,
      matchesGoldenFile('screenshots/16-family-settings.png'));
  });
}
