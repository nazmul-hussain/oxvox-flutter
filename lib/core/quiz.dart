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

/// First listed part of speech, or null when the word has none.
String? _posOf(Word w) {
  final pos = w.pos.isEmpty ? '' : w.pos.first.trim();
  return pos.isEmpty ? null : pos;
}

String _lower(String s) => s.trim().toLowerCase();

/// True when a and b are listed as synonyms (either direction): both could fit
/// the same gap.
bool _related(Word a, Word b) {
  final aw = _lower(a.word);
  final bw = _lower(b.word);
  return a.synonyms.any((s) => _lower(s) == bw) ||
      b.synonyms.any((s) => _lower(s) == aw);
}

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

/// Three English distractors that cannot also fit the gap, so there is only one
/// right answer. Never a synonym of the answer, never a word already in the
/// sentence, and words of a different part of speech come first (they do not
/// fit grammatically). Same part of speech is a last resort.
List<String> _gapDistractors(Word w, String sentence, List<Word> distractPool) {
  final answer = _lower(w.word);
  final cands = distractPool.where((x) {
    final word = _lower(x.word);
    return x.id != w.id &&
        word.isNotEmpty &&
        word != answer &&
        !_related(w, x) &&
        !_wordRe(x.word).hasMatch(sentence);
  }).toList();
  final pos = _posOf(w);
  bool otherPos(Word x) {
    final xp = _posOf(x);
    return pos != null && xp != null && xp != pos;
  }

  final other = _shuffled(cands.where(otherPos).toList());
  final rest = _shuffled(cands.where((x) => !otherPos(x)).toList());
  final seen = {answer};
  final picked = <String>[];
  for (final x in [...other, ...rest]) {
    if (!seen.add(x.word.toLowerCase())) continue;
    picked.add(x.word);
    if (picked.length == 3) break;
  }
  return picked;
}

/// Fill-the-gap question for a word. Null when the word has no example sentence
/// to blank or the pool cannot give three distractors.
QuizQuestion? _gapQuestion(Word w, List<Word> distractPool) {
  if (w.word.trim().isEmpty) return null;
  final sentence = _gapSentence(w);
  if (sentence == null) return null;
  final options = _gapDistractors(w, sentence.original, distractPool);
  if (options.length < 3) return null;
  return QuizQuestion(
    word: w,
    dir: 'gap',
    prompt: sentence.blanked,
    answer: w.word,
    options: _shuffled([w.word, ...options]),
  );
}

/// Meaning question with mixed direction (web meaningQuestion). Null when the
/// word has no meaning text or the pool cannot give three distractors, so an
/// empty question is skipped rather than shown.
QuizQuestion? _meaningQuestion(
  Word w,
  List<Word> distractPool,
  String Function(Word) meaningOf,
) {
  final bn2en = _rng.nextBool();
  String key(Word x) => (bn2en ? x.word : meaningOf(x)).trim();
  final answer = key(w);
  final prompt = (bn2en ? meaningOf(w) : w.word).trim();
  if (answer.isEmpty || prompt.isEmpty) return null;
  final ownMeaning = _lower(meaningOf(w));
  // Distractors: non-empty, unique, not a synonym and not sharing the answer's
  // meaning (else two options are right).
  final seen = {_lower(answer)};
  final distractors = <String>[];
  for (final x in _shuffled(distractPool)) {
    if (x.id == w.id) continue;
    final k = key(x);
    if (k.isEmpty ||
        seen.contains(_lower(k)) ||
        _related(w, x) ||
        _lower(meaningOf(x)) == ownMeaning) {
      continue;
    }
    seen.add(_lower(k));
    distractors.add(k);
    if (distractors.length == 3) break;
  }
  if (distractors.length < 3) return null;
  return QuizQuestion(
    word: w,
    dir: bn2en ? 'bn2en' : 'en2bn',
    prompt: prompt,
    answer: answer,
    options: _shuffled([answer, ...distractors]),
  );
}

/// Mixed session: about 25% fill-the-gap, the rest meaning questions.
/// Words are never repeated (web buildQuestions). A word that cannot make a
/// usable question is skipped, so the list can be shorter than [count].
List<QuizQuestion> buildQuizQuestions(
  List<Word> pool,
  int count,
  List<Word> distractPool,
  String Function(Word) meaningOf,
) {
  final ordered = _shuffled(pool);
  final gapTarget = (count * gapShare).round();
  final gaps = <QuizQuestion>[];
  final meanings = <QuizQuestion>[];
  final used = <String>{};
  for (final w in ordered) {
    if (gaps.length >= gapTarget) break;
    if (used.contains(w.id)) continue;
    final q = _gapQuestion(w, distractPool);
    if (q == null) continue;
    gaps.add(q);
    used.add(w.id);
  }
  for (final w in ordered) {
    if (gaps.length + meanings.length >= count) break;
    if (used.contains(w.id)) continue;
    final q = _meaningQuestion(w, distractPool, meaningOf);
    if (q == null) continue;
    meanings.add(q);
    used.add(w.id);
  }
  // Top up with gap questions if some words had no usable meaning question.
  for (final w in ordered) {
    if (gaps.length + meanings.length >= count) break;
    if (used.contains(w.id)) continue;
    final q = _gapQuestion(w, distractPool);
    if (q == null) continue;
    gaps.add(q);
    used.add(w.id);
  }
  return _shuffled([...gaps, ...meanings]);
}

/// Web MIN_Q: 1 in development, 10 in release. Max is the pool size.
int quizMinCount(int poolSize) => min(kDebugMode ? 1 : 10, poolSize);

/// Web defaultQuizCount: 50% of the pool, kept within the limits.
int defaultQuizCount(int poolSize) {
  final lo = quizMinCount(poolSize);
  return min(poolSize, max(lo, (poolSize * 0.5).round()));
}
