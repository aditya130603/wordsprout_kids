import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordsprout_kids/older/rewards.dart';

void main() {
  setUp(()=>SharedPreferences.setMockInitialValues({}));

  test('first-try and retry XP, with idempotent awards across reloads',() async {
    final ledger=await RewardLedger.load();
    final first=await ledger.answer(missionId:'ex_lantern',
      stage:'detective',index:0,wrongAttempts:0,
      now:DateTime(2026,11,2));
    expect(first.points,10);
    final repeat=await ledger.answer(missionId:'ex_lantern',
      stage:'detective',index:0,wrongAttempts:0);
    expect(repeat.points,0);
    expect(repeat.alreadyClaimed,isTrue);
    final retry=await ledger.answer(missionId:'ex_lantern',
      stage:'detective',index:1,wrongAttempts:2);
    expect(retry.points,4);
    final sentence=await ledger.answer(missionId:'ex_lantern',
      stage:'sentence',index:0,wrongAttempts:0);
    expect(sentence.points,15);
    final finished=await ledger.finish('ex_lantern');
    expect(finished.points,20);
    expect((await ledger.finish('ex_lantern')).points,0);
    expect((await RewardLedger.load()).totalXp,49);
  });

  test('missed sentence only earns six points when corrected',() async {
    final rewards=await RewardLedger.load();
    expect((await rewards.answer(missionId:'ad_bridge',
      stage:'sentence',index:0,wrongAttempts:2)).points,6);
    expect((await rewards.answer(missionId:'ad_bridge',
      stage:'sentence',index:0,wrongAttempts:0)).points,0);
    expect(rewards.totalXp,6);
  });

  test('correct memory recall pays once per day up to daily cap',() async {
    final rewards=await RewardLedger.load();
    final day=DateTime(2026,11,2);
    expect((await rewards.review('FRAGILE',now:day)).points,5);
    expect((await rewards.review('FRAGILE',now:day)).points,0);
    expect((await rewards.review('FRAGILE',correct:false,now:day)).points,0);
    for(var i=0;i<12;i++){
      final word='WORD'+String.fromCharCode(65+i);
      await rewards.review(word,now:day);
    }
    expect(rewards.totalXp,50);
    expect((await rewards.review('FRAGILE',now:DateTime(2026,11,3))).points,5);
  });

  test('badges unlock through genuine progress without purchases',() async {
    final rewards=await RewardLedger.load();
    expect(rewards.badges().first.unlocked,isFalse);
    await rewards.finish('ex_lantern');
    expect(rewards.badges().first.unlocked,isTrue);
    expect(rewards.badges().where((b)=>b.unlocked).length,1);
    await rewards.perfect('ex_lantern');
    expect(rewards.badges().any((b)=>
      b.id=='careful_champion'&&b.unlocked),isTrue);
    expect(rewards.badges(highestMissionStars:3).any((b)=>
      b.id=='triple_star'&&b.unlocked),isTrue);
  });

  test('rejects fake event keys and invalid XP requests',() async {
    final ledger=await RewardLedger.load();
    expect(()=>ledger.answer(missionId:'../../foo',stage:'detective',
      index:0,wrongAttempts:0),throwsArgumentError);
    expect(()=>ledger.answer(missionId:'ex_lantern',stage:'garbage',
      index:0,wrongAttempts:0),throwsArgumentError);
    expect(()=>ledger.review('../../etc/passwd'),throwsArgumentError);
  });

  test('weekly totals include only this week and reset naturally',() async {
    final ledger=await RewardLedger.load();
    await ledger.answer(missionId:'ex_lantern',stage:'pattern',
      index:0,wrongAttempts:0,now:DateTime(2026,10,25));
    await ledger.answer(missionId:'ad_bridge',stage:'pattern',
      index:0,wrongAttempts:0,now:DateTime(2026,11,2));
    expect(ledger.pointsSince(DateTime(2026,11,2)),10);
    expect(ledger.totalXp,20);
  });
}
