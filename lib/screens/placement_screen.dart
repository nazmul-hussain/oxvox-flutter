import 'dart:async';

import 'package:flutter/material.dart';

import '../core/placement.dart';
import '../core/plan.dart';
import '../core/theme.dart';
import '../data/app_state.dart';
import '../widgets/quiz_kit.dart';

/// Web components/PlacementTest.js: 40 questions across A1–C2. Retakes use new words.
class PlacementScreen extends StatefulWidget {
  final AppState state;
  final OxPalette p;

  /// Web setState view 'settings' from "Set my study plan" (opened after this screen closes).
  final VoidCallback? onOpenPlan;
  const PlacementScreen({
    super.key,
    required this.state,
    required this.p,
    this.onOpenPlan,
  });

  @override
  State<PlacementScreen> createState() => _PlacementScreenState();
}

class _PlacementScreenState extends State<PlacementScreen> {
  late List<PlacementQuestion> _questions = _build();
  final List<String> _answers = [];
  int _index = 0;
  bool _finished = false;
  String? _picked;
  Timer? _timer;

  OxPalette get p => widget.p;
  AppState get s => widget.state;

  List<PlacementQuestion> _build() =>
      buildPlacement(s.placementPools(), s.placementUsed, s.meaningOf);

  late final QuizVoice _voice = QuizVoice(
    s: s,
    options: () => _finished || _questions.isEmpty
        ? const []
        : [for (final o in _questions[_index].options) o.label],
    lang: () =>
        _questions[_index].dir == 'bn-en' ? 'en' : s.primaryMeaningLang.code,
    canAnswer: () => !_finished && _picked == null && _questions.isNotEmpty,
    onPick: (label) {
      for (final o in _questions[_index].options) {
        if (o.label == label) return _choose(o.wid);
      }
    },
  );

  @override
  void initState() {
    super.initState();
    if (s.voiceAnswers) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _voice.listen());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _voice.dispose();
    super.dispose();
  }

  void _choose(String wid) {
    if (_picked != null || _finished) return;
    _voice.stop();
    setState(() => _picked = wid);
    _timer = Timer(const Duration(milliseconds: 450), _advance);
  }

  Future<void> _advance() async {
    if (!mounted) return;
    final q = _questions[_index];
    _answers.add(_picked!);
    await s.recordPlacementAnswer(q.wid);
    if (!mounted) return;
    setState(() => _picked = null);
    if (_index + 1 >= _questions.length) {
      final r = placementResult(_questions, _answers);
      await s.setPlacementResult(r.level);
      if (mounted) setState(() => _finished = true);
    } else {
      setState(() => _index += 1);
      _voice.listen();
    }
  }

  void _retake() {
    setState(() {
      _questions = _build();
      _answers.clear();
      _index = 0;
      _picked = null;
      _finished = false;
    });
    _voice.listen();
  }

  String _levelName(String c) {
    for (final l in s.levelOptions) {
      if (l['id'] == c) return l['name'] as String;
    }
    return c;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.bg,
        foregroundColor: p.ink,
        title: const Text('Level test'),
        actions: [if (!_finished) VoiceToggleChip(voice: _voice, p: p)],
      ),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) =>
            SafeArea(child: _finished ? _result() : _question()),
      ),
    );
  }

  Widget _question() {
    if (_questions.isEmpty) {
      return Center(
        child: Text('No words available.', style: TextStyle(color: p.muted)),
      );
    }
    final q = _questions[_index];
    final bn = q.dir == 'bn-en';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          'Question ${_index + 1} of ${_questions.length}',
          style: TextStyle(color: p.muted, fontSize: 13.6),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: _index / _questions.length,
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
                bn
                    ? 'Choose the English word'
                    : 'Choose the ${s.primaryMeaningLang.name} meaning',
                style: TextStyle(color: p.muted, fontSize: 13.6),
              ),
              const SizedBox(height: 6),
              Text(
                q.prompt,
                style: TextStyle(
                  color: bn ? p.ink : p.accent,
                  fontSize: bn ? 22 : 28,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              for (final o in q.options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _option(o, q),
                ),
              if (s.voiceAnswers && _picked == null)
                VoicePanel(voice: _voice, p: p),
            ],
          ),
        ),
      ],
    );
  }

  Widget _option(PlacementOption o, PlacementQuestion q) {
    final answered = _picked != null;
    return QuizOptionTile(
      p: p,
      label: o.label,
      state: QuizOptionTile.stateFor(o.wid, q.wid, _picked),
      rtl: q.dir != 'bn-en' && s.primaryMeaningLang.rtl,
      onTap: answered ? null : () => _choose(o.wid),
    );
  }

  Widget _result() {
    final r = placementResult(_questions, _answers);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
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
                'Your suggested starting level',
                style: TextStyle(color: p.muted, fontSize: 13.6),
              ),
              Text(
                r.level,
                style: TextStyle(
                  color: p.accent,
                  fontSize: 40,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _levelName(r.level),
                style: TextStyle(color: p.ink, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              Text(
                'Next, set your study plan: pick one level or several, and how many days.',
                style: TextStyle(color: p.muted, fontSize: 13.6),
              ),
              const SizedBox(height: 14),
              for (final c in cefrLevels)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _statRow(c, r.stats[c]!),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () async {
            await s.setLevels([r.level]);
            await s.setPlacementResult(r.level);
            if (!mounted) return;
            Navigator.of(context).pop();
            widget.onOpenPlan?.call();
          },
          style: FilledButton.styleFrom(
            backgroundColor: p.brand,
            minimumSize: const Size.fromHeight(48),
          ),
          child: const Text('Set my study plan'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          // Web: asked words stay saved, so the retake only uses words not asked yet.
          onPressed: _retake,
          style: OutlinedButton.styleFrom(
            foregroundColor: p.accent,
            side: BorderSide(color: p.accent),
            minimumSize: const Size.fromHeight(48),
          ),
          child: const Text('Retake with new words'),
        ),
      ],
    );
  }

  Widget _statRow(String c, PlacementStat st) {
    final pct = st.total == 0 ? 0.0 : st.ok / st.total;
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(
            c,
            style: TextStyle(fontWeight: FontWeight.w500, color: p.ink),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              color: p.accent,
              backgroundColor: p.surface2,
            ),
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            '${st.ok}/${st.total}',
            textAlign: TextAlign.end,
            style: TextStyle(color: p.muted, fontSize: 12.8),
          ),
        ),
      ],
    );
  }
}
