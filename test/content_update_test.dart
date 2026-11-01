import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordsprout_kids/curriculum.dart';
import 'package:wordsprout_kids/content_store.dart';

void main() {
  final baseline = jsonDecode(
    File('assets/content/words_v1.json').readAsStringSync()) as Map<String,dynamic>;

  test('can publish corrections to facts and artwork without renumbering progress', () {
    final revised = jsonDecode(jsonEncode(baseline)) as Map<String,dynamic>;
    revised['content_version']='2026.11.02.test';
    final words = revised['words'] as List;
    (words[0] as Map<String,dynamic>)['facts']=[
      'Ants are insects.','Ants have six legs.','Many ants live in colonies.'
    ];
    (words[0] as Map<String,dynamic>)['image']='media/ant/still.png';
    (words[0] as Map<String,dynamic>)['animation_frames']=[
      'media/ant/frame_00000.png','media/ant/frame_00007.png'
    ];
    final candidate=Curriculum.fromJson(revised);
    expect(candidate.words.first.image,'media/ant/still.png');
    expect(candidate.words.first.animationFrames.length,2);
    candidate.assertCompatibleWith(Curriculum.fromJson(baseline));
  });

  test('supports additional bonus words without disturbing 130 core positions', () {
    final revised=jsonDecode(jsonEncode(baseline)) as Map<String,dynamic>;
    (revised['words'] as List).add({
      'id':'en_bonus_bear_001','letter':'B','word':'BEAR',
      'image':'media/bear/still.png',
      'facts':['Bears have fur.','Some bears eat fish.','Bears can smell well.'],
      'pronunciation':'BEAR','animation_frames':['media/bear/frame_00007.png'],
    });
    final catalog=Curriculum.fromJson(revised);
    expect(catalog.words.length,131);
    expect(catalog.bonusWords.single.name,'BEAR');
    catalog.assertCompatibleWith(Curriculum.fromJson(baseline));
  });

  test('rejects silent starter word replacement', () {
    final bad=jsonDecode(jsonEncode(baseline)) as Map<String,dynamic>;
    (bad['words'] as List)[0]['id']='en_a_other_001';
    final candidate=Curriculum.fromJson(bad);
    expect(()=>candidate.assertCompatibleWith(Curriculum.fromJson(baseline)),
      throwsFormatException);
  });

  test('blocks arbitrary local paths or remote code in a word entry', () {
    final bad=jsonDecode(jsonEncode(baseline)) as Map<String,dynamic>;
    (bad['words'] as List)[0]['image']='../../lib/main.dart';
    expect(()=>Curriculum.fromJson(bad),throwsFormatException);
  });

  test('accepts same-host HTTPS manifest with bounded download size', () {
    final offer=PackOffer.fromJson({
      'schema_version':1,
      'content_version':'2026.11.02.test.1',
      'pack_url':'wordsprout_pack.zip',
      'size_bytes':12000,
      'sha256':'a'*64,
    },Uri.parse('https://content.example.com/wordsprout/manifest.json'));
    expect(offer.url.toString(),
      'https://content.example.com/wordsprout/wordsprout_pack.zip');
  });

  test('rejects cross-host pack URLs and excessive media payloads', () {
    final base={
      'schema_version':1,'content_version':'1',
      'pack_url':'https://evil.example/pack.zip',
      'size_bytes':1000,'sha256':'f'*64,
    };
    expect(()=>PackOffer.fromJson(base,
      Uri.parse('https://content.example.com/manifest.json')),throwsFormatException);
    base['pack_url']='pack.zip';
    base['size_bytes']=100000000;
    expect(()=>PackOffer.fromJson(base,
      Uri.parse('https://content.example.com/manifest.json')),throwsFormatException);
  });
}
