import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordsprout_kids/family_settings.dart';
import 'package:wordsprout_kids/older/friends_api.dart';
import 'package:wordsprout_kids/older/rewards.dart';
import 'package:wordsprout_kids/older/rewards_hub.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(()=>SharedPreferences.setMockInitialValues({}));

  testWidgets('Friends League starts visible and parents can turn it off',
    (tester) async {
      tester.view.physicalSize=const Size(390,844);
      tester.view.devicePixelRatio=1;
      addTearDown((){
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(const MaterialApp(home:FamilySettings()));
      await tester.pumpAndSettle();
      expect(await FamilySettings.leagueEnabled(),isTrue);
      final toggle=find.byKey(const ValueKey('family_friends_toggle'));
      expect(toggle,findsOneWidget);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(await FamilySettings.leagueEnabled(),isFalse);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(await FamilySettings.leagueEnabled(),isTrue);
    });

  testWidgets('disabled friends feature shows clear offline message',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        FamilySettings.leagueKey:false
      });
      final ledger=await RewardLedger.load();
      tester.view.physicalSize=const Size(390,844);
      tester.view.devicePixelRatio=1;
      addTearDown((){
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(MaterialApp(home:RewardsHub(
        ledger:ledger,missionStars:const {})));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Friends League'));
      await tester.pumpAndSettle();
      expect(find.text('Friends League is switched off'),findsOneWidget);
    });

  test('online child pairing cannot bypass disabled family setting', () async {
    final prefs=await SharedPreferences.getInstance();
    await prefs.setBool(FamilySettings.leagueKey,false);
    const api=FriendsApi();
    await expectLater(api.connect('ABCDEF1234'),throwsStateError);
  });
}
