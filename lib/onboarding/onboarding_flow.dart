import 'package:flutter/material.dart';

import 'learner_profile.dart';

const _ink=Color(0xFF173E38);
const _green=Color(0xFF69AC29);
const _deep=Color(0xFF267B40);
const _cream=Color(0xFFFFFAF0);
const _sub=Color(0xFF59756D);

/// Actual first-launch UI from the approved illustrated garden concept.
class WordSproutOnboarding extends StatefulWidget {
  const WordSproutOnboarding({super.key,required this.onFinished,
    this.initialProfile,this.editMode=false});
  final void Function(LearnerProfile) onFinished;
  final LearnerProfile? initialProfile;
  final bool editMode;
  @override
  State<WordSproutOnboarding> createState()=>_WordSproutOnboardingState();
}

class _WordSproutOnboardingState extends State<WordSproutOnboarding> {
  late final TextEditingController name;
  String? age,error;
  String track='explorer';
  bool pathPage=false,saving=false;

  @override
  void initState(){
    super.initState();
    name=TextEditingController(text:widget.initialProfile?.name??'');
    age=widget.initialProfile?.ageGroup;
    track=widget.initialProfile?.track??'explorer';
    name.addListener(_clearError);
  }
  void _clearError(){if(error!=null&&mounted)setState(()=>error=null);}
  @override
  void dispose(){
    name.removeListener(_clearError);name.dispose();super.dispose();
  }
  void next(){
    FocusManager.instance.primaryFocus?.unfocus();
    final issue=LearnerProfile.validateName(name.text);
    if(issue!=null){setState(()=>error=issue);return;}
    if(age==null){setState(()=>error='Choose your age adventure.');return;}
    if(age=='6-12'){setState((){pathPage=true;error=null;});return;}
    finish();
  }
  Future<void> finish()async{
    if(saving||age==null)return;
    setState((){saving=true;error=null;});
    try{
      final profile=LearnerProfile(name:name.text.trim(),
        ageGroup:age!,track:track);
      await profile.save();
      if(!mounted)return;
      if(widget.editMode)Navigator.of(context).pop(profile);
      else widget.onFinished(profile);
    }catch(_){
      if(mounted)setState(()=>
        error='Could not save your adventure. Please try again.');
    }finally{
      if(mounted)setState(()=>saving=false);
    }
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:_cream,
    body:SafeArea(child:Center(child:ConstrainedBox(
      constraints:const BoxConstraints(maxWidth:530),
      child:Column(children:[
        Padding(padding:const EdgeInsets.fromLTRB(20,17,20,11),
          child:Row(children:[
            if(pathPage)IconButton(
              key:const ValueKey('onboarding_back'),
              onPressed:()=>setState(()=>pathPage=false),
              icon:const Icon(Icons.arrow_back_rounded,color:_deep),
              style:IconButton.styleFrom(
                backgroundColor:const Color(0xFFE0F0D4)))
            else const SizedBox(width:48),
            const Spacer(),
            for(var i=0;i<4;i++)Container(
              width:i==(pathPage?1:0)?34:21,height:7,
              margin:const EdgeInsets.symmetric(horizontal:3),
              decoration:BoxDecoration(
                color:i<=(pathPage?1:0)?_green:const Color(0xFFE0E0D9),
                borderRadius:BorderRadius.circular(9))),
            const Spacer(),
            const SizedBox(width:48),
          ])),
        Expanded(child:SingleChildScrollView(
          physics:const BouncingScrollPhysics(),
          padding:const EdgeInsets.fromLTRB(19,4,19,14),
          child:AnimatedSwitcher(duration:const Duration(milliseconds:180),
            child:pathPage?pathContent():welcomeContent()))),
        if(error!=null)Padding(padding:const EdgeInsets.symmetric(
          horizontal:24,vertical:5),
          child:Text(error!,textAlign:TextAlign.center,style:const TextStyle(
            color:Color(0xFFBA5248),fontSize:13,fontWeight:FontWeight.w800))),
        Padding(padding:const EdgeInsets.fromLTRB(20,6,20,17),
          child:SizedBox(width:double.infinity,height:55,
            child:FilledButton(
              key:ValueKey(pathPage?'onboarding_start':'onboarding_continue'),
              onPressed:saving?null:pathPage?finish:next,
              style:FilledButton.styleFrom(backgroundColor:_green,
                foregroundColor:Colors.white,
                shape:RoundedRectangleBorder(
                  borderRadius:BorderRadius.circular(19))),
              child:FittedBox(fit:BoxFit.scaleDown,
                child:Row(mainAxisSize:MainAxisSize.min,
                  mainAxisAlignment:MainAxisAlignment.center,children:[
                Text(saving?'Saving…':pathPage?'Start Adventure':'Continue',
                  style:const TextStyle(
                    fontSize:20,fontWeight:FontWeight.w900)),
                const SizedBox(width:11),
                Icon(pathPage?Icons.rocket_launch_rounded:
                  Icons.arrow_forward_rounded,size:22),
              ]))))),
      ]),
    ))),
  );

  Widget welcomeContent()=>Column(
    key:const ValueKey('onboarding_welcome'),
    crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Row(mainAxisAlignment:MainAxisAlignment.center,children:[
        Text('WORDSPROUT',style:TextStyle(
          color:_ink,fontWeight:FontWeight.w900,fontSize:17,
          letterSpacing:2.1)),
        SizedBox(width:7),
        Icon(Icons.auto_stories_rounded,color:Color(0xFF319B83),size:26),
      ]),
      const SizedBox(height:2),
      const Text('ADVENTURE CLUB',textAlign:TextAlign.center,
        style:TextStyle(color:Color(0xFF269B81),fontSize:11,
          fontWeight:FontWeight.w900,letterSpacing:2)),
      const SizedBox(height:15),
      const Text('Welcome to\nWordSprout!',textAlign:TextAlign.center,
        style:TextStyle(color:_ink,fontSize:34,height:1.04,
          fontWeight:FontWeight.w900,letterSpacing:-1.2)),
      const SizedBox(height:8),
      const Text('A fun place to learn English,\nsolve mysteries, and go on\namazing word adventures!',
        textAlign:TextAlign.center,
        style:TextStyle(color:_sub,fontSize:14,height:1.4)),
      const SizedBox(height:10),
      Semantics(label:'Two happy young explorers on a garden path',
        child:ClipRRect(
          borderRadius:BorderRadius.circular(19),
          child:Image.asset('assets/scene/onboarding_explorers.webp',
            key:const ValueKey('onboarding_hero'),
            width:double.infinity,height:207,
            fit:BoxFit.cover,
            filterQuality:FilterQuality.high,
            semanticLabel:'Children exploring a bright mountain garden'))),
      Container(
        padding:const EdgeInsets.all(18),
        decoration:BoxDecoration(color:Colors.white,
          borderRadius:BorderRadius.circular(25),
          boxShadow:const [BoxShadow(color:Color(0x119C996F),
            blurRadius:12,offset:Offset(0,5))]),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Row(children:[
            Icon(Icons.auto_awesome_rounded,color:Color(0xFFE3AD39),size:22),
            SizedBox(width:8),
            Flexible(child:Text('What’s your name?',style:TextStyle(
              color:_ink,fontSize:19,fontWeight:FontWeight.w900))),
          ]),
          const SizedBox(height:9),
          TextField(key:const ValueKey('onboarding_name'),
            controller:name,maxLength:20,
            textCapitalization:TextCapitalization.words,
            textInputAction:TextInputAction.done,
            decoration:InputDecoration(
              counterText:'',hintText:'Type your name or nickname',
              prefixIcon:const Icon(Icons.person_outline_rounded,
                color:Color(0xFF81A494)),
              filled:true,fillColor:const Color(0xFFF0F6E9),
              contentPadding:const EdgeInsets.symmetric(
                horizontal:16,vertical:14),
              border:OutlineInputBorder(
                borderRadius:BorderRadius.circular(16)),
              enabledBorder:OutlineInputBorder(
                borderSide:const BorderSide(color:Color(0xFFCBDEC8)),
                borderRadius:BorderRadius.circular(16)),
              focusedBorder:OutlineInputBorder(
                borderSide:const BorderSide(color:_green,width:2),
                borderRadius:BorderRadius.circular(16)))),
          const SizedBox(height:16),
          const Row(children:[
            Icon(Icons.auto_awesome_rounded,color:Color(0xFFE3AD39),size:22),
            SizedBox(width:8),
            Flexible(child:Text('How old are you?',style:TextStyle(
              color:_ink,fontSize:19,fontWeight:FontWeight.w900))),
          ]),
          const SizedBox(height:10),
          Row(children:[
            Expanded(child:ageCard('4-6','Ages 4–6',
              Icons.spa_rounded,'Little Sprout')),
            const SizedBox(width:12),
            Expanded(child:ageCard('6-12','Ages 6–12',
              Icons.landscape_rounded,'Big Adventure')),
          ]),
        ])),
      const SizedBox(height:9),
      const Text('Your name stays on this device.',
        textAlign:TextAlign.center,style:TextStyle(color:_sub,fontSize:11)),
    ]);

  Widget ageCard(String value,String title,IconData icon,String subtitle){
    final active=age==value;
    return InkWell(key:ValueKey('onboarding_age_'+value),
      onTap:()=>setState((){age=value;error=null;}),
      borderRadius:BorderRadius.circular(20),
      child:AnimatedContainer(
        duration:const Duration(milliseconds:160),
        padding:const EdgeInsets.symmetric(vertical:13,horizontal:5),
        decoration:BoxDecoration(
          color:active?const Color(0xFFECF7E6):
            const Color(0xFFFFFCF7),
          borderRadius:BorderRadius.circular(20),
          border:Border.all(color:active?_deep:
            const Color(0xFFEAE2D1),width:active?2:1.2)),
        child:Column(children:[
          Align(alignment:Alignment.topRight,
            child:Icon(active?Icons.check_circle_rounded:
              Icons.radio_button_unchecked_rounded,
              color:active?_deep:const Color(0xFFC7C8B8),size:19)),
          Icon(icon,size:43,color:active?_deep:const Color(0xFF8CB750)),
          const SizedBox(height:6),
          Text(title,style:const TextStyle(
            color:_ink,fontSize:17,fontWeight:FontWeight.w900)),
          const SizedBox(height:3),
          Text(subtitle,textAlign:TextAlign.center,
            style:const TextStyle(color:_sub,fontSize:10)),
        ])));
  }

  Widget pathContent()=>Column(
    key:const ValueKey('onboarding_path'),
    crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Align(alignment:Alignment.center,child:Container(
        padding:const EdgeInsets.symmetric(horizontal:17,vertical:8),
        decoration:BoxDecoration(color:const Color(0xFFDDEFD2),
          borderRadius:BorderRadius.circular(23)),
        child:const Text('Age 6–12',style:TextStyle(color:_ink,
          fontWeight:FontWeight.w900,fontSize:14)))),
      const SizedBox(height:17),
      Text('Choose your\nadventure, '+name.text.trim()+'!',
        textAlign:TextAlign.center,maxLines:3,
        overflow:TextOverflow.ellipsis,
        style:const TextStyle(color:_ink,fontSize:30,
          height:1.12,letterSpacing:-.8,fontWeight:FontWeight.w900)),
      const SizedBox(height:10),
      const Text('Pick a learning path that fits what you love.\nYou can try the others later!',
        textAlign:TextAlign.center,style:TextStyle(
          color:_sub,fontSize:14,height:1.5)),
      const SizedBox(height:27),
      trackCard('explorer','Explorer','Ages 6–8',
        'First clues, short stories,\nand sentence patterns.',
        Icons.terrain_rounded,const Color(0xFF6BA977)),
      const SizedBox(height:12),
      trackCard('adventurer','Adventurer','Ages 9–10',
        'Word relationships, mysteries,\nand exciting adventures.',
        Icons.travel_explore_rounded,const Color(0xFFDFAC60)),
      const SizedBox(height:12),
      trackCard('master','Word Master','Ages 11–12',
        'Reasoning, precise language,\nand real choices.',
        Icons.auto_stories_rounded,const Color(0xFF9595C8)),
      const SizedBox(height:19),
      const Row(mainAxisAlignment:MainAxisAlignment.center,children:[
        Icon(Icons.favorite_outline_rounded,color:_deep,size:17),
        SizedBox(width:6),
        Flexible(child:Text('All paths make learning fun!',
          textAlign:TextAlign.center,
          style:TextStyle(color:_sub,fontSize:12))),
      ]),
    ]);

  Widget trackCard(String id,String title,String hint,
      String description,IconData icon,Color accent){
    final active=track==id;
    return InkWell(key:ValueKey('onboarding_track_'+id),
      onTap:()=>setState(()=>track=id),
      borderRadius:BorderRadius.circular(22),
      child:AnimatedContainer(
        duration:const Duration(milliseconds:170),
        padding:const EdgeInsets.all(13),
        decoration:BoxDecoration(
          color:active?const Color(0xFFEDF7E5):Colors.white,
          borderRadius:BorderRadius.circular(22),
          border:Border.all(color:active?_deep:
            const Color(0xFFE6E4DB),width:active?2:1),
          boxShadow:const [BoxShadow(color:Color(0x0D8B815E),
            offset:Offset(0,3),blurRadius:7)]),
        child:Row(children:[
          Container(height:75,width:83,
            decoration:BoxDecoration(color:Color.lerp(accent,Colors.white,.73),
              borderRadius:BorderRadius.circular(17)),
            child:Stack(alignment:Alignment.center,children:[
              const Positioned(top:5,left:7,
                child:Icon(Icons.cloud_rounded,color:Colors.white,size:24)),
              Icon(icon,color:accent,size:51),
              const Positioned(bottom:4,right:7,
                child:Icon(Icons.spa_rounded,color:Color(0xFF81B255),size:23)),
            ])),
          const SizedBox(width:12),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
            children:[
              Text(title,style:const TextStyle(color:_ink,
                fontWeight:FontWeight.w900,fontSize:20)),
              const SizedBox(height:2),
              Text(hint,style:const TextStyle(color:_deep,
                fontWeight:FontWeight.w800,fontSize:11)),
              const SizedBox(height:6),
              Text(description,style:const TextStyle(
                color:_sub,height:1.35,fontSize:11.5)),
            ])),
          const SizedBox(width:4),
          Icon(active?Icons.check_circle_rounded:
            Icons.radio_button_unchecked_rounded,
            color:active?_deep:const Color(0xFFB7BCAF),size:25),
        ])));
  }
}
