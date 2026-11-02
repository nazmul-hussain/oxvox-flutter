class Word {
  final String id; // web: wid (lowercase headword)
  final String word;
  final List<String> pos;
  final String cefr;
  final String meaning;
  final String type;
  final String example;
  final List<String> examples;
  final List<String> synonyms;
  final List<String> antonyms;
  final String? usage;
  final String? scenario;
  final String? intent;
  final String? story;

  const Word({
    required this.id,
    required this.word,
    required this.pos,
    required this.cefr,
    required this.meaning,
    required this.type,
    required this.example,
    required this.examples,
    required this.synonyms,
    required this.antonyms,
    this.usage,
    this.scenario,
    this.intent,
    this.story,
  });

  factory Word.fromJson(Map<String, dynamic> j) => Word(
    id: (j['wid'] ?? j['id'] ?? j['word']).toString().toLowerCase(),
    word: j['word'] as String,
    pos: _strList(j['pos']),
    cefr: (j['cefr'] ?? '') as String,
    meaning: (j['meaning'] ?? '') as String,
    type: (j['type'] ?? '') as String,
    example: (j['example'] ?? '') as String,
    examples: _strList(j['examples']),
    synonyms: _strList(j['synonyms']),
    antonyms: _strList(j['antonyms']),
    usage: _text(j['usage']),
    scenario: j['scenario'] as String?,
    intent: j['intent'] as String?,
    story: j['story'] as String?,
  );
}

/// Some web entries store text as a list (for example usage); join them.
String? _text(dynamic v) =>
    v == null ? null : (v is List ? v.join(' ') : v.toString());

List<String> _strList(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : const [];

class ListeningLesson {
  final String id;
  final int number;
  final String title;
  final String audio;
  final String voice;
  final List<String> lines;
  final double duration;

  const ListeningLesson({
    required this.id,
    required this.number,
    required this.title,
    required this.audio,
    required this.voice,
    required this.lines,
    required this.duration,
  });

  factory ListeningLesson.fromJson(Map<String, dynamic> j) => ListeningLesson(
    id: j['id'] as String,
    number: j['num'] as int,
    title: j['title'] as String,
    audio: (j['audio'] ?? '') as String,
    voice: (j['voice'] ?? '') as String,
    lines: _strList(j['lines']),
    duration: (j['duration'] as num?)?.toDouble() ?? 0,
  );
}
