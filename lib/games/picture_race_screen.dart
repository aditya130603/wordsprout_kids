import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../curriculum.dart';
import '../family_settings.dart';
import '../older/friends_api.dart';

const raceInk=Color(0xFF234F3B);
const raceLeaf=Color(0xFF75B63D);
const raceCream=Color(0xFFFFF9EC);
const raceGold=Color(0xFFE6AE50);

class RaceSnapshot {
  const RaceSnapshot({required this.code,required this.state,
    required this.round,required this.total,required this.ceiling,
    required this.host,required this.seconds,required this.players,
    this.wordIndex,this.tiles=const [],this.answer,this.winner});
  final String code,state,ceiling;
  final int round,total;
  final bool host;
  final double seconds;
  final List<RacePlayer> players;
  final int? wordIndex;
  final List<String> tiles;
  final String? answer,winner;
  factory RaceSnapshot.fromJson(Map<String,dynamic> x)=>RaceSnapshot(
    code:x['code'] as String,state:x['state'] as String,
    round:x['round_index'] as int,total:x['total_rounds'] as int,
    ceiling:x['ceiling_letter'] as String,host:x['is_host'] as bool,
    seconds:(x['seconds_left'] as num).toDouble(),
    players:(x['players'] as List).map((v)=>RacePlayer.fromJson(v as Map<String,dynamic>)).toList(),
    wordIndex:x['word_index'] as int?,
    tiles:List<String>.from(x['tiles'] as List? ?? const []),
    answer:x['answer'] as String?,winner:x['winner_alias'] as String?);
}
class RacePlayer {
  const RacePlayer(this.alias,this.points,this.letter,this.me,this.winner);
  final String alias,letter;
  final int points;
  final bool me,winner;
  factory RacePlayer.fromJson(Map<String,dynamic> j)=>RacePlayer(
    j['alias'] as String,j['points'] as int,j['furthest_letter'] as String,
    j['is_me'] as bool,j['is_winner'] as bool);
}

/// Real game widgets. Screenshot tests pass a fixed sample network state to
/// this widget; installed builds use HTTP polling to the authoritative room.
class PictureRaceScreen extends StatefulWidget {
  const PictureRaceScreen({super.key,required this.catalog,
    required this.furthestLetter,this.imageDirectory,this.preview});
  final Curriculum catalog;
  final int furthestLetter;
  final Directory? imageDirectory;
  @visibleForTesting
  final RaceSnapshot? preview;
  @override
  State<PictureRaceScreen> createState()=>_PictureRaceScreenState();
}

class _PictureRaceScreenState extends State<PictureRaceScreen> {
  final api=const FriendsApi();
  final code=TextEditingController();
  Timer? ticker;
  RaceSnapshot? room;
  bool busy=false,paired=false,allowed=true,submitting=false;
  String feedback='';
  final List<int> picked=[];
  bool get preview=>widget.preview!=null;

  @override
  void initState(){
    super.initState();
    room=widget.preview;
    if(!preview)_check();
  }
  @override
  void dispose(){ticker?.cancel();code.dispose();super.dispose();}
  Future<void> _check()async{
    final enabled=await FamilySettings.leagueEnabled();
    bool isPaired=false;
    if(enabled&&api.configured){
      try{isPaired=await api.paired;}catch(_){}
    }
    if(mounted)setState((){allowed=enabled;paired=isPaired;});
  }
  Future<void> _refresh()async{
    if(room==null||busy||preview)return;
    try{
      final next=RaceSnapshot.fromJson(await api.raceGet(room!.code));
      if(!mounted)return;
      if(next.round!=room!.round||next.state!=room!.state){
        picked.clear();feedback='';submitting=false;
      }
      setState(()=>room=next);
      if(next.state=='finished')ticker?.cancel();
    }catch(_){
      if(mounted)setState(()=>feedback='Connection lost. Reconnecting…');
    }
  }
  void _startPolling(){
    ticker?.cancel();
    ticker=Timer.periodic(const Duration(seconds:1),(_)=>_refresh());
    _refresh();
  }
  Future<void> _run(Future<void> Function() task)async{
    if(busy||preview)return;
    setState((){busy=true;feedback='';});
    try{await task();}
    catch(e){if(mounted)setState(()=>feedback=e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> _create()=>_run(()async{
    final j=await api.racePost('rooms',
      {'furthest_letter':widget.furthestLetter.clamp(0,25)});
    final state=await api.raceGet(j['code'] as String);
    if(mounted)setState(()=>room=RaceSnapshot.fromJson(state));
    _startPolling();
  });
  Future<void> _join()=>_run(()async{
    final value=code.text.trim().toUpperCase();
    if(!RegExp(r'^[A-Z2-9]{6}$').hasMatch(value)){
      throw const FormatException('Enter a six-character room code');
    }
    await api.racePost('rooms/'+value+'/join',
      {'furthest_letter':widget.furthestLetter.clamp(0,25)});
    final state=await api.raceGet(value);
    if(mounted)setState(()=>room=RaceSnapshot.fromJson(state));
    _startPolling();
  });
  Future<void> _advance()=>_run(()async{
    await api.racePost('rooms/'+room!.code+'/' +
      (room!.state=='lobby'?'start':'next'),{});
    await _refresh();
  });
  Future<void> _submit()async{
    if(submitting||preview||room==null)return;
    final word=picked.map((i)=>room!.tiles[i]).join();
    setState(()=>submitting=true);
    try{
      final result=await api.racePost('rooms/'+room!.code+'/answer',{
        'round_index':room!.round,'word':word});
      if(!mounted)return;
      if(result['correct']==true)setState(()=>
        feedback='Correct! First to spell it! +100 points');
      else if(result['round_closed']==true)setState(()=>
        feedback='Someone else finished first. Next round!');
      else setState((){
        feedback='Try again! Shuffle the letters into another order.';
        picked.clear();
      });
      await _refresh();
    }catch(e){if(mounted)setState(()=>feedback='Try again: '+e.toString());}
    finally{if(mounted)setState(()=>submitting=false);}
  }
  Widget _panel(Widget body)=>Container(
    width:double.infinity,padding:const EdgeInsets.all(16),
    decoration:BoxDecoration(color:Colors.white,
      borderRadius:BorderRadius.circular(21),
      border:Border.all(color:const Color(0xFFE4EADF))),
    child:body);
  Widget _button(String text,VoidCallback? action)=>SizedBox(
    width:double.infinity,height:52,
    child:FilledButton(onPressed:action,
      style:FilledButton.styleFrom(backgroundColor:raceLeaf,
        foregroundColor:Colors.white,
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))),
      child:Text(text,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16))));
  Widget _illustration(int index){
    final word=widget.catalog.words[index];
    Widget art;
    if(word.image.endsWith('.svg'))art=SvgPicture.asset(word.image,fit:BoxFit.contain);
    else if(widget.imageDirectory!=null)art=Image.file(
      File(widget.imageDirectory!.path+'/'+word.image),fit:BoxFit.contain,
      errorBuilder:(_,__,___)=>const Icon(Icons.image_not_supported,size:70));
    else art=SvgPicture.asset('assets/words/'+word.id+'.svg',fit:BoxFit.contain);
    return Container(width:double.infinity,height:226,
      padding:const EdgeInsets.all(15),
      decoration:BoxDecoration(color:const Color(0xFFFFFEF9),
        borderRadius:BorderRadius.circular(24),
        border:Border.all(color:const Color(0xFFE5E9D9))),
      child:art);
  }
  @override
  Widget build(BuildContext context) {
    final r=room;
    return Scaffold(backgroundColor:raceCream,
      appBar:AppBar(backgroundColor:raceCream,
        title:const Text('Picture Race',style:TextStyle(
          fontWeight:FontWeight.w900,color:raceInk)),
        actions:[Padding(padding:const EdgeInsets.only(right:16),
          child:Center(child:Row(children:[
            const Icon(Icons.bolt_rounded,color:raceGold),
            const SizedBox(width:5),
            Text(r?.state=='playing'?'LIVE':'FRIENDS',
              style:const TextStyle(color:raceInk,fontWeight:FontWeight.w900,
                fontSize:11)),
          ])))],
      ),
      body:SafeArea(child:ListView(padding:const EdgeInsets.fromLTRB(18,9,18,30),
        children:[
          if(r==null)_welcome()
          else ...[
            _header(r),
            const SizedBox(height:12),
            if(r.state=='lobby')_lobby(r)
            else if(r.state=='playing')_playing(r)
            else _finished(r),
          ],
          if(feedback.isNotEmpty)...[
            const SizedBox(height:13),
            _panel(Row(children:[
              const Icon(Icons.info_outline,color:raceInk),
              const SizedBox(width:8),
              Expanded(child:Text(feedback,style:const TextStyle(
                color:raceInk,fontWeight:FontWeight.w700))),
            ])),
          ],
        ])),
    );
  }
  Widget _welcome()=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('See it. Spell it.\nWin the round!',
      style:TextStyle(color:raceInk,fontSize:32,fontWeight:FontWeight.w900,
        height:1.14)),
    const SizedBox(height:12),
    const Text('Every player sees the same picture. Tap the shuffled letters. The first correct spelling wins!',
      style:TextStyle(color:Color(0xFF63796C),fontSize:15,height:1.5)),
    const SizedBox(height:17),
    _panel(Column(children:[
      const Icon(Icons.groups_rounded,color:raceLeaf,size:55),
      const SizedBox(height:8),
      const Text('Play with friends',style:TextStyle(
        color:raceInk,fontSize:21,fontWeight:FontWeight.w900)),
      const SizedBox(height:12),
      Text('Your level: A–'+String.fromCharCode(65+widget.furthestLetter.clamp(0,25)),
        style:const TextStyle(color:raceInk,fontWeight:FontWeight.w700)),
      const SizedBox(height:13),
      if(!allowed)const Text('Friends League is disabled in Family Settings.')
      else if(!api.configured)const Text(
        'Live rooms need the private server to be deployed. Multiplayer is not connected in this build.',
        textAlign:TextAlign.center)
      else if(!paired)const Text(
        'Connect your approved private Friends League profile first.',
        textAlign:TextAlign.center)
      else ...[
        _button('Create a room',busy?null:_create),
        const SizedBox(height:10),
        TextField(controller:code,maxLength:6,
          textCapitalization:TextCapitalization.characters,
          decoration:const InputDecoration(labelText:'Friend’s room code',
            border:OutlineInputBorder())),
        _button('Join my friends',busy?null:_join),
      ],
    ])),
    const SizedBox(height:18),
    const Text('Five quick rounds • 2–6 approved friends',
      style:TextStyle(color:raceInk,fontSize:16,fontWeight:FontWeight.w900)),
    const SizedBox(height:7),
    const Text('The furthest player’s alphabet sets the word range. Everyone gets the same picture but differently shuffled letters. The first correct answer gets 100 points.',
      style:TextStyle(color:Color(0xFF63796C),height:1.5)),
  ]);
  Widget _header(RaceSnapshot r)=>_panel(Row(children:[
    const CircleAvatar(radius:24,backgroundColor:Color(0xFFE9F5D8),
      child:Icon(Icons.people_alt_rounded,color:raceInk,size:25)),
    const SizedBox(width:13),
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('ROOM '+r.code,style:const TextStyle(
        color:raceInk,fontWeight:FontWeight.w900,fontSize:16)),
      const SizedBox(height:4),
      Text('Pictures A–'+r.ceiling+'  •  '+r.players.length.toString()+' players',
        style:const TextStyle(color:Color(0xFF607568),fontSize:12)),
    ])),
    Text(r.state=='lobby'?'WAITING':r.state=='playing'?
      'ROUND '+r.round.toString()+'/'+r.total.toString():
      r.state=='finished'?'FINAL':'ROUND OVER',
      style:const TextStyle(color:raceLeaf,fontWeight:FontWeight.w900,fontSize:10)),
  ]));
  Widget _players(RaceSnapshot r,{bool progress=false})=>Column(children:[
    for(final p in r.players)Padding(padding:const EdgeInsets.only(bottom:11),
      child:Row(children:[
        CircleAvatar(radius:19,backgroundColor:
          p.me?const Color(0xFFDCF0D7):const Color(0xFFFFEBC9),
          child:Icon(p.winner?Icons.emoji_events_rounded:Icons.person_rounded,
            color:p.winner?raceGold:raceInk,size:21)),
        const SizedBox(width:10),
        Expanded(child:Text(p.alias+(p.me?' (you)':''),
          style:const TextStyle(color:raceInk,fontSize:15,
            fontWeight:FontWeight.w800))),
        Text(progress?'to '+p.letter:p.points.toString()+' pts',
          style:const TextStyle(color:raceInk,fontWeight:FontWeight.w800)),
      ])),
  ]);
  Widget _lobby(RaceSnapshot r)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('Ready, word explorers?',style:TextStyle(
      color:raceInk,fontSize:26,fontWeight:FontWeight.w900)),
    const SizedBox(height:8),
    const Text('Share the room code with your approved friends.',
      style:TextStyle(color:Color(0xFF65786A))),
    const SizedBox(height:14),
    _panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(r.players.length.toString()+' / 6 PLAYERS',style:const TextStyle(
        color:raceInk,fontWeight:FontWeight.w900)),
      const SizedBox(height:14),
      _players(r,progress:true),
    ])),
    const SizedBox(height:16),
    _panel(Column(children:[
      const Icon(Icons.auto_awesome_rounded,color:raceGold,size:29),
      const SizedBox(height:7),
      Text('Word pool: A–'+r.ceiling,style:const TextStyle(
        color:raceInk,fontWeight:FontWeight.w900,fontSize:19)),
      const SizedBox(height:5),
      const Text('The player who has reached the furthest letter sets the range.',
        textAlign:TextAlign.center,
        style:TextStyle(color:Color(0xFF687B6A),height:1.4)),
    ])),
    const SizedBox(height:16),
    if(r.host)_button('Start 5-round race',
      r.players.length>=2&&!preview&&!busy?_advance:null)
    else const Text('Waiting for the host to start.',
      style:TextStyle(color:raceInk)),
  ]);
  Widget _tile(String value,{bool filled=false})=>Container(
    width:45,height:47,alignment:Alignment.center,
    decoration:BoxDecoration(color:filled?const Color(0xFFE4F3D7):Colors.white,
      borderRadius:BorderRadius.circular(12),
      border:Border.all(color:filled?raceLeaf:const Color(0xFFB9D7A4),
        width:filled?2:1.5)),
    child:Text(value,style:const TextStyle(color:raceInk,
      fontSize:21,fontWeight:FontWeight.w900)));
  Widget _playing(RaceSnapshot r){
    if(r.wordIndex==null)return const Text('Preparing picture…');
    final done=picked.length==r.tiles.length;
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        const Expanded(child:Text('WHAT’S THIS PICTURE?',style:TextStyle(
          color:raceInk,fontSize:17,fontWeight:FontWeight.w900))),
        Container(padding:const EdgeInsets.symmetric(horizontal:11,vertical:6),
          decoration:BoxDecoration(color:const Color(0xFFFFE9BF),
            borderRadius:BorderRadius.circular(12)),
          child:Text(r.seconds.ceil().toString()+'s',style:const TextStyle(
            color:raceInk,fontWeight:FontWeight.w900,fontSize:17))),
      ]),
      const SizedBox(height:12),
      _illustration(r.wordIndex!),
      const SizedBox(height:14),
      const Text('Make the word',style:TextStyle(
        color:raceInk,fontWeight:FontWeight.w900,fontSize:19)),
      const SizedBox(height:9),
      Container(width:double.infinity,constraints:const BoxConstraints(minHeight:63),
        padding:const EdgeInsets.all(8),
        decoration:BoxDecoration(color:Colors.white,
          border:Border.all(color:const Color(0xFFB5DFA1),width:2),
          borderRadius:BorderRadius.circular(17)),
        child:Wrap(spacing:7,runSpacing:7,children:[
          for(final i in picked)InkWell(
            onTap:submitting?null:()=>setState((){picked.remove(i);feedback='';}),
            child:_tile(r.tiles[i],filled:true)),
          if(picked.isEmpty)const Padding(
            padding:EdgeInsets.symmetric(vertical:12),
            child:Text('Tap the letters below!',style:TextStyle(
              color:Color(0xFF697A67)))),
        ])),
      const SizedBox(height:12),
      const Text('SHUFFLED LETTERS',style:TextStyle(
        color:Color(0xFF63766A),fontWeight:FontWeight.w900,letterSpacing:1.3,
        fontSize:11)),
      const SizedBox(height:9),
      Wrap(spacing:8,runSpacing:9,children:[
        for(var i=0;i<r.tiles.length;i++)if(!picked.contains(i))
          InkWell(key:ValueKey('race_tile_'+i.toString()),
            onTap:submitting?null:()=>setState((){
              picked.add(i);feedback='';
            }),child:_tile(r.tiles[i])),
      ]),
      const SizedBox(height:11),
      Row(children:[
        TextButton.icon(onPressed:picked.isEmpty?null:()=>setState((){
          picked.removeLast();feedback='';
        }),icon:const Icon(Icons.undo_rounded),label:const Text('Undo')),
        const Spacer(),
        TextButton(onPressed:picked.isEmpty?null:()=>setState((){
          picked.clear();feedback='';
        }),child:const Text('Clear')),
      ]),
      _button('Submit spelling',done&&!submitting&&!preview?_submit:null),
      const SizedBox(height:13),
      _panel(Column(children:[
        const Text('Round scoreboard',style:TextStyle(
          color:raceInk,fontWeight:FontWeight.w900)),
        const SizedBox(height:10),
        _players(r),
      ])),
    ]);
  }
  Widget _finished(RaceSnapshot r)=>Column(children:[
    const SizedBox(height:5),
    Icon(r.winner==null?Icons.hourglass_empty_rounded:
      Icons.emoji_events_rounded,color:raceGold,size:60),
    const SizedBox(height:10),
    Text(r.state=='finished'?'Race complete!':
      r.winner==null?'Time is up!':'We have a winner!',
      textAlign:TextAlign.center,
      style:const TextStyle(color:raceInk,fontSize:27,fontWeight:FontWeight.w900)),
    const SizedBox(height:7),
    Text(r.winner==null?'Great try, everyone!':r.winner!+' spelled it first!',
      textAlign:TextAlign.center,
      style:const TextStyle(color:raceInk,fontSize:15)),
    const SizedBox(height:17),
    if(r.wordIndex!=null)...[
      _illustration(r.wordIndex!),
      const SizedBox(height:11),
      Text(r.answer??widget.catalog.words[r.wordIndex!].name,
        style:const TextStyle(color:raceInk,
          fontSize:30,fontWeight:FontWeight.w900)),
      const SizedBox(height:17),
    ],
    _panel(Column(children:[
      const Text('SCOREBOARD',style:TextStyle(color:raceInk,
        fontWeight:FontWeight.w900,letterSpacing:1.2)),
      const SizedBox(height:15),
      _players(r),
    ])),
    const SizedBox(height:15),
    if(r.host&&r.state!='finished')
      _button(r.round>=r.total?'See final scores':'Next picture',
        preview?null:_advance)
    else if(r.state!='finished')
      const Text('Waiting for the next round.',
        style:TextStyle(color:Color(0xFF63796C))),
  ]);
}
