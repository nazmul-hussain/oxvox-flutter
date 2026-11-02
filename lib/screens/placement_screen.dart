import 'dart:async';

import 'package:flutter/material.dart';

import '../core/placement.dart';
import '../core/plan.dart';
import '../core/theme.dart';
import '../data/app_state.dart';

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
      buildPlacement(s.placementPools(), s.placementUsed);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _choose(String wid) {
    if (_picked != null || _finished) return;
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
        LinearProgressIndicator(
          value: _index / _questions.length,
          minHeight: 6,
          color: p.accent,
          backgroundColor: p.surface2,
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
                bn ? 'Choose the English word' : 'Choose the Bangla meaning',
                style: TextStyle(color: p.muted, fontSize: 12.8),
              ),
              const SizedBox(height: 6),
              Text(
                q.prompt,
                style: TextStyle(
                  color: p.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              for (final o in q.options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _option(o, q),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _option(PlacementOption o, PlacementQuestion q) {
    final answered = _picked != null;
    final correct = o.wid == q.wid;
    Color border = p.line;
    Color bg = p.surface;
    if (answered && correct) {
      border = p.green;
      bg = p.greenSoft;
    } else if (answered && o.wid == _picked) {
      border = p.red;
      bg = p.redSoft;
    }
    return InkWell(
      onTap: answered ? null : () => _choose(o.wid),
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
          o.label,
          style: TextStyle(
            color: p.ink,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
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
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                _levelName(r.level),
                style: TextStyle(color: p.ink, fontWeight: FontWeight.w700),
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
            style: TextStyle(fontWeight: FontWeight.w700, color: p.ink),
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
