import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const WordSprout());
const green=Color(0xff24582e), lime=Color(0xff77b932), cream=Color(0xfffff8eb), yellow=Color(0xffffdf7c);
class Word {
 final String name, picture;
 final List<String> facts;
 const Word(this.name,this.picture,this.facts);
}
const words=[
 Word('ANT','🐜',['An ant is tiny.','Some ants can bite.','Ants live together in colonies.']),
 Word('APPLE','🍎',['Apples grow on trees.','Apples can be red, green or yellow.','You can eat an apple’s skin.']),
 Word('ARM','💪',['Most people have two arms.','Arms help you lift things.','Your elbow helps your arm bend.']),
 Word('AXE','🪓',['An axe is a tool.','People use axes to chop wood.','An axe has a sharp blade.']),
 Word('ARROW','➡️',['An arrow has a pointed tip.','An arrow can be shot from a bow.','Arrows on signs can show directions.']),
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
 void spelling(){tiles=[...current.name.split(''),...['B','O']]..shuffle();setState((){chosen=[];step=1;feedback='';});}
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
 Widget art(int i,{double size=155})=>i==0?SizedBox(width:size,height:size,child:CustomPaint(painter:AntPainter())):Text(words[i].picture,style:TextStyle(fontSize:size*.7));
 Widget heading(String text)=>Text(text,textAlign:TextAlign.center,style:const TextStyle(fontSize:27,color:green,fontWeight:FontWeight.w900));
 Widget listen(String text)=>IconButton.filled(onPressed:()=>speak(text),style:IconButton.styleFrom(backgroundColor:lime,foregroundColor:Colors.white),icon:const Icon(Icons.volume_up_rounded,size:28));
 @override Widget build(BuildContext context)=>Scaffold(
  body:SafeArea(child:Column(children:[
   if(step<0)...[const SizedBox(height:17),heading('🌱 WordSprout')],
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
   card(const Row(children:[Text('🌼',style:TextStyle(fontSize:45)),SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Hello, explorer!',style:TextStyle(fontSize:23,fontWeight:FontWeight.w900,color:green)),Text("Let's learn some new words!")]))])),
   const SizedBox(height:18),
   Expanded(child:Container(width:double.infinity,padding:const EdgeInsets.all(20),decoration:BoxDecoration(gradient:const LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Color(0xffdcf2c1),Color(0xff9ed568)]),borderRadius:BorderRadius.circular(32)),child:Column(children:[
    heading('Alphabet Adventure'),const SizedBox(height:15),
    Expanded(child:LayoutBuilder(builder:(context,c)=>Stack(children:[
      for(int i=0;i<5;i++)Positioned(left:i.isEven?c.maxWidth*.09:c.maxWidth*.62,top:i*(c.maxHeight-67)/4,child:GestureDetector(onTap:()=>start(i),child:Container(width:63,height:63,alignment:Alignment.center,decoration:BoxDecoration(shape:BoxShape.circle,color:i==0?yellow:i<unlocked?Colors.white:Colors.white54,border:Border.all(color:Colors.white,width:5)),child:Text(String.fromCharCode(65+i),style:TextStyle(fontSize:29,fontWeight:FontWeight.w900,color:i<unlocked?green:Colors.grey))))),
    ]))),
    button('Continue ➜',()=>start(List.generate(unlocked,(i)=>i).where((i)=>!done.contains(i)).firstOrNull??0),color:const Color(0xffef856c)),
   ]))),
   const SizedBox(height:12),card(InkWell(onTap:()=>setState(()=>tab=2),child:const Row(children:[Text('🎮',style:TextStyle(fontSize:34)),SizedBox(width:12),Expanded(child:Text('Games\nPlay and practice!',style:TextStyle(fontSize:16,fontWeight:FontWeight.bold,color:green))),Icon(Icons.chevron_right)]))),
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
class AntPainter extends CustomPainter{
 @override void paint(Canvas c,Size size){
  c.save();c.scale(size.width/200,size.height/200);
  final line=Paint()..color=const Color(0xff96341f)..strokeWidth=4..style=PaintingStyle.stroke..strokeCap=StrokeCap.round;
  for(final x in [98.0,126.0,157.0]){c.drawLine(Offset(x,118),Offset(x-21,169),line);c.drawLine(Offset(x+3,118),Offset(x+22,169),line);}
  c.drawOval(const Rect.fromLTWH(95,80,87,72),Paint()..color=const Color(0xffd35233));
  c.drawLine(const Offset(72,70),const Offset(61,30),line);c.drawLine(const Offset(108,70),const Offset(125,28),line);
  c.drawCircle(const Offset(61,30),6,Paint()..color=const Color(0xffe86b48));c.drawCircle(const Offset(125,28),6,Paint()..color=const Color(0xffe86b48));
  c.drawCircle(const Offset(85,105),51,Paint()..color=const Color(0xfff37f50));
  for(final x in [61.0,101.0]){c.drawOval(Rect.fromLTWH(x,83,24,34),Paint()..color=Colors.white);c.drawCircle(Offset(x+14,100),9,Paint()..color=const Color(0xff36221b));}
  final smile=Path()..moveTo(75,131)..quadraticBezierTo(88,149,103,131);c.drawPath(smile,line);
  c.restore();
 }
 @override bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;
}
