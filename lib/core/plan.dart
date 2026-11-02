import '../models/word.dart';

/// Port of web data/wordData.js plan helpers (pickLevels, interleave, buildPlan).
/// The ordered word lists per level set come from plan_index.json, exported from the web
/// levelWords(), so every level and topic choice gives the same plan as the web app.
const cefrLevels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
const defaultLevels = ['A2', 'B1', 'B2'];
const minPlanDays = 7;
const maxPlanDays = 365;
const defaultPlanDays = 30;

/// Web pickLevels: keep CEFR order, fall back to the default levels when none are chosen.
List<String> pickLevels(List<String> levels) {
  final set = levels.toSet();
  final picked = [
    for (final c in cefrLevels)
      if (set.contains(c)) c,
  ];
  return picked.isEmpty ? defaultLevels : picked;
}

/// Web interleave: keep Speaking/Listening (any word type) mixed within each day.
List<Word> _interleave(List<Word> list) {
  final groups = <String, List<Word>>{};
  for (final w in list) {
    groups.putIfAbsent(w.type, () => []).add(w);
  }
  final arrays = groups.values.toList();
  final out = <Word>[];
  for (var i = 0; out.length < list.length; i++) {
    for (final a in arrays) {
      if (i < a.length) out.add(a[i]);
    }
  }
  return out;
}

/// Web buildPlan: split the ordered list evenly over the chosen number of days.
Map<int, List<Word>> buildPlanDays(List<Word> words, int days) {
  final totalDays = words.isEmpty ? 1 : days.clamp(1, words.length).toInt();
  final out = <int, List<Word>>{};
  for (var d = 1; d <= totalDays; d++) {
    final start = ((d - 1) * words.length) ~/ totalDays;
    final end = (d * words.length) ~/ totalDays;
    out[d] = _interleave(words.sublist(start, end));
  }
  return out;
}

/// Words per day as "99" or "98–99" when the split is uneven (web perDayLabel).
String perDayLabel(Map<int, List<Word>> days) {
  if (days.isEmpty) return '0';
  final sizes = days.values.map((l) => l.length);
  final lo = sizes.reduce((a, b) => a < b ? a : b);
  final hi = sizes.reduce((a, b) => a > b ? a : b);
  return lo == hi ? '$lo' : '$lo–$hi';
}
