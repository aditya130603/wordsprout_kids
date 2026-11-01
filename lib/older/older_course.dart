import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

/// Ages 6–12 curriculum independent of the original 4–6 alphabet course.
class OlderCourse {
  const OlderCourse({required this.version,required this.tracks,required this.missions});
  final String version;
  final List<LearningTrack> tracks;
  final List<StoryMission> missions;

  static Future<OlderCourse> load() async {
    final raw=await rootBundle.loadString('assets/content/older_missions_v1.json');
    final original=OlderCourse.fromJson(jsonDecode(raw) as Map<String,dynamic>);
    try {
      final prefs=await SharedPreferences.getInstance();
      final active=prefs.getString('content_pack_active_v1');
      if(active==null || !RegExp(r'^[a-f0-9]{20}
  factory OlderCourse.fromJson(Map<String,dynamic> raw) {
    if (raw['schema_version']!=1) throw const FormatException('Invalid older-course version');
    final tracks=(raw['tracks'] as List).map((e)=>LearningTrack.fromJson(e as Map<String,dynamic>)).toList();
    final missions=(raw['missions'] as List).map((e)=>StoryMission.fromJson(e as Map<String,dynamic>)).toList();
    if (tracks.length!=3 || missions.length<12 || missions.length>150) {
      throw const FormatException('Invalid track or mission count');
    }
    final ids=<String>{};
    final terms=<String>{};
    final trackIds=tracks.map((t)=>t.id).toSet();
    for (var i=0;i<missions.length;i++) {
      final m=missions[i];
      if (!ids.add(m.id) || !trackIds.contains(m.level)) {
        throw FormatException('Invalid mission id or track: '+m.id);
      }
      if (i<12 && m.level!=tracks[i~/4].id) {
        throw const FormatException('First 12 missions must be ordered by track');
      }
      if (m.words.length!=4 || m.words.any((w)=>w.term.length<3)) {
        throw const FormatException('Each starter mission needs four valid vocabulary words');
      }
      for (final w in m.words) {
        if (!terms.add(w.term)) throw FormatException('Repeated word: '+w.term);
        if (w.meaning.isEmpty || w.context.isEmpty ||
            w.synonym.isEmpty || w.antonym.isEmpty) {
          throw FormatException('Incomplete word: '+w.term);
        }
      }
      if (m.sentence.toLowerCase().split(RegExp(r'\s+')).length<5 ||
          !m.sentence.endsWith('.') ||
          m.sentencePrompt.isEmpty ||
          m.sentenceAlternatives.length>3 ||
          m.pattern.options.length!=4 ||
          m.transfer.options.length!=4 ||
          m.pattern.answer<0 || m.pattern.answer>=4 ||
          m.transfer.answer<0 || m.transfer.answer>=4) {
        throw FormatException('Invalid mission challenges: '+m.id);
      }
    }
    return OlderCourse(version:raw['content_version'] as String,tracks:tracks,missions:missions);
  }
  List<StoryMission> forTrack(String id)=>missions.where((m)=>m.level==id).toList(growable:false);
}

class LearningTrack {
  const LearningTrack(this.id,this.title,this.ageHint,this.description,this.hex);
  final String id,title,ageHint,description,hex;
  factory LearningTrack.fromJson(Map<String,dynamic> map)=>LearningTrack(
    map['id'] as String,map['title'] as String,map['age_hint'] as String,
    map['description'] as String,map['color'] as String);
}

class StoryWord {
  const StoryWord(this.term,this.meaning,this.context,this.synonym,this.antonym);
  final String term,meaning,context,synonym,antonym;
  factory StoryWord.fromJson(Map<String,dynamic> map)=>StoryWord(
    map['term'] as String,map['meaning'] as String,
    map['context'] as String,map['synonym'] as String,
    map['antonym'] as String);
}

class ChoiceChallenge {
  const ChoiceChallenge(this.question,this.options,this.answer,this.explain);
  final String question,explain;
  final List<String> options;
  final int answer;
  factory ChoiceChallenge.fromJson(Map<String,dynamic> map)=>ChoiceChallenge(
    map['question'] as String,
    List<String>.from(map['options'] as List),
    map['answer'] as int,map['explain'] as String);
}

class StoryMission {
  const StoryMission({
    required this.id,required this.level,required this.title,
    required this.scene,required this.subtitle,required this.goal,
    required this.story,required this.words,required this.sentence,
    required this.sentencePrompt,required this.sentenceAlternatives,
    required this.consequence,required this.wrongConsequence,
    required this.pattern,required this.transfer,required this.order,
  });
  final String id,level,title,scene,subtitle,goal,story;
  final List<StoryWord> words;
  final String sentence,sentencePrompt;
  final List<String> sentenceAlternatives;
  final String consequence,wrongConsequence;
  final ChoiceChallenge pattern,transfer;
  final int order;

  factory StoryMission.fromJson(Map<String,dynamic> map)=>StoryMission(
    id:map['id'] as String,level:map['level'] as String,
    title:map['title'] as String,scene:map['scene'] as String,
    subtitle:map['subtitle'] as String,goal:map['goal'] as String,
    story:map['story'] as String,
    words:(map['words'] as List).map((w)=>StoryWord.fromJson(w as Map<String,dynamic>)).toList(growable:false),
    sentence:map['sentence'] as String,
    sentencePrompt:map['sentencePrompt'] as String,
    sentenceAlternatives:List<String>.from(map['sentenceAlternatives'] as List),
    consequence:map['consequence'] as String,
    wrongConsequence:map['wrongConsequence'] as String,
    pattern:ChoiceChallenge.fromJson(map['pattern'] as Map<String,dynamic>),
    transfer:ChoiceChallenge.fromJson(map['transfer'] as Map<String,dynamic>),
    order:map['order'] as int);

  List<String> get sentenceTokens=>sentence
    .replaceAll(RegExp(r'[.!?]'), '').split(RegExp(r'\s+'));

  /// Specific teacher-reviewed word-order answers only. Not unrestricted AI.
  bool acceptsSentence(String candidate) {
    String normalize(String value)=>value.toLowerCase().trim()
      .replaceAll(RegExp(r'[.!?,]'), '')
      .replaceAll(RegExp(r'\s+'),' ');
    final result=normalize(candidate);
    return result==normalize(sentence) ||
      sentenceAlternatives.any((v)=>normalize(v)==result);
  }
}

enum OlderStep { story, detective, relation, sentence, pattern, transfer, finish }

class MissionScore {
  const MissionScore(this.correct,this.attempts);
  final int correct,attempts;
  double get accuracy=>attempts==0?1.0:correct/attempts;
  int get stars=>accuracy>=.9?3:accuracy>=.65?2:1;
}
).hasMatch(active)) return original;
      final folder=await getApplicationSupportDirectory();
      final file=File(folder.path+'/wordsprout_content/'+active+'/older_missions.json');
      if(!await file.exists())return original;
      final updated=OlderCourse.fromJson(
        jsonDecode(await file.readAsString()) as Map<String,dynamic>);
      for(var i=0;i<12;i++) {
        if(updated.missions[i].id!=original.missions[i].id) return original;
        for(var j=0;j<4;j++){
          if(updated.missions[i].words[j].term!=original.missions[i].words[j].term) {
            return original;
          }
        }
      }
      return updated;
    }catch(_){
      return original; // Network and data errors must never break offline play.
    }
  }
  factory OlderCourse.fromJson(Map<String,dynamic> raw) {
    if (raw['schema_version']!=1) throw const FormatException('Invalid older-course version');
    final tracks=(raw['tracks'] as List).map((e)=>LearningTrack.fromJson(e as Map<String,dynamic>)).toList();
    final missions=(raw['missions'] as List).map((e)=>StoryMission.fromJson(e as Map<String,dynamic>)).toList();
    if (tracks.length!=3 || missions.length<12 || missions.length>150) {
      throw const FormatException('Invalid track or mission count');
    }
    final ids=<String>{};
    final terms=<String>{};
    final trackIds=tracks.map((t)=>t.id).toSet();
    for (var i=0;i<missions.length;i++) {
      final m=missions[i];
      if (!ids.add(m.id) || !trackIds.contains(m.level)) {
        throw FormatException('Invalid mission id or track: '+m.id);
      }
      if (i<12 && m.level!=tracks[i~/4].id) {
        throw const FormatException('First 12 missions must be ordered by track');
      }
      if (m.words.length!=4 || m.words.any((w)=>w.term.length<3)) {
        throw const FormatException('Each starter mission needs four valid vocabulary words');
      }
      for (final w in m.words) {
        if (!terms.add(w.term)) throw FormatException('Repeated word: '+w.term);
        if (w.meaning.isEmpty || w.context.isEmpty ||
            w.synonym.isEmpty || w.antonym.isEmpty) {
          throw FormatException('Incomplete word: '+w.term);
        }
      }
      if (m.sentence.toLowerCase().split(RegExp(r'\s+')).length<5 ||
          !m.sentence.endsWith('.') ||
          m.sentencePrompt.isEmpty ||
          m.sentenceAlternatives.length>3 ||
          m.pattern.options.length!=4 ||
          m.transfer.options.length!=4 ||
          m.pattern.answer<0 || m.pattern.answer>=4 ||
          m.transfer.answer<0 || m.transfer.answer>=4) {
        throw FormatException('Invalid mission challenges: '+m.id);
      }
    }
    return OlderCourse(version:raw['content_version'] as String,tracks:tracks,missions:missions);
  }
  List<StoryMission> forTrack(String id)=>missions.where((m)=>m.level==id).toList(growable:false);
}

class LearningTrack {
  const LearningTrack(this.id,this.title,this.ageHint,this.description,this.hex);
  final String id,title,ageHint,description,hex;
  factory LearningTrack.fromJson(Map<String,dynamic> map)=>LearningTrack(
    map['id'] as String,map['title'] as String,map['age_hint'] as String,
    map['description'] as String,map['color'] as String);
}

class StoryWord {
  const StoryWord(this.term,this.meaning,this.context,this.synonym,this.antonym);
  final String term,meaning,context,synonym,antonym;
  factory StoryWord.fromJson(Map<String,dynamic> map)=>StoryWord(
    map['term'] as String,map['meaning'] as String,
    map['context'] as String,map['synonym'] as String,
    map['antonym'] as String);
}

class ChoiceChallenge {
  const ChoiceChallenge(this.question,this.options,this.answer,this.explain);
  final String question,explain;
  final List<String> options;
  final int answer;
  factory ChoiceChallenge.fromJson(Map<String,dynamic> map)=>ChoiceChallenge(
    map['question'] as String,
    List<String>.from(map['options'] as List),
    map['answer'] as int,map['explain'] as String);
}

class StoryMission {
  const StoryMission({
    required this.id,required this.level,required this.title,
    required this.scene,required this.subtitle,required this.goal,
    required this.story,required this.words,required this.sentence,
    required this.sentencePrompt,required this.sentenceAlternatives,
    required this.consequence,required this.wrongConsequence,
    required this.pattern,required this.transfer,required this.order,
  });
  final String id,level,title,scene,subtitle,goal,story;
  final List<StoryWord> words;
  final String sentence,sentencePrompt;
  final List<String> sentenceAlternatives;
  final String consequence,wrongConsequence;
  final ChoiceChallenge pattern,transfer;
  final int order;

  factory StoryMission.fromJson(Map<String,dynamic> map)=>StoryMission(
    id:map['id'] as String,level:map['level'] as String,
    title:map['title'] as String,scene:map['scene'] as String,
    subtitle:map['subtitle'] as String,goal:map['goal'] as String,
    story:map['story'] as String,
    words:(map['words'] as List).map((w)=>StoryWord.fromJson(w as Map<String,dynamic>)).toList(growable:false),
    sentence:map['sentence'] as String,
    sentencePrompt:map['sentencePrompt'] as String,
    sentenceAlternatives:List<String>.from(map['sentenceAlternatives'] as List),
    consequence:map['consequence'] as String,
    wrongConsequence:map['wrongConsequence'] as String,
    pattern:ChoiceChallenge.fromJson(map['pattern'] as Map<String,dynamic>),
    transfer:ChoiceChallenge.fromJson(map['transfer'] as Map<String,dynamic>),
    order:map['order'] as int);

  List<String> get sentenceTokens=>sentence
    .replaceAll(RegExp(r'[.!?]'), '').split(RegExp(r'\s+'));

  /// Specific teacher-reviewed word-order answers only. Not unrestricted AI.
  bool acceptsSentence(String candidate) {
    String normalize(String value)=>value.toLowerCase().trim()
      .replaceAll(RegExp(r'[.!?,]'), '')
      .replaceAll(RegExp(r'\s+'),' ');
    final result=normalize(candidate);
    return result==normalize(sentence) ||
      sentenceAlternatives.any((v)=>normalize(v)==result);
  }
}

enum OlderStep { story, detective, relation, sentence, pattern, transfer, finish }

class MissionScore {
  const MissionScore(this.correct,this.attempts);
  final int correct,attempts;
  double get accuracy=>attempts==0?1.0:correct/attempts;
  int get stars=>accuracy>=.9?3:accuracy>=.65?2:1;
}
