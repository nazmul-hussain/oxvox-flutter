import 'srs.dart';

/// Smart study reminders. Pure logic (no plugins), so it can be tested directly.
///
/// Rules (see the reminder plan):
/// - At most one notification per calendar day.
/// - Nothing on a day you already studied.
/// - Quiet hours: nothing before 8:00 or after 21:59 (all times below are inside that).
/// - After 3 nudges in a row that you did not answer, only the streak reminder is still sent.
enum NudgeKind { streak, missed, ear, comeback }

class NudgeMessage {
  final NudgeKind kind;
  final DateTime at;
  final String title;
  final String body;
  const NudgeMessage(this.kind, this.at, this.title, this.body);
}

class NudgeInput {
  final DateTime now;
  /// Days you studied, as yyyy-mm-dd.
  final Set<String> studyDays;
  final int streak;
  final int missedCount;
  /// Last day you listened to a conversation (yyyy-mm-dd), or null.
  final String? lastListenDate;
  /// Last day an ear-training reminder was planned (yyyy-mm-dd), or null.
  final String? lastEarNudge;
  final int unansweredInRow;
  /// Time of the first daily reminder from Settings; the streak reminder is 30 minutes before it.
  final int studyHour;
  final int studyMinute;

  const NudgeInput({
    required this.now,
    required this.studyDays,
    required this.streak,
    required this.missedCount,
    required this.lastListenDate,
    required this.lastEarNudge,
    required this.unansweredInRow,
    required this.studyHour,
    required this.studyMinute,
  });
}

DateTime _day(DateTime d, [int add = 0]) =>
    DateTime(d.year, d.month, d.day + add);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Whole days from [from] (yyyy-mm-dd) to [to] (a day).
int _daysSince(String from, DateTime to) {
  final p = from.split('-');
  final start = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  return _day(to).difference(start).inDays;
}

/// Plans the next week's nudges. Returns them in time order.
List<NudgeMessage> planNudges(NudgeInput i) {
  final today = _day(i.now);
  final studiedToday = i.studyDays.contains(fmtDate(today));
  final out = <NudgeMessage>[];

  bool taken(DateTime t) => out.any((n) => _sameDay(n.at, t));
  bool studiedOn(DateTime d) => i.studyDays.contains(fmtDate(d));
  DateTime at(int dayOffset, int h, int m) =>
      DateTime(today.year, today.month, today.day + dayOffset, h, m);

  // 1. Streak at risk: tonight only, 30 minutes before the daily reminder.
  final streakTime = at(0, i.studyHour, i.studyMinute)
      .subtract(const Duration(minutes: 30));
  if (!studiedToday && i.streak >= 2 && streakTime.isAfter(i.now)) {
    out.add(
      NudgeMessage(
        NudgeKind.streak,
        streakTime,
        'Keep your streak',
        'Your ${i.streak}-day streak ends tonight. One quick review keeps it alive.',
      ),
    );
  }

  // After 3 unanswered nudges, only the streak reminder is still allowed.
  if (i.unansweredInRow >= 3) return out;

  // 2. Missed words: 18:30 on the first day in the next two that is free.
  if (i.missedCount > 0) {
    for (var d = 0; d < 2; d++) {
      final t = at(d, 18, 30);
      if (t.isBefore(i.now) || studiedOn(t) || taken(t)) continue;
      out.add(
        NudgeMessage(
          NudgeKind.missed,
          t,
          'Missed words',
          '${i.missedCount} word${i.missedCount == 1 ? '' : 's'} need another look. Two minutes is enough.',
        ),
      );
      break;
    }
  }

  // 3. Ear training: when you have not listened for 2+ days, at most once every 3 days, 19:00.
  final listenGap = i.lastListenDate == null
      ? 99
      : _daysSince(i.lastListenDate!, today);
  final earGap = i.lastEarNudge == null
      ? 99
      : _daysSince(i.lastEarNudge!, today);
  if (listenGap >= 2 && earGap >= 3) {
    for (var d = 0; d < 2; d++) {
      final t = at(d, 19, 0);
      if (t.isBefore(i.now) || studiedOn(t) || taken(t)) continue;
      out.add(
        NudgeMessage(
          NudgeKind.ear,
          t,
          'Train your ear',
          'Listen to a short conversation to train your ear.',
        ),
      );
      break;
    }
  }

  // 4. Comeback: away for 2+ days. Two gentle nudges at 10:00, then stop.
  if (i.studyDays.isNotEmpty) {
    final last = i.studyDays.reduce((a, b) => a.compareTo(b) > 0 ? a : b);
    if (_daysSince(last, today) >= 2) {
      for (final d in [1, 3]) {
        final t = at(d, 10, 0);
        if (taken(t)) continue;
        out.add(
          NudgeMessage(
            NudgeKind.comeback,
            t,
            'Your words are waiting',
            'Come back for a short session. Even five minutes helps.',
          ),
        );
      }
    }
  }

  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}
