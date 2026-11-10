import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/app_state.dart';
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
                    w.word.toLowerCase().contains(q) ||
                    s.meaningOf(w).toLowerCase().contains(q),
              )
              .toList();

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
                  fontWeight: FontWeight.w500,
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
                    fontWeight: FontWeight.w500,
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
                style: TextStyle(color: p.muted, fontSize: OxType.small),
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
                  icon: Icons.style_outlined,
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
                  icon: Icons.quiz_outlined,
                  label: 'Quiz',
                  onTap: () => showDayQuizCountSheet(
                    context,
                    state: s,
                    p: p,
                    day: day,
                    pool: words,
                  ),
                ),
                const SizedBox(width: 8),
                _ActionBtn(
                  p: p,
                  icon: done ? Icons.check : Icons.task_alt_outlined,
                  label: done ? 'Done' : 'Mark done',
                  on: done,
                  onTap: () => s.toggleDayDone(day),
                ),
              ],
            ),
          if (words.isNotEmpty) const SizedBox(height: 8),
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
                style: TextStyle(color: p.muted, fontSize: OxType.small),
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
                  lines: s.lineOf(w),
                  exampleBn: s.exampleBn,
                  saved: s.bookmarks.containsKey(w.id),
                  onToggleSave: () => s.toggleBookmark(w.id),
                ),
                lines: s.lineOf(w),
                showSynonyms: s.showSynonyms,
              ),
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
      child: Ink(
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
    child: Material(
      color: on ? p.accentSoft : p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: on ? p.accent : p.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(
            children: [
              // Icon badge in the theme accent: filled when the action is active (day done).
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on ? p.accent : p.accentSoft,
                ),
                child: Icon(icon, size: 18, color: on ? p.accentInk : p.accent),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: on ? p.accent : p.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
