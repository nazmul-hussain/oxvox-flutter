import 'dart:math';

import '../models/word.dart';
import 'plan.dart';

/// Port of web utils/placement.js: a 40-question level test across A1–C2.
const placementSize = 40;
const passShare = 0.6;
final _rng = Random();

List<T> _shuffled<T>(List<T> list) => [...list]..shuffle(_rng);

class PlacementOption {
  final String wid;
  final String label;
  const PlacementOption(this.wid, this.label);
}

class PlacementQuestion {
  final String wid;
  final String level;
  final String dir; // bn-en or en-bn
  final String prompt;
  final List<PlacementOption> options;
  const PlacementQuestion({
    required this.wid,
    required this.level,
    required this.dir,
    required this.prompt,
    required this.options,
  });
}

/// Builds questions per level, skipping words already asked (used = word ids).
List<PlacementQuestion> buildPlacement(
  Map<String, List<Word>> pools,
  List<String> used,
  String Function(Word) meaningOf,
) {
  final usedSet = used.toSet();
  final base = placementSize ~/ cefrLevels.length;
  final extra = placementSize % cefrLevels.length;
  final questions = <PlacementQuestion>[];
  for (var li = 0; li < cefrLevels.length; li++) {
    final c = cefrLevels[li];
    final all = pools[c] ?? const <Word>[];
    var pool = all.where((w) => !usedSet.contains(w.id)).toList();
    if (pool.length < 10) pool = all; // all asked before: reuse the level
    if (pool.isEmpty) continue;
    final count = base + (li < extra ? 1 : 0);
    for (final w in _shuffled(pool).take(count)) {
      final bn = _rng.nextBool();
      final dir = bn ? 'bn-en' : 'en-bn';
      final distractors = _shuffled(pool.where((x) => x.id != w.id).toList())
          .take(3);
      final options = _shuffled([w, ...distractors])
          .map(
            (o) => PlacementOption(
              o.id,
              dir == 'bn-en' ? o.word : meaningOf(o),
            ),
          )
          .toList();
      questions.add(
        PlacementQuestion(
          wid: w.id,
          level: c,
          dir: dir,
          prompt: dir == 'bn-en' ? meaningOf(w) : w.word,
          options: options,
        ),
      );
    }
  }
  return _shuffled(questions);
}

class PlacementStat {
  int ok = 0;
  int total = 0;
}

/// Highest level reached counting up from A1: a level counts at 60% correct.
({String level, Map<String, PlacementStat> stats}) placementResult(
  List<PlacementQuestion> questions,
  List<String> answers,
) {
  final stats = {for (final c in cefrLevels) c: PlacementStat()};
  for (var i = 0; i < questions.length; i++) {
    final st = stats[questions[i].level]!;
    st.total += 1;
    if (i < answers.length && answers[i] == questions[i].wid) st.ok += 1;
  }
  var level = cefrLevels.first;
  for (final c in cefrLevels) {
    final st = stats[c]!;
    if (st.total > 0 && st.ok / st.total >= passShare) {
      level = c;
    } else {
      break;
    }
  }
  return (level: level, stats: stats);
}
