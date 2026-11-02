import 'package:flutter/material.dart';

import '../core/quiz.dart';
import '../core/theme.dart';
import '../data/app_state.dart';
import '../models/word.dart';
import '../widgets/web_ui.dart';
import '../widgets/word_card.dart';
import 'flashcards_screen.dart';
import 'quiz_screen.dart';

/// Web: components/WordList.js. Day bar, three action buttons, day quiz panel,
/// search, and word rows that open the detail bottom sheet.
class WordsScreen extends StatefulWidget {
  final AppState state;
  final OxPalette p;
  const WordsScreen({super.key, required this.state, required this.p});

  @override
  State<WordsScreen> createState() => _WordsScreenState();
}

class _WordsScreenState extends State<WordsScreen> {
  String _query = '';
  bool _quizOpen = false;
  // null = default (30% of the day's words); set once the user moves the slider.
  int? _quizCount;
  int? _quizCountDay;
  final _dayCtrl = TextEditingController();

  @override
  void dispose() {
    _dayCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final p = widget.p;
    final day = s.currentDay.clamp(1, s.totalDays);
    final words = s.dayWords(day);
    final done = s.completedDays[day] == true;
    final q = _query.trim().toLowerCase();
    final visible = q.isEmpty
        ? words
        : words
              .where(
                (w) =>
                    w.word.toLowerCase().contains(q) || w.meaning.contains(q),
              )
              .toList();

    if (_quizCountDay != day) {
      _quizCountDay = day;
      _quizCount = null;
    }

    return AnimatedBuilder(
      animation: s,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _IconOnly(
                p: p,
                icon: Icons.chevron_left,
                enabled: day > 1,
                onTap: () => s.setDay(day - 1),
              ),
              const Spacer(),
              Text(
                'Day',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: p.ink,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 67,
                child: TextField(
                  controller: _dayCtrl..text = '$day',
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    color: p.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.all(9),
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
                    if (n != null && n >= 1 && n <= s.totalDays && n != day) {
                      s.setDay(n);
                    }
                  },
                ),
              ),
              Text(
                ' / ${s.totalDays}',
                style: TextStyle(color: p.muted, fontSize: 13.6),
              ),
              const Spacer(),
              _IconOnly(
                p: p,
                icon: Icons.chevron_right,
                enabled: day < s.totalDays,
                onTap: () => s.setDay(day + 1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (words.isNotEmpty)
            Row(
              children: [
                _ActionBtn(
                  p: p,
                  icon: Icons.layers,
                  label: 'Flashcards',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FlashcardsScreen(
                        state: s,
                        p: p,
                        title: 'Day $day cards',
                        words: words,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _ActionBtn(
                  p: p,
                  icon: Icons.psychology,
                  label: 'Quiz',
                  on: _quizOpen,
                  onTap: () => setState(() => _quizOpen = !_quizOpen),
                ),
                const SizedBox(width: 8),
                _ActionBtn(
                  p: p,
                  icon: Icons.check_circle_outline,
                  label: done ? 'Done' : 'Mark done',
                  on: done,
                  onTap: () => s.toggleDayDone(day),
                ),
              ],
            ),
          if (words.isNotEmpty) const SizedBox(height: 8),
          if (_quizOpen && words.isNotEmpty) _dayQuizPanel(s, p, day, words),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Search word or meaning',
              filled: true,
              fillColor: p.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 11,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: p.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: p.line),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (words.isEmpty)
            WebNotice(p: p, text: 'Day $day words are still being prepared.')
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${visible.length} of ${words.length} words',
                style: TextStyle(color: p.muted, fontSize: 13.6),
              ),
            ),
          for (final w in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: WordCard(
                w: w,
                p: p,
                onTap: () => showWordSheet(
                  context,
                  w,
                  p,
                  arabic: s.content?.arabic[w.id],
                  exampleBn: s.content?.exampleBn ?? const {},
                  saved: s.bookmarks.containsKey(w.id),
                  onToggleSave: () => s.toggleBookmark(w.id),
                ),
                arabic: s.content?.arabic[w.id],
                showSynonyms: s.showSynonyms,
              ),
            ),
        ],
      ),
    );
  }

  /// Web: the "Day N quiz" card (count picker + Start quiz).
  Widget _dayQuizPanel(AppState s, OxPalette p, int day, List<Word> words) {
    final n = words.length;
    final min = quizMinCount(n);
    final value = (_quizCount ?? defaultQuizCount(n)).clamp(min, n).toInt();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 12),
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
            'Day $day quiz',
            style: TextStyle(fontWeight: FontWeight.w700, color: p.ink),
          ),
          const SizedBox(height: 6),
          CountPicker(
            p: p,
            value: value,
            min: min,
            max: n,
            onChanged: (v) => setState(() => _quizCount = v),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => QuizScreen(
                  state: s,
                  p: p,
                  title: 'Day $day quiz',
                  day: day,
                  pool: words,
                  count: value,
                  distractPool: words,
                ),
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: p.accent,
              foregroundColor: p.accentInk,
              minimumSize: const Size.fromHeight(44),
            ),
            child: const Text('Start quiz'),
          ),
        ],
      ),
    );
  }
}

class _IconOnly extends StatelessWidget {
  final OxPalette p;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _IconOnly({
    required this.p,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: enabled ? 1 : 0.35,
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: enabled ? onTap : null,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: p.surface,
          border: Border.all(color: p.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: p.accent, size: 18),
      ),
    ),
  );
}

class _ActionBtn extends StatelessWidget {
  final OxPalette p;
  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.p,
    required this.icon,
    required this.label,
    required this.onTap,
    this.on = false,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: on ? p.accentSoft : p.surface,
          border: Border.all(color: on ? p.accent : p.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: on ? p.accent : p.ink),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: on ? p.accent : p.ink,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
