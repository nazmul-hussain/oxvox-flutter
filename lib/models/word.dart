class Word {
  final String id;
  final String word;
  final List<String> pos;
  final String cefr;
  final List<String> lists;
  final String meaning;
  final String example;
  final List<String> examples;
  final List<String> synonyms;
  final List<String> antonyms;
  final String? usage;
  final String? scenario;

  const Word({
    required this.id,
    required this.word,
    required this.pos,
    required this.cefr,
    required this.lists,
    required this.meaning,
    required this.example,
    required this.examples,
    required this.synonyms,
    required this.antonyms,
    this.usage,
    this.scenario,
  });

  factory Word.fromJson(Map<String, dynamic> j) => Word(
        id: j['id'] as String,
        word: j['word'] as String,
        pos: _strList(j['pos']),
        cefr: (j['cefr'] ?? '') as String,
        lists: _strList(j['lists']),
        meaning: (j['meaning'] ?? '') as String,
        example: (j['example'] ?? '') as String,
        examples: _strList(j['examples']),
        synonyms: _strList(j['synonyms']),
        antonyms: _strList(j['antonyms']),
        usage: j['usage'] as String?,
        scenario: j['scenario'] as String?,
      );
}

List<String> _strList(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : const [];

class ListeningLesson {
  final String id;
  final int number;
  final String title;
  final List<String> lines;
  final double duration;

  const ListeningLesson({
    required this.id,
    required this.number,
    required this.title,
    required this.lines,
    required this.duration,
  });

  factory ListeningLesson.fromJson(Map<String, dynamic> j) => ListeningLesson(
        id: j['id'] as String,
        number: j['num'] as int,
        title: j['title'] as String,
        lines: _strList(j['lines']),
        duration: (j['duration'] as num?)?.toDouble() ?? 0,
      );
}
