import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordsprout_kids/app_v2.dart';
import 'package:wordsprout_kids/curriculum.dart';

/// True render captures of the current Word Discovery Flutter widget.
/// NEVER generate a visual mockup for this QA test. Assets are the exact
/// SVGs bundled by scripts/build_assets.py in the current Android APK.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture=Curriculum.fromJson(jsonDecode(
    File('assets/content/words_v1.json').readAsStringSync())
    as Map<String,dynamic>);

  setUpAll(() async {
    Future<void> loadFont(String family,String path) async {
      final file=File(path);
      if(!await file.exists())return;
      final loader=FontLoader(family);
      loader.addFont(Future.value(ByteData.sublistView(await file.readAsBytes())));
      await loader.load();
    }
    await loadFont('Roboto','/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf');
    await loadFont('sans-serif','/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf');
    final command=await Process.run('which',['flutter']);
    final executable=command.stdout.toString().trim();
    if(executable.isNotEmpty) {
      final resolved=File(executable).resolveSymbolicLinksSync();
      final iconPath=File(resolved).parent.parent.path+
        '/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
      await loadFont('MaterialIcons',iconPath);
    }
    await loadFont('Noto Color Emoji',
      '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf');
  });

  setUp((){
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('flutter_tts'),
        (call)async=>1);
  });

  const samples=<({String letter,int position,String word,String file})>[
    (letter:'G',position:2,word:'GRAPES',file:'17-G-2-GRAPES.png'),
    (letter:'K',position:4,word:'KANGAROO',file:'18-K-4-KANGAROO.png'),
    (letter:'L',position:5,word:'LOBSTER',file:'19-L-5-LOBSTER.png'),
    (letter:'M',position:4,word:'MANGO',file:'20-M-4-MANGO.png'),
    (letter:'W',position:5,word:'WATERMELON',file:'21-W-5-WATERMELON.png'),
    (letter:'P',position:4,word:'PENCIL',file:'22-P-4-PENCIL.png'),
  ];

  for(final sample in samples){
    testWidgets('REAL app Word Discovery '+sample.letter+sample.position.toString()+
      ': '+sample.word,(tester)async{
      final index=(sample.letter.codeUnitAt(0)-65)*5+sample.position-1;
      final word=fixture.words[index];
      expect(word.letter,sample.letter);
      expect(word.name,sample.word);
      expect(word.facts.length,3);
      // This is the actual Home widget's real lesson rendering code. The
      // only test hook is setting the active word to the chosen position.
      tester.view.physicalSize=const Size(390,844);
      tester.view.devicePixelRatio=1;
      addTearDown((){
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(MaterialApp(
        theme:ThemeData(useMaterial3:true,
          scaffoldBackgroundColor:const Color(0xFFFFF8EB),
          colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xFF77B932))),
        home:Home(initialCatalog:fixture,previewWordIndex:index)));
      await tester.pumpAndSettle();
      expect(find.text(sample.word),findsOneWidget);
      for(final fact in word.facts){
        expect(find.text(fact),findsOneWidget);
      }
      await expectLater(find.byType(Scaffold),
        matchesGoldenFile('screenshots/'+sample.file));
    });
  }
}
