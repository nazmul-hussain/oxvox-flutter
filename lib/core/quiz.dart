import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/word.dart';

/// Port of web components/Quiz.js question building and utils/quizCount.js.
final _rng = Random();

List<T> _shuffled<T>(List<T> list) => [...list]..shuffle(_rng);

/// Share of each session that is fill-the-gap (web GAP_SHARE).
const gapShare = 0.25;

class QuizQuestion {
  final Word word;

  /// bn2en: shows Bangla, asks English. en2bn: shows English, asks Bangla.
  /// gap: shows an example sentence with a blank, asks the English word.
  final String dir;
  final String prompt;
  final String answer;
  final List<String> options;
  const QuizQuestion({
    required this.word,
    required this.dir,
    required this.prompt,
    required this.answer,
    required this.options,
  });
}

String _escapeRe(String s) =>
    s.replaceAllMapped(RegExp(r'[.*+?^${}()|[\]\\]'), (m) => '\\${m[0]}');

RegExp _wordRe(String word) =>
    RegExp('\\b${_escapeRe(word)}\\b', caseSensitive: false);

String? _posOf(Word w) => w.pos.isEmpty ? null : w.pos.first;

/// An example sentence containing the word, with every occurrence blanked.
({String original, String blanked})? _gapSentence(Word w) {
  final re = _wordRe(w.word);
  for (final s in w.examples) {
    if (re.hasMatch(s)) {
      return (original: s, blanked: s.replaceAll(re, '______'));
    }
  }
  return null;
}

/// Three English distractors: same part of speech first, never a word
/// already in the sentence.
List<String> _gapDistractors(Word w, String sentence, List<Word> distractPool) {
  final cands = distractPool.where(
    (x) =>
        x.id != w.id &&
        x.word.toLowerCase() != w.word.toLowerCase() &&
        !_wordRe(x.word).hasMatch(sentence),
  );
  final pos = _posOf(w);
  final same = _shuffled(
    cands.where((x) => _posOf(x) != null && _posOf(x) == pos).toList(),
  );
  final rest = _shuffled(cands.where((x) => _posOf(x) != pos).toList());
  final seen = {w.word.toLowerCase()};
  final picked = <String>[];
  for (final x in [...same, ...rest]) {
    final k = x.word.toLowerCase();
    if (seen.contains(k)) continue;
    seen.add(k);
    picked.add(x.word);
    if (picked.length == 3) break;
  }
  return picked;
}

/// Meaning question with mixed direction (web meaningQuestion).
QuizQuestion _meaningQuestion(Word w, List<Word> distractPool) {
  final bn2en = _rng.nextBool();
  String key(Word x) => bn2en ? x.word : x.meaning;
  final answer = key(w);
  final distractors = _shuffled(
    distractPool.where((x) => x.id != w.id && key(x) != answer).toList(),
  ).take(3).map(key).toList();
  return QuizQuestion(
    word: w,
    dir: bn2en ? 'bn2en' : 'en2bn',
    prompt: bn2en ? w.meaning : w.word,
    answer: answer,
    options: _shuffled([answer, ...distractors]),
  );
}

/// Mixed session: about 25% fill-the-gap, the rest meaning questions.
/// Words are never repeated (web buildQuestions).
List<QuizQuestion> buildQuizQuestions(
  List<Word> pool,
  int count,
  List<Word> distractPool,
) {
  final ordered = _shuffled(pool);
  final gapTarget = (count * gapShare).round();
  final gaps = <QuizQuestion>[];
  final used = <String>{};
  for (final w in ordered) {
    if (gaps.length >= gapTarget) break;
    final sentence = _gapSentence(w);
    if (sentence == null) continue;
    final options = _gapDistractors(w, sentence.original, distractPool);
    if (options.length < 3) continue;
    gaps.add(
      QuizQuestion(
        word: w,
        dir: 'gap',
        prompt: sentence.blanked,
        answer: w.word,
        options: _shuffled([w.word, ...options]),
      ),
    );
    used.add(w.id);
  }
  final meanings = <QuizQuestion>[];
  for (final w in ordered) {
    if (gaps.length + meanings.length >= count) break;
    if (used.contains(w.id)) continue;
    meanings.add(_meaningQuestion(w, distractPool));
  }
  return _shuffled([...gaps, ...meanings]);
}

/// Web MIN_Q: 1 in development, 10 in release. Max is the pool size.
int quizMinCount(int poolSize) => min(kDebugMode ? 1 : 10, poolSize);

/// Web defaultQuizCount: 30% of the pool, kept within the limits.
int defaultQuizCount(int poolSize) {
  final lo = quizMinCount(poolSize);
  return min(poolSize, max(lo, (poolSize * 0.3).round()));
}
