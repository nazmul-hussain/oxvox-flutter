import 'package:flutter/material.dart';

import '../core/quiz.dart';
import '../core/theme.dart';
import '../data/app_state.dart';
import '../models/word.dart';
import '../widgets/word_card.dart';
import 'quiz_screen.dart';

/// Web: components/ReviewMissed.js. Words answered wrongly in any quiz; tap a word to see it,
/// clear it once learned, or start a review quiz on them.
class MissedScreen extends StatelessWidget {
  final AppState state;
  final OxPalette p;
  const MissedScreen({super.key, required this.state, required this.p});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final list = state.missedList;
        final count = list.length;
        final quizCount = count < 30 ? count : 30;
        return Scaffold(
          backgroundColor: p.bg,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                // Web: .btn.ghost.small-btn.detail-back
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Back'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.accent,
                      side: BorderSide(color: p.accent),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.8,
                        vertical: 6.4,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13.6,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Web: .detail-hero
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.accentSoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.replay, size: 26, color: p.accent),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Missed words',
                            style: TextStyle(
                              color: p.ink,
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '$count ${count == 1 ? 'word' : 'words'} to review',
                            style: TextStyle(color: p.muted, fontSize: 13.6),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Web: .btn.detail-cta
                FilledButton(
                  onPressed: count == 0
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => QuizScreen(
                              state: state,
                              p: p,
                              title: 'Review missed',
                              pool: [for (final m in list) m.w],
                              count: quizCount,
                              distractPool: state.allWords.toList(),
                            ),
                          ),
                        ),
                  style: FilledButton.styleFrom(
                    backgroundColor: p.accent,
                    foregroundColor: p.accentInk,
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: Text(
                    count == 0
                        ? 'Nothing to review'
                        : 'Start review quiz ($quizCount)',
                  ),
                ),
                const SizedBox(height: 16),
                for (final m in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: WordCard(
                            w: m.w,
                            p: p,
                            lines: state.lineOf(m.w),
                            showSynonyms: state.showSynonyms,
                            meta: 'Missed ${m.count}×',
                            onTap: () => _open(context, m.w),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Web: .icon-btn (32px, bordered) clears the word.
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => state.clearMissed(m.w.id),
                          child: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: p.surface,
                              border: Border.all(color: p.line),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.close, size: 16, color: p.muted),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _open(BuildContext context, Word w) {
    showWordSheet(
      context,
      w,
      p,
      lines: state.lineOf(w),
      exampleBn: state.content?.exampleBn ?? const {},
      saved: state.bookmarks.containsKey(w.id),
      onToggleSave: () => state.toggleBookmark(w.id),
    );
  }
}

/// Web: components/Bookmarks.js. Saved words with a saved-words quiz.
class SavedScreen extends StatefulWidget {
  final AppState state;
  final OxPalette p;
  const SavedScreen({super.key, required this.state, required this.p});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  // null = default (30% of saved words); set once the user moves the slider.
  int? _count;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final p = widget.p;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final saved = s.savedWords;
        final n = saved.length;
        final min = quizMinCount(n);
        final value = (_count ?? defaultQuizCount(n)).clamp(min, n).toInt();
        return Scaffold(
          backgroundColor: p.bg,
          appBar: AppBar(
            backgroundColor: p.bg,
            foregroundColor: p.ink,
            title: const Text('Saved words'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              if (n == 0)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: p.noticeBg,
                    border: Border.all(color: p.noticeLine),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'No saved words yet. Open a word in Words and tap ☆ Save.',
                    style: TextStyle(color: p.noticeInk),
                  ),
                ),
              if (n > 0) ...[
                Text(
                  '$n saved',
                  style: TextStyle(color: p.muted, fontSize: 13.6),
                ),
                const SizedBox(height: 8),
                Container(
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
                        'Saved words quiz',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: p.ink,
                        ),
                      ),
                      Text(
                        'Drawn from your $n saved words.',
                        style: TextStyle(color: p.muted, fontSize: 13.6),
                      ),
                      const SizedBox(height: 6),
                      CountPicker(
                        p: p,
                        value: value,
                        min: min,
                        max: n,
                        onChanged: (v) => setState(() => _count = v),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => QuizScreen(
                              state: s,
                              p: p,
                              title: 'Saved words quiz',
                              pool: saved,
                              count: value,
                              distractPool: s.planWords,
                            ),
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: p.accent,
                          foregroundColor: p.accentInk,
                          minimumSize: const Size.fromHeight(44),
                        ),
                        child: const Text('Start saved words quiz'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              for (final w in saved)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: WordCard(
                    w: w,
                    p: p,
                    lines: s.lineOf(w),
                    showSynonyms: s.showSynonyms,
                    meta: _meta(s, w.id),
                    onTap: () => showWordSheet(
                      context,
                      w,
                      p,
                      lines: s.lineOf(w),
                      exampleBn: s.content?.exampleBn ?? const {},
                      saved: true,
                      onToggleSave: () => s.toggleBookmark(w.id),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Web meta: "Day N · saved on Day M · YYYY-MM-DD".
  String _meta(AppState s, String wid) {
    final planDay = s.planDayOf(wid);
    final mark = s.bookmarks[wid];
    final savedDay = mark?['day'];
    final savedDate = mark?['date'];
    final parts = [
      'Day ${planDay ?? '–'}',
      if (savedDay != null) 'saved on Day $savedDay',
      if (savedDate != null) '$savedDate',
    ];
    return parts.join(' · ');
  }
}
