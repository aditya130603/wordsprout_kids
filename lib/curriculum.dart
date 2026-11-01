import 'dart:convert';
import 'package:flutter/services.dart';

/// Versioned curriculum, separate from the Flutter interface.
class Word {
  const Word({
    required this.id,
    required this.letter,
    required this.name,
    required this.image,
    required this.facts,
    required this.pronunciation,
  });
  final String id;
  final String letter;
  final String name;
  final String image;
  final List<String> facts;
  final String pronunciation;

  factory Word.fromJson(Map<String, dynamic> json) => Word(
    id: json['id'] as String,
    letter: json['letter'] as String,
    name: json['word'] as String,
    image: json['image'] as String,
    facts: List<String>.from(json['facts'] as List),
    pronunciation: json['pronunciation'] as String,
  );

  String get spelling => name.replaceAll(RegExp('[^A-Z]'), '');
}

class Curriculum {
  const Curriculum(this.version, this.words);
  final String version;
  final List<Word> words;

  static Future<Curriculum> load() async {
    final raw = await rootBundle.loadString('assets/content/words_v1.json');
    return Curriculum.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  factory Curriculum.fromJson(Map<String, dynamic> json) {
    final entries = (json['words'] as List)
        .map((v) => Word.fromJson(v as Map<String, dynamic>)).toList(growable: false);
    if (entries.length != 130) {
      throw FormatException('Expected 130 vocabulary entries; got ' + entries.length.toString());
    }
    final ids = <String>{};
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (!ids.add(entry.id)) throw FormatException('Duplicate ID ' + entry.id);
      if (entry.letter != String.fromCharCode(65 + i ~/ 5)) {
        throw FormatException('Curriculum letter mismatch: ' + entry.name);
      }
      if (entry.facts.length != 3 || entry.facts.any((f) => f.trim().isEmpty)) {
        throw FormatException(entry.name + ' needs exactly three facts');
      }
      if (entry.spelling.length < 2 || !entry.image.endsWith('.svg')) {
        throw FormatException('Invalid spelling / asset for ' + entry.name);
      }
      if (entry.letter == 'X' && !entry.spelling.contains('X')) {
        throw FormatException('X lesson needs a word containing X');
      }
    }
    return Curriculum(json['content_version'] as String, entries);
  }

  List<Word> forLetter(int index) =>
      words.sublist(index * 5, index * 5 + 5);
  Word at(int letter, int position) => words[letter * 5 + position];
}
