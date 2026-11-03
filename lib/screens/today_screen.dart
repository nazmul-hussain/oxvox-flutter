import 'package:flutter/material.dart';
import '../core/listening.dart';
import '../core/srs.dart';
import '../core/theme.dart';
import '../data/app_state.dart';
import '../widgets/web_ui.dart';
import 'detail_pages.dart';
import 'placement_screen.dart';
import 'quiz_screen.dart';

/// Web: components/Today.js. Same sections, same order, same copy and tile style.
class TodayScreen extends StatefulWidget {
  final AppState state;
  final OxPalette p;
  final ValueChanged<String> go;
  final VoidCallback? openLevelTest;
  const TodayScreen({
    super.key,
    required this.state,
    required this.p,
    required this.go,
    this.openLevelTest,
  });

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  AppState get state => widget.state;
  OxPalette get p => widget.p;
  ValueChanged<String> get go => widget.go;
  VoidCallback? get openLevelTest => widget.openLevelTest;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final day = s.currentDay.clamp(1, s.totalDays);
    final days = List.generate(s.totalDays, (i) => i + 1);
    final studyNext = days
        .where((d) => !s.isDayStudied(d))
        .cast<int?>()
        .firstOrNull;
    final nextLessonItem = nextLesson(s.lessons, s.listening);
    final quizNext = s.quizNextDay;

    return AnimatedBuilder(
      animation: s,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Hero(
            p: p,
            state: s,
            day: day,
            onLevelTest: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PlacementScreen(
                  state: s,
                  p: p,
                  onOpenPlan: () => go('settings'),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (s.isDayStudied(day) && !s.isDayQuizzed(day))
                  WebNotice(
                    p: p,
                    text: 'You studied Day $day. Take its quiz to lock it in.',
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Next up',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: p.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _TileRow(
                        left: _Tile(
                          p: p,
                          icon: Icons.menu_book,
                          title: 'Study',
                          sub: studyNext != null
                              ? 'Day $studyNext'
                              : 'All done',
                          onTap: studyNext == null
                              ? null
                              : () {
                                  s.setDay(studyNext);
                                  go('words');
                                },
                        ),
                        right: _Tile(
                          p: p,
                          icon: Icons.psychology,
                          title: 'Quiz',
                          sub: quizNext == null ? 'All done' : 'Day $quizNext',
                          onTap: quizNext == null
                              ? null
                              : () => showDayQuizCountSheet(
                                  context,
                                  state: s,
                                  p: p,
                                  day: quizNext,
                                  pool: s.dayWords(quizNext),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _TileRow(
                        left: _Tile(
                          p: p,
                          icon: Icons.headphones,
                          title: 'Listen',
                          sub: nextLessonItem == null
                              ? 'All done'
                              : 'Lesson ${nextLessonItem.number}',
                          onTap: nextLessonItem == null
                              ? null
                              : () => go('listen'),
                        ),
                        right: _Tile(
                          p: p,
                          icon: Icons.auto_awesome,
                          title: 'Topics',
                          sub: 'Native phrases',
                          onTap: () => go('topics'),
                        ),
                      ),
                      if (s.quizHistory.any((h) => h['date'] == todayStr()))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Quizzes taken today: ${s.quizHistory.where((h) => h['date'] == todayStr()).length}',
                            style: TextStyle(color: p.muted, fontSize: OxType.small),
                          ),
                        ),
                      if (studyNext == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Every day is studied. Nice work.',
                            style: TextStyle(color: p.muted, fontSize: OxType.small),
                          ),
                        ),
                    ],
                  ),
                ),
                _TileRow(
                  left: _Tile(
                    p: p,
                    icon: Icons.replay,
                    title: 'Missed',
                    sub:
                        '${s.missedList.length} ${s.missedList.length == 1 ? 'word' : 'words'}',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MissedScreen(state: s, p: p),
                      ),
                    ),
                  ),
                  right: _Tile(
                    p: p,
                    icon: Icons.bookmark,
                    title: 'Saved',
                    sub:
                        '${s.savedWords.length} ${s.savedWords.length == 1 ? 'word' : 'words'}',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SavedScreen(state: s, p: p),
                      ),
                    ),
                  ),
                ),
                WebCard(
                  p: p,
                  child: _ActivityChart(p: p, s: s),
                ),
                WebCard(
                  p: p,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recent quiz scores',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: p.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        s.quizHistory.isEmpty ? 'No quizzes taken yet.' : '',
                        style: TextStyle(color: p.muted, fontSize: OxType.small),
                      ),
                      if (s.quizHistory.isNotEmpty)
                        _ScoreChart(p: p, history: s.quizHistory),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TileRow extends StatelessWidget {
  final Widget left;
  final Widget right;
  const _TileRow({required this.left, required this.right});

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: left),
        const SizedBox(width: 10),
        Expanded(child: right),
      ],
    ),
  );
}

class _Hero extends StatelessWidget {
  final OxPalette p;
  final AppState state;
  final int day;
  final VoidCallback? onLevelTest;
  const _Hero({
    required this.p,
    required this.state,
    required this.day,
    required this.onLevelTest,
  });

  @override
  Widget build(BuildContext context) {
    final s = state;
    final streak = s.streak;
    final seen = s.progress.length;
    final wordLevel = s.estimatedWordLevel;
    final avg = s.quizAverage;
    final est = estimateLevel(s.questions, s.listening);
    final listenLevel = est?.level ?? 'A1';

    return WaveHero(
      p: p,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 38),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Day $day of ${s.totalDays}', style: _small),
                    Text('${s.daysDone} days done', style: _small),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Your progress',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _LevelTestButton(onTap: onLevelTest),
                  ],
                ),
                if (s.placementLast != null) ...[
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Started at '),
                        TextSpan(
                          text: '${s.placementLast!['level']}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: ' · tested ${s.placementLast!['date']}'),
                      ],
                    ),
                    style: const TextStyle(
                      color: Color(0xE6FFFFFF),
                      fontSize: OxType.small,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    _HeroStat(
                      label: 'Streak',
                      value: '$streak ${streak == 1 ? 'day' : 'days'}',
                    ),
                    const SizedBox(width: 8),
                    _HeroStat(label: 'Words seen', value: '$seen'),
                    const SizedBox(width: 8),
                    _HeroStat(
                      label: 'Quiz average',
                      value: avg == null ? '–' : '${(avg * 100).round()}%',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _LevelText(
                      icon: Icons.menu_book,
                      label: 'Words',
                      level: wordLevel,
                    ),
                    _LevelText(
                      icon: Icons.headphones,
                      label: 'Listening',
                      level: listenLevel,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _small = TextStyle(
    color: Color(0xE6FFFFFF),
    fontSize: 12.8,
    fontWeight: FontWeight.w400,
  );
}

class _LevelTestButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _LevelTestButton({required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0x2EFFFFFF),
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap:
          onTap ??
          () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Level test is coming in the next update.'),
            ),
          ),
      child: Ink(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0x66FFFFFF)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school, size: 16, color: Colors.white),
            SizedBox(width: 6),
            Text(
              'Level test',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.8,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _LevelText extends StatelessWidget {
  final IconData icon;
  final String label;
  final String level;
  const _LevelText({
    required this.icon,
    required this.label,
    required this.level,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: const Color(0xF2FFFFFF)),
      const SizedBox(width: 6),
      Text(
        '$label ',
        style: const TextStyle(color: Colors.white, fontSize: OxType.small),
      ),
      Text(
        level,
        style: const TextStyle(
          color: Colors.white,
          fontSize: OxType.small,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  const _HeroStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0x2EFFFFFF),
        border: Border.all(color: const Color(0x40FFFFFF)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xE6FFFFFF),
              fontSize: 10.9,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Tile extends StatelessWidget {
  final OxPalette p;
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback? onTap;
  const _Tile({
    required this.p,
    required this.icon,
    required this.title,
    required this.sub,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: p.surface,
          border: Border.all(color: p.line),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: p.shadow,
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: p.brand,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: p.onBrand, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: OxType.body,
                            fontWeight: FontWeight.w500,
                            color: p.ink,
                          ),
                        ),
                        Text(
                          sub,
                          style: TextStyle(fontSize: 12, color: p.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Web .chart for Recent quiz scores: last 10 quizzes, bar height = score share, label D{day} or Rnd.
class _ScoreChart extends StatelessWidget {
  final OxPalette p;
  final List<Map<String, dynamic>> history;
  const _ScoreChart({required this.p, required this.history});

  @override
  Widget build(BuildContext context) {
    final recent = history.length > 10
        ? history.sublist(history.length - 10)
        : history;
    return SizedBox(
      height: 140,
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final h in recent)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor:
                                h['total'] is num && (h['total'] as num) > 0
                                ? ((h['score'] as num) / (h['total'] as num))
                                      .clamp(0.08, 1.0)
                                      .toDouble()
                                : 0.08,
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: p.accent,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        h['day'] != null ? 'D${h['day']}' : 'Rnd',
                        style: TextStyle(fontSize: 10.4, color: p.muted),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActivityChart extends StatelessWidget {
  final OxPalette p;
  final AppState s;
  const _ActivityChart({required this.p, required this.s});

  @override
  Widget build(BuildContext context) {
    final days = List.generate(
      14,
      (i) => DateTime.now().subtract(Duration(days: 13 - i)),
    );
    String key(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Study activity (last 14 days)',
          style: TextStyle(fontWeight: FontWeight.w500, color: p.ink),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final d in days)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: s.studyLog[key(d)] == true
                                  ? 1
                                  : 0.08,
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: s.studyLog[key(d)] == true
                                      ? p.accent
                                      : p.line,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${d.day}',
                          style: TextStyle(fontSize: 10.4, color: p.muted),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
