import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordsprout_kids/onboarding/onboarding_flow.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font=File('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf');
    if(await font.exists()){
      final loader=FontLoader('Roboto');
      loader.addFont(Future.value(ByteData.sublistView(await font.readAsBytes())));
      await loader.load();
    }
    final result=(await Process.run('which',['flutter'])).stdout.toString().trim();
    if(result.isNotEmpty){
      final sdk=File(result).resolveSymbolicLinksSync();
      final file=File(File(sdk).parent.parent.path+
        '/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
      if(await file.exists()){
        final loader=FontLoader('MaterialIcons');
        loader.addFont(Future.value(
          ByteData.sublistView(await file.readAsBytes())));
        await loader.load();
      }
    }
  });
  setUp(()=>SharedPreferences.setMockInitialValues({}));

  Future<void> launch(WidgetTester tester)async{
    tester.view.physicalSize=const Size(390,844);
    tester.view.devicePixelRatio=1;
    addTearDown((){
      tester.view.resetPhysicalSize();tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(home:WordSproutOnboarding(
      onFinished:(_){ })));
    await tester.pumpAndSettle();
  }

  testWidgets('capture actual illustrated name and age onboarding',(tester)async{
    await launch(tester);
    expect(find.byKey(const ValueKey('onboarding_hero')),findsOneWidget);
    await expectLater(find.byType(Scaffold),
      matchesGoldenFile('screenshots/28-onboarding-name-and-age.png'));
  });

  testWidgets('capture actual Explorer/Adventurer/Word Master selection',
    (tester)async{
    await launch(tester);
    await tester.enterText(find.byKey(const ValueKey('onboarding_name')),'Mira');
    await tester.ensureVisible(find.byKey(const ValueKey('onboarding_age_6-12')));
    await tester.tap(find.byKey(const ValueKey('onboarding_age_6-12')));
    await tester.tap(find.byKey(const ValueKey('onboarding_continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('onboarding_track_explorer')),
      findsOneWidget);
    await expectLater(find.byType(Scaffold),
      matchesGoldenFile('screenshots/29-onboarding-choose-adventure.png'));
  });
}
