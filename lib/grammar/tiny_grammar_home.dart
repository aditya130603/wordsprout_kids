import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tiny_grammar_course.dart';
import 'tiny_grammar_scene.dart';

const pine=Color(0xFF24582E);
const green=Color(0xFF73B42F);
const peach=Color(0xFFFFF8EB);
const amber=Color(0xFFF0B757);

class TinyGrammarHome extends StatefulWidget {
  const TinyGrammarHome({super.key,this.initialCourse});
  final TinyGrammarCourse? initialCourse;
  @override
  State<TinyGrammarHome> createState()=>_TinyGrammarHomeState();
}
class _TinyGrammarHomeState extends State<TinyGrammarHome>{
  TinyGrammarCourse? course;
  String? error;
  int group=0;
  final Map<String,int> stars={};
  @override
  void initState(){super.initState();_load();}
  Future<void> _load() async{
    try{
      final result=widget.initialCourse??await TinyGrammarCourse.load();
      final prefs=await SharedPreferences.getInstance();
      if(!mounted)return;
      setState((){
        course=result;
        for(final s in prefs.getStringList('grammar_4_6_stars_v1')??<String>[]){
          final pair=s.split(':');
          if(pair.length==2){
            final rating=int.tryParse(pair[1]);
            if(rating!=null&&rating>=1&&rating<=3)stars[pair[0]]=rating;
          }
        }
      });
    }catch(e){if(mounted)setState(()=>error=e.toString());}
  }
  Future<void> _play(TinyGrammarLesson item)async{
    final score=await Navigator.of(context).push<int>(MaterialPageRoute(
      builder:(context)=>TinyGrammarPlay(lesson:item)));
    if(score==null||!mounted)return;
    setState(()=>stars[item.id]=math.max(score,stars[item.id]??0));
    final prefs=await SharedPreferences.getInstance();
    await prefs.setStringList('grammar_4_6_stars_v1',
      stars.entries.map((e)=>e.key+':'+e.value.toString()).toList());
  }
  @override
  Widget build(BuildContext context){
    final data=course;
    return Scaffold(backgroundColor:peach,
      appBar:AppBar(backgroundColor:peach,
        title:const Text('Grammar Garden',style:TextStyle(
          color:pine,fontSize:22,fontWeight:FontWeight.w900)),
        actions:[Padding(padding:const EdgeInsets.only(right:15),
          child:Center(child:Row(mainAxisSize:MainAxisSize.min,children:[
            const Icon(Icons.star_rounded,color:amber),
            Text(stars.values.fold<int>(0,(a,b)=>a+b).toString(),
              style:const TextStyle(color:pine,fontWeight:FontWeight.w900)),
          ])))],
      ),
      body:data==null?Center(child:error==null?
        const CircularProgressIndicator(color:green):Text(error!)):
      SafeArea(child:Column(children:[
        Padding(padding:const EdgeInsets.fromLTRB(18,6,18,10),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('Little words. Big ideas!',style:TextStyle(
              fontSize:26,color:pine,fontWeight:FontWeight.w900)),
            const SizedBox(height:6),
            const Text('Listen, look, choose, and build a sentence.',
              style:TextStyle(color:Color(0xFF69815F),fontSize:13)),
            const SizedBox(height:12),
            TinyGrammarScene(scene:data.lessons[group==1?6:group==2?16:
              group==3?20:group==4?24:0].visual,height:108),
            const SizedBox(height:12),
            Row(children:[
              Expanded(child:Text(stars.length.toString()+' / '+
                data.lessons.length.toString()+' lessons',
                style:const TextStyle(color:pine,fontWeight:FontWeight.w900))),
              const Icon(Icons.local_florist_rounded,color:green,size:19),
              const SizedBox(width:6),
              Text(stars.values.fold<int>(0,(a,b)=>a+b).toString()+' stars',
                style:const TextStyle(color:pine,fontWeight:FontWeight.w800)),
            ]),
            const SizedBox(height:7),
            LinearProgressIndicator(value:stars.length/data.lessons.length,
              color:green,backgroundColor:const Color(0xFFE3EED8),minHeight:7,
              borderRadius:BorderRadius.circular(9)),
          ])),
        SizedBox(height:49,child:ListView.separated(
          padding:const EdgeInsets.symmetric(horizontal:16),
          scrollDirection:Axis.horizontal,
          itemCount:data.groups.length,
          separatorBuilder:(_,__)=>const SizedBox(width:7),
          itemBuilder:(context,i)=>ChoiceChip(
            key:ValueKey('grammar_group_'+data.groups[i].id),
            selected:group==i,
            label:Text(data.groups[i].title,
              style:TextStyle(color:group==i?Colors.white:pine,
                fontWeight:FontWeight.w800)),
            selectedColor:pine,
            backgroundColor:Colors.white,
            shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14),
              side:BorderSide(color:group==i?pine:const Color(0xFFE1E6D9))),
            onSelected:(_)=>setState(()=>group=i))),
        ),
        const SizedBox(height:6),
        Expanded(child:ListView(padding:const EdgeInsets.fromLTRB(18,8,18,22),
          children:[
            Text(data.groups[group].description,style:const TextStyle(
              color:Color(0xFF667B5F),fontSize:14)),
            const SizedBox(height:13),
            ...data.lessons.where((item)=>item.group==data.groups[group].id)
              .map((item)=>_card(item)),
          ])),
      ])),
    );
  }
  Widget _card(TinyGrammarLesson item){
    final earned=stars[item.id]??0;
    return Padding(padding:const EdgeInsets.only(bottom:10),
      child:InkWell(
        key:ValueKey('grammar_lesson_'+item.id),
        onTap:()=>_play(item),
        borderRadius:BorderRadius.circular(18),
        child:Container(padding:const EdgeInsets.all(13),
          decoration:BoxDecoration(color:Colors.white,
            borderRadius:BorderRadius.circular(18),
            border:Border.all(color:earned>0?const Color(0xFFC9E1B6):
              const Color(0xFFE4E9DE))),
          child:Row(children:[
            Container(width:46,height:46,
              alignment:Alignment.center,
              decoration:BoxDecoration(color:const Color(0xFFEEF5E0),
                borderRadius:BorderRadius.circular(14)),
              child:Text(item.title.substring(0,1),style:const TextStyle(
                color:pine,fontSize:25,fontWeight:FontWeight.w900))),
            const SizedBox(width:12),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(item.title,style:const TextStyle(
                color:pine,fontSize:17,fontWeight:FontWeight.w900)),
              const SizedBox(height:4),
              Text(item.teach,maxLines:2,overflow:TextOverflow.ellipsis,
                style:const TextStyle(color:Color(0xFF66805B),
                  fontSize:12,height:1.4)),
            ])),
            if(earned==0)const Icon(Icons.play_circle_fill_rounded,
              color:green,size:27)
            else Row(mainAxisSize:MainAxisSize.min,
              children:List.generate(3,(i)=>Icon(Icons.star_rounded,size:16,
                color:i<earned?amber:const Color(0xFFDDE3D5)))),
          ]),
        )));
  }
}

class TinyGrammarPlay extends StatefulWidget{
  const TinyGrammarPlay({super.key,required this.lesson});
  final TinyGrammarLesson lesson;
  @override
  State<TinyGrammarPlay> createState()=>_TinyGrammarPlayState();
}
class _TinyGrammarPlayState extends State<TinyGrammarPlay>{
  final FlutterTts tts=FlutterTts();
  int stage=0,errors=0,stageMistakes=0;
  int? picked;
  bool correct=false;
  String explanation='';
  final List<int> chosen=[];
  late final List<String> tiles;
  TinyGrammarLesson get item=>widget.lesson;

  @override
  void initState(){
    super.initState();
    tiles=List.of(item.sentenceTokens)
      ..shuffle(math.Random(item.id.codeUnits.fold(0,(a,b)=>a+b)));
    if(tiles.join(' ')==item.sentenceTokens.join(' ')&&tiles.length>1){
      tiles.add(tiles.removeAt(0));
    }
    tts.setLanguage('en-US');
    tts.setSpeechRate(.44);
  }
  @override
  void dispose(){tts.stop();super.dispose();}
  Future<void> say(String value) async{
    try{await tts.stop();await tts.speak(value);}catch(_){}
  }
  void next(){
    if(stage<4){
      setState((){
        stage++;picked=null;correct=false;explanation='';stageMistakes=0;
      });
    }else{
      Navigator.pop(context,errors==0?3:errors<=2?2:1);
    }
  }
  void choose(TinyGrammarChoice q,int option){
    if(correct)return;
    if(option==q.answer){
      HapticFeedback.selectionClick();
      setState((){
        picked=option;correct=true;explanation=q.explain;
      });
    }else{
      HapticFeedback.lightImpact();
      setState((){
        picked=option;errors++;stageMistakes++;
        explanation='Try again! Look at the picture and read the choices.';
      });
    }
  }
  void checkSentence(){
    final input=chosen.map((i)=>tiles[i]).join(' ');
    if(item.acceptsSentence(input)){
      setState((){
        correct=true;explanation='You did it! '+item.sentence;
      });
    }else{
      setState((){
        errors++;stageMistakes++;
        explanation=stageMistakes>=2?
          'Try a new order. '+item.hint:
          'Try again. The word order matters.';
      });
    }
  }
  Widget button(String label,VoidCallback? action)=>SizedBox(
    width:double.infinity,height:54,child:FilledButton(
      onPressed:action,
      style:FilledButton.styleFrom(backgroundColor:green,
        foregroundColor:Colors.white,
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))),
      child:Text(label,style:const TextStyle(
        fontSize:17,fontWeight:FontWeight.w900))));
  Widget panel(String message,{bool good=false})=>Container(
    width:double.infinity,padding:const EdgeInsets.all(15),
    decoration:BoxDecoration(
      color:good?const Color(0xFFE5F3DA):Colors.white,
      border:Border.all(color:good?const Color(0xFFB6D9A2):
        const Color(0xFFE6EBDD)),
      borderRadius:BorderRadius.circular(17)),
    child:Text(message,style:const TextStyle(
      color:pine,fontSize:17,fontWeight:FontWeight.w700,height:1.4)));
  Widget response()=>explanation.isEmpty?const SizedBox.shrink():
    Padding(padding:const EdgeInsets.only(top:11),
      child:Container(padding:const EdgeInsets.all(12),
        decoration:BoxDecoration(color:correct?const Color(0xFFE3F4DA):
          const Color(0xFFFFECD8),borderRadius:BorderRadius.circular(14)),
        child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Icon(correct?Icons.check_circle_rounded:Icons.lightbulb_outline,
            color:correct?green:const Color(0xFFB17B51)),
          const SizedBox(width:8),
          Expanded(child:Text(explanation,style:const TextStyle(
            color:pine,fontSize:14,height:1.4,fontWeight:FontWeight.w800))),
        ])));
  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:peach,
    appBar:AppBar(backgroundColor:peach,
      title:Text(item.title,style:const TextStyle(
        color:pine,fontWeight:FontWeight.w900)),
      actions:[IconButton(
        icon:const Icon(Icons.volume_up_rounded,color:pine),
        onPressed:()=>say(stage==0?item.teach+' '+item.example:
          stage==1?item.challenge.prompt:
          stage==2?item.transfer.prompt:item.sentence))]),
    body:SafeArea(child:Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(20,7,20,5),
        child:Row(children:List.generate(5,(i)=>Expanded(child:
          Container(height:7,margin:const EdgeInsets.symmetric(horizontal:3),
            decoration:BoxDecoration(color:i<=stage?green:
              const Color(0xFFE6EDDC),borderRadius:BorderRadius.circular(7)))))),
      Expanded(child:ListView(
        padding:const EdgeInsets.fromLTRB(19,12,19,15),
        children:[
          if(stage==0)...[
            const Text('LET’S DISCOVER',style:TextStyle(
              color:green,fontWeight:FontWeight.w900,letterSpacing:1.5)),
            const SizedBox(height:9),
            Text(item.title,style:const TextStyle(
              fontSize:36,fontWeight:FontWeight.w900,color:pine)),
            const SizedBox(height:12),
            TinyGrammarScene(scene:item.visual,height:182),
            const SizedBox(height:14),
            panel(item.teach),
            const SizedBox(height:11),
            panel(item.example,good:true),
            const SizedBox(height:11),
            TextButton.icon(onPressed:()=>say(item.teach+' '+item.example),
              icon:const Icon(Icons.volume_up_rounded),
              label:const Text('Listen again')),
          ]else if(stage==1||stage==2)...[
            Text('QUESTION '+stage.toString()+' OF 3',
              style:const TextStyle(color:green,fontWeight:FontWeight.w900)),
            const SizedBox(height:10),
            Text(stage==1?item.challenge.prompt:item.transfer.prompt,
              style:const TextStyle(color:pine,fontSize:23,
                fontWeight:FontWeight.w900,height:1.2)),
            const SizedBox(height:13),
            TinyGrammarScene(scene:item.visual,height:129),
            const SizedBox(height:13),
            ...List.generate(4,(i){
              final q=stage==1?item.challenge:item.transfer;
              return Padding(padding:const EdgeInsets.only(bottom:9),
                child:InkWell(key:ValueKey('grammar_answer_'+i),
                  onTap:correct?null:()=>choose(q,i),
                  borderRadius:BorderRadius.circular(15),
                  child:Container(padding:const EdgeInsets.symmetric(
                      horizontal:15,vertical:13),
                    decoration:BoxDecoration(
                      color:correct&&i==q.answer?const Color(0xFFE4F4D9):
                        picked==i&&!correct?const Color(0xFFFFEBD9):Colors.white,
                      borderRadius:BorderRadius.circular(15),
                      border:Border.all(color:picked==i?green:
                        const Color(0xFFE3EADB))),
                    child:Row(children:[
                      Expanded(child:Text(q.options[i],
                        style:const TextStyle(color:pine,
                          fontWeight:FontWeight.w800,fontSize:16))),
                      Icon(correct&&i==q.answer?Icons.check_circle_rounded:
                        Icons.circle_outlined,color:correct&&i==q.answer?
                        green:const Color(0xFF9FAE99),size:20),
                    ]))));
            }),
            response(),
          ]else if(stage==3)...[
            const Text('SENTENCE BUILDER',style:TextStyle(
              color:green,fontWeight:FontWeight.w900,letterSpacing:1.5)),
            const SizedBox(height:10),
            const Text('Tap the words in order!',style:TextStyle(
              color:pine,fontWeight:FontWeight.w900,fontSize:25)),
            const SizedBox(height:12),
            TinyGrammarScene(scene:item.visual,height:128),
            const SizedBox(height:12),
            panel('Make a sentence about what you learned.'),
            const SizedBox(height:12),
            Container(width:double.infinity,
              constraints:const BoxConstraints(minHeight:90),
              padding:const EdgeInsets.all(10),
              decoration:BoxDecoration(color:const Color(0xFFE8F3DF),
                borderRadius:BorderRadius.circular(18),
                border:Border.all(color:const Color(0xFFB6D8A7))),
              child:Wrap(spacing:6,runSpacing:8,
                children:chosen.map((i)=>ActionChip(
                  onPressed:correct?null:()=>setState((){
                    chosen.remove(i);explanation='';
                  }),
                  backgroundColor:Colors.white,
                  label:Text(tiles[i],style:const TextStyle(
                    color:pine,fontWeight:FontWeight.w900)))).toList())),
            const SizedBox(height:13),
            Wrap(spacing:7,runSpacing:8,
              children:List.generate(tiles.length,(i){
                if(chosen.contains(i))return const SizedBox.shrink();
                return ActionChip(key:ValueKey('grammar_tile_'+i),
                  onPressed:correct?null:()=>setState((){
                    chosen.add(i);explanation='';
                  }),
                  backgroundColor:Colors.white,
                  label:Text(tiles[i],style:const TextStyle(
                    color:pine,fontSize:15,fontWeight:FontWeight.w900)));
              })),
            const SizedBox(height:12),
            if(!correct)Row(children:[
              TextButton.icon(
                onPressed:chosen.isEmpty?null:()=>setState((){
                  chosen.removeLast();explanation='';
                }),
                icon:const Icon(Icons.undo_rounded),
                label:const Text('Undo')),
              const Spacer(),
              TextButton(onPressed:()=>setState((){
                chosen.clear();explanation='';
              }),child:const Text('Start again')),
            ]),
            if(!correct)button('Check my sentence',
              chosen.length==tiles.length?checkSentence:null),
            response(),
          ]else...[
            const Text('Wonderful work!',textAlign:TextAlign.center,
              style:TextStyle(color:pine,fontSize:30,fontWeight:FontWeight.w900)),
            const SizedBox(height:18),
            TinyGrammarScene(scene:item.visual,height:155),
            const SizedBox(height:22),
            Row(mainAxisAlignment:MainAxisAlignment.center,
              children:List.generate(3,(i)=>Icon(Icons.star_rounded,size:45,
                color:i<(errors==0?3:errors<=2?2:1)?amber:
                  const Color(0xFFDDE3D7)))),
            const SizedBox(height:11),
            const Text('You learned a new way to speak!',
              textAlign:TextAlign.center,style:TextStyle(
                color:pine,fontSize:18,fontWeight:FontWeight.w800)),
            const SizedBox(height:14),
            panel(item.example,good:true),
          ],
          const SizedBox(height:20),
        ])),
      Padding(padding:const EdgeInsets.fromLTRB(20,6,20,18),
        child:stage==3&&!correct?const SizedBox.shrink():
          button(stage==0?'Let’s play!':stage==4?'Back to Grammar Garden':
            'Continue ➜',(stage==1||stage==2)&&!correct?null:next)),
    ])),
  );
}
