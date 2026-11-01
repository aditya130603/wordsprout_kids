import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const WordSprout());
const green=Color(0xff24582e), lime=Color(0xff77b932), cream=Color(0xfffff8eb), yellow=Color(0xffffdf7c);
class Word {
 final String name;
 final List<String> facts;
 const Word(this.name,this.facts);
}
const words=[
 Word('ANT',['An ant is tiny.','Some ants can bite.','Ants live together in colonies.']),
 Word('APPLE',['Apples grow on trees.','Apples can be red, green or yellow.','You can eat an apple’s skin.']),
 Word('ARM',['Most people have two arms.','Arms help you lift things.','Your elbow helps your arm bend.']),
 Word('AXE',['An axe is a tool.','People use axes to chop wood.','An axe has a sharp blade.']),
 Word('ARROW',['An arrow has a pointed tip.','An arrow can be shot from a bow.','Arrows on signs can show directions.']),
];
class WordSprout extends StatelessWidget {
 const WordSprout({super.key});
 @override Widget build(BuildContext context)=>MaterialApp(debugShowCheckedModeBanner:false,title:'WordSprout',theme:ThemeData(useMaterial3:true,scaffoldBackgroundColor:cream,colorScheme:ColorScheme.fromSeed(seedColor:lime)),home:const Home());
}
class Home extends StatefulWidget {const Home({super.key}); @override State<Home> createState()=>_HomeState();}
class _HomeState extends State<Home>{
 final tts=FlutterTts();
 int tab=0,word=0,step=-1;
 Set<int> done={};
 List<String> tiles=[];
 List<int> chosen=[];
 String feedback='';
 int get unlocked=>done.containsAll({0,1,2})?5:3;
 Word get current=>words[word];
 @override void initState(){super.initState();tts.setLanguage('en-US');tts.setSpeechRate(.42);_load();}
 Future<void> _load() async {final p=await SharedPreferences.getInstance();if(mounted)setState(()=>done=(p.getStringList('done')??[]).map(int.parse).toSet());}
 Future<void> speak(String s) async {await tts.stop();await tts.speak(s);}
 @override void dispose(){tts.stop();super.dispose();}
 void start(int i){if(i>=unlocked)return;setState((){word=i;step=0;feedback='';});speak(words[i].name);}
 void spelling(){tiles=[...current.name.split(''),...['B','O']]..shuffle(math.Random(word * 41 + done.length * 13 + 17));setState((){chosen=[];step=1;feedback='';});}
 void check(){
  if(chosen.length!=current.name.length){setState(()=>feedback='Fill all the boxes!');return;}
  if(chosen.map((i)=>tiles[i]).join()==current.name){setState((){step=2;feedback='';});speak('Great! Find the picture.');}
  else setState(()=>feedback='Not quite! Try again.');
 }
 void identify(int i){if(i==word){setState((){step=3;feedback='';});speak('Wonderful! Choose a true fact.');}else setState(()=>feedback='Look closely and try again!');}
 Future<void> fact(int i) async {if(i!=0){setState(()=>feedback='Listen again and try!');return;}setState((){step=4;done.add(word);feedback='';});final p=await SharedPreferences.getInstance();await p.setStringList('done',done.map((i)=>i.toString()).toList());speak('Fantastic!');}
 void next(){final remaining=List.generate(unlocked,(i)=>i).where((i)=>!done.contains(i));if(remaining.isEmpty){setState((){step=-1;tab=1;});}else{start(remaining.first);}}
 Widget card(Widget child)=>Container(padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:Colors.white.withValues(alpha:.89),borderRadius:BorderRadius.circular(28),boxShadow:const [BoxShadow(color:Color(0x180a3619),blurRadius:12,offset:Offset(0,5))]),child:child);
 Widget button(String label,VoidCallback press,{Color color=lime})=>SizedBox(height:56,width:double.infinity,child:FilledButton(onPressed:press,style:FilledButton.styleFrom(backgroundColor:color,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(30))),child:Text(label,style:const TextStyle(fontSize:19,fontWeight:FontWeight.w900))));
 Widget art(int i,{double size=155})=>SvgPicture.asset('assets/words/'+words[i].name.toLowerCase()+'.svg',width:size,height:size,fit:BoxFit.contain,semanticsLabel:words[i].name);
 Widget heading(String text)=>Text(text,textAlign:TextAlign.center,style:const TextStyle(fontSize:27,color:green,fontWeight:FontWeight.w900));
 Widget listen(String text)=>IconButton.filled(onPressed:()=>speak(text),style:IconButton.styleFrom(backgroundColor:lime,foregroundColor:Colors.white),icon:const Icon(Icons.volume_up_rounded,size:28));
 @override Widget build(BuildContext context)=>Scaffold(
  body:SafeArea(child:Column(children:[
   if(step<0)...[const SizedBox(height:15),const Row(
     mainAxisAlignment:MainAxisAlignment.center, children:[
      Icon(Icons.spa_rounded,size:28,color:lime),
      SizedBox(width:6),
      Text('WordSprout',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900,color:green,letterSpacing:-1)),
     ])],
   if(step>=0)Padding(padding:const EdgeInsets.all(12),child:Row(children:[IconButton.filledTonal(onPressed:()=>setState(()=>step=-1),icon:const Icon(Icons.arrow_back)),const Spacer(),...List.generate(5,(i)=>Container(width:30,height:10,margin:const EdgeInsets.all(3),decoration:BoxDecoration(color:i<=step?lime:const Color(0xffe2dfd5),borderRadius:BorderRadius.circular(12)))),const Spacer()])),
   Expanded(child:Padding(padding:const EdgeInsets.all(18),child:step>=0?lesson():page())),
  ])),
  bottomNavigationBar:step<0?NavigationBar(selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),destinations:const [
   NavigationDestination(icon:Icon(Icons.home_rounded),label:'Home'),
   NavigationDestination(icon:Icon(Icons.menu_book_rounded),label:'Learn'),
   NavigationDestination(icon:Icon(Icons.sports_esports_rounded),label:'Games'),
   NavigationDestination(icon:Icon(Icons.star_rounded),label:'Progress'),
  ]):null,
 );
 Widget page(){
  if(tab==1)return ListView(children:[heading('Letter A adventure'),const SizedBox(height:20),...List.generate(5,(i)=>Padding(padding:const EdgeInsets.only(bottom:13),child:card(ListTile(onTap:i<unlocked?()=>start(i):null,leading:art(i,size:55),title:Text(words[i].name,style:const TextStyle(fontSize:21,fontWeight:FontWeight.bold,color:green)),subtitle:Text(done.contains(i)?'Learned ✓':i<unlocked?'Tap to learn':'🔒 Learn the first three words'),trailing:const Icon(Icons.chevron_right)))))]);
  if(tab==2)return Column(children:[heading('Games & Friends'),const SizedBox(height:25),...['🏁  Spelling Race','❓  Guess in 5','🔍  Word Detective','🎭  WordMayhem'].map((s)=>Padding(padding:const EdgeInsets.only(bottom:15),child:card(ListTile(title:Text(s,style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold,color:green)),trailing:const Icon(Icons.lock_outline))))),const SizedBox(height:18),const Text('Online games require parent-approved friends and a secure game server. Coming later.',textAlign:TextAlign.center)]);
  if(tab==3)return Column(children:[heading('My growing garden 🌿'),const SizedBox(height:35),card(Column(children:[Text(done.length.toString()+' / 5',style:const TextStyle(fontSize:44,fontWeight:FontWeight.w900,color:green)),const Text('Words learned'),const SizedBox(height:16),LinearProgressIndicator(value:done.length/5,minHeight:16,borderRadius:BorderRadius.circular(20))]))]);
  return Column(children:[
    card(Row(children:[
      const CircleAvatar(radius:26,backgroundColor:Color(0xFFFFE29A),
        child:Icon(Icons.wb_sunny_rounded,color:Color(0xFFEFAE32),size:34)),
      const SizedBox(width:12),
      const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Hello, explorer!',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:green)),
        Text("Ready for a word adventure?",style:TextStyle(fontSize:12,color:Color(0xFF65715B))),
      ])),
      Container(padding:const EdgeInsets.symmetric(vertical:7,horizontal:9),
       decoration:BoxDecoration(color:const Color(0xFFE7F5CC),borderRadius:BorderRadius.circular(14)),
       child:Text(done.length.toString()+'/5',style:const TextStyle(color:green,fontWeight:FontWeight.w900))),
    ])),
    const SizedBox(height:13),
    Expanded(child:ClipRRect(
      borderRadius:BorderRadius.circular(30),
      child:LayoutBuilder(builder:(context,layout)=>Stack(children:[
        Positioned.fill(child:SvgPicture.asset('assets/scene/alphabet_garden.svg',fit:BoxFit.fill)),
        Positioned(top:12,left:14,right:14,child:Container(
          padding:const EdgeInsets.symmetric(vertical:9,horizontal:12),
          decoration:BoxDecoration(color:const Color(0xF7FFFAE9),borderRadius:BorderRadius.circular(19)),
          child:Column(children:[
            const Text('Your Alphabet Trail',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900,color:green)),
            Text('Letter A • '+done.length.toString()+' of 5 words learned',
              style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700,color:Color(0xFF577F4A))),
          ]),
        )),
        for(int i=0;i<5;i++) Positioned(
          left:layout.maxWidth*[.24,.75,.26,.73,.29][i]-34,
          top:layout.maxHeight*[.23,.41,.54,.67,.78][i]-34,
          child:Semantics(label:'Letter '+String.fromCharCode(65+i)+(i==0?' ready':' locked'),
            child:GestureDetector(onTap:i==0?()=>start(
              List.generate(unlocked,(x)=>x).where((x)=>!done.contains(x)).firstOrNull??0):null,
              child:Container(width:68,height:68,
                decoration:BoxDecoration(shape:BoxShape.circle,
                  color:i==0?const Color(0xFFFFDB75):const Color(0xFFFFFDF2),
                  border:Border.all(color:Colors.white,width:5),
                  boxShadow:const [BoxShadow(color:Color(0x3B416932),blurRadius:9,offset:Offset(0,4))]),
                child:Stack(alignment:Alignment.center,children:[
                  Text(String.fromCharCode(65+i),style:TextStyle(
                    fontSize:31,fontWeight:FontWeight.w900,
                    color:i==0?const Color(0xFFA85B27):const Color(0xFF797A70))),
                  if(i>0)const Positioned(right:3,bottom:3,
                    child:Icon(Icons.lock_rounded,size:13,color:Color(0xFF9E9E8D))),
                  if(i==0)const Positioned(right:0,top:0,
                    child:Icon(Icons.auto_awesome_rounded,size:17,color:Color(0xFFED9B36))),
                ]),
              ),
            ),
          ),
        ),
      ])),
    )),
    const SizedBox(height:10),
    button('Continue Learning  ➜',()=>start(
      List.generate(unlocked,(i)=>i).where((i)=>!done.contains(i)).firstOrNull??0),
      color:const Color(0xFFEF856C)),
    const SizedBox(height:11),
    card(InkWell(onTap:()=>setState(()=>tab=2),child:Row(children:[
      Container(width:52,height:52,
        decoration:BoxDecoration(color:Color(0xFFFFE6B0),borderRadius:BorderRadius.all(Radius.circular(16))),
        child:Icon(Icons.sports_esports_rounded,size:35,color:Color(0xFFED9B35))),
      SizedBox(width:12),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Games & Friends',style:TextStyle(fontSize:17,fontWeight:FontWeight.w900,color:green)),
        Text('Play with words you know!',style:TextStyle(fontSize:12,color:Color(0xFF65715B))),
      ])),
      Icon(Icons.chevron_right_rounded,color:green),
    ]))),
  ]);
 }
 Widget lesson()=>switch(step){
  0=>Column(children:[
   Expanded(flex:5,child:card(Column(children:[Expanded(child:Center(child:art(word,size:185))),Row(mainAxisAlignment:MainAxisAlignment.center,children:[heading(current.name),const SizedBox(width:15),listen(current.name)])]))),
   const SizedBox(height:13),
   ...current.facts.map((f)=>Expanded(flex:2,child:Padding(padding:const EdgeInsets.only(bottom:9),child:card(Row(children:[const Icon(Icons.auto_awesome,color:lime),const SizedBox(width:10),Expanded(child:Text(f,style:const TextStyle(fontSize:15,fontWeight:FontWeight.bold,color:green))),IconButton(onPressed:()=>speak(f),icon:const Icon(Icons.volume_up_rounded,color:lime))]))))),
   button('Next ➜',spelling),
  ]),
  1=>Column(children:[
   Expanded(child:Center(child:art(word,size:160))),heading('Spell the word!'),listen(current.name),
   const SizedBox(height:13),
   Wrap(spacing:5,children:List.generate(current.name.length,(i)=>Container(width:current.name.length>3?51:76,height:65,alignment:Alignment.center,decoration:BoxDecoration(color:Colors.white,border:Border.all(color:lime,width:3),borderRadius:BorderRadius.circular(17)),child:Text(i<chosen.length?tiles[chosen[i]]:'',style:const TextStyle(fontSize:30,fontWeight:FontWeight.w900,color:green))))),
   const SizedBox(height:25),
   Wrap(alignment:WrapAlignment.center,spacing:9,runSpacing:10,children:List.generate(tiles.length,(i)=>SizedBox(width:64,height:64,child:FilledButton(onPressed:chosen.contains(i)||chosen.length>=current.name.length?null:()=>setState((){chosen.add(i);feedback='';}),style:FilledButton.styleFrom(backgroundColor:yellow,foregroundColor:green,padding:EdgeInsets.zero,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(17))),child:Text(tiles[i],style:const TextStyle(fontSize:28,fontWeight:FontWeight.w900)))))),
   const Spacer(),Text(feedback,style:const TextStyle(color:Color(0xffb6482e),fontWeight:FontWeight.bold)),Row(children:[Expanded(child:TextButton(onPressed:()=>setState((){if(chosen.isNotEmpty)chosen.removeLast();feedback='';}),child:const Text('↶ Undo'))),Expanded(child:TextButton(onPressed:()=>setState((){chosen=[];feedback='';}),child:const Text('Clear'))),Expanded(flex:2,child:button('✓ Check',check))]),
  ]),
  2=>Column(children:[
   heading('Tap the '+current.name+'!'),listen('Find the '+current.name),
   const SizedBox(height:20),
   Expanded(child:GridView.count(crossAxisCount:2,mainAxisSpacing:12,crossAxisSpacing:12,childAspectRatio:1,physics:const NeverScrollableScrollPhysics(),children:[word,(word+1)%5,(word+2)%5,(word+3)%5].map((i)=>GestureDetector(onTap:()=>identify(i),child:card(Center(child:art(i,size:115))))).toList())),
   Text(feedback,style:const TextStyle(color:Colors.deepOrange,fontWeight:FontWeight.bold)),
  ]),
  3=>Column(children:[
   heading('Which fact is true?'),Expanded(child:Center(child:art(word,size:170))),
   ...[current.facts.first,'It lives on the Moon.','It is made of glass.'].asMap().entries.map((e)=>Padding(padding:const EdgeInsets.only(bottom:12),child:card(ListTile(onTap:()=>fact(e.key),title:Text(e.value,style:const TextStyle(fontSize:16,fontWeight:FontWeight.bold,color:green)),trailing:IconButton(onPressed:()=>speak(e.value),icon:const Icon(Icons.volume_up_rounded,color:lime)))))),
   Text(feedback,style:const TextStyle(color:Colors.deepOrange)),
  ]),
  _=>Column(mainAxisAlignment:MainAxisAlignment.center,children:[const Text('⭐ ⭐ ⭐',style:TextStyle(fontSize:44)),const SizedBox(height:18),heading('Great job!'),const SizedBox(height:20),art(word,size:180),const SizedBox(height:25),Text('You learned '+current.name+'!',style:const TextStyle(fontSize:20,color:green)),const SizedBox(height:40),button('Next word ➜',next)]),
 };
}
