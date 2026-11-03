import 'package:flutter/material.dart';

import '../core/srs.dart';
import '../core/theme.dart';
import '../data/app_state.dart';
import '../models/word.dart';
import '../widgets/web_ui.dart';

/// Web components/Flashcards.js: tap a card to reveal it, then rate how well you knew it.
/// Due cards come first; the queue is fixed when the session starts.
class FlashcardsScreen extends StatefulWidget {
  final AppState state;
  final OxPalette p;
  final String title;
  final List<Word> words;
  const FlashcardsScreen({
    super.key,
    required this.state,
    required this.p,
    required this.title,
    required this.words,
  });

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  late final List<Word> _queue = () {
    final due = widget.words
        .where((w) => isDue(widget.state.progress[w.id]))
        .toList();
    return due.isNotEmpty ? due : [...widget.words];
  }();
  int _index = 0;
  bool _flipped = false;

  OxPalette get p => widget.p;

  Future<void> _rate(Rating r) async {
    await widget.state.rateCard(_queue[_index].id, r);
    setState(() {
      _flipped = false;
      _index += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.bg,
        foregroundColor: p.ink,
        title: Text(widget.title),
      ),
      body: SafeArea(
        child: _queue.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: WebNotice(p: p, text: 'No cards for this day yet.'),
              )
            : _index >= _queue.length
            ? _done()
            : _card(),
      ),
    );
  }

  Widget _card() {
    final card = _queue[_index];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          'Card ${_index + 1} of ${_queue.length}',
          style: TextStyle(color: p.muted, fontSize: 13.6),
        ),
        const SizedBox(height: 8),
        // Web: .bar (10px, rounded) with .bar-fill.
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: _index / _queue.length,
            minHeight: 10,
            color: p.accent,
            backgroundColor: p.line,
          ),
        ),
        const SizedBox(height: 16),
        // Web: .flashcard (min-height 260, radius 20, flipped = accent-soft).
        InkWell(
          onTap: () => setState(() => _flipped = !_flipped),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            constraints: const BoxConstraints(minHeight: 260),
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _flipped ? p.accentSoft : p.surface,
              border: Border.all(color: p.line),
              borderRadius: BorderRadius.circular(20),
            ),
            child: !_flipped
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        card.word,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: p.accent,
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to reveal',
                        style: TextStyle(color: p.muted, fontSize: 13.6),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Web: .bangla.big (the .bangla size wins: 1.1rem).
                      Text(
                        widget.state.meaningOf(card),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: p.ink, fontSize: 17.6),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '"${card.example}"',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: p.ink,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      if (card.usage != null && card.usage!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          card.usage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.ink, fontSize: 13.6),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),
        if (_flipped) _ratingRow(),
      ],
    );
  }

  /// Web: .rating-row (4 equal columns) with .rate-again/-hard/-good/-easy.
  Widget _ratingRow() {
    return Row(
      children: [
        for (final r in Rating.values) ...[
          Expanded(
            child: FilledButton(
              onPressed: () => _rate(r),
              style: FilledButton.styleFrom(
                backgroundColor: switch (r) {
                  Rating.again => p.red,
                  Rating.hard => p.orange,
                  Rating.good => p.accent,
                  Rating.easy => p.green,
                },
                foregroundColor: switch (r) {
                  Rating.good => p.accentInk,
                  _ => Colors.white,
                },
                padding: const EdgeInsets.symmetric(
                  vertical: 9.6,
                  horizontal: 3.2,
                ),
                textStyle: const TextStyle(
                  fontSize: 13.6,
                  fontWeight: FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(switch (r) {
                Rating.again => 'Again',
                Rating.hard => 'Hard',
                Rating.good => 'Good',
                Rating.easy => 'Easy',
              }),
            ),
          ),
          if (r != Rating.easy) const SizedBox(width: 8),
        ],
      ],
    );
  }

  /// Web: .page.center with "Session complete 🎉", the count, and "Back to words".
  Widget _done() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Session complete 🎉',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: p.ink,
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'You reviewed ${_queue.length} cards.',
              style: TextStyle(color: p.muted),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: p.accent,
                foregroundColor: p.accentInk,
              ),
              child: const Text('Back to words'),
            ),
          ],
        ),
      ),
    );
  }
}
