import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordsprout_kids/curriculum.dart';
import 'package:wordsprout_kids/games/picture_race_screen.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  final catalog=Curriculum.fromJson(jsonDecode(
    File('assets/content/words_v1.json').readAsStringSync()) as Map<String,dynamic>);
  const children=[
    RacePlayer('Sunny Comet',200,'R',true,false),
    RacePlayer('Golden Otter',100,'G',false,false),
    RacePlayer('Brave Sparrow',100,'M',false,false),
  ];

  setUpAll(()async{
    Future<void> font(String name,String path)async{
      final file=File(path);
      if(!await file.exists())return;
      final loader=FontLoader(name);
      loader.addFont(Future.value(ByteData.sublistView(await file.readAsBytes())));
      await loader.load();
    }
    await font('Roboto','/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf');
    final result=(await Process.run('which',['flutter'])).stdout.toString().trim();
    if(result.isNotEmpty){
      final flutter=File(result).resolveSymbolicLinksSync();
      await font('MaterialIcons',File(flutter).parent.parent.path+
        '/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    }
  });
  setUp(()=>SharedPreferences.setMockInitialValues({}));

  Future<void> render(WidgetTester tester,RaceSnapshot room)async{
    tester.view.physicalSize=const Size(390,844);
    tester.view.devicePixelRatio=1;
    addTearDown((){
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(
      theme:ThemeData(useMaterial3:true),
      home:PictureRaceScreen(catalog:catalog,furthestLetter:17,
        preview:room)));
    await tester.pumpAndSettle();
  }
  test('Picture Race word answers use curriculum and duplicate letters',(){
    expect(catalog.words[1].name,'APPLE');
    expect(catalog.words[1].spelling.split('')..sort(),
      equals('APPLE'.split('')..sort()));
    expect(catalog.words.length,greaterThanOrEqualTo(130));
  });
  testWidgets('real Flutter multiplayer waiting room',(tester)async{
    await render(tester,const RaceSnapshot(
      code:'H8Q3KT',state:'lobby',round:0,total:5,
      ceiling:'R',host:true,seconds:0,players:children));
    expect(find.text('Word pool: A–R'),findsOneWidget);
    expect(find.text('3 / 6 PLAYERS'),findsOneWidget);
    await expectLater(find.byType(Scaffold),
      matchesGoldenFile('screenshots/23-picture-race-lobby.png'));
  });
  testWidgets('actual picture race round with shuffled P L A E P',(tester)async{
    await render(tester,const RaceSnapshot(
      code:'H8Q3KT',state:'playing',round:3,total:5,
      ceiling:'R',host:true,seconds:27,players:children,
      wordIndex:1,tiles:['P','L','A','E','P']));
    expect(find.text('WHAT’S THIS PICTURE?'),findsOneWidget);
    expect(find.text('SHUFFLED LETTERS'),findsOneWidget);
    expect(find.byKey(const ValueKey('race_tile_0')),findsOneWidget);
    expect(find.text('Submit spelling'),findsOneWidget);
    await expectLater(find.byType(Scaffold),
      matchesGoldenFile('screenshots/24-picture-race-round.png'));
  });
  testWidgets('letter tiles are selectable with repeat letters distinct',(tester)async{
    await render(tester,const RaceSnapshot(
      code:'H8Q3KT',state:'playing',round:3,total:5,
      ceiling:'R',host:true,seconds:27,players:children,
      wordIndex:1,tiles:['P','L','A','E','P']));
    await tester.tap(find.byKey(const ValueKey('race_tile_0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('race_tile_0')),findsNothing);
    expect(find.byKey(const ValueKey('race_tile_4')),findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('race_tile_4')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('race_tile_4')),findsNothing);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('race_tile_4')),findsOneWidget);
  });
  testWidgets('real Flutter winner and 100 point scoreboard',(tester)async{
    await render(tester,const RaceSnapshot(
      code:'H8Q3KT',state:'round_complete',round:3,total:5,
      ceiling:'R',host:true,seconds:0,
      players:[
        RacePlayer('Sunny Comet',300,'R',true,true),
        RacePlayer('Golden Otter',100,'G',false,false),
        RacePlayer('Brave Sparrow',100,'M',false,false),
      ],wordIndex:1,tiles:['P','L','A','E','P'],
      answer:'APPLE',winner:'Sunny Comet'));
    expect(find.text('We have a winner!'),findsOneWidget);
    expect(find.text('APPLE'),findsOneWidget);
    expect(find.text('300 pts'),findsOneWidget);
    await expectLater(find.byType(Scaffold),
      matchesGoldenFile('screenshots/25-picture-race-winner.png'));
  });
}
