import 'package:flutter/material.dart';

import '../core/listening.dart';
import '../core/theme.dart';
import '../data/app_state.dart';
import '../widgets/listen_thumb.dart';
import '../models/word.dart';
import 'lesson_screen.dart';

String _fmtDur(double s) {
  final m = s ~/ 60;
  final r = (s % 60).floor();
  return '$m:${r.toString().padLeft(2, '0')}';
}

const _typeLabel = {
  'main': 'Main idea',
  'detail': 'Details',
  'inference': 'Understanding meaning',
};

/// Web components/ListeningPractice.js (list view).
class ListenScreen extends StatefulWidget {
  final AppState state;
  final OxPalette p;
  const ListenScreen({super.key, required this.state, required this.p});

  @override
  State<ListenScreen> createState() => _ListenScreenState();
}

class _ListenScreenState extends State<ListenScreen> {
  late int _day;

  @override
  void initState() {
    super.initState();
    final s = widget.state;
    final next = nextLesson(s.lessons, s.listening);
    _day = next == null ? 1 : lessonDay(s.lessons, next.id);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final p = widget.p;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final results = s.listening;
        final est = estimateLevel(s.questions, results);
        final list = lessonsOfDay(s.lessons, _day);
        final doneCount = list.where((l) => results[l.id] != null).length;
        final doneAll = results.length;
        final levelText = est?.level ?? 'A1';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.headphones, size: 22, color: p.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Listening',
                          style: TextStyle(
                            fontSize: 22.4,
                            fontWeight: FontWeight.w500,
                            color: p.ink,
                          ),
                        ),
                        Text(
                          '${s.lessons.length} conversations · $doneAll done',
                          style: TextStyle(fontSize: 13.6, color: p.muted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    decoration: BoxDecoration(
                      color: p.surface,
                      border: Border.all(color: p.line),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 12.8, color: p.ink),
                        children: [
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 5),
                              child: Icon(
                                Icons.headphones,
                                size: 16,
                                color: p.ink,
                              ),
                            ),
                          ),
                          TextSpan(
                            text: 'Level ',
                            style: TextStyle(
                              fontWeight: FontWeight.w400,
                              color: p.ink,
                            ),
                          ),
                          TextSpan(
                            text: levelText,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: p.brand,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _DayBar(
              p: p,
              day: _day,
              onChanged: (d) => setState(() => _day = d),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                '$doneCount of ${list.length} lessons done',
                style: TextStyle(fontSize: 13.6, color: p.muted),
              ),
            ),
            for (final l in list) _LessonRow(state: s, p: p, lesson: l),
            const SizedBox(height: 8),
            _LevelCard(p: p, est: est),
          ],
        );
      },
    );
  }
}

class _DayBar extends StatefulWidget {
  final OxPalette p;
  final int day;
  final ValueChanged<int> onChanged;
  const _DayBar({required this.p, required this.day, required this.onChanged});

  @override
  State<_DayBar> createState() => _DayBarState();
}

class _DayBarState extends State<_DayBar> {
  late final TextEditingController _c = TextEditingController(
    text: '${widget.day}',
  );

  @override
  void didUpdateWidget(covariant _DayBar old) {
    super.didUpdateWidget(old);
    if (old.day != widget.day && _c.text != '${widget.day}') {
      _c.text = '${widget.day}';
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    Widget iconBtn(
      IconData icon,
      bool enabled,
      VoidCallback onTap,
      String label,
    ) => Semantics(
      label: label,
      button: true,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: enabled ? 1 : 0.35,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: p.surface,
              border: Border.all(color: p.line),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: p.accent),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          iconBtn(
            Icons.chevron_left,
            widget.day > 1,
            () => widget.onChanged(widget.day - 1),
            'Previous day',
          ),
          Row(
            children: [
              Text(
                'Day',
                style: TextStyle(fontWeight: FontWeight.w500, color: p.ink),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 67,
                height: 36,
                child: TextField(
                  controller: _c,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                    color: p.ink,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.all(8),
                    filled: true,
                    fillColor: p.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: p.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: p.line),
                    ),
                  ),
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n >= 1 && n <= listenDays) {
                      widget.onChanged(n);
                    }
                  },
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '/ $listenDays',
                style: TextStyle(fontSize: 13.6, color: p.muted),
              ),
            ],
          ),
          iconBtn(
            Icons.chevron_right,
            widget.day < listenDays,
            () => widget.onChanged(widget.day + 1),
            'Next day',
          ),
        ],
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  final AppState state;
  final OxPalette p;
  final ListeningLesson lesson;
  const _LessonRow({
    required this.state,
    required this.p,
    required this.lesson,
  });

  @override
  Widget build(BuildContext context) {
    final r = state.listening[lesson.id];
    final score = r == null
        ? null
        : ((r['correct'] as List).where((e) => e == true).length);
    final total = r == null ? 0 : (r['correct'] as List).length;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                LessonScreen(state: state, p: p, lessonId: lesson.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                child: ListenThumbView(
                  title: lesson.title,
                  num: lesson.number,
                  inRow: true,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: p.ink,
                      ),
                    ),
                    Text(
                      'Lesson ${lesson.number} · ${_fmtDur(lesson.duration)} · ${lesson.lines.length} lines',
                      style: TextStyle(
                        fontSize: 12.8,
                        fontWeight: FontWeight.w500,
                        color: p.brand,
                      ),
                    ),
                  ],
                ),
              ),
              if (score != null)
                Text(
                  '$score/$total',
                  style: TextStyle(
                    fontSize: 12.8,
                    fontWeight: FontWeight.w500,
                    color: p.green,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final OxPalette p;
  final LevelEstimate? est;
  const _LevelCard({required this.p, required this.est});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your listening level',
            style: TextStyle(fontWeight: FontWeight.w500, color: p.ink),
          ),
          const SizedBox(height: 6),
          if (est != null) ...[
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: est!.level,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      color: p.ink,
                    ),
                  ),
                  TextSpan(
                    text: '  · ${est!.pct}% correct',
                    style: TextStyle(fontSize: 13.6, color: p.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            for (final t in listenQuestionTypes)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: p.line)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_typeLabel[t]!, style: TextStyle(color: p.ink)),
                    Text(
                      '${est!.byType[t]![0]} / ${est!.byType[t]![1]}',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: p.ink,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Text(
              'Based on ${est!.lessons} lessons. It gets more accurate as you finish more.',
              style: TextStyle(fontSize: 13.6, color: p.muted),
            ),
          ] else
            Text(
              'Finish 3 lessons to see your estimated listening level.',
              style: TextStyle(fontSize: 13.6, color: p.muted),
            ),
        ],
      ),
    );
  }
}
