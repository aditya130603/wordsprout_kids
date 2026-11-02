import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'older_course.dart';
import 'older_scene.dart';
import 'rewards.dart';
import 'rewards_hub.dart';
import 'friends_api.dart';
import '../family_settings.dart';

const midnight=Color(0xFF203D3D);
const mist=Color(0xFFF4F6EF);
const jade=Color(0xFF438E78);
const amber=Color(0xFFE8A963);
const lavender=Color(0xFF8583B9);

Color trackColor(String id)=>id=='explorer'?jade:id=='adventurer'?const Color(0xFFC98F50):lavender;

class OlderHome extends StatefulWidget {
  const OlderHome({super.key,this.initialCourse});
  final OlderCourse? initialCourse;
  @override
  State<OlderHome> createState()=>_OlderHomeState();
}

class _OlderHomeState extends State<OlderHome> {
  OlderCourse? course;
  String? error;
  String selected='explorer';
  final Map<String,int> stars={};
  final Map<String,int> dueDates={};
  RewardLedger? ledger;
  bool busy=false;

  @override
  void initState(){
    super.initState();
    if(widget.initialCourse!=null) course=widget.initialCourse;
    _load();
  }
  Future<void> _load() async {
    try {
      final loaded=widget.initialCourse??await OlderCourse.load();
      final prefs=await SharedPreferences.getInstance();
      final loadedRewards=await RewardLedger.load();
      if(!mounted)return;
      ledger=loadedRewards;
      setState((){
        course=loaded;
        selected=prefs.getString('older_selected_track')??'explorer';
        if(!loaded.tracks.any((t)=>t.id==selected))selected='explorer';
        for(final pair in prefs.getStringList('older_stars')??<String>[]){
          final parts=pair.split(':');
          if(parts.length==2)stars[parts[0]]=int.tryParse(parts[1])??0;
        }
        for(final pair in prefs.getStringList('older_review_due')??<String>[]){
          final parts=pair.split(':');
          if(parts.length==2)dueDates[parts[0]]=int.tryParse(parts[1])??0;
        }
      });
    } catch(e){if(mounted)setState(()=>error=e.toString());}
  }
  Future<void> _save() async {
    final prefs=await SharedPreferences.getInstance();
    await prefs.setString('older_selected_track',selected);
    await prefs.setStringList('older_stars',
      stars.entries.map((e)=>e.key+':'+e.value.toString()).toList());
    await prefs.setStringList('older_review_due',
      dueDates.entries.map((e)=>e.key+':'+e.value.toString()).toList());
  }
  int get totalCompleted=>stars.values.where((value)=>value>0).length;
  List<StoryWord> get reviewWords {
    final result=<StoryWord>[];
    final now=DateTime.now().millisecondsSinceEpoch;
    for(final m in course!.missions) {
      if((stars[m.id]??0)==0)continue;
      for(final w in m.words){
        if((dueDates[w.term]??0)<=now)result.add(w);
      }
    }
    return result;
  }
  void _choose(String id) {
    setState(()=>selected=id);
    _save();
  }
  Future<void> _begin(StoryMission mission) async {
    final oldBadges=ledger?.badges(highestMissionStars:
      stars.values.fold<int>(0,(a,b)=>a>b?a:b))
      .where((b)=>b.unlocked).map((b)=>b.id).toSet()??<String>{};
    final result=await Navigator.of(context).push<MissionScore>(MaterialPageRoute(
      builder:(context)=>OlderMissionScreen(mission:mission,ledger:ledger)));
    if(result==null||!mounted)return;
    setState((){
      stars[mission.id]=math.max(result.stars,stars[mission.id]??0);
      final tomorrow=DateTime.now().add(const Duration(days:1)).millisecondsSinceEpoch;
      for(final word in mission.words) dueDates[word.term]=tomorrow;
    });
    await _save();
    if(!mounted)return;
    final newBadges=ledger?.badges(highestMissionStars:
      stars.values.fold<int>(0,(a,b)=>a>b?a:b))
      .where((b)=>b.unlocked&&!oldBadges.contains(b.id)).toList()??[];
    if(newBadges.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:Text('Achievement unlocked: '+newBadges.first.title+'!')));
    }
  }
  Future<void> _review() async {
    final done=await Navigator.of(context).push<Map<String,bool>>(MaterialPageRoute(
      builder:(context)=>OlderReview(words:reviewWords,ledger:ledger)));
    if(done==null||!mounted)return;
    setState((){
      for(final result in done.entries) {
        final days=result.value?3:1;
        dueDates[result.key]=DateTime.now()
          .add(Duration(days:days)).millisecondsSinceEpoch;
      }
    });
    _save();
  }
  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:mist,
    body:SafeArea(child:course==null
      ? Center(child:error==null?const CircularProgressIndicator():
        Padding(padding:const EdgeInsets.all(22),child:Text(error!)))
      : CustomScrollView(slivers:[
        SliverToBoxAdapter(child:Padding(
          padding:const EdgeInsets.fromLTRB(20,14,20,6),
          child:Row(children:[
            if(Navigator.canPop(context))
              IconButton(onPressed:()=>Navigator.pop(context),
                icon:const Icon(Icons.arrow_back_ios_new_rounded,color:midnight)),
            const Spacer(),
            const Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
              Text('WORDSPROUT',style:TextStyle(fontWeight:FontWeight.w900,
                letterSpacing:2.2,fontSize:12,color:midnight)),
              Text('ADVENTURE CLUB',style:TextStyle(fontWeight:FontWeight.bold,
                letterSpacing:1.1,fontSize:10,color:jade)),
            ]),
            const SizedBox(width:5),
            const Icon(Icons.auto_stories_rounded,color:jade,size:29),
            IconButton(
              key:const ValueKey('older_family_settings'),
              tooltip:'Family settings',
              onPressed:()=>Navigator.push(context,MaterialPageRoute(
                builder:(context)=>const FamilySettings())),
              icon:const Icon(Icons.settings_outlined,color:midnight)),
          ]),
        )),
        SliverToBoxAdapter(child:Padding(
          padding:const EdgeInsets.fromLTRB(22,8,22,12),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('Words have\nsuperpowers.',
              style:TextStyle(color:midnight,fontWeight:FontWeight.w900,
                fontSize:37,height:1.08,letterSpacing:-1.4)),
            const SizedBox(height:10),
            const Text('Solve mysteries. Build sentences. Change the story.',
              style:TextStyle(fontSize:14,color:Color(0xFF5D746D),height:1.4)),
            const SizedBox(height:20),
            StoryScene(scene:selected=='master'?'library':
              selected=='adventurer'?'cave':'forest',height:166),
            const SizedBox(height:19),
            _summary(),
            const SizedBox(height:10),
            OutlinedButton.icon(
              key:const ValueKey('older_rewards_entry'),
              onPressed:ledger==null?null:()=>Navigator.push(context,
                MaterialPageRoute(builder:(context)=>RewardsHub(
                  ledger:ledger!,missionStars:stars))).then((_)=>setState((){})),
              icon:const Icon(Icons.military_tech_rounded),
              label:const Text('XP • Achievements • Friends League'),
              style:OutlinedButton.styleFrom(foregroundColor:midnight,
                minimumSize:const Size(double.infinity,45))),
            const SizedBox(height:17),
            Row(children:[
              const Expanded(child:Text('Choose your quest',style:TextStyle(
                fontSize:22,color:midnight,fontWeight:FontWeight.w900))),
              TextButton.icon(onPressed:()=>_placement(),icon:const Icon(
                Icons.explore_outlined,size:16),label:const Text('Find my level')),
            ]),
            const SizedBox(height:8),
            ...course!.tracks.map((t)=>_trackCard(t)),
            const SizedBox(height:24),
            Row(children:[
              const Expanded(child:Text('Story Missions',maxLines:1,
                 overflow:TextOverflow.ellipsis,style:TextStyle(
                   color:midnight,fontSize:20,fontWeight:FontWeight.w900))),
               const SizedBox(width:8),
              Text(course!.forTrack(selected).length.toString()+' STORIES',
                style:const TextStyle(color:jade,fontWeight:FontWeight.bold,
                  letterSpacing:1.1,fontSize:11)),
            ]),
            const SizedBox(height:10),
          ]),
        )),
        SliverPadding(padding:const EdgeInsets.fromLTRB(20,0,20,28),
          sliver:SliverList(delegate:SliverChildBuilderDelegate((context,index){
            final missions=course!.forTrack(selected);
            final mission=missions[index];
            final locked=index>0&&(stars[missions[index-1].id]??0)==0;
            return Padding(padding:const EdgeInsets.only(bottom:12),
              child:_missionCard(mission,index,locked));
          },childCount:course!.forTrack(selected).length))),
      ])),
  );

  Widget _summary(){
    final due=reviewWords.length;
    return Container(padding:const EdgeInsets.all(15),
      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20),
        border:Border.all(color:const Color(0xFFE4EAE0))),
      child:Row(children:[
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('YOUR PROGRESS',style:TextStyle(color:jade,
            letterSpacing:1.6,fontSize:10,fontWeight:FontWeight.w900)),
          const SizedBox(height:6),
          Text(totalCompleted.toString()+' / '+course!.missions.length.toString()+' missions',
            style:const TextStyle(color:midnight,fontSize:19,fontWeight:FontWeight.w900)),
          const SizedBox(height:3),
          Text(stars.values.fold<int>(0,(a,b)=>a+b).toString()+' mission stars • '+
            (ledger?.totalXp??0).toString()+' XP',
            style:const TextStyle(color:Color(0xFF6D8077),fontSize:12)),
        ])),
        const SizedBox(width:8),
        FilledButton.tonalIcon(
          onPressed:due==0?null:_review,
          icon:const Icon(Icons.replay_rounded,size:17),
          label:Text(due==0?'All clear':'Review '+due.toString()),
          style:FilledButton.styleFrom(foregroundColor:midnight,
            backgroundColor:const Color(0xFFE7F0DB)),
        ),
      ]));
  }

  Widget _trackCard(LearningTrack track){
    final picked=selected==track.id;
    final color=trackColor(track.id);
    return Padding(padding:const EdgeInsets.only(bottom:10),child:
      InkWell(onTap:()=>_choose(track.id),borderRadius:BorderRadius.circular(18),
        child:AnimatedContainer(
          duration:const Duration(milliseconds:180),
          padding:const EdgeInsets.all(14),
          decoration:BoxDecoration(
            color:picked?color.withValues(alpha:.11):Colors.white,
            borderRadius:BorderRadius.circular(18),
            border:Border.all(color:picked?color:const Color(0xFFE0E6DF),
              width:picked?2:1)),
          child:Row(children:[
            Container(width:50,height:50,decoration:BoxDecoration(
              color:color.withValues(alpha:.16),borderRadius:BorderRadius.circular(14)),
              child:Icon(track.id=='explorer'?Icons.terrain_rounded:
                track.id=='adventurer'?Icons.travel_explore_rounded:
                Icons.psychology_alt_rounded,color:color,size:28)),
            const SizedBox(width:13),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Wrap(spacing:8,runSpacing:3,
                crossAxisAlignment:WrapCrossAlignment.center,children:[
                Text(track.title,style:const TextStyle(color:midnight,
                  fontSize:16,fontWeight:FontWeight.w900)),
                Text('AGES '+track.ageHint,style:TextStyle(color:color,
                  fontSize:10,fontWeight:FontWeight.w900)),
              ]),
              const SizedBox(height:4),
              Text(track.description,style:const TextStyle(
                color:Color(0xFF667C74),fontSize:12,height:1.25)),
            ])),
            Icon(picked?Icons.check_circle_rounded:Icons.chevron_right_rounded,
              color:picked?color:const Color(0xFFA9B7AC)),
          ]),
        )));
  }

  Widget _missionCard(StoryMission m,int i,bool locked){
    final color=trackColor(m.level);
    final earned=stars[m.id]??0;
    return Opacity(opacity:locked ? 0.62 : 1.0,child:InkWell(
      key:ValueKey('older_mission_'+m.id),
      onTap:locked?null:()=>_begin(m),
      borderRadius:BorderRadius.circular(20),
      child:Container(padding:const EdgeInsets.all(11),decoration:BoxDecoration(
        color:Colors.white,borderRadius:BorderRadius.circular(20),
        border:Border.all(color:earned>0?color.withValues(alpha:.5):
          const Color(0xFFE8ECE5))),
        child:Row(children:[
          Stack(children:[
            SizedBox(width:99,height:91,child:StoryScene(scene:m.scene,height:91)),
            Positioned(top:7,left:7,child:Container(
              width:25,height:25,alignment:Alignment.center,
              decoration:const BoxDecoration(color:Colors.white,shape:BoxShape.circle),
              child:Text((i+1).toString(),style:const TextStyle(
                fontWeight:FontWeight.w900,color:midnight,fontSize:13)))),
          ]),
          const SizedBox(width:12),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(m.title,maxLines:2,style:const TextStyle(
              color:midnight,fontSize:17,fontWeight:FontWeight.w900,height:1.12)),
            const SizedBox(height:6),
            Text(m.subtitle,maxLines:2,style:const TextStyle(
              color:Color(0xFF6A7E76),fontSize:12,height:1.3)),
            const SizedBox(height:8),
            if(earned>0) Row(children:List.generate(3,(j)=>Icon(
              Icons.star_rounded,size:18,
              color:j<earned?const Color(0xFFE7B15C):const Color(0xFFE0E5E0))))
            else Text(locked?'Complete the previous mission':
              '4 words • 5 challenges',style:TextStyle(
                color:color,fontWeight:FontWeight.bold,fontSize:11)),
          ])),
          Icon(locked?Icons.lock_rounded:Icons.chevron_right_rounded,color:color),
        ]),
      )));
  }

  Future<void> _placement() async {
    final track=await Navigator.push<String>(context,MaterialPageRoute(
      builder:(context)=>PlacementQuest(course:course!)));
    if(track!=null&&mounted)_choose(track);
  }
}

class PlacementQuest extends StatefulWidget {
  const PlacementQuest({super.key,required this.course});
  final OlderCourse course;
  @override
  State<PlacementQuest> createState()=>_PlacementQuestState();
}
class _PlacementQuestState extends State<PlacementQuest>{
  int at=0,score=0;
  int? answer;
  static const questions=<({String prompt,List<String> choices,int correct})>[
    (prompt:'What does curious mean?',choices:['Wanting to know more',
      'Feeling sleepy','Being rude'],correct:0),
    (prompt:'Which is the opposite of protect?',choices:['Guard','Harm','Keep safe'],correct:1),
    (prompt:'Which is closest to fragile?',choices:['Delicate','Enormous','Noisy'],correct:0),
    (prompt:'What does investigate mean?',choices:['Examine carefully',
      'Forget completely','Make a loud sound'],correct:0),
    (prompt:'A compromise means...',choices:['A solution with give-and-take',
      'A very old object','A sudden prediction'],correct:0),
    (prompt:'Which is an example of evidence?',choices:['A wild guess',
      'A measurement from a test','A rumour with no source'],correct:1),
  ];
  void next(){
    if(answer==null)return;
    score+=answer==questions[at].correct?1:0;
    if(at==questions.length-1){
      final result=score>=5?'master':score>=3?'adventurer':'explorer';
      Navigator.pop(context,result);
    }else{
      setState((){at++;answer=null;});
    }
  }
  @override
  Widget build(BuildContext context){
    final q=questions[at];
    return Scaffold(backgroundColor:mist,
      appBar:AppBar(title:const Text('Find my level'),backgroundColor:mist),
      body:SafeArea(child:Padding(padding:const EdgeInsets.all(22),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('QUESTION '+(at+1).toString()+' OF 6',style:
            const TextStyle(color:jade,fontWeight:FontWeight.w900,letterSpacing:1.4)),
          const SizedBox(height:12),
          LinearProgressIndicator(value:(at+1)/6,color:jade,minHeight:8,
            borderRadius:BorderRadius.circular(10)),
          const SizedBox(height:32),
          const Text('No timer. Just try your best.',style:TextStyle(
            fontSize:15,color:Color(0xFF6A7C75))),
          const SizedBox(height:14),
          Text(q.prompt,style:const TextStyle(
            fontSize:27,color:midnight,fontWeight:FontWeight.w900)),
          const SizedBox(height:24),
          ...List.generate(3,(i)=>Padding(padding:const EdgeInsets.only(bottom:12),
            child:_option(q.choices[i],selected:answer==i,
              onTap:()=>setState(()=>answer=i)))),
          const Spacer(),
          _primary(answer==null?null:next,
            at==5?'See my starting track':'Continue'),
        ]))));
  }
}

Widget _option(String text,{required bool selected,required VoidCallback onTap}){
  return InkWell(onTap:onTap,borderRadius:BorderRadius.circular(17),
    child:Container(width:double.infinity,
      padding:const EdgeInsets.symmetric(horizontal:16,vertical:15),
      decoration:BoxDecoration(color:selected?const Color(0xFFDFF1E7):Colors.white,
        borderRadius:BorderRadius.circular(17),
        border:Border.all(color:selected?jade:const Color(0xFFE1E9E3),
          width:selected?2:1)),
      child:Row(children:[
        Expanded(child:Text(text,style:const TextStyle(color:midnight,
          fontSize:16,fontWeight:FontWeight.w700))),
        Icon(selected?Icons.check_circle:Icons.circle_outlined,
          color:selected?jade:const Color(0xFFACBCB1)),
      ])));
}
Widget _primary(VoidCallback? action,String text)=>SizedBox(
  width:double.infinity,height:58,child:FilledButton(
    onPressed:action,
    style:FilledButton.styleFrom(backgroundColor:jade,foregroundColor:Colors.white,
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(17))),
    child:Text(text,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900))));

class OlderReview extends StatefulWidget {
  const OlderReview({super.key,required this.words,this.ledger});
  final List<StoryWord> words;
  final RewardLedger? ledger;
  @override
  State<OlderReview> createState()=>_OlderReviewState();
}
class _OlderReviewState extends State<OlderReview>{
  int at=0;
  int? choice;
  final reviewed=<String,bool>{};
  bool checked=false;
  int recallXp=0;
  @override
  Widget build(BuildContext context){
    if(widget.words.isEmpty)return const Scaffold(body:Center(
      child:Text('No reviews due today.')));
    final w=widget.words[at];
    final distractors=widget.words.where((v)=>v.term!=w.term)
      .take(3).map((e)=>e.meaning).toList();
    while(distractors.length<3){
      distractors.add(const ['A special kind of weather',
        'Something with bright colours','A tool used for measuring'][distractors.length]);
    }
    final choices=[w.meaning,...distractors];
    final shuffled=List<String>.of(choices)..shuffle(math.Random(at*29+7));
    return Scaffold(backgroundColor:mist,
      appBar:AppBar(title:const Text('Memory Garden'),backgroundColor:mist),
      body:SafeArea(child:Padding(padding:const EdgeInsets.all(22),child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('WORD '+(at+1).toString()+' OF '+widget.words.length.toString(),
            style:const TextStyle(color:jade,fontWeight:FontWeight.w900)),
          const SizedBox(height:22),
          const Text('What does this word mean?',style:TextStyle(
            color:Color(0xFF688075),fontSize:16)),
          const SizedBox(height:9),
          Text(w.term,style:const TextStyle(
            fontSize:38,color:midnight,fontWeight:FontWeight.w900)),
          const SizedBox(height:22),
          ...shuffled.asMap().entries.map((e)=>Padding(
            padding:const EdgeInsets.only(bottom:11),
            child:_option(e.value,selected:choice==e.key,
              onTap:checked?(){}:()=>setState(()=>choice=e.key)))),
          if(checked)Padding(padding:const EdgeInsets.all(8),
            child:Text(shuffled[choice??0]==w.meaning
              ?'Correct! '+(recallXp>0?'+5 XP • ':'')+w.context
              :'Try again tomorrow. '+w.meaning,
              style:const TextStyle(color:midnight,fontWeight:FontWeight.w700))),
          const Spacer(),
          _primary(choice==null?null:(){
            if(!checked){
              final isRight=shuffled[choice??0]==w.meaning;
              setState(()=>checked=true);
              if(isRight&&widget.ledger!=null){
                widget.ledger!.review(w.term).then((earned){
                  if(mounted)setState(()=>recallXp=earned.points);
                });
              }
              return;
            }
            reviewed[w.term]=shuffled[choice??0]==w.meaning;
            if(at==widget.words.length-1){
              Navigator.pop(context,reviewed);return;
            }
            setState((){at++;choice=null;checked=false;recallXp=0;});
          },checked?'Next word':'Check answer'),
        ]))));
  }
}

class OlderMissionScreen extends StatefulWidget {
  const OlderMissionScreen({super.key,required this.mission,this.ledger});
  final StoryMission mission;
  final RewardLedger? ledger;
  @override
  State<OlderMissionScreen> createState()=>_OlderMissionScreenState();
}

class _OlderMissionScreenState extends State<OlderMissionScreen>{
  final FlutterTts tts=FlutterTts();
  final FriendsApi league=const FriendsApi();
  OlderStep step=OlderStep.story;
  int at=0,attempts=0,correct=0,errors=0;
  int wrongForQuestion=0;
  int earnedNow=0;
  int lessonXp=0;
  int finishBonusXp=0;
  int? selection;
  bool approved=false;
  String feedback='';
  bool? sceneResult;
  late final List<String> shuffledTokens;
  final List<int> chosen=[];
  bool muted=false;
  StoryMission get m=>widget.mission;

  @override
  void initState(){
    super.initState();
    shuffledTokens=List<String>.of(m.sentenceTokens)
      ..shuffle(math.Random(m.order*73+13));
    tts.setLanguage('en-US');
    tts.setSpeechRate(.45);
  }
  @override
  void dispose(){tts.stop();super.dispose();}
  Future<void> speak(String value) async {
    if(muted)return;
    await tts.stop();
    await tts.speak(value);
  }
  void _move(OlderStep next){
    setState((){
      step=next;at=0;selection=null;approved=false;
      feedback='';sceneResult=null;
      wrongForQuestion=0;earnedNow=0;
    });
    if(next==OlderStep.finish)_awardCompletion();
  }
  Future<void> _awardQuestion(OlderStep stage,int questionIndex,int wrongCount) async {
    final ledger=widget.ledger;
    if(ledger==null)return;
    try {
      final result=await ledger.answer(
        missionId:m.id,stage:stage.name,index:questionIndex,
        wrongAttempts:wrongCount);
      if(mounted&&step==stage&&at==questionIndex){
        setState((){earnedNow=result.points;lessonXp+=result.points;});
      }
    } catch (_) { /* Offline rewards must never interrupt a lesson. */ }
  }
  Future<void> _awardCompletion() async {
    final ledger=widget.ledger;
    if(ledger==null)return;
    try {
      final bonus=await ledger.finish(m.id);
      final perfect=errors==0?await ledger.perfect(m.id):
        const RewardGrant(0,alreadyClaimed:false);
      if(mounted&&step==OlderStep.finish){
        setState((){
          finishBonusXp=bonus.points+perfect.points;
          lessonXp+=finishBonusXp;
        });
      }
    } catch (_) { /* Score persistence must not block graduation. */ }
  }
  void _right(String explanation){
    if(approved)return;
    final earnedStage=step;
    final questionIndex=at;
    final missed=wrongForQuestion;
    HapticFeedback.selectionClick();
    setState((){
      approved=true;feedback=explanation;attempts++;correct++;earnedNow=0;
    });
    _awardQuestion(earnedStage,questionIndex,missed);
  }
  void _wrong(String hint){
    HapticFeedback.lightImpact();
    setState((){
      attempts++;errors++;wrongForQuestion++;
      earnedNow=0;
      feedback=hint;
      approved=false;
      selection=null;
    });
  }
  void _chooseAnswer(int i,int answer,String explanation,String hint,
    {required String response}){
    if(approved)return;
    league.submitAnswer(missionId:m.id,stage:step.name,index:at,
      response:response);
    setState(()=>selection=i);
    if(i==answer)_right(explanation);
    else _wrong(hint);
  }
  void _advanceQuestion(){
    if(step==OlderStep.detective){
      if(at==m.words.length-1){_move(OlderStep.relation);return;}
      setState((){at++;approved=false;selection=null;
        feedback='';earnedNow=0;wrongForQuestion=0;});
    }else if(step==OlderStep.relation){
      if(at==m.words.length-1){_move(OlderStep.sentence);return;}
      setState((){at++;approved=false;selection=null;feedback='';});
    }else if(step==OlderStep.pattern){_move(OlderStep.transfer);}
    else if(step==OlderStep.transfer){_move(OlderStep.finish);}
  }
  void _selectTile(int i){
    if(approved||chosen.contains(i))return;
    setState((){chosen.add(i);feedback='';sceneResult=null;});
  }
  void _sentenceCheck(){
    final response=chosen.map((i)=>shuffledTokens[i]).join(' ');
    league.submitAnswer(missionId:m.id,stage:'sentence',index:0,
      response:response);
    if(m.acceptsSentence(response)){
      final missed=wrongForQuestion;
      setState((){approved=true;sceneResult=true;
        feedback=m.consequence;correct++;attempts++;earnedNow=0;});
      _awardQuestion(OlderStep.sentence,0,missed);
    } else {
      setState((){approved=false;sceneResult=false;
        feedback='The word order changes the meaning. Try again!';
        attempts++;errors++;wrongForQuestion++;earnedNow=0;});
    }
  }
  String get stageName{
    switch(step){
      case OlderStep.story:return 'THE STORY';
      case OlderStep.detective:return 'WORD DETECTIVE';
      case OlderStep.relation:return 'WORD CONNECTIONS';
      case OlderStep.sentence:return 'SENTENCE MAYHEM';
      case OlderStep.pattern:return 'SPELLING LAB';
      case OlderStep.transfer:return 'A NEW SITUATION';
      case OlderStep.finish:return 'MISSION COMPLETE';
    }
  }
  double get progress{
    switch(step){
      case OlderStep.story:return .05;
      case OlderStep.detective:return .10+.08*at;
      case OlderStep.relation:return .46+.07*at;
      case OlderStep.sentence:return .77;
      case OlderStep.pattern:return .87;
      case OlderStep.transfer:return .94;
      case OlderStep.finish:return 1;
    }
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:mist,
    appBar:AppBar(backgroundColor:mist,
      leading:IconButton(icon:const Icon(Icons.close_rounded,color:midnight),
        onPressed:()=>Navigator.pop(context)),
      title:Text(m.title,style:const TextStyle(
        color:midnight,fontSize:16,fontWeight:FontWeight.w900)),
      actions:[IconButton(onPressed:()=>setState(()=>muted=!muted),
        icon:Icon(muted?Icons.volume_off_rounded:Icons.volume_up_rounded,
          color:jade))]),
    body:SafeArea(child:Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(23,7,23,6),child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            Text(stageName,style:const TextStyle(color:jade,
              fontSize:11,letterSpacing:1.9,fontWeight:FontWeight.w900)),
            const Spacer(),
            if(step==OlderStep.detective||step==OlderStep.relation)
              Text((at+1).toString()+' / '+m.words.length.toString(),
                style:const TextStyle(color:midnight,fontWeight:FontWeight.bold)),
          ]),
          const SizedBox(height:9),
          LinearProgressIndicator(value:progress,color:jade,
            backgroundColor:const Color(0xFFE0E9DF),minHeight:7,
            borderRadius:BorderRadius.circular(12)),
        ])),
      Expanded(child:SingleChildScrollView(
        padding:const EdgeInsets.fromLTRB(22,12,22,12),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          if(step==OlderStep.story)_story()
          else if(step==OlderStep.detective)_detective()
          else if(step==OlderStep.relation)_relation()
          else if(step==OlderStep.sentence)_sentence()
          else if(step==OlderStep.pattern)_choiceChallenge(m.pattern)
          else if(step==OlderStep.transfer)_choiceChallenge(m.transfer)
          else _finish(),
          const SizedBox(height:12),
        ]))),
      Padding(padding:const EdgeInsets.fromLTRB(22,5,22,18),
        child:Column(mainAxisSize:MainAxisSize.min,children:[
          if(approved&&step!=OlderStep.finish)
            Padding(padding:const EdgeInsets.only(bottom:7),
              child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
                const Icon(Icons.check_circle_rounded,color:jade,size:18),
                const SizedBox(width:7),
                Flexible(child:Text(earnedNow>0
                  ?'Well done! +'+earnedNow.toString()+' XP earned'
                  :'Correct! Keep building your skills',
                  textAlign:TextAlign.center,style:const TextStyle(
                    color:midnight,fontSize:13,fontWeight:FontWeight.w900))),
              ])),
          _bottomButton(),
        ])),
    ])),
  );

  Widget _story()=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(m.title,style:const TextStyle(fontSize:30,color:midnight,
      height:1.12,letterSpacing:-.7,fontWeight:FontWeight.w900)),
    const SizedBox(height:5),
    Text(m.subtitle,style:const TextStyle(fontSize:14,color:Color(0xFF718278))),
    const SizedBox(height:18),
    StoryScene(scene:m.scene,height:188),
    const SizedBox(height:18),
    _panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('YOUR MISSION',style:TextStyle(color:jade,
        fontSize:11,fontWeight:FontWeight.w900,letterSpacing:1.5)),
      const SizedBox(height:6),
      Text(m.goal,style:const TextStyle(color:midnight,
        fontSize:15,fontWeight:FontWeight.w700)),
      const SizedBox(height:11),
      Text(m.story,style:const TextStyle(color:midnight,fontSize:16,height:1.55)),
      const SizedBox(height:5),
      Align(alignment:Alignment.centerRight,
        child:TextButton.icon(onPressed:()=>speak(m.story),
          icon:const Icon(Icons.volume_up_rounded,size:18),
          label:const Text('Hear the story'))),
    ])),
    const SizedBox(height:17),
    const Text('WORDS TO DISCOVER',style:TextStyle(color:jade,
      fontSize:11,fontWeight:FontWeight.w900,letterSpacing:1.3)),
    const SizedBox(height:9),
    Wrap(spacing:8,runSpacing:8,children:m.words.map((w)=>Chip(
      backgroundColor:const Color(0xFFE7EFDF),
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12),
        side:BorderSide.none),
      label:Text(w.term.toLowerCase(),style:const TextStyle(
        fontWeight:FontWeight.w800,color:midnight)))).toList()),
  ]);

  Widget _detective(){
    final word=m.words[at];
    // Choices are all words in this mission, and the correct answer moves.
    final options=List<String>.of(m.words.map((w)=>w.term))
      ..shuffle(math.Random(m.order*21+at*19));
    final answer=options.indexOf(word.term);
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const _Eyebrow('READ THE CLUE'),
      const SizedBox(height:8),
      Text('Which word fits this situation?',style:const TextStyle(
        color:midnight,fontSize:25,fontWeight:FontWeight.w900,height:1.13)),
      const SizedBox(height:16),
      StoryScene(scene:m.scene,height:108),
      const SizedBox(height:14),
      _panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          const Icon(Icons.search_rounded,color:jade),
          const SizedBox(width:8),
          Expanded(child:Text(word.context,style:const TextStyle(
            color:midnight,fontWeight:FontWeight.w700,fontSize:17,height:1.45))),
          IconButton(onPressed:()=>speak(word.context),
            icon:const Icon(Icons.volume_up_rounded,color:jade)),
        ]),
      ])),
      const SizedBox(height:17),
      ...options.asMap().entries.map((e)=>Padding(
        padding:const EdgeInsets.only(bottom:10),
        child:_option(e.value.toLowerCase(),selected:selection==e.key,
          onTap:()=>_chooseAnswer(e.key,answer,
            word.term.toLowerCase()+' means '+word.meaning.toLowerCase(),
            'Think about the clue. '+word.context,
            response:e.value)))),
      _feedback(),
    ]);
  }

  Widget _relation(){
    final w=m.words[at];
    final opposite=at.isOdd;
    final key=opposite?w.antonym:w.synonym;
    final options=List<String>.of(
      m.words.map((p)=>opposite?p.antonym:p.synonym))
      ..shuffle(math.Random(m.order*47+at*31));
    final answer=options.indexOf(key);
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const _Eyebrow('FIND THE WORD CONNECTION'),
      const SizedBox(height:8),
      Text(opposite?'Which is the opposite of this word?':
        'Which has almost the same meaning?',
        style:const TextStyle(color:midnight,fontSize:25,
          fontWeight:FontWeight.w900,height:1.2)),
      const SizedBox(height:22),
      _panel(Center(child:Column(children:[
        Text(w.term,style:const TextStyle(fontSize:34,
          fontWeight:FontWeight.w900,color:midnight)),
        const SizedBox(height:5),
        Text(w.meaning,textAlign:TextAlign.center,
          style:const TextStyle(color:Color(0xFF65796E),fontSize:14)),
      ]))),
      const SizedBox(height:20),
      ...options.asMap().entries.map((e)=>Padding(
        padding:const EdgeInsets.only(bottom:10),
        child:_option(e.value,selected:selection==e.key,
          onTap:()=>_chooseAnswer(e.key,answer,
            opposite?key+' has an opposite meaning.':
              key+' expresses a similar idea.',
            opposite?'Look for a word with the reverse meaning.':
              'Look for the nearest meaning, not just a related topic.',
            response:e.value)))),
      _feedback(),
    ]);
  }

  Widget _sentence(){
    final ready=chosen.length==shuffledTokens.length;
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const _Eyebrow('WORDS CAN CHANGE A STORY'),
      const SizedBox(height:8),
      const Text('Build the sentence',style:TextStyle(
        color:midnight,fontSize:28,fontWeight:FontWeight.w900)),
      const SizedBox(height:9),
      Text(m.sentencePrompt,style:const TextStyle(
        color:Color(0xFF5E7367),fontSize:15,height:1.45)),
      const SizedBox(height:16),
      StoryScene(scene:m.scene,height:140,outcome:sceneResult),
      const SizedBox(height:13),
      if(sceneResult!=null)_panel(Text(sceneResult==true?
        m.consequence:m.wrongConsequence,
        style:const TextStyle(color:midnight,fontSize:14,
          fontWeight:FontWeight.w700,height:1.35))),
      const SizedBox(height:13),
      const Text('YOUR SENTENCE',style:TextStyle(color:jade,
        fontWeight:FontWeight.w900,fontSize:11,letterSpacing:1.4)),
      const SizedBox(height:7),
      DragTarget<int>(
        onAcceptWithDetails:(details)=>_selectTile(details.data),
        builder:(context,candidate,rejected)=>Container(
          width:double.infinity,
          constraints:const BoxConstraints(minHeight:112),
          padding:const EdgeInsets.all(11),
          decoration:BoxDecoration(
            color:const Color(0xFFE7F1E9),
            border:Border.all(color:candidate.isNotEmpty?jade:const Color(0xFFBCD7C5),
              width:1.8),
            borderRadius:BorderRadius.circular(18)),
          child:chosen.isEmpty?
            const Center(child:Text('Tap or drag the words here',
              style:TextStyle(color:Color(0xFF68816F),fontSize:14)))
            :Wrap(spacing:6,runSpacing:7,
              children:chosen.map((i)=>ActionChip(
                onPressed:approved?null:()=>setState((){
                  chosen.remove(i);sceneResult=null;feedback='';
                }),
                label:Text(shuffledTokens[i],style:const TextStyle(
                  color:midnight,fontWeight:FontWeight.bold)),
                backgroundColor:Colors.white,
                side:const BorderSide(color:Color(0xFFD4E3D5)))).toList()),
        )),
      const SizedBox(height:12),
      const Text('WORD TILES',style:TextStyle(color:jade,
        fontWeight:FontWeight.w900,fontSize:11,letterSpacing:1.4)),
      const SizedBox(height:8),
      Wrap(spacing:7,runSpacing:8,children:List.generate(shuffledTokens.length,(i){
        if(chosen.contains(i))return const SizedBox.shrink();
        final chip=Container(padding:const EdgeInsets.symmetric(
          horizontal:12,vertical:13),
          decoration:BoxDecoration(color:Colors.white,
            border:Border.all(color:const Color(0xFFD9E4D9)),
            borderRadius:BorderRadius.circular(12)),
          child:Text(shuffledTokens[i],style:const TextStyle(
            color:midnight,fontSize:15,fontWeight:FontWeight.w800)));
        return LongPressDraggable<int>(
          data:i,feedback:Material(color:Colors.transparent,child:chip),
          childWhenDragging:Opacity(opacity:.3,child:chip),
          child:InkWell(onTap:()=>_selectTile(i),child:chip));
      })),
      const SizedBox(height:14),
      if(!approved)Row(children:[
        TextButton.icon(onPressed:chosen.isEmpty?null:()=>setState((){
          chosen.removeLast();sceneResult=null;feedback='';
        }),icon:const Icon(Icons.undo_rounded),
          label:const Text('Undo')),
        TextButton(onPressed:()=>setState((){
          chosen.clear();sceneResult=null;feedback='';
        }),child:const Text('Clear')),
        const Spacer(),
        TextButton(onPressed:()=>setState((){
          feedback='Hint: Start with "'+m.sentenceTokens.first+'".';
        }),child:const Text('Hint')),
      ]),
      if(!approved)Padding(padding:const EdgeInsets.only(top:8),
        child:_primary(ready?_sentenceCheck:null,'Check sentence')),
      _feedback(),
    ]);
  }

  Widget _choiceChallenge(ChoiceChallenge c){
    final options=List<String>.of(c.options);
    final order=List<int>.generate(options.length,(i)=>i)
      ..shuffle(math.Random(m.order*39+(step==OlderStep.pattern?7:13)));
    final answer=order.indexOf(c.answer);
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      _Eyebrow(step==OlderStep.pattern?'NOTICE THE PATTERN':'THINK BEYOND THE STORY'),
      const SizedBox(height:9),
      Text(c.question,style:const TextStyle(color:midnight,
        fontSize:25,fontWeight:FontWeight.w900,height:1.2)),
      const SizedBox(height:19),
      StoryScene(scene:m.scene,height:151),
      const SizedBox(height:16),
      ...order.asMap().entries.map((e)=>Padding(
        padding:const EdgeInsets.only(bottom:11),
        child:_option(c.options[e.value],selected:selection==e.key,
          onTap:()=>_chooseAnswer(e.key,answer,c.explain,
            'Read carefully, then try a different answer.',
            response:c.options[e.value])))),
      _feedback(),
    ]);
  }

  Widget _finish(){
    final score=MissionScore(correct,attempts);
    return Column(crossAxisAlignment:CrossAxisAlignment.center,children:[
      const SizedBox(height:15),
      const Text('A mission solved.',style:TextStyle(
        color:midnight,fontSize:31,fontWeight:FontWeight.w900)),
      const SizedBox(height:10),
      StoryScene(scene:m.scene,height:192,outcome:true),
      const SizedBox(height:18),
      Row(mainAxisAlignment:MainAxisAlignment.center,children:
        List.generate(3,(i)=>Icon(Icons.star_rounded,size:47,
          color:i<score.stars?const Color(0xFFE8B35E):
            const Color(0xFFD8E0D6)))),
      const SizedBox(height:12),
      Text('+'+lessonXp.toString()+' XP earned this mission',
        style:const TextStyle(fontSize:18,color:jade,
          fontWeight:FontWeight.w900)),
      if(finishBonusXp>0)Text('Congratulations! +'+
        finishBonusXp.toString()+' XP completion reward',
        style:const TextStyle(color:Color(0xFF9F773C),
          fontSize:12,fontWeight:FontWeight.w800)),
      const SizedBox(height:7),
      Text(correct.toString()+' correct / '+attempts.toString()+' attempts',
        style:const TextStyle(fontSize:15,color:midnight,
          fontWeight:FontWeight.w700)),
      const SizedBox(height:15),
      _panel(Column(children:[
        const Text('WORDS YOU CAN USE',style:TextStyle(
          fontSize:11,letterSpacing:1.4,color:jade,fontWeight:FontWeight.w900)),
        const SizedBox(height:10),
        Wrap(spacing:7,runSpacing:7,
          children:m.words.map((w)=>Chip(label:Text(w.term.toLowerCase()),
            backgroundColor:const Color(0xFFE7F2DD))).toList()),
        const SizedBox(height:9),
        const Text('Words return in future review challenges.',
          textAlign:TextAlign.center,
          style:TextStyle(color:Color(0xFF657A6E),fontSize:13)),
      ])),
    ]);
  }

  Widget _bottomButton(){
    if(step==OlderStep.story)return _primary(
      ()=>_move(OlderStep.detective),'Start the adventure');
    if(step==OlderStep.sentence)return approved
      ?_primary(()=>_move(OlderStep.pattern),'Continue to Spelling Lab')
      :const SizedBox.shrink();
    if(step==OlderStep.finish)return _primary(
      ()=>Navigator.pop(context,MissionScore(correct,attempts)),
      'Finish mission');
    return _primary(approved?_advanceQuestion:null,
      approved?'Continue':'Choose an answer to continue');
  }

  Widget _feedback(){
    if(feedback.isEmpty)return const SizedBox.shrink();
    return Padding(padding:const EdgeInsets.only(top:12),
      child:Container(width:double.infinity,padding:const EdgeInsets.all(13),
        decoration:BoxDecoration(
          color:approved?const Color(0xFFDCF2DE):const Color(0xFFFFEFE0),
          borderRadius:BorderRadius.circular(14)),
        child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Icon(approved?Icons.check_circle_rounded:Icons.lightbulb_outline,
            color:approved?jade:const Color(0xFFAF794D),size:20),
          const SizedBox(width:9),
          Expanded(child:Text(feedback,style:const TextStyle(color:midnight,
            fontSize:14,height:1.35,fontWeight:FontWeight.w600))),
        ])));
  }
  Widget _panel(Widget child)=>Container(width:double.infinity,
    padding:const EdgeInsets.all(17),
    decoration:BoxDecoration(color:Colors.white,
      border:Border.all(color:const Color(0xFFE1E7DF)),
      borderRadius:BorderRadius.circular(19)),
    child:child);
}

class _Eyebrow extends StatelessWidget{
  const _Eyebrow(this.value);
  final String value;
  @override
  Widget build(BuildContext context)=>Text(value,style:const TextStyle(
    fontSize:11,fontWeight:FontWeight.w900,letterSpacing:1.6,color:jade));
}
