import 'package:flutter/material.dart';

import '../models/word.dart';

/// Port of web utils/listening.js. Same day layout, quiz building, level estimate and artwork.
const listenQuestionTypes = ['main', 'detail', 'inference'];
// 30 days: days 1-10 have 4 lessons, days 11-30 have 3 (100 lessons in total).
final List<int> listenDaySizes = List<int>.generate(30, (i) => i < 10 ? 4 : 3);
final int listenDays = listenDaySizes.length;

/// Hand-written questions (web src/data/listening_questions_*.js), keyed by lesson id.
class ListeningQuestions {
  final Map<String, List<Map<String, dynamic>>> byLesson;
  const ListeningQuestions(this.byLesson);
}

class QuizOption {
  final String label;
  final bool correct;
  const QuizOption(this.label, this.correct);
}

class QuizQuestion {
  final String type;
  final String prompt;
  final List<QuizOption> options;
  const QuizQuestion(this.type, this.prompt, this.options);
}

class LevelEstimate {
  final int pct;
  final String level;
  final int lessons;
  final Map<String, List<int>> byType; // type -> [correct, total]
  const LevelEstimate(this.pct, this.level, this.lessons, this.byType);
}

int lessonDay(List<ListeningLesson> all, String id) {
  for (var d = 1; d <= listenDays; d++) {
    if (lessonsOfDay(all, d).any((l) => l.id == id)) return d;
  }
  return 1;
}

/// First lesson with no result yet, or null when all are done.
ListeningLesson? nextLesson(
  List<ListeningLesson> all,
  Map<String, dynamic> results,
) {
  for (final l in all) {
    if (results[l.id] == null) return l;
  }
  return null;
}

List<ListeningLesson> lessonsOfDay(List<ListeningLesson> all, int day) {
  var start = 0;
  for (var i = 0; i < day - 1; i++) {
    start += listenDaySizes[i];
  }
  final end = (start + listenDaySizes[day - 1]).clamp(0, all.length);
  return all.sublist(start.clamp(0, all.length), end);
}

ListeningLesson? getLesson(List<ListeningLesson> all, String id) {
  for (final l in all) {
    if (l.id == id) return l;
  }
  return null;
}

List<QuizQuestion> buildQuiz(ListeningQuestions qs, String lessonId) {
  final items = qs.byLesson[lessonId] ?? const [];
  return [
    for (final q in items)
      QuizQuestion(q['type'] as String, q['prompt'] as String, [
        for (var i = 0; i < (q['options'] as List).length; i++)
          QuizOption(
            (q['options'] as List)[i] as String,
            i == (q['answer'] as int),
          ),
      ]),
  ];
}

/// Estimate from completed lessons. Null until there are at least 3 results.
LevelEstimate? estimateLevel(
  ListeningQuestions qs,
  Map<String, dynamic> results,
) {
  final entries = results.entries
      .where((e) => e.value is Map && (e.value as Map)['correct'] is List)
      .toList();
  if (entries.length < 3) return null;
  final byType = {
    for (final t in listenQuestionTypes) t: [0, 0],
  };
  var correct = 0;
  var total = 0;
  for (final e in entries) {
    final quiz = buildQuiz(qs, e.key);
    final flags = ((e.value as Map)['correct'] as List).cast<bool>();
    for (var i = 0; i < flags.length; i++) {
      final type = i < quiz.length ? quiz[i].type : null;
      if (type == null || !byType.containsKey(type)) continue;
      total += 1;
      byType[type]![1] += 1;
      if (flags[i]) {
        correct += 1;
        byType[type]![0] += 1;
      }
    }
  }
  final pct = total > 0 ? (correct / total * 100).round() : 0;
  final level = pct >= 90
      ? 'C1'
      : pct >= 80
      ? 'B2'
      : pct >= 65
      ? 'B1'
      : pct >= 50
      ? 'A2'
      : 'A1';
  return LevelEstimate(pct, level, entries.length, byType);
}

/// Thumbnail artwork, same integer math as the web's thumbFor (seeded PRNG from the title).
class ListenThumb {
  final Color from;
  final Color to;
  final List<double> bars;
  const ListenThumb(this.from, this.to, this.bars);
}

const _mask = 0xFFFFFFFF;

int _imul(int a, int b) => ((a & _mask) * (b & _mask)) & _mask;

ListenThumb thumbFor(String title) {
  var h = 0;
  for (final c in title.codeUnits) {
    h = ((h * 31) + c) & _mask;
  }
  var a = h;
  double rnd() {
    a = (a + 0x6d2b79f5) & _mask;
    var t = a;
    t = _imul(t ^ (t >> 15), t | 1);
    t = (t ^ ((t + _imul(t ^ (t >> 7), t | 61)) & _mask)) & _mask;
    return ((t ^ (t >> 14)) & _mask) / 4294967296;
  }

  final hue = (rnd() * 360).floor();
  final bars = List<double>.generate(32, (_) => 0.2 + rnd() * 0.8);
  final from = HSLColor.fromAHSL(1, hue.toDouble(), 0.70, 0.58).toColor();
  final to = HSLColor.fromAHSL(
    1,
    ((hue + 50) % 360).toDouble(),
    0.75,
    0.42,
  ).toColor();
  return ListenThumb(from, to, bars);
}
