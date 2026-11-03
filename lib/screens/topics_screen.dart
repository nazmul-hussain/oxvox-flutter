import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/app_state.dart';
import '../models/topic.dart';
import '../services/speech.dart';
import '../widgets/word_card.dart';
import 'context_quiz_screen.dart';
import 'flashcards_screen.dart';
import 'quiz_screen.dart';

/// Web: components/TopicsPanel.js. Topic grid, then a topic's words (tap a word for its sheet).
class TopicsScreen extends StatefulWidget {
  final AppState state;
  final OxPalette p;
  const TopicsScreen({super.key, required this.state, required this.p});

  @override
  State<TopicsScreen> createState() => _TopicsScreenState();
}

class _TopicsScreenState extends State<TopicsScreen> {
  String? _activeId;

  OxPalette get p => widget.p;
  AppState get s => widget.state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final topic = s.topics.where((t) => t.id == _activeId).firstOrNull;
        if (topic == null) return _grid();
        return _detail(topic);
      },
    );
  }

  Widget _grid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Topics',
          style: TextStyle(
            fontSize: OxType.heading,
            fontWeight: FontWeight.w500,
            color: p.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Sound like a native speaker. Pick a topic, study the cards, then take a quiz on the same words.',
          style: TextStyle(fontSize: OxType.small, color: p.muted),
        ),
        const SizedBox(height: 12),
        for (final t in s.topics)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TopicCard(
              p: p,
              topic: t,
              done: t.words.where((w) => s.progress[w.id] != null).length,
              onTap: () => setState(() => _activeId = t.id),
            ),
          ),
      ],
    );
  }

  Widget _detail(TopicItem topic) {
    final count = topic.words.length < 20 ? topic.words.length : 20;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _activeId = null),
            icon: Icon(Icons.arrow_back, size: 16, color: p.accent),
            label: Text(
              'All topics',
              style: TextStyle(color: p.accent, fontWeight: FontWeight.w500),
            ),
          ),
        ),
        Text(
          topic.label,
          style: TextStyle(
            fontSize: OxType.heading,
            fontWeight: FontWeight.w500,
            color: p.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          topic.description,
          style: TextStyle(fontSize: OxType.small, color: p.muted),
        ),
        const SizedBox(height: 12),
        if (topic.narration != null) ...[
          OutlinedButton.icon(
            onPressed: () => _showGrammar(topic.narration!),
            icon: Icon(Icons.menu_book, size: 16, color: p.accent),
            label: const Text('Grammar rules'),
            style: OutlinedButton.styleFrom(
              foregroundColor: p.accent,
              side: BorderSide(color: p.accent),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FlashcardsScreen(
                    state: s,
                    p: p,
                    title: '${topic.label} cards',
                    words: topic.words,
                  ),
                ),
              ),
              icon: const Icon(Icons.layers, size: 16),
              label: Text('Study cards (${topic.words.length})'),
              style: FilledButton.styleFrom(backgroundColor: p.brand),
            ),
            if (topic.questions != null)
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ContextQuizScreen(
                      p: p,
                      title: '${topic.label} in context',
                      questions: topic.questions!,
                    ),
                  ),
                ),
                icon: Icon(Icons.psychology, size: 16, color: p.accent),
                label: Text(
                  'Context quiz (${topic.questions!.length} situations)',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.accent,
                  side: BorderSide(color: p.accent),
                ),
              ),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => QuizScreen(
                    state: s,
                    p: p,
                    title: '${topic.label} quiz',
                    pool: topic.words,
                    count: count,
                    distractPool: topic.words,
                  ),
                ),
              ),
              icon: Icon(Icons.psychology, size: 16, color: p.accent),
              label: Text('Word quiz ($count questions)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: p.accent,
                side: BorderSide(color: p.accent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final w in topic.words)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: WordCard(
              w: w,
              p: p,
              lines: s.lineOf(w),
              showSynonyms: s.showSynonyms,
              onTap: () => showWordSheet(
                context,
                w,
                p,
                lines: s.lineOf(w),
                exampleBn: s.content?.exampleBn ?? const {},
                saved: s.bookmarks.containsKey(w.id),
                onToggleSave: () => s.toggleBookmark(w.id),
              ),
            ),
          ),
      ],
    );
  }

  /// Web: GrammarSheet, a bottom sheet opened from the topic.
  void _showGrammar(TopicNarration narration) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _GrammarSheet(p: p, narration: narration),
    );
  }
}

/// Icon per topic id (data/topics.json). Unknown ids use the default.
const _topicIcons = <String, IconData>{
  'phrasal': Icons.alt_route,
  'idioms': Icons.lightbulb_outline,
  'discourse': Icons.forum_outlined,
  'collocations': Icons.join_inner,
  'linking': Icons.link,
  'hedging': Icons.blur_on,
  'modals': Icons.rule,
};

IconData _topicIcon(String id) => _topicIcons[id] ?? Icons.auto_awesome;

class _TopicCard extends StatelessWidget {
  final OxPalette p;
  final TopicItem topic;
  final int done;
  final VoidCallback onTap;
  const _TopicCard({
    required this.p,
    required this.topic,
    required this.done,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final total = topic.words.length;
    final pct = total == 0 ? 0.0 : done / total;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: p.shadow, offset: const Offset(0, 2), blurRadius: 8),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: p.accentSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_topicIcon(topic.id), color: p.accent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topic.label,
                        style: TextStyle(
                          fontSize: 16.4,
                          fontWeight: FontWeight.w500,
                          color: p.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$total items · $done practised',
                        style: TextStyle(
                          fontSize: 12.8,
                          fontWeight: FontWeight.w400,
                          color: p.accent,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        topic.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: p.muted),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 5,
                          backgroundColor: p.surface2,
                          valueColor: AlwaysStoppedAnimation(p.accent),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right, color: p.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Web components/GrammarSheet.js: title, Listen/Stop, then each section's heading and paragraphs.
class _GrammarSheet extends StatefulWidget {
  final OxPalette p;
  final TopicNarration narration;
  const _GrammarSheet({required this.p, required this.narration});

  @override
  State<_GrammarSheet> createState() => _GrammarSheetState();
}

class _GrammarSheetState extends State<_GrammarSheet> {
  bool _speaking = false;

  @override
  void dispose() {
    Speech.stop();
    super.dispose();
  }

  void _toggle() {
    if (_speaking) {
      Speech.stop();
      setState(() => _speaking = false);
      return;
    }
    final n = widget.narration;
    final text = [
      n.title,
      for (final sec in n.sections) ...[sec.heading, ...sec.text],
    ].join('. ');
    setState(() => _speaking = true);
    Speech.speak(
      text,
      onEnd: () {
        if (mounted) setState(() => _speaking = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final narration = widget.narration;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      narration.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                        color: p.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Speech.stop();
                      Navigator.of(context).pop();
                    },
                    icon: Icon(Icons.close, color: p.ink),
                    tooltip: 'Close',
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _toggle,
                  icon: Icon(
                    _speaking ? Icons.stop : Icons.mic,
                    size: 14,
                    color: p.accent,
                  ),
                  label: Text(_speaking ? 'Stop' : 'Listen'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: p.accent,
                    side: BorderSide(color: p.accent),
                  ),
                ),
              ),
              for (final sec in narration.sections) ...[
                const SizedBox(height: 10),
                Text(
                  sec.heading,
                  style: TextStyle(fontWeight: FontWeight.w500, color: p.ink),
                ),
                for (final t in sec.text)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      t,
                      style: TextStyle(
                        color: p.ink,
                        fontSize: OxType.small,
                        height: 1.45,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
