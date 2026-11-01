import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class TinyGrammarCourse {
  const TinyGrammarCourse(this.version,this.groups,this.lessons);
  final String version;
  final List<TinyGrammarGroup> groups;
  final List<TinyGrammarLesson> lessons;

  static Future<TinyGrammarCourse> load() async {
    final value=await rootBundle.loadString('assets/content/grammar_4_6_v1.json');
    final original=TinyGrammarCourse.fromJson(
      jsonDecode(value) as Map<String,dynamic>);
    try {
      final prefs=await SharedPreferences.getInstance();
      final active=prefs.getString('content_pack_active_v1');
      if(active==null||!RegExp(r'^[a-f0-9]{20}
  factory TinyGrammarCourse.fromJson(Map<String,dynamic> json) {
    if(json['schema_version']!=1)throw const FormatException('Unsupported grammar version');
    final groups=(json['groups'] as List).map((g)=>
      TinyGrammarGroup.fromJson(g as Map<String,dynamic>)).toList();
    final lessons=(json['lessons'] as List).map((l)=>
      TinyGrammarLesson.fromJson(l as Map<String,dynamic>)).toList();
    if(groups.length!=5||lessons.length<26||lessons.length>200){
      throw const FormatException('Grammar track has an invalid number of lessons');
    }
    final names=<String>{};
    for(var i=0;i<lessons.length;i++) {
      final lesson=lessons[i];
      if(!RegExp(r'^[a-z_]+$').hasMatch(lesson.id)||!names.add(lesson.id)||
         !groups.any((g)=>g.id==lesson.group)){
        throw FormatException('Duplicate or invalid grammar ID: '+lesson.id);
      }
      if(i<26&&lesson.group!=groups[(i<6?0:i<16?1:i<20?2:i<24?3:4)].id){
        throw const FormatException('Starter grammar lesson order changed');
      }
      if(lesson.title.trim().isEmpty||lesson.teach.length<12||
         lesson.example.trim().isEmpty||
         lesson.sentence.trim().isEmpty||lesson.hint.trim().isEmpty||
         lesson.visual.trim().isEmpty){
        throw FormatException('Incomplete grammar lesson: '+lesson.id);
      }
      if(lesson.challenge.options.length!=4||lesson.transfer.options.length!=4||
         lesson.sentenceTokens.length<4||lesson.sentenceTokens.length>12){
        throw FormatException('Incorrect exercise structure in '+lesson.id);
      }
    }
    return TinyGrammarCourse(json['content_version'] as String,groups,lessons);
  }
}

class TinyGrammarGroup {
  const TinyGrammarGroup(this.id,this.title,this.description);
  final String id,title,description;
  factory TinyGrammarGroup.fromJson(Map<String,dynamic> data)=>
    TinyGrammarGroup(data['id'] as String,data['title'] as String,
      data['description'] as String);
}

class TinyGrammarChoice {
  const TinyGrammarChoice(this.prompt,this.options,this.answer,this.explain);
  final String prompt,explain;
  final List<String> options;
  final int answer;
  factory TinyGrammarChoice.fromJson(Map<String,dynamic> raw){
    final options=List<String>.from(raw['options'] as List);
    final answer=raw['answer'];
    if(options.length!=4||options.toSet().length!=4||answer is! int||
       answer<0||answer>=4||!options.every((o)=>o.trim().isNotEmpty)||
       (raw['explain'] as String).trim().isEmpty){
      throw const FormatException('Invalid preschool grammar choice');
    }
    return TinyGrammarChoice(raw['prompt'] as String,options,answer,
      raw['explain'] as String);
  }
}

class TinyGrammarLesson {
  const TinyGrammarLesson({
    required this.id,required this.group,required this.title,
    required this.visual,required this.teach,required this.example,
    required this.challenge,required this.transfer,
    required this.sentence,required this.hint});
  final String id,group,title,visual,teach,example,sentence,hint;
  final TinyGrammarChoice challenge,transfer;
  List<String> get sentenceTokens=>sentence
    .replaceAll(RegExp(r'[.!?]'), '').split(RegExp(r'\s+'));
  bool acceptsSentence(String typed){
    String normalize(String text)=>text.toLowerCase().trim()
      .replaceAll(RegExp(r'[.!?,]'), '')
      .replaceAll(RegExp(r'\s+'),' ');
    return normalize(typed)==normalize(sentence);
  }

  factory TinyGrammarLesson.fromJson(Map<String,dynamic> raw)=>
    TinyGrammarLesson(
      id:raw['id'] as String,group:raw['group'] as String,
      title:raw['title'] as String,visual:raw['visual'] as String,
      teach:raw['teach'] as String,example:raw['example'] as String,
      challenge:TinyGrammarChoice.fromJson(raw['challenge'] as Map<String,dynamic>),
      transfer:TinyGrammarChoice.fromJson(raw['transfer'] as Map<String,dynamic>),
      sentence:raw['sentence'] as String,hint:raw['hint'] as String);
}
).hasMatch(active))return original;
      final support=await getApplicationSupportDirectory();
      final file=File(support.path+'/wordsprout_content/'+active+
        '/grammar_4_6.json');
      if(!await file.exists())return original;
      final updated=TinyGrammarCourse.fromJson(
        jsonDecode(await file.readAsString()) as Map<String,dynamic>);
      for(var i=0;i<26;i++){
        if(original.lessons[i].id!=updated.lessons[i].id)return original;
      }
      return updated;
    }catch(_){
      // Never let a bad downloaded lesson stop the bundled offline curriculum.
      return original;
    }
  }
  factory TinyGrammarCourse.fromJson(Map<String,dynamic> json) {
    if(json['schema_version']!=1)throw const FormatException('Unsupported grammar version');
    final groups=(json['groups'] as List).map((g)=>
      TinyGrammarGroup.fromJson(g as Map<String,dynamic>)).toList();
    final lessons=(json['lessons'] as List).map((l)=>
      TinyGrammarLesson.fromJson(l as Map<String,dynamic>)).toList();
    if(groups.length!=5||lessons.length<26||lessons.length>200){
      throw const FormatException('Grammar track has an invalid number of lessons');
    }
    final names=<String>{};
    for(var i=0;i<lessons.length;i++) {
      final lesson=lessons[i];
      if(!RegExp(r'^[a-z_]+$').hasMatch(lesson.id)||!names.add(lesson.id)||
         !groups.any((g)=>g.id==lesson.group)){
        throw FormatException('Duplicate or invalid grammar ID: '+lesson.id);
      }
      if(i<26&&lesson.group!=groups[(i<6?0:i<16?1:i<20?2:i<24?3:4)].id){
        throw const FormatException('Starter grammar lesson order changed');
      }
      if(lesson.title.trim().isEmpty||lesson.teach.length<12||
         lesson.example.trim().isEmpty||
         lesson.sentence.trim().isEmpty||lesson.hint.trim().isEmpty||
         lesson.visual.trim().isEmpty){
        throw FormatException('Incomplete grammar lesson: '+lesson.id);
      }
      if(lesson.challenge.options.length!=4||lesson.transfer.options.length!=4||
         lesson.sentenceTokens.length<4||lesson.sentenceTokens.length>12){
        throw FormatException('Incorrect exercise structure in '+lesson.id);
      }
    }
    return TinyGrammarCourse(json['content_version'] as String,groups,lessons);
  }
}

class TinyGrammarGroup {
  const TinyGrammarGroup(this.id,this.title,this.description);
  final String id,title,description;
  factory TinyGrammarGroup.fromJson(Map<String,dynamic> data)=>
    TinyGrammarGroup(data['id'] as String,data['title'] as String,
      data['description'] as String);
}

class TinyGrammarChoice {
  const TinyGrammarChoice(this.prompt,this.options,this.answer,this.explain);
  final String prompt,explain;
  final List<String> options;
  final int answer;
  factory TinyGrammarChoice.fromJson(Map<String,dynamic> raw){
    final options=List<String>.from(raw['options'] as List);
    final answer=raw['answer'];
    if(options.length!=4||options.toSet().length!=4||answer is! int||
       answer<0||answer>=4||!options.every((o)=>o.trim().isNotEmpty)||
       (raw['explain'] as String).trim().isEmpty){
      throw const FormatException('Invalid preschool grammar choice');
    }
    return TinyGrammarChoice(raw['prompt'] as String,options,answer,
      raw['explain'] as String);
  }
}

class TinyGrammarLesson {
  const TinyGrammarLesson({
    required this.id,required this.group,required this.title,
    required this.visual,required this.teach,required this.example,
    required this.challenge,required this.transfer,
    required this.sentence,required this.hint});
  final String id,group,title,visual,teach,example,sentence,hint;
  final TinyGrammarChoice challenge,transfer;
  List<String> get sentenceTokens=>sentence
    .replaceAll(RegExp(r'[.!?]'), '').split(RegExp(r'\s+'));
  bool acceptsSentence(String typed){
    String normalize(String text)=>text.toLowerCase().trim()
      .replaceAll(RegExp(r'[.!?,]'), '')
      .replaceAll(RegExp(r'\s+'),' ');
    return normalize(typed)==normalize(sentence);
  }

  factory TinyGrammarLesson.fromJson(Map<String,dynamic> raw)=>
    TinyGrammarLesson(
      id:raw['id'] as String,group:raw['group'] as String,
      title:raw['title'] as String,visual:raw['visual'] as String,
      teach:raw['teach'] as String,example:raw['example'] as String,
      challenge:TinyGrammarChoice.fromJson(raw['challenge'] as Map<String,dynamic>),
      transfer:TinyGrammarChoice.fromJson(raw['transfer'] as Map<String,dynamic>),
      sentence:raw['sentence'] as String,hint:raw['hint'] as String);
}
