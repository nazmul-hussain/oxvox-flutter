import 'package:flutter_test/flutter_test.dart';
import 'package:oxvox/core/reminder_plan.dart';

NudgeInput input({
  DateTime? now,
  Set<String> studied = const {},
  int streak = 0,
  int missed = 0,
  String? listen,
  String? ear,
  int unanswered = 0,
}) => NudgeInput(
  now: now ?? DateTime(2026, 11, 3, 15),
  studyDays: studied,
  streak: streak,
  missedCount: missed,
  lastListenDate: listen,
  lastEarNudge: ear,
  unansweredInRow: unanswered,
  studyHour: 21,
  studyMinute: 0,
);

void main() {
  test('studied today: no nudges today', () {
    final p = planNudges(input(studied: {'2026-11-03'}, streak: 5, missed: 2));
    expect(p.where((n) => n.at.day == 3), isEmpty);
  });

  test('streak at risk tonight at 20:30 when not studied', () {
    final p = planNudges(input(studied: {'2026-11-02'}, streak: 4));
    final s = p.firstWhere((n) => n.kind == NudgeKind.streak);
    expect(s.at, DateTime(2026, 11, 3, 20, 30));
    expect(s.body, contains('4-day streak'));
  });

  test('no streak reminder for a streak under 2 days', () {
    final p = planNudges(input(streak: 1));
    expect(p.any((n) => n.kind == NudgeKind.streak), isFalse);
  });

  test('at most one nudge per day', () {
    final p = planNudges(input(streak: 3, missed: 2, listen: '2026-10-20'));
    final days = p.map((n) => n.at.day).toList();
    expect(days.toSet().length, days.length);
  });

  test('ear training waits 3 days between nudges', () {
    final p = planNudges(input(listen: '2026-10-20', ear: '2026-11-02'));
    expect(p.any((n) => n.kind == NudgeKind.ear), isFalse);
  });

  test('comeback after 2+ days away, stops after two', () {
    final p = planNudges(input(studied: {'2026-10-30'}));
    expect(p.where((n) => n.kind == NudgeKind.comeback).length, 2);
  });

  test('after 3 unanswered nudges only the streak reminder remains', () {
    final p = planNudges(input(streak: 3, missed: 5, unanswered: 3));
    expect(p.every((n) => n.kind == NudgeKind.streak), isTrue);
  });
}
