import 'package:flutter_test/flutter_test.dart';
import 'package:oxvox/core/quiz.dart';
import 'package:oxvox/models/word.dart';

Word w(
  String word, {
  String meaning = '',
  List<String> pos = const ['n.'],
  List<String> synonyms = const [],
  List<String> examples = const [],
}) => Word(
  id: word.toLowerCase(),
  word: word,
  pos: pos,
  cefr: 'A1',
  meaning: meaning,
  type: 'Speaking',
  example: examples.isEmpty ? '' : examples.first,
  examples: examples,
  synonyms: synonyms,
  antonyms: const [],
);

/// A pool big enough to always fill three distractor slots.
List<Word> filler(int n) => [
  for (var i = 0; i < n; i++)
    w('filler$i', meaning: 'অর্থ$i', examples: ['A filler$i sentence.']),
];

String meaningOf(Word x) => x.meaning;

void main() {
  test('default count is half the pool', () {
    expect(defaultQuizCount(40), 20);
    expect(defaultQuizCount(100), 50);
  });

  test('a word with no meaning never becomes a question', () {
    final blank = w('bank'); // no meaning, no examples
    final qs = buildQuizQuestions([blank], 5, filler(10), meaningOf);
    expect(qs, isEmpty);
  });

  test('no question has an empty prompt, answer or option', () {
    final pool = [
      w('flight', meaning: 'ফ্লাইট', examples: ['The flight was late.']),
      w('bank'),
      w('rest'),
      ...filler(12),
    ];
    final qs = buildQuizQuestions(pool, 12, pool, meaningOf);
    expect(qs, isNotEmpty);
    for (final q in qs) {
      expect(q.prompt.trim(), isNotEmpty);
      expect(q.answer.trim(), isNotEmpty);
      expect(q.options.length, 4);
      expect(q.options.where((o) => o.trim().isEmpty), isEmpty);
      expect(q.options.toSet().length, 4, reason: 'options are unique');
      expect(q.options, contains(q.answer));
    }
  });

  test('a synonym of the answer is never offered as an option', () {
    final answer = w(
      'big',
      meaning: 'বড়',
      pos: const ['adj.'],
      synonyms: const ['large'],
      examples: const ['It was a big house.'],
    );
    // 'large' lists nothing, so only the answer's own synonym list rules it out.
    final large = w('large', meaning: 'বিশাল', pos: const ['adj.']);
    // 'huge' names the answer, so the reverse direction has to rule it out too.
    final huge = w(
      'huge',
      meaning: 'প্রকাণ্ড',
      pos: const ['adj.'],
      synonyms: const ['big'],
    );
    final pool = [answer, large, huge, ...filler(12)];
    for (var i = 0; i < 40; i++) {
      final qs = buildQuizQuestions([answer], 1, pool, meaningOf);
      for (final q in qs) {
        expect(q.options, isNot(contains('large')));
        expect(q.options, isNot(contains('huge')));
      }
    }
  });

  test('two options never share the answer meaning', () {
    final answer = w('car', meaning: 'গাড়ি', examples: const ['A fast car.']);
    final twin = w('automobile', meaning: 'গাড়ি');
    final pool = [answer, twin, ...filler(12)];
    for (var i = 0; i < 40; i++) {
      for (final q in buildQuizQuestions([answer], 1, pool, meaningOf)) {
        final rightCount = q.options
            .where((o) => o == q.answer || (q.dir == 'en2bn' && o == 'গাড়ি'))
            .length;
        expect(rightCount, 1);
      }
    }
  });

  test('gap questions never use a word that is already in the sentence', () {
    final target = w(
      'flight',
      meaning: 'ফ্লাইট',
      examples: const ['The flight to Dhaka was delayed by fog.'],
    );
    final inSentence = w('fog', meaning: 'কুয়াশা');
    final pool = [target, inSentence, ...filler(12)];
    for (var i = 0; i < 40; i++) {
      for (final q in buildQuizQuestions([target], 4, pool, meaningOf)) {
        if (q.dir != 'gap') continue;
        expect(q.prompt, contains('______'));
        expect(q.options, isNot(contains('fog')));
      }
    }
  });

  test('words are never repeated across a session', () {
    final pool = [
      for (var i = 0; i < 20; i++)
        w(
          'word$i',
          meaning: 'অর্থ$i',
          examples: ['This is word$i in a sentence.'],
        ),
    ];
    final qs = buildQuizQuestions(pool, 20, pool, meaningOf);
    expect(qs.length, 20);
    expect(qs.map((q) => q.word.id).toSet().length, 20);
  });
}
