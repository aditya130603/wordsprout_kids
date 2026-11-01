import 'dart:convert';
import 'package:flutter/services.dart';

/// Data-only word content. The first 130 IDs and positions are permanent so
/// existing learners never lose progress when a content pack is published.
class Word {
  const Word({
    required this.id,
    required this.letter,
    required this.name,
    required this.image,
    required this.facts,
    required this.pronunciation,
    this.animationFrames = const [],
  });
  final String id;
  final String letter;
  final String name;
  final String image;
  final List<String> facts;
  final String pronunciation;
  final List<String> animationFrames;

  factory Word.fromJson(Map<String, dynamic> json) => Word(
    id: json['id'] as String,
    letter: json['letter'] as String,
    name: json['word'] as String,
    image: json['image'] as String,
    facts: List<String>.from(json['facts'] as List),
    pronunciation: json['pronunciation'] as String,
    animationFrames: List<String>.from(json['animation_frames'] as List? ?? []),
  );

  String get spelling => name.toUpperCase().replaceAll(RegExp('[^A-Z]'), '');
  bool get isDownloadedImage => image.startsWith('media/');
}

class Curriculum {
  const Curriculum(this.version, this.words);
  final String version;
  final List<Word> words;
  static const starterCount = 130;

  static Future<Curriculum> load() async {
    final raw = await rootBundle.loadString('assets/content/words_v1.json');
    return Curriculum.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  factory Curriculum.fromJson(Map<String, dynamic> json) {
    if (json['schema_version'] != 1) throw const FormatException('Unsupported curriculum schema');
    final raw = json['words'];
    if (raw is! List) throw const FormatException('words must be a list');
    final entries = raw.map((e) {
      if (e is! Map<String, dynamic>) throw const FormatException('Invalid word entry');
      return Word.fromJson(e);
    }).toList(growable: false);
    if (entries.length < starterCount || entries.length > 1000) {
      throw FormatException('Expected between 130 and 1000 words, got '+entries.length.toString());
    }
    final ids = <String>{};
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (!ids.add(entry.id)) throw FormatException('Duplicate ID '+entry.id);
      if (entry.id.length > 100 || !RegExp(r'^[a-z0-9_]+$').hasMatch(entry.id)) {
        throw FormatException('Invalid word ID '+entry.id);
      }
      if (entry.letter.length != 1 || !RegExp(r'^[A-Z]$').hasMatch(entry.letter)) {
        throw FormatException('Invalid letter for '+entry.name);
      }
      if (i < starterCount && entry.letter != String.fromCharCode(65 + i ~/ 5)) {
        throw FormatException('Starter order cannot change: '+entry.name);
      }
      if (entry.name.length < 2 || entry.name.length > 32 ||
          !RegExp(r"^[A-Z][A-Z -]*$").hasMatch(entry.name)) {
        throw FormatException('Invalid word '+entry.name);
      }
      if (entry.facts.length != 3 ||
          entry.facts.any((f) => f.trim().isEmpty || f.length > 180)) {
        throw FormatException(entry.name+' needs exactly three short facts');
      }
      if (entry.pronunciation.trim().isEmpty || entry.pronunciation.length > 90) {
        throw FormatException('Missing pronunciation for '+entry.name);
      }
      if (entry.spelling.length < 2 || entry.spelling.length > 24) {
        throw FormatException('Invalid spelling for '+entry.name);
      }
      if (i < starterCount && entry.letter == 'X' && !entry.spelling.contains('X')) {
        throw FormatException('Letter X word must contain X');
      }
      if (!_allowedImage(entry.image)) throw FormatException('Invalid image for '+entry.name);
      if (entry.animationFrames.length > 24 ||
          entry.animationFrames.any((f) => !RegExp(r'^media/[a-z0-9_-]+/frame_[0-9]{5}[.]png$').hasMatch(f))) {
        throw FormatException('Invalid animation for '+entry.name);
      }
    }
    return Curriculum(json['content_version'] as String, entries);
  }

  static bool _allowedImage(String path) =>
      RegExp(r'^assets/words/[a-z0-9_-]+[.]svg$').hasMatch(path) ||
      RegExp(r'^media/[a-z0-9_-]+/still[.]png$').hasMatch(path);

  /// Existing starter positions and IDs must survive every online update.
  void assertCompatibleWith(Curriculum bundled) {
    for (var i = 0; i < starterCount; i++) {
      if (words[i].id != bundled.words[i].id ||
          words[i].spelling != bundled.words[i].spelling) {
        throw FormatException('Starter word IDs and spellings must remain stable at index '+i.toString());
      }
    }
  }

  List<Word> forLetter(int index) => words.sublist(index*5,index*5+5);
  Word at(int letter, int position) => words[letter*5+position];
  List<Word> get bonusWords => words.skip(starterCount).toList(growable:false);
}
