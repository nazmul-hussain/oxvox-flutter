import 'dart:math';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/topic.dart';
import '../services/speech.dart';

/// Web: components/ContextQuiz.js. Each question is a real situation; the learner picks the
/// word that fits, then reads why it fits and why the tempting options do not.
class ContextQuizScreen extends StatefulWidget {
  final OxPalette p;
  final String title;
  final List<ContextQuestion> questions;
  const ContextQuizScreen({
    super.key,
    required this.p,
    required this.title,
    required this.questions,
  });

  @override
  State<ContextQuizScreen> createState() => _ContextQuizScreenState();
}

class _ContextQuizScreenState extends State<ContextQuizScreen> {
  final _rng = Random();
  late List<ContextQuestion> _items;
  final List<String?> _answers = [];
  int _index = 0;

  OxPalette get p => widget.p;

  bool _speaking = false;

  @override
  void dispose() {
    Speech.stop();
    super.dispose();
  }

  void _listen(ContextQuestion q) {
    if (_speaking) {
      Speech.stop();
      setState(() => _speaking = false);
      return;
    }
    setState(() => _speaking = true);
    Speech.speak(
      '${q.context}. ${q.sentence.replaceAll('___', 'blank')}',
      onEnd: () {
        if (mounted) setState(() => _speaking = false);
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _shuffle();
  }

  // Web: shuffled once on mount; the question and option order stay until the screen closes.

  void _shuffle() {
    final list = [...widget.questions]..shuffle(_rng);
    _items = [
      for (final q in list)
        ContextQuestion(
          context: q.context,
          sentence: q.sentence,
          options: [...q.options]..shuffle(_rng),
          answer: q.answer,
          explain: q.explain,
        ),
    ];
    _answers.clear();
    _index = 0;
  }

  int get _total => _items.length;
  int get _score {
    var n = 0;
    for (var i = 0; i < _answers.length; i++) {
      if (_answers[i] == _items[i].answer) n++;
    }
    return n;
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
      body: SafeArea(child: _index >= _total ? _result() : _question()),
    );
  }

  Widget _question() {
    final q = _items[_index];
    final chosen = _index < _answers.length ? _answers[_index] : null;
    final answered = chosen != null;
    final parts = q.sentence.split('___');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          '${widget.title} · Question ${_index + 1} of $_total · Score $_score',
          style: TextStyle(color: p.muted, fontSize: 13.6),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _index / _total,
            minHeight: 6,
            color: p.accent,
            backgroundColor: p.surface2,
          ),
        ),
        const SizedBox(height: 12),
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
                'Situation',
                style: TextStyle(color: p.muted, fontSize: 12.8),
              ),
              Text(q.context, style: TextStyle(color: p.ink, fontSize: 15.2)),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () => _listen(q),
                icon: Icon(
                  _speaking ? Icons.stop : Icons.mic,
                  size: 16,
                  color: p.accent,
                ),
                label: Text(_speaking ? 'Stop' : 'Listen'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.accent,
                  side: BorderSide(color: p.accent),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  for (var i = 0; i < parts.length; i++) ...[
                    Text(
                      parts[i],
                      style: TextStyle(
                        color: p.accent,
                        fontSize: 19.2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (i < parts.length - 1)
                      Container(
                        width: 64,
                        height: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        color: p.accent,
                      ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              for (final opt in q.options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _option(opt, q, chosen),
                ),
              if (answered) ...[
                const SizedBox(height: 4),
                Text(
                  chosen == q.answer
                      ? 'Correct.'
                      : 'Not quite. The answer is "${q.answer}".',
                  style: TextStyle(color: p.ink, fontSize: 13.6),
                ),
                const SizedBox(height: 4),
                Text(
                  q.explain,
                  style: TextStyle(color: p.muted, fontSize: 13.6),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: p.accent,
                side: BorderSide(color: p.accent),
              ),
              child: const Text('Exit'),
            ),
            const Spacer(),
            FilledButton(
              onPressed: !answered ? null : () => setState(() => _index += 1),
              style: FilledButton.styleFrom(backgroundColor: p.brand),
              child: Text(_index + 1 == _total ? 'See result' : 'Next'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _option(String opt, ContextQuestion q, String? chosen) {
    final answered = chosen != null;
    Color border = p.line;
    Color bg = p.surface;
    if (answered && opt == q.answer) {
      border = p.green;
      bg = p.greenSoft;
    } else if (answered && opt == chosen) {
      border = p.red;
      bg = p.redSoft;
    }
    return InkWell(
      onTap: answered ? null : () => _choose(opt),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          opt,
          style: TextStyle(
            color: p.ink,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  void _choose(String opt) {
    setState(() {
      while (_answers.length <= _index) {
        _answers.add(null);
      }
      _answers[_index] = opt;
    });
  }

  Widget _result() {
    final pct = _total == 0 ? 0 : (_score / _total * 100).round();
    final band = pct >= 90
        ? 'Excellent. You read the situation and chose the right modal every time.'
        : pct >= 70
        ? 'Good. Review the questions you missed, because the context gave the clue.'
        : 'Keep going. Read the narration again, then try the quiz once more.';
    final wrong = [
      for (var i = 0; i < _total; i++)
        if (_answers.length <= i || _answers[i] != _items[i].answer) i,
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          '${widget.title} finished',
          style: TextStyle(
            fontSize: 22.4,
            fontWeight: FontWeight.w500,
            color: p.ink,
          ),
        ),
        const SizedBox(height: 12),
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
                'Score: $_score of $_total ($pct%)',
                style: TextStyle(fontWeight: FontWeight.w500, color: p.ink),
              ),
              const SizedBox(height: 4),
              Text(band, style: TextStyle(color: p.muted, fontSize: 13.6)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton(
              // Web restart keeps the same question order and clears answers.
              onPressed: () => setState(() {
                _answers.clear();
                _index = 0;
              }),
              style: OutlinedButton.styleFrom(
                foregroundColor: p.accent,
                side: BorderSide(color: p.accent),
              ),
              child: const Text('Try again'),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(backgroundColor: p.brand),
              child: const Text('Back to topic'),
            ),
          ],
        ),
        if (wrong.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Review',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 16,
              color: p.ink,
            ),
          ),
          for (final i in wrong)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.surface,
                border: Border.all(color: p.line),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _items[i].context,
                    style: TextStyle(color: p.muted, fontSize: 12.8),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _items[i].sentence.replaceFirst(
                      '___',
                      '[${_items[i].answer}]',
                    ),
                    style: TextStyle(color: p.ink),
                  ),
                  Text(
                    'Your answer: ${_answers.length > i ? _answers[i] ?? '—' : '—'}',
                    style: TextStyle(color: p.muted, fontSize: 13.6),
                  ),
                  Text(
                    _items[i].explain,
                    style: TextStyle(color: p.muted, fontSize: 13.6),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
