import 'package:flutter/material.dart';
import 'rewards.dart';

const darkInk=Color(0xFF263F3F);
const mint=Color(0xFF468975);
const pale=Color(0xFFF5F7F0);
const gold=Color(0xFFE4AD51);

class RewardsHub extends StatelessWidget {
  const RewardsHub({super.key,required this.ledger,required this.missionStars});
  final RewardLedger ledger;
  final Map<String,int> missionStars;

  IconData symbol(String name){
    switch(name){
      case 'footprints':return Icons.directions_walk_rounded;
      case 'search':return Icons.travel_explore_rounded;
      case 'map':return Icons.map_rounded;
      case 'star':return Icons.star_rounded;
      case 'brain':return Icons.psychology_alt_rounded;
      case 'lightbulb':return Icons.lightbulb_rounded;
      case 'compass':return Icons.explore_rounded;
      case 'trophy':return Icons.emoji_events_rounded;
      case 'shield':return Icons.verified_rounded;
      default:return Icons.workspace_premium_rounded;
    }
  }
  @override
  Widget build(BuildContext context){
    final badges=ledger.badges(
      highestMissionStars:missionStars.values.fold<int>(0,(a,b)=>a>b?a:b));
    final unlocked=badges.where((b)=>b.unlocked).length;
    return DefaultTabController(length:2,child:Scaffold(
      backgroundColor:pale,
      appBar:AppBar(backgroundColor:pale,
        title:const Text('My Rewards',style:TextStyle(color:darkInk,
          fontWeight:FontWeight.w900)),
        bottom:const TabBar(labelColor:mint,indicatorColor:mint,tabs:[
          Tab(icon:Icon(Icons.military_tech_rounded),text:'Badges'),
          Tab(icon:Icon(Icons.groups_rounded),text:'Friends League'),
        ])),
      body:TabBarView(children:[
        ListView(padding:const EdgeInsets.all(18),children:[
          Container(padding:const EdgeInsets.all(19),
            decoration:BoxDecoration(
              gradient:const LinearGradient(colors:[Color(0xFF387D68),Color(0xFF244F50)]),
              borderRadius:BorderRadius.circular(23)),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              const Text('YOUR LEARNING TREASURE',style:TextStyle(
                color:Color(0xFFDCF4DE),fontSize:11,letterSpacing:1.5,
                fontWeight:FontWeight.w800)),
              const SizedBox(height:13),
              Row(children:[
                const Icon(Icons.auto_awesome_rounded,color:Color(0xFFFFDB8B),size:33),
                const SizedBox(width:10),
                Text(ledger.totalXp.toString()+' XP',style:const TextStyle(
                  color:Colors.white,fontSize:33,fontWeight:FontWeight.w900)),
                const Spacer(),
                Text(unlocked.toString()+'/'+badges.length.toString()+' badges',
                  style:const TextStyle(color:Colors.white,
                    fontWeight:FontWeight.bold)),
              ]),
              const SizedBox(height:10),
              Text(ledger.thisWeekXp.toString()+' XP this week • Every correct answer counts',
                style:const TextStyle(color:Color(0xFFE0F1E8),fontSize:12)),
            ])),
          const SizedBox(height:23),
          const Text('Achievement collection',style:TextStyle(
            fontSize:22,fontWeight:FontWeight.w900,color:darkInk)),
          const SizedBox(height:4),
          const Text('Real learning unlocks badges. No purchases or lucky spins.',
            style:TextStyle(fontSize:13,color:Color(0xFF698076))),
          const SizedBox(height:14),
          ...badges.map((b)=>_badgeCard(b)),
        ]),
        _FriendsLeague(ledger:ledger),
      ]),
    ));
  }

  Widget _badgeCard(RewardBadge badge){
    final earned=badge.unlocked;
    final iconColor=earned?const Color(0xFFAA7934):const Color(0xFF9EA8A1);
    return Padding(padding:const EdgeInsets.only(bottom:10),
      child:Container(padding:const EdgeInsets.all(13),
        decoration:BoxDecoration(color:Colors.white,
          borderRadius:BorderRadius.circular(19),
          border:Border.all(color:earned?const Color(0xFFF0D5A4):
            const Color(0xFFE4E9E2))),
        child:Row(children:[
          Container(width:56,height:56,
            decoration:BoxDecoration(
              color:earned?const Color(0xFFFFF1D2):const Color(0xFFEFF1ED),
              borderRadius:BorderRadius.circular(17)),
            child:Icon(symbol(badge.symbol),color:iconColor,size:30)),
          const SizedBox(width:14),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(badge.title,style:const TextStyle(color:darkInk,
              fontSize:16,fontWeight:FontWeight.w900)),
            const SizedBox(height:4),
            Text(badge.description,style:const TextStyle(
              fontSize:12,color:Color(0xFF657A70))),
            const SizedBox(height:7),
            ClipRRect(borderRadius:BorderRadius.circular(5),
              child:LinearProgressIndicator(
                value:(badge.progress/badge.target).clamp(0.0,1.0),
                backgroundColor:const Color(0xFFEBEFE7),
                valueColor:AlwaysStoppedAnimation<Color>(
                  earned?gold:mint),minHeight:5)),
            const SizedBox(height:4),
            Text(earned?'ACHIEVED':badge.progress.toString()+'/'+
              badge.target.toString()+' progress',
              style:TextStyle(fontSize:10,fontWeight:FontWeight.w800,
                color:earned?const Color(0xFFAC7937):mint)),
          ])),
          const SizedBox(width:5),
          Icon(earned?Icons.verified_rounded:Icons.lock_outline_rounded,
            color:earned?gold:const Color(0xFFACB7AF),size:23),
        ])));
  }
}

/// Deliberately no fabricated friends, public profiles, free chat or public
/// scores. A real online league requires parent-verified accounts and a
/// deployed, server-validated backend. Offline XP works meanwhile.
class _FriendsLeague extends StatelessWidget {
  const _FriendsLeague({required this.ledger});
  final RewardLedger ledger;
  @override
  Widget build(BuildContext context)=>ListView(
    padding:const EdgeInsets.all(18),children:[
      Container(padding:const EdgeInsets.all(20),
        decoration:BoxDecoration(color:const Color(0xFF2F6769),
          borderRadius:BorderRadius.circular(23)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Row(children:[
            Icon(Icons.shield_rounded,color:Color(0xFFF3D88F)),
            SizedBox(width:9),
            Text('FRIENDS ONLY',style:TextStyle(
              color:Color(0xFFF3E4B9),fontWeight:FontWeight.w900,
              letterSpacing:1.3,fontSize:12)),
          ]),
          const SizedBox(height:14),
          const Text('Better together.',style:TextStyle(
            color:Colors.white,fontSize:28,fontWeight:FontWeight.w900)),
          const SizedBox(height:7),
          const Text('A private weekly challenge with approved friends.',
            style:TextStyle(color:Color(0xFFE1F2EA),height:1.45)),
          const SizedBox(height:17),
          Text(ledger.thisWeekXp.toString()+' XP',style:const TextStyle(
            color:Color(0xFFFFE2A2),fontSize:32,fontWeight:FontWeight.w900)),
          const Text('Your learning points this week',
            style:TextStyle(color:Color(0xFFE1F2EA),fontSize:12)),
        ])),
      const SizedBox(height:24),
      const Text('Friend leaderboard',style:TextStyle(
        color:darkInk,fontSize:23,fontWeight:FontWeight.w900)),
      const SizedBox(height:10),
      Container(padding:const EdgeInsets.all(18),
        decoration:BoxDecoration(color:Colors.white,
          border:Border.all(color:const Color(0xFFE0E7DE)),
          borderRadius:BorderRadius.circular(20)),
        child:Column(children:[
          const Icon(Icons.family_restroom_rounded,
            size:45,color:mint),
          const SizedBox(height:9),
          const Text('Parent setup required',style:TextStyle(
            fontSize:19,color:darkInk,fontWeight:FontWeight.w900)),
          const SizedBox(height:9),
          const Text('Your friends are not connected yet. The online league will show only children approved by their parents, with private nicknames and no chat.',
            textAlign:TextAlign.center,
            style:TextStyle(color:Color(0xFF62766C),height:1.5)),
          const SizedBox(height:12),
          const Text('Online competition is not active in this preview.',
            textAlign:TextAlign.center,style:TextStyle(
              color:Color(0xFF9C6C3D),fontWeight:FontWeight.w800)),
        ])),
      const SizedBox(height:18),
      const Text('How our league will work',style:TextStyle(
        color:darkInk,fontSize:17,fontWeight:FontWeight.w900)),
      const SizedBox(height:11),
      ...[
        ['1','A parent approves the account and each friend invitation'],
        ['2','Children earn verified weekly XP by learning and recalling words'],
        ['3','Only approved friends appear, never a public global ranking'],
        ['4','Every Monday starts fresh, so everyone gets another chance'],
      ].map((item)=>Padding(padding:const EdgeInsets.only(bottom:13),
        child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          CircleAvatar(radius:14,backgroundColor:const Color(0xFFDEF0E3),
            child:Text(item[0],style:const TextStyle(
              color:mint,fontSize:12,fontWeight:FontWeight.w900))),
          const SizedBox(width:10),
          Expanded(child:Text(item[1],style:const TextStyle(
            color:Color(0xFF4D6860),fontSize:13,height:1.5))),
        ]))),
    ]);
}
