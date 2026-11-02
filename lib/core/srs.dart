/// SM-2 style spaced repetition, same rules as the web app's utils/srs.js.
/// Ratings: again=1, hard=3, good=4, easy=5.
class SrsCard {
  final double ease;
  final int interval;
  final int reps;
  final String due; // YYYY-MM-DD
  final String? lastReviewed;

  const SrsCard({this.ease = 2.5, this.interval = 0, this.reps = 0, required this.due, this.lastReviewed});

  factory SrsCard.fromJson(Map<String, dynamic> j) => SrsCard(
        ease: (j['ease'] as num).toDouble(),
        interval: j['interval'] as int,
        reps: j['reps'] as int,
        due: j['due'] as String,
        lastReviewed: j['lastReviewed'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'ease': ease,
        'interval': interval,
        'reps': reps,
        'due': due,
        'lastReviewed': lastReviewed,
      };
}

enum Rating { again, hard, good, easy }

const _quality = {Rating.again: 1, Rating.hard: 3, Rating.good: 4, Rating.easy: 5};

String fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String todayStr() => fmtDate(DateTime.now());

bool isDue(SrsCard? card) => card == null || card.due.compareTo(todayStr()) <= 0;

SrsCard reviewCard(SrsCard? card, Rating rating) {
  final q = _quality[rating]!;
  var ease = card?.ease ?? 2.5;
  var interval = card?.interval ?? 0;
  var reps = card?.reps ?? 0;

  if (q < 3) {
    reps = 0;
    interval = 1;
  } else {
    reps += 1;
    if (reps == 1) {
      interval = 1;
    } else if (reps == 2) {
      interval = 3;
    } else {
      interval = (interval * ease).round();
    }
    final next = ease + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
    ease = next < 1.3 ? 1.3 : next;
  }

  final due = DateTime.now().add(Duration(days: interval));
  return SrsCard(
    ease: ease,
    interval: interval,
    reps: reps,
    due: fmtDate(due),
    lastReviewed: todayStr(),
  );
}
