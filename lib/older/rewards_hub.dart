import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'friends_api.dart';
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

/// No public rankings, fake friends, or unapproved child accounts.
/// Parent verification and friend approval are handled by the private server.
class _FriendsLeague extends StatefulWidget {
  const _FriendsLeague({required this.ledger});
  final RewardLedger ledger;
  @override
  State<_FriendsLeague> createState()=>_FriendsLeagueState();
}
class _FriendsLeagueState extends State<_FriendsLeague> {
  final api=const FriendsApi();
  final code=TextEditingController();
  LeagueBoard? board;
  bool connected=false;
  bool busy=false;
  String? error;

  @override
  void initState(){super.initState();_refresh();}
  @override
  void dispose(){code.dispose();super.dispose();}

  Future<void> _refresh() async {
    if(!api.configured)return;
    setState((){busy=true;error=null;});
    try {
      final paired=await api.paired;
      final league=paired?await api.leaderboard():null;
      if(mounted)setState((){connected=paired;board=league;});
    }catch(e){
      if(mounted)setState((){error='Could not reach the private league. Offline XP is safe.';});
    }finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> _pair() async {
    if(busy)return;
    setState((){busy=true;error=null;});
    try{
      await api.connect(code.text.trim());
      code.clear();
      if(!mounted)return;
      setState(()=>connected=true);
      final league=await api.leaderboard();
      if(mounted)setState(()=>board=league);
    }catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }

  Future<void> _unlink() async {
    await api.disconnect();
    if(mounted)setState((){connected=false;board=null;error=null;});
  }

  @override
  Widget build(BuildContext context){
    final entries=board?.entries??const <LeagueEntry>[];
    final me=entries.where((e)=>e.isMe).firstOrNull;
    return ListView(padding:const EdgeInsets.all(18),children:[
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
          const Text('Your own private weekly learning challenge.',
            style:TextStyle(color:Color(0xFFE1F2EA),height:1.45)),
          const SizedBox(height:17),
          Text((me?.weekXp??widget.ledger.thisWeekXp).toString()+' XP',
            style:const TextStyle(color:Color(0xFFFFE2A2),
              fontSize:32,fontWeight:FontWeight.w900)),
          Text(me!=null?'Verified league XP this week':
            'Your offline learning XP this week',
            style:const TextStyle(color:Color(0xFFE1F2EA),fontSize:12)),
        ])),
      const SizedBox(height:24),
      Row(children:[
        const Expanded(child:Text('Friend leaderboard',style:TextStyle(
          color:darkInk,fontSize:22,fontWeight:FontWeight.w900))),
        if(connected)IconButton(onPressed:busy?null:_refresh,
          icon:const Icon(Icons.refresh_rounded,color:mint)),
      ]),
      if(busy)const Padding(padding:EdgeInsets.all(12),
        child:LinearProgressIndicator(color:mint)),
      if(error!=null)Padding(padding:const EdgeInsets.symmetric(vertical:10),
        child:Text(error!,style:const TextStyle(
          color:Color(0xFF9B5D44),fontSize:13))),
      const SizedBox(height:10),
      if(!api.configured)_notice(
        icon:Icons.cloud_off_rounded,
        title:'Parent setup required',
        message:'The private league server has not been connected to this app build. Your badges and XP still work offline. No imaginary friends or scores are shown.')
      else if(!connected)_pairForm()
      else ...[
        Text('Week starting '+(board?.weekStart??'—')+
          ' (UTC) • Only approved friends',
          style:const TextStyle(color:Color(0xFF657B70),fontSize:12)),
        const SizedBox(height:13),
        if(entries.isEmpty)_notice(
          icon:Icons.wifi_off_rounded,title:'League unavailable',
          message:'Try refreshing. Your offline learning progress is unchanged.')
        else ...entries.asMap().entries.map((entry){
          final rank=entry.key+1;
          final child=entry.value;
          return Padding(padding:const EdgeInsets.only(bottom:9),child:
            Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(
              color:child.isMe?const Color(0xFFE4F1E7):Colors.white,
              borderRadius:BorderRadius.circular(17),
              border:Border.all(color:child.isMe?mint:const Color(0xFFE1E8E0))),
              child:Row(children:[
                SizedBox(width:38,child:Text('#'+rank.toString(),
                  style:TextStyle(fontSize:19,fontWeight:FontWeight.w900,
                    color:rank<=3?const Color(0xFFB68C46):darkInk))),
                CircleAvatar(backgroundColor:const Color(0xFFFFE8BC),
                  child:Icon(child.isMe?Icons.person_rounded:Icons.auto_awesome_rounded,
                    color:const Color(0xFF876C40))),
                const SizedBox(width:12),
                Expanded(child:Text(child.alias+(child.isMe?' (you)':''),
                  style:const TextStyle(color:darkInk,
                    fontSize:15,fontWeight:FontWeight.w800))),
                Text(child.weekXp.toString()+' XP',style:const TextStyle(
                  color:mint,fontSize:15,fontWeight:FontWeight.w900)),
              ])));
        }),
        if(entries.length==1)const Padding(
          padding:EdgeInsets.only(top:11),
          child:Text('No approved friends yet. A parent can invite another family from the parent portal.',
            style:TextStyle(color:Color(0xFF6C7C70),height:1.4))),
        TextButton.icon(onPressed:_unlink,
          icon:const Icon(Icons.logout_rounded,size:17),
          label:const Text('Unlink this device')),
      ],
      const SizedBox(height:20),
      const Text('Fair-play rules',style:TextStyle(
        color:darkInk,fontSize:17,fontWeight:FontWeight.w900)),
      const SizedBox(height:9),
      const Text('Only parents can approve friends. The league counts server-checked learning answers, not time spent or unlimited taps. No public rankings, messaging, photos, or location sharing. Offline XP stays on this device and does not count toward the online league until a server checks a new answer.',
        style:TextStyle(color:Color(0xFF677F72),height:1.6,fontSize:13)),
    ]);
  }

  Widget _pairForm()=>Container(padding:const EdgeInsets.all(18),
    decoration:BoxDecoration(color:Colors.white,
      border:Border.all(color:const Color(0xFFE0E7DE)),
      borderRadius:BorderRadius.circular(20)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Connect with a parent',style:TextStyle(
        fontSize:19,color:darkInk,fontWeight:FontWeight.w900)),
      const SizedBox(height:9),
      const Text('A parent verifies their email, approves each friend, and creates a one-time pairing code. Never enter your personal information here.',
        style:TextStyle(color:Color(0xFF657A70),height:1.5,fontSize:13)),
      const SizedBox(height:12),
      TextField(controller:code,maxLength:10,autocorrect:false,
        textCapitalization:TextCapitalization.characters,
        decoration:InputDecoration(labelText:'Parent-issued device code',
          border:OutlineInputBorder(borderRadius:BorderRadius.circular(14)))),
      FilledButton.icon(onPressed:busy?null:_pair,
        icon:const Icon(Icons.lock_open_rounded),
        label:const Text('Connect private league'),
        style:FilledButton.styleFrom(backgroundColor:mint,
          foregroundColor:Colors.white,minimumSize:const Size(double.infinity,47))),
      const SizedBox(height:8),
      TextButton.icon(
        onPressed:()=>Clipboard.setData(ClipboardData(text:api.parentPortal)),
        icon:const Icon(Icons.copy_all_rounded,size:18),
        label:const Text('Copy the parent setup website')),
    ]));

  Widget _notice({required IconData icon,required String title,required String message})=>
    Container(padding:const EdgeInsets.all(22),
      decoration:BoxDecoration(color:Colors.white,
        border:Border.all(color:const Color(0xFFE0E7DE)),
        borderRadius:BorderRadius.circular(20)),
      child:Column(children:[
        Icon(icon,size:41,color:mint),
        const SizedBox(height:9),
        Text(title,style:const TextStyle(color:darkInk,
          fontSize:19,fontWeight:FontWeight.w900)),
        const SizedBox(height:9),
        Text(message,textAlign:TextAlign.center,
          style:const TextStyle(color:Color(0xFF62766C),height:1.5)),
      ]));
}
