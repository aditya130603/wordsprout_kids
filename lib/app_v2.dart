import 'dart:math' as math;
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'curriculum.dart';
import 'content_store.dart';
import 'older/older_home.dart';
import 'grammar/tiny_grammar_home.dart';
import 'family_settings.dart';
import 'games/picture_race_screen.dart';

const forest = Color(0xFF24582E);
const leaf = Color(0xFF77B932);
const cream = Color(0xFFFFF8EB);
const sun = Color(0xFFFFDF7C);
const coral = Color(0xFFEF856C);

class WordSprout extends StatelessWidget {
  const WordSprout({super.key, this.initialCatalog, this.quizSeed});
  final Curriculum? initialCatalog;
  /// Test-only seed to make screenshot goldens stable despite random answers.
  @visibleForTesting
  final int? quizSeed;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'WordSprout Kids',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: cream,
      colorScheme: ColorScheme.fromSeed(seedColor: leaf),
    ),
    home: Home(initialCatalog: initialCatalog,quizSeed:quizSeed),
  );
}

class Home extends StatefulWidget {
  const Home({super.key, this.initialCatalog, this.previewWordIndex,
    this.initialCompleted = const {}, this.initialCheckpoints = const {},
    this.quizSeed});
  final Curriculum? initialCatalog;
  /// Test-only progress fixture, never used by the installed app.
  @visibleForTesting
  final Set<int> initialCompleted;
  @visibleForTesting
  final Set<int> initialCheckpoints;
  @visibleForTesting
  final int? quizSeed;

  /// For deterministic golden screenshots of the *real lesson widget*.
  /// Production app instances never set this. This does not unlock words or
  /// alter learner progress for installed users.
  @visibleForTesting
  final int? previewWordIndex;

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final tts = FlutterTts();
  final contentStore = const ContentStore();
  Directory? imageDirectory;
  bool contentBusy = false;
  bool bonusMode = false;
  Curriculum? catalog;
  String? loadError;
  Set<int> completed = {}, tested = {}, checkpoints = {};
  Map<int,int> reviewDates = {}, reviewStages = {};
  int tab = 0, selectedLetter = 0, wordIndex = 0, step = -1;
  String feedback = '', celebration = '';
  bool reviewMode = false, assessmentMode = false, checkpointMode = false;
  List<int> assessmentItems = [];
  int question = 0, testLetter = 0;
  List<String> tiles = [];
  List<int> selectedTiles = [];
  late final math.Random _quizRandom;
  List<int> pictureChoices = [];
  List<String> factChoices = [];
  int correctFactIndex = -1;

  List<Word> get entries => catalog!.words;
  Word get current => entries[wordIndex];
  String nameOf(int letterIndex) => String.fromCharCode(65 + letterIndex);
  bool get graduated => tested.length == 26 && checkpoints.contains(25);
  int get dueCheckpoint {
    for (final end in [4, 9, 14, 19, 25]) {
      final begin = end == 25 ? 20 : end - 4;
      if (!checkpoints.contains(end) &&
          List.generate(end - begin + 1, (i) => begin + i).every(tested.contains)) {
        return end;
      }
    }
    return -1;
  }
  int get activeLetter {
    if (dueCheckpoint >= 0) return dueCheckpoint;
    for (var i = 0; i < 26; i++) {
      if (!tested.contains(i)) return i;
    }
    return 25;
  }
  int get accessibleWords {
    final first = activeLetter * 5;
    return completed.containsAll({first,first+1,first+2}) ? 5 : 3;
  }
  List<int> get revisions {
    final now = DateTime.now().millisecondsSinceEpoch;
    return completed.where((i) => (reviewDates[i] ?? 0) <= now).toList()..sort();
  }

  @override
  void initState() {
    super.initState();
    _quizRandom=widget.quizSeed==null?math.Random():math.Random(widget.quizSeed);
    tts.setLanguage('en-US');
    tts.setSpeechRate(.44);
    if (widget.initialCatalog != null) {
      catalog = widget.initialCatalog;
      completed={...widget.initialCompleted};
      tested={for(var l=0;l<26;l++)
        if(List.generate(5,(i)=>l*5+i).every(completed.contains)) l};
      checkpoints={...widget.initialCheckpoints};
      selectedLetter=activeLetter;
      final preview = widget.previewWordIndex;
      if (preview != null && preview >= 0 &&
          preview < widget.initialCatalog!.words.length) {
        wordIndex = preview;
        step = 0; // Actual Word Discovery screen, not a simulated mockup.
      }
    } else {
      _restore();
    }
  }
  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }
  Future<void> say(String text) async {
    await tts.stop();
    await tts.speak(text);
  }
  Map<int,int> decodePairs(List<String> values) {
    final map = <int,int>{};
    for (final raw in values) {
      final pair = raw.split(':');
      if (pair.length != 2) continue;
      final k = int.tryParse(pair[0]), v = int.tryParse(pair[1]);
      if (k != null && v != null) map[k] = v;
    }
    return map;
  }
  Future<void> _restore() async {
    try {
      final loaded = await contentStore.load();
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        catalog = loaded.catalog;
        imageDirectory = loaded.directory;
        completed = (prefs.getStringList('done') ?? []).map(int.parse)
            .where((i) => i >= 0 && i < loaded.catalog.words.length).toSet();
        // A letter is completed by learning its five words. Older progress is preserved.
        tested = {for(var l=0;l<26;l++)
          if(List.generate(5,(i)=>l*5+i).every(completed.contains)) l};
        checkpoints = (prefs.getStringList('checkpoints') ?? []).map(int.parse)
          .where((end)=>[4,9,14,19,25].contains(end)).toSet();
        reviewDates = decodePairs(prefs.getStringList('review_dates') ?? []);
        reviewStages = decodePairs(prefs.getStringList('review_stages') ?? []);
      });
      selectedLetter = activeLetter;
      if (contentStore.manifestUrl.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => checkForContent());
      }
    } catch (error) {
      if (mounted) setState(() => loadError = error.toString());
    }
  }
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('done', completed.map((i) => i.toString()).toList());
    await prefs.setStringList('letter_tests', tested.map((i) => i.toString()).toList());
    await prefs.setStringList('checkpoints', checkpoints.map((i) => i.toString()).toList());
    await prefs.setStringList('review_dates', reviewDates.entries
        .map((e) => e.key.toString()+':'+e.value.toString()).toList());
    await prefs.setStringList('review_stages', reviewStages.entries
        .map((e) => e.key.toString()+':'+e.value.toString()).toList());
  }

  Future<void> checkForContent() async {
    if (!mounted || contentBusy || step>=0 || contentStore.manifestUrl.isEmpty) return;
    setState(() => contentBusy = true);
    try {
      final offer = await contentStore.checkForUpdate(catalog!.version);
      if (offer == null || !mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder:(context)=>AlertDialog(
          title:const Text('New words and pictures!'),
          content:Text('A grown-up can download a '+offer.megabytes.toStringAsFixed(1)+
             ' MB learning pack. It will work offline after downloading.'),
          actions:[
            TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Not now')),
            FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Download')),
          ],
        ),
      );
      if (confirmed!=true || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Downloading learning content…')));
      final loaded = await contentStore.install(offer);
      if (!mounted) return;
      setState(() {
        catalog=loaded.catalog;
        imageDirectory=loaded.directory;
        selectedLetter=activeLetter;
        step=-1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('New learning content is ready offline!')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('Content update unavailable. Your offline words still work.')));
    } finally {
      if(mounted) setState(()=>contentBusy=false);
    }
  }

  void openWord(int index, {bool review = false, bool bonus = false}) {
    if (catalog == null || index < 0 || index >= entries.length) return;
    final l = index ~/ 5;
    if (review) {
      if (!completed.contains(index)) return;
    } else if (!bonus) {
      if (dueCheckpoint >= 0 || l != activeLetter) return;
      if (index % 5 >= accessibleWords) return;
    } else if (index < 130) {
      return;
    }
    setState(() {
      bonusMode = bonus;
      wordIndex = index;
      reviewMode = review;
      assessmentMode = false;
      step = 0;
      feedback = '';
    });
    say(current.pronunciation);
  }
  void continueLearning() {
    if (bonusMode) {
      setState(() { step = -1; tab = 1; bonusMode = false; });
      return;
    }
    if (graduated) {
      setState(() { step = -1; tab = 3; });
      return;
    }
    if (dueCheckpoint >= 0) {
      beginTest();
      return;
    }
    final first = activeLetter * 5;
    final next = List.generate(accessibleWords, (i) => first+i)
        .where((i) => !completed.contains(i));
    if (next.isNotEmpty) {
      openWord(next.first);
    }
  }
  void preparePictureChoices() {
    final first=wordIndex~/5*5;
    pictureChoices=wordIndex<130
      ? [wordIndex,first+(wordIndex%5+1)%5,
         first+(wordIndex%5+2)%5,first+(wordIndex%5+3)%5]
      : [wordIndex,0,1,2];
    pictureChoices.shuffle(_quizRandom);
  }
  void prepareFactChoices() {
    factChoices=[current.facts.first,entries[(wordIndex+36)%130].facts.first,
      entries[(wordIndex+79)%130].facts.first]..shuffle(_quizRandom);
    correctFactIndex=factChoices.indexOf(current.facts.first);
  }
  void prepareTiles() {
    final letters = current.spelling.split('');
    tiles = [...letters, 'B','O']..shuffle(math.Random(wordIndex * 41 + 17));
    selectedTiles = [];
    feedback = '';
  }
  void spell() {
    prepareTiles();
    setState(() => step = 1);
  }
  void checkSpelling() {
    if (selectedTiles.length < current.spelling.length) {
      setState(() => feedback = 'Fill all the boxes!');
    } else if (selectedTiles.map((i) => tiles[i]).join() == current.spelling) {
      HapticFeedback.lightImpact();
      if (assessmentMode) {
        advanceTest();
      } else {
        setState(() { preparePictureChoices(); step=2; feedback=''; });
        say('Great! Find the picture.');
      }
    } else {
      setState(() => feedback = 'Try another letter!');
    }
  }
  void checkPicture(int answer) {
    if (answer != wordIndex) {
      setState(() => feedback = 'Look closely and try again!');
    } else if (assessmentMode) {
      advanceTest();
    } else {
      setState(() { prepareFactChoices(); step=3; feedback=''; });
      say('Great! Pick a true fact.');
    }
  }
  void scheduleRevision(int index, {required bool revisited}) {
    final stage = revisited ? (reviewStages[index] ?? 1)+1 : 1;
    reviewStages[index] = stage;
    const days = [1,3,7,14,30,60];
    reviewDates[index] = DateTime.now().add(Duration(
      days: days[math.min(stage-1, days.length-1)])).millisecondsSinceEpoch;
  }
  void checkFact(int answer) {
    if (answer != correctFactIndex) {
      setState(() => feedback = 'Listen again and try!');
      return;
    }
    if (assessmentMode) {
      advanceTest();
      return;
    }
    setState(() {
      completed.add(wordIndex);
      final letter=wordIndex~/5;
      if(wordIndex<130&&List.generate(5,(i)=>letter*5+i).every(completed.contains)) {
        tested.add(letter);
      }
      selectedLetter=activeLetter;
      scheduleRevision(wordIndex, revisited: reviewMode);
      celebration = reviewMode ? 'Review complete!' : 'You learned ' + current.name + '!';
      step=4;
      feedback='';
    });
    _save();
    say('Fantastic!');
  }
  void next() {
    if (reviewMode) {
      setState(() { step=-1; reviewMode=false; bonusMode=false; tab=3; });
    } else {
      continueLearning();
    }
  }
  void beginTest() {
    final end=dueCheckpoint;
    if(end<0)return;
    final begin=end==25?20:end-4;
    // No per-letter test. Assess a mixed sample from every letter
    // after a set of five alphabets (U–Z is the six-letter finale).
    final items=<int>[];
    for(var letter=begin;letter<=end;letter++){
      final candidates=List.generate(5,(i)=>letter*5+i)
        ..shuffle(_quizRandom);
      items.addAll(candidates.take(3));
    }
    items.shuffle(_quizRandom);
    setState((){
      assessmentItems=items;
      checkpointMode=true;
      testLetter=end;
      question=0;
      assessmentMode=true;
      reviewMode=false;
    });
    openQuestion();
  }
  void openQuestion() {
    setState(() {
      wordIndex = assessmentItems[question];
      feedback='';
      final mode = question%3;
      step = mode == 0 ? 1 : mode == 1 ? 2 : 3;
      if (mode == 0) prepareTiles();
      if (mode == 1) preparePictureChoices();
      if (mode == 2) prepareFactChoices();
    });
    say(current.pronunciation);
  }
  void advanceTest() {
    question++;
    if (question < assessmentItems.length) {
      openQuestion();
      return;
    }
    setState(() {
      assessmentMode=false;
      step=4;
      checkpoints.add(testLetter);
      celebration=testLetter==25?'Alphabet graduation complete!':
        'Five-letter checkpoint complete!';
      selectedLetter=activeLetter;
    });
    _save();
    say('Amazing job!');
  }

  Widget card(Widget child) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: const Color(0xFFFDFCF7),
      borderRadius: BorderRadius.circular(27),
      boxShadow: const [BoxShadow(color:Color(0x180A3619),blurRadius:12,offset:Offset(0,5))]),
    child: child,
  );
  Widget button(String text, VoidCallback onTap, {Color color=leaf}) =>
      SizedBox(height:55,width:double.infinity,child:FilledButton(
        onPressed:onTap, style:FilledButton.styleFrom(backgroundColor:color,
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(30))),
        child:Text(text,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900))));
  Widget illustration(int index,{double size=140, bool animate=false}) {
    final word = entries[index];
    if (imageDirectory != null && word.isDownloadedImage) {
      if (animate && word.animationFrames.isNotEmpty) {
        return _WordSequence(
          key: ValueKey(word.id + catalog!.version),
          root: imageDirectory!, frames: word.animationFrames,
          size: size, label: word.name);
      }
      return Image.file(File(imageDirectory!.path + '/' + word.image),
          width:size,height:size,fit:BoxFit.contain,
          semanticLabel:word.name,
          errorBuilder:(context,error,stack) =>
            Icon(Icons.image_not_supported_outlined,size:size*.55,color:forest));
    }
    return SvgPicture.asset(word.image,width:size,height:size,fit:BoxFit.contain,
      semanticsLabel:word.name);
  }
  Widget title(String value) => Text(value,textAlign:TextAlign.center,
    style:const TextStyle(fontSize:25,fontWeight:FontWeight.w900,color:forest));
  Widget audio(String value) => IconButton.filled(
    onPressed:()=>say(value),
    style:IconButton.styleFrom(backgroundColor:leaf,foregroundColor:Colors.white),
    icon:const Icon(Icons.volume_up_rounded,size:26));

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child:catalog == null
      ? Center(child:loadError == null ? const CircularProgressIndicator() :
          Padding(padding:const EdgeInsets.all(22),
            child:Text('Unable to open the word pack:\n'+loadError!,textAlign:TextAlign.center)))
      : Column(children:[
        if (step < 0) Padding(
          padding:const EdgeInsets.fromLTRB(12,12,12,0),
          child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
            const Expanded(child:FittedBox(
              fit:BoxFit.scaleDown,alignment:Alignment.centerLeft,
              child:Row(mainAxisSize:MainAxisSize.min,children:[
                Icon(Icons.spa_rounded,color:leaf,size:27),
                SizedBox(width:5),
                Text('WordSprout',style:TextStyle(color:forest,
                  fontSize:26,fontWeight:FontWeight.w900,letterSpacing:-1)),
              ]))),
            const SizedBox(width:8),
            SizedBox(width:124,child:TextButton.icon(
              key:const ValueKey('older_entry'),
              onPressed:()=>Navigator.push(context,MaterialPageRoute(
                builder:(context)=>const OlderHome())),
              icon:const Icon(Icons.auto_stories_rounded,size:17),
              label:const Text('Ages 6–12'),
              style:TextButton.styleFrom(
                foregroundColor:forest,
                padding:EdgeInsets.zero))),
            IconButton(
              tooltip:'Family settings',
              key:const ValueKey('family_settings_entry'),
              onPressed:()=>Navigator.push(context,MaterialPageRoute(
                builder:(context)=>const FamilySettings())),
              icon:const Icon(Icons.settings_outlined,color:forest,size:22)),
          ])),
        if (step >= 0) Padding(padding:const EdgeInsets.all(11),
          child:Row(children:[
            IconButton.filledTonal(onPressed:()=>setState(() {
              step=-1;assessmentMode=false;
            }),icon:const Icon(Icons.arrow_back_rounded)),
            const Spacer(),
            ...List.generate(5,(i)=>Container(width:29,height:10,
              margin:const EdgeInsets.symmetric(horizontal:3),
              decoration:BoxDecoration(
                color:i<=math.min(step,4)?leaf:const Color(0xFFE1DFD5),
                borderRadius:BorderRadius.circular(10)))),
            const Spacer(),
          ])),
        Expanded(child:Padding(padding:const EdgeInsets.all(16),
          child:step<0?page():lesson())),
      ])),
    bottomNavigationBar:step<0 && catalog != null
      ? NavigationBar(selectedIndex:tab,
          onDestinationSelected:(i)=>setState(()=>tab=i),destinations:const [
            NavigationDestination(icon:Icon(Icons.home_rounded),label:'Home'),
            NavigationDestination(icon:Icon(Icons.menu_book_rounded),label:'Learn'),
            NavigationDestination(icon:Icon(Icons.sports_esports_rounded),label:'Games'),
            NavigationDestination(icon:Icon(Icons.star_rounded),label:'Progress'),
          ]) : null,
  );

  Widget page() {
    if (tab==1) return learnPage();
    if (tab==2) return gamesPage();
    if (tab==3) return progressPage();
    return homePage();
  }
  Widget homePage() {
    final active=activeLetter;
    final groupStart=active==25?21:active~/5*5;
    final n=List.generate(5,(i)=>active*5+i).where(completed.contains).length;
    return Column(children:[
      card(Row(children:[
        const CircleAvatar(radius:25,backgroundColor:Color(0xFFFFE29A),
          child:Icon(Icons.wb_sunny_rounded,size:33,color:Color(0xFFEFAE32))),
        const SizedBox(width:10),
        const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('Hello, explorer!',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:forest)),
          Text('Ready for a word adventure?',style:TextStyle(fontSize:12,color:Color(0xFF65715B))),
        ])),
        Text(completed.length.toString()+'/'+entries.length.toString(),
          style:const TextStyle(color:forest,fontSize:12,fontWeight:FontWeight.w900)),
      ])),
      const SizedBox(height:11),
      Expanded(child:ClipRRect(borderRadius:BorderRadius.circular(30),
        child:LayoutBuilder(builder:(context,c)=>Stack(children:[
          Positioned.fill(child:SvgPicture.asset('assets/scene/alphabet_garden.svg',fit:BoxFit.fill)),
          Positioned(top:11,left:13,right:13,child:Container(
            padding:const EdgeInsets.symmetric(vertical:9,horizontal:11),
            decoration:BoxDecoration(color:const Color(0xF7FFFAE9),
              borderRadius:BorderRadius.circular(18)),
            child:Column(children:[
              const Text('Your Alphabet Trail',style:TextStyle(
                fontSize:18,fontWeight:FontWeight.w900,color:forest)),
              Text(dueCheckpoint>=0?'Five-letter checkpoint!' :
                'Letter '+nameOf(active)+' • '+n.toString()+' / 5 words',
                style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700,
                  color:Color(0xFF577F4A))),
            ]))),
          for(var i=0;i<5;i++) Positioned(
            left:c.maxWidth*[.24,.75,.26,.73,.29][i]-33,
            top:c.maxHeight*[.23,.41,.54,.67,.78][i]-33,
            child:GestureDetector(onTap:groupStart+i==active ? continueLearning : null,
              child:Container(height:66,width:66,
                decoration:BoxDecoration(shape:BoxShape.circle,
                  color:groupStart+i==active?sun:const Color(0xFFFFFDF2),
                  border:Border.all(color:Colors.white,width:5),
                  boxShadow:const [BoxShadow(color:Color(0x34416932),blurRadius:8,
                    offset:Offset(0,4))]),
                child:Stack(alignment:Alignment.center,children:[
                  Text(nameOf(groupStart+i),style:TextStyle(fontSize:29,
                    fontWeight:FontWeight.w900,color:groupStart+i==active
                      ?const Color(0xFFA85B27):const Color(0xFF797A70))),
                  if(tested.contains(groupStart+i)) const Positioned(
                    bottom:0,right:0,child:Icon(Icons.check_circle,color:leaf,size:16)),
                  if(groupStart+i>active) const Positioned(
                    bottom:0,right:0,child:Icon(Icons.lock_rounded,
                      color:Color(0xFF929285),size:13)),
                ]),
              ))),
        ])))),
      const SizedBox(height:10),
      button(graduated?'View My Progress ➜':
        dueCheckpoint>=0?'Play checkpoint ➜':'Continue Learning  ➜',
        continueLearning,color:coral),
      const SizedBox(height:11),
      card(InkWell(
        key:const ValueKey('grammar_entry'),
        onTap:()=>Navigator.push(context,MaterialPageRoute(
          builder:(context)=>const TinyGrammarHome())),
        child:const Row(children:[
          Icon(Icons.auto_stories_rounded,size:41,color:Color(0xFFED9B35)),
          SizedBox(width:11),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('Grammar Garden',style:TextStyle(
              fontSize:17,fontWeight:FontWeight.w900,color:forest)),
            Text('26 little lessons: what, why, where, above, below and more!',
              maxLines:2,overflow:TextOverflow.ellipsis,
              style:TextStyle(fontSize:12,color:Color(0xFF65715B))),
          ])),
          Icon(Icons.chevron_right_rounded,color:forest),
        ]))),
    ]);
  }

  Widget learnPage() {
    final first=selectedLetter*5;
    final unlocked=selectedLetter==activeLetter && dueCheckpoint<0;
    return ListView(children:[
      title('Alphabet A–Z'),
      const SizedBox(height:6),
      const Text('130 words • five per letter',textAlign:TextAlign.center),
      const SizedBox(height:14),
      Wrap(alignment:WrapAlignment.center,spacing:5,runSpacing:6,
        children:List.generate(26,(i)=>SizedBox(width:40,height:40,
          child:InkWell(onTap:()=>setState(()=>selectedLetter=i),
            child:Container(alignment:Alignment.center,
              decoration:BoxDecoration(
                color:selectedLetter==i?sun:
                  tested.contains(i)?const Color(0xFFDFF0CE):Colors.white,
                borderRadius:BorderRadius.circular(12),
                border:Border.all(color:i==activeLetter?leaf:Colors.transparent,width:2)),
              child:Text(nameOf(i),style:const TextStyle(
                fontSize:18,fontWeight:FontWeight.w900,color:forest))))))),
      const SizedBox(height:18),
      title('Letter '+nameOf(selectedLetter)),
      const SizedBox(height:12),
      if(dueCheckpoint==selectedLetter)
        Padding(padding:const EdgeInsets.only(bottom:11),
          child:button('Five-letter checkpoint ➜',continueLearning)),
      ...List.generate(5,(i){
        final index=first+i;
        final allowed=(unlocked && i<accessibleWords) || tested.contains(selectedLetter);
        return Padding(padding:const EdgeInsets.only(bottom:10),child:card(
          InkWell(onTap:allowed?()=>openWord(index,
            review:tested.contains(selectedLetter)):null,
            child:Row(children:[
              SizedBox(width:63,height:65,child:Center(child:illustration(index,size:61))),
              const SizedBox(width:12),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(entries[index].name,style:const TextStyle(fontSize:18,
                  fontWeight:FontWeight.w900,color:forest)),
                Text(completed.contains(index)?'Learned • tap to revisit':
                  allowed?'Tap to learn':'Unlock by learning earlier words',
                  style:const TextStyle(fontSize:12,color:Color(0xFF687063))),
              ])),
              Icon(completed.contains(index)?Icons.check_circle:
                allowed?Icons.chevron_right_rounded:Icons.lock_rounded,color:leaf),
            ]),
          ),
        ));
      }),
      if(entries.length>130)...[
        const SizedBox(height:20),
        title('Extra Words • '+(entries.length-130).toString()),
        const SizedBox(height:9),
        ...List.generate(entries.length-130,(i){
          final idx=130+i;
          return Padding(padding:const EdgeInsets.only(bottom:9),
            child:card(InkWell(onTap:()=>openWord(idx,bonus:true),
              child:Row(children:[
                illustration(idx,size:55),const SizedBox(width:10),
                Expanded(child:Text(entries[idx].name,style:const TextStyle(
                  fontSize:17,fontWeight:FontWeight.w800,color:forest))),
                Icon(completed.contains(idx)?Icons.check_circle:Icons.play_arrow,
                  color:leaf),
              ]))));
        }),
      ],
    ]);
  }
  Widget gamesPage()=>ListView(children:[
    title('Games & Friends'),const SizedBox(height:17),
    card(InkWell(onTap:()=>Navigator.push(context,MaterialPageRoute(
      builder:(context)=>const TinyGrammarHome())),
      child:const ListTile(
        key:ValueKey('grammar_games_entry'),
        leading:Icon(Icons.auto_stories_rounded,color:leaf,size:31),
        title:Text('Grammar Garden',style:TextStyle(
          fontSize:18,color:forest,fontWeight:FontWeight.w900)),
        subtitle:Text('26 offline mini lessons • Ages 4–6'),
        trailing:Icon(Icons.chevron_right_rounded,color:forest)))),
    const SizedBox(height:12),
    card(InkWell(
      key:const ValueKey('picture_race_entry'),
      onTap:()=>Navigator.push(context,MaterialPageRoute(
        builder:(context)=>PictureRaceScreen(
          catalog:catalog!,furthestLetter:activeLetter,
          learnedWordIndices:completed.toList(),
          imageDirectory:imageDirectory))),
      child:const ListTile(
        leading:Icon(Icons.bolt_rounded,color:coral,size:33),
        title:Text('Picture Race',style:TextStyle(
          fontSize:18,fontWeight:FontWeight.w900,color:forest)),
        subtitle:Text('See the picture • race to spell it first'),
        trailing:Icon(Icons.chevron_right_rounded,color:forest)))),
    const SizedBox(height:12),
    for(final game in ['Guess in 5','Word Detective','WordMayhem'])
      Padding(padding:const EdgeInsets.only(bottom:12),
        child:card(ListTile(
          leading:const Icon(Icons.sports_esports_rounded,color:coral,size:30),
          title:Text(game,style:const TextStyle(
            fontSize:18,fontWeight:FontWeight.bold,color:forest)),
          trailing:const Icon(Icons.lock_outline)))),
    const SizedBox(height:10),
    const Text('Picture Race uses private rooms with approved friends. '
      'A live HTTPS game server is needed to connect real players.',textAlign:TextAlign.center),
  ]);
  Widget progressPage()=>ListView(children:[
    title('My Growing Garden'),const SizedBox(height:15),
    card(Column(children:[
      Text(completed.length.toString()+'/'+entries.length.toString(),style:const TextStyle(
        fontSize:42,fontWeight:FontWeight.w900,color:forest)),
      const Text('Words discovered'),
      const SizedBox(height:12),
      LinearProgressIndicator(value:completed.length/entries.length,minHeight:15,
        borderRadius:BorderRadius.circular(18),color:leaf,
        backgroundColor:const Color(0xFFE8F2D8)),
      const SizedBox(height:13),
      Text(tested.length.toString()+'/26 letters learned • '+
        checkpoints.length.toString()+'/5 group checkpoints',
        style:const TextStyle(color:forest)),
    ])),
    if (contentStore.manifestUrl.isNotEmpty) ...[
      const SizedBox(height:13),
      button(contentBusy?'Checking for updates…':'Check for New Words',
        contentBusy?(){}:checkForContent),
    ],
    const SizedBox(height:19),title('Words to Review'),
    const SizedBox(height:10),
    if(revisions.isEmpty) card(const Text('Nothing due right now. Keep growing!',
      textAlign:TextAlign.center))
    else ...revisions.take(20).map((i)=>Padding(padding:const EdgeInsets.only(bottom:8),
      child:card(InkWell(onTap:()=>openWord(i,review:true),child:Row(children:[
        illustration(i,size:57),const SizedBox(width:12),
        Expanded(child:Text(entries[i].name,style:const TextStyle(
          color:forest,fontSize:18,fontWeight:FontWeight.w900))),
        const Icon(Icons.replay_rounded,color:leaf),
      ]))))),
  ]);

  Widget lesson() {
    if(step==0)return discover();
    if(step==1)return spellingScreen();
    if(step==2)return recognitionScreen();
    if(step==3)return factScreen();
    return finishScreen();
  }
  Widget subtitle()=>Padding(padding:const EdgeInsets.only(bottom:7),
    child:Text(assessmentMode
      ?'Mixed alphabet checkpoint • '+
        (question+1).toString()+'/'+assessmentItems.length.toString()
      :reviewMode?'Review word':'Learn Letter '+current.letter,
      style:const TextStyle(color:forest,fontSize:13,fontWeight:FontWeight.w700)));
  Widget discover()=>Column(children:[
    subtitle(),
    Expanded(flex:5,child:card(Column(children:[
      Expanded(child:Center(child:illustration(wordIndex,size:183,animate:true))),
      Row(mainAxisAlignment:MainAxisAlignment.center,children:[
        title(current.name),const SizedBox(width:13),audio(current.pronunciation),
      ]),
    ]))),
    const SizedBox(height:12),
    ...current.facts.map((f)=>Expanded(flex:2,child:Padding(
      padding:const EdgeInsets.only(bottom:8),
      child:card(Row(children:[
        const Icon(Icons.auto_awesome,color:leaf),const SizedBox(width:9),
        Expanded(child:Text(f,style:const TextStyle(fontSize:14,
          fontWeight:FontWeight.bold,color:forest))),
        IconButton(onPressed:()=>say(f),icon:const Icon(
          Icons.volume_up_rounded,color:leaf)),
      ]))))),
    button('Next ➜',spell),
  ]);
  Widget spellingScreen()=>Column(children:[
    subtitle(),
    Expanded(child:Center(child:illustration(wordIndex,size:150))),
    title('Spell the word!'),
    audio(current.pronunciation),
    const SizedBox(height:14),
    Wrap(alignment:WrapAlignment.center,spacing:4,runSpacing:5,
      children:List.generate(current.spelling.length,(i)=>Container(
        width:math.min(72,302/current.spelling.length),height:60,
        alignment:Alignment.center,decoration:BoxDecoration(
          color:Colors.white,border:Border.all(color:leaf,width:3),
          borderRadius:BorderRadius.circular(15)),
        child:Text(i<selectedTiles.length?tiles[selectedTiles[i]]:'',
          style:const TextStyle(fontSize:27,fontWeight:FontWeight.w900,color:forest)),
      ))),
    const SizedBox(height:16),
    Wrap(alignment:WrapAlignment.center,spacing:6,runSpacing:6,
      children:List.generate(tiles.length,(i)=>SizedBox(
        width:53,height:53,
        child:FilledButton(
          onPressed:selectedTiles.contains(i)||
            selectedTiles.length>=current.spelling.length?null:
            ()=>setState((){selectedTiles.add(i);feedback='';}),
          style:FilledButton.styleFrom(backgroundColor:sun,foregroundColor:forest,
            padding:EdgeInsets.zero,shape:RoundedRectangleBorder(
              borderRadius:BorderRadius.circular(14))),
          child:Text(tiles[i],style:const TextStyle(
            fontSize:25,fontWeight:FontWeight.w900)),
        ),
      ))),
    const Spacer(),
    Text(feedback,style:const TextStyle(
      color:Color(0xFFB6482E),fontWeight:FontWeight.w700)),
    Row(children:[
      Expanded(child:TextButton(onPressed:()=>setState((){
        if(selectedTiles.isNotEmpty)selectedTiles.removeLast();feedback='';
      }),child:const Text('↶ Undo'))),
      Expanded(child:TextButton(onPressed:()=>setState((){
        selectedTiles=[];feedback='';
      }),child:const Text('Clear'))),
      Expanded(flex:2,child:button('✓ Check',checkSpelling)),
    ]),
  ]);
  Widget recognitionScreen() {
    return Column(children:[
      subtitle(),title('Tap the '+current.name+'!'),
      audio('Find the '+current.pronunciation),const SizedBox(height:15),
      Expanded(child:GridView.count(crossAxisCount:2,
        mainAxisSpacing:12,crossAxisSpacing:12,childAspectRatio:1,
        physics:const NeverScrollableScrollPhysics(),
        children:pictureChoices.map((i)=>GestureDetector(
          key:ValueKey('picture_option_'+i.toString()),
          onTap:()=>checkPicture(i),
          child:card(Center(child:illustration(i,size:116))))).toList())),
      Text(feedback,style:const TextStyle(
        color:Colors.deepOrange,fontWeight:FontWeight.bold)),
    ]);
  }
  Widget factScreen(){
    return Column(children:[
      subtitle(),title('Which fact is about '+current.name+'?'),
      Expanded(child:Center(child:illustration(wordIndex,size:158))),
      ...factChoices.asMap().entries.map((e)=>Padding(
        padding:const EdgeInsets.only(bottom:11),
        child:card(Material(type:MaterialType.transparency,child:ListTile(
          key:ValueKey('fact_option_'+e.key.toString()),
          onTap:()=>checkFact(e.key),
          title:Text(e.value,style:const TextStyle(
            fontWeight:FontWeight.bold,fontSize:15,color:forest)),
          trailing:IconButton(onPressed:()=>say(e.value),
            icon:const Icon(Icons.volume_up_rounded,color:leaf))))))),
      Text(feedback,style:const TextStyle(color:Colors.deepOrange)),
    ]);
  }
  Widget finishScreen()=>Column(mainAxisAlignment:MainAxisAlignment.center,children:[
    const Row(mainAxisAlignment:MainAxisAlignment.center,children:[
      Icon(Icons.star_rounded,color:Color(0xFFFFC63B),size:47),
      Icon(Icons.star_rounded,color:Color(0xFFFFC63B),size:54),
      Icon(Icons.star_rounded,color:Color(0xFFFFC63B),size:47),
    ]),
    const SizedBox(height:16),title('Great job!'),
    const SizedBox(height:20),illustration(wordIndex,size:164),
    const SizedBox(height:25),
    Text(celebration,style:const TextStyle(fontSize:19,color:forest,
      fontWeight:FontWeight.w700),textAlign:TextAlign.center),
    const SizedBox(height:35),button('Continue ➜',next),
  ]);
}


/// Plays the supplied PNG appearance sequence once and holds frame 00007.
/// Recognition and spelling always use the clear final still instead.
class _WordSequence extends StatefulWidget {
  const _WordSequence({super.key,required this.root,required this.frames,
    required this.size,required this.label});
  final Directory root;
  final List<String> frames;
  final double size;
  final String label;
  @override
  State<_WordSequence> createState()=>_WordSequenceState();
}
class _WordSequenceState extends State<_WordSequence> {
  int position=0;
  Timer? clock;
  @override
  void initState(){
    super.initState();
    clock=Timer.periodic(const Duration(milliseconds:130),(timer){
      if(!mounted || position>=widget.frames.length-1){timer.cancel();return;}
      setState(()=>position++);
    });
  }
  @override
  void dispose(){clock?.cancel();super.dispose();}
  @override
  Widget build(BuildContext context) => Image.file(
    File(widget.root.path+'/'+widget.frames[position]),
    width:widget.size,height:widget.size,fit:BoxFit.contain,
    semanticLabel:widget.label,
    gaplessPlayback:true,
    errorBuilder:(context,error,stack) =>
      Icon(Icons.image_not_supported_outlined,size:widget.size*.55,color:forest));
}
