import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../data/app_state.dart';
import '../models/lab.dart';
import '../services/speech.dart';
import '../services/voice_answer.dart';
import '../widgets/quiz_kit.dart';

/// One lab module: units on a path with stars, then mastery, advanced, speed round and guide.
class LabScreen extends StatelessWidget {
  final AppState state;
  final OxPalette p;
  final String labKey;
  final String title;
  final String story;
  const LabScreen({
    super.key,
    required this.state,
    required this.p,
    required this.labKey,
    required this.title,
    this.story = '',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.bg,
        foregroundColor: p.ink,
        title: Text(title),
      ),
      body: SafeArea(
        child: FutureBuilder<Lab?>(
          future: state.loadLab(labKey),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final lab = snap.data;
            if (lab == null) {
              return Center(
                child: Text(
                  'This lesson could not be opened. Try again later.',
                  style: TextStyle(color: p.muted),
                ),
              );
            }
            return ListenableBuilder(
              listenable: state,
              builder: (context, _) => _hub(context, lab),
            );
          },
        ),
      ),
    );
  }

  Widget _hub(BuildContext context, Lab c) {
    int score(String id) => state.labScore(labKey, id);
    final done = c.units.where((u) => score(u.id) >= 80).length;
    final adv = c.advancedDrills;
    final next = c.units.indexWhere((u) => score(u.id) < 80);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        if (story.isNotEmpty) _storyBubble(story),
        Text(
          c.intro,
          style: TextStyle(color: p.ink, fontSize: OxType.body),
        ),
        if (c.introBn.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            c.introBn,
            style: TextStyle(color: p.muted, fontSize: OxType.small),
          ),
        ],
        const SizedBox(height: 12),
        _card(
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Units passed: $done of ${c.units.length}',
                      style: TextStyle(
                        color: p.ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: c.units.isEmpty ? 0 : done / c.units.length,
                        minHeight: 6,
                        color: p.green,
                        backgroundColor: p.surface2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Stars(p: p, n: state.labStars(labKey, c), size: 22),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < c.units.length; i++)
          _unitStep(context, c, i, i == next, i == c.units.length - 1),
        const SizedBox(height: 8),
        Text(
          'Challenges',
          style: TextStyle(
            color: p.ink,
            fontSize: OxType.subtitle,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (c.mastery.isNotEmpty)
              _chip(
                context,
                Icons.workspace_premium,
                'Mastery test',
                score('mastery'),
                LabDrillScreen(
                  state: state,
                  p: p,
                  title: '$title: mastery',
                  drills: c.mastery,
                  labKey: labKey,
                  unitId: 'mastery',
                ),
              ),
            if (adv.isNotEmpty)
              _chip(
                context,
                Icons.local_fire_department,
                'Advanced (${adv.length})',
                score('advanced'),
                LabDrillScreen(
                  state: state,
                  p: p,
                  title: '$title: advanced',
                  drills: adv,
                  labKey: labKey,
                  unitId: 'advanced',
                ),
              ),
            _chip(
              context,
              Icons.bolt,
              'Speed round 60s',
              score('speed'),
              LabDrillScreen(
                state: state,
                p: p,
                title: '$title: speed round',
                drills: c.allDrills,
                labKey: labKey,
                unitId: 'speed',
                seconds: 60,
              ),
              points: true,
            ),
            if (c.decide.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => showDecisionGuide(context, p, c),
                icon: Icon(Icons.alt_route, size: 16, color: p.accent),
                label: const Text('Quick guide'),
                style: _outline(),
              ),
          ],
        ),
      ],
    );
  }

  Widget _storyBubble(String text) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: p.accentSoft,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: p.brand,
          child: Text(
            'R',
            style: TextStyle(color: p.onBrand, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: p.accent, fontSize: OxType.small),
          ),
        ),
      ],
    ),
  );

  /// A unit as a step on a vertical path: number/check, title, stars, line to the next one.
  Widget _unitStep(BuildContext context, Lab c, int i, bool isNext, bool last) {
    final u = c.units[i];
    final sc = state.labScore(labKey, u.id);
    final passed = sc >= 80;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: passed ? p.green : (isNext ? p.brand : p.surface2),
                    boxShadow: isNext
                        ? [
                            BoxShadow(
                              color: p.brand.withValues(alpha: 0.35),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: passed
                      ? Icon(Icons.check, color: readableOn(p.green), size: 20)
                      : Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: isNext ? p.onBrand : p.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 3,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: passed ? p.green : p.line,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LabUnitScreen(
                      state: state,
                      p: p,
                      labKey: labKey,
                      unit: u,
                      num: i + 1,
                    ),
                  ),
                ),
                child: _card(
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isNext)
                              Text(
                                'UP NEXT',
                                style: TextStyle(
                                  color: p.accent,
                                  fontSize: OxType.micro,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            Text(
                              u.title,
                              style: TextStyle(
                                color: p.ink,
                                fontSize: OxType.subtitle,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${u.level} · ${u.drills.length} drills${sc >= 0 ? ' · best $sc%' : ''}',
                              style: TextStyle(
                                color: p.muted,
                                fontSize: OxType.caption,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Stars(p: p, n: AppState.starsFor(sc), size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    IconData icon,
    String label,
    int best,
    Widget screen, {
    bool points = false,
  }) => OutlinedButton.icon(
    onPressed: () =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)),
    icon: Icon(icon, size: 16, color: p.accent),
    label: Text(
      best < 0 ? label : '$label · ${points ? 'best $best' : '$best%'}',
    ),
    style: _outline(),
  );

  ButtonStyle _outline() => OutlinedButton.styleFrom(
    foregroundColor: p.accent,
    side: BorderSide(color: p.accent),
  );

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: p.surface,
      border: Border.all(color: p.line),
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );
}

/// 0–3 stars in a row.
class Stars extends StatelessWidget {
  final OxPalette p;
  final int n;
  final double size;
  const Stars({super.key, required this.p, required this.n, this.size = 18});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < 3; i++)
        Icon(
          i < n ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: i < n ? starColor(p) : p.faint,
        ),
    ],
  );
}

/// Interactive yes/no flow that ends at the right answer.
void showDecisionGuide(BuildContext context, OxPalette p, Lab c) {
  var step = 0;
  String? result;
  showModalBottomSheet(
    context: context,
    backgroundColor: p.surface,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final done = result != null;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick guide',
                style: TextStyle(
                  color: p.ink,
                  fontSize: OxType.title,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Think of your sentence and answer each question.',
                style: TextStyle(color: p.muted, fontSize: OxType.small),
              ),
              const SizedBox(height: 16),
              if (!done) ...[
                Text(
                  'Step ${step + 1} of ${c.decide.length}',
                  style: TextStyle(color: p.muted, fontSize: OxType.caption),
                ),
                const SizedBox(height: 4),
                Text(
                  c.decide[step].q,
                  style: TextStyle(color: p.ink, fontSize: OxType.subtitle),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    FilledButton(
                      onPressed: () => set(() => result = c.decide[step].yes),
                      style: FilledButton.styleFrom(
                        backgroundColor: p.brand,
                        foregroundColor: p.onBrand,
                      ),
                      child: const Text('Yes'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: p.accent,
                        side: BorderSide(color: p.accent),
                      ),
                      onPressed: () => set(() {
                        if (step == c.decide.length - 1) {
                          result = c.decide[step].no;
                        } else {
                          step++;
                        }
                      }),
                      child: const Text('No'),
                    ),
                  ],
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: p.greenSoft,
                    border: Border.all(color: p.green),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    result ?? '',
                    style: TextStyle(color: p.ink, fontSize: OxType.subtitle),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: p.accent,
                    side: BorderSide(color: p.accent),
                  ),
                  onPressed: () => set(() {
                    step = 0;
                    result = null;
                  }),
                  child: const Text('Start again'),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}

class LabUnitScreen extends StatelessWidget {
  final AppState state;
  final OxPalette p;
  final String labKey;
  final LabUnit unit;
  final int num;
  const LabUnitScreen({
    super.key,
    required this.state,
    required this.p,
    required this.labKey,
    required this.unit,
    required this.num,
  });

  @override
  Widget build(BuildContext context) {
    final u = unit;
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.bg,
        foregroundColor: p.ink,
        title: Text('Unit $num · ${u.level}'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LabDrillScreen(
                  state: state,
                  p: p,
                  title: u.title,
                  drills: u.drills,
                  labKey: labKey,
                  unitId: u.id,
                ),
              ),
            ),
            icon: const Icon(Icons.play_arrow, size: 18),
            label: Text('Practise ${u.drills.length} drills'),
            style: FilledButton.styleFrom(
              backgroundColor: p.brand,
              foregroundColor: p.onBrand,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text(
            u.title,
            style: TextStyle(
              color: p.ink,
              fontSize: OxType.heading,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          _box(
            p.noticeBg,
            p.noticeLine,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Core idea', style: _label()),
                Text(
                  u.idea,
                  style: TextStyle(color: p.noticeInk, fontSize: OxType.body),
                ),
                const SizedBox(height: 6),
                Text(
                  u.ideaBn,
                  style: TextStyle(color: p.noticeInk, fontSize: OxType.small),
                ),
              ],
            ),
          ),
          if (u.timeline.isNotEmpty) ...[
            _heading('See it on the timeline'),
            _box(p.surface, p.line, LabTimeline(p: p, marks: u.timeline)),
          ],
          _heading('Pattern'),
          for (final f in u.formula)
            _box(
              p.surface,
              p.line,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    f.name,
                    style: TextStyle(
                      color: p.accent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _row(f.neg.isEmpty && f.q.isEmpty ? '•' : '+', f.pos),
                  if (f.neg.isNotEmpty) _row('−', f.neg),
                  if (f.q.isNotEmpty) _row('?', f.q),
                ],
              ),
            ),
          _heading('When to use it'),
          for (final x in u.uses)
            _box(
              p.surface,
              p.line,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    x.rule,
                    style: TextStyle(color: p.ink, fontSize: OxType.body),
                  ),
                  if (x.bn.isNotEmpty)
                    Text(
                      x.bn,
                      style: TextStyle(color: p.muted, fontSize: OxType.small),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    x.ex,
                    style: TextStyle(
                      color: p.accent,
                      fontStyle: FontStyle.italic,
                      fontSize: OxType.small,
                    ),
                  ),
                ],
              ),
            ),
          if (u.signals.isNotEmpty) ...[
            _heading('Key words'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in u.signals)
                  Chip(
                    label: Text(s),
                    backgroundColor: p.accentSoft,
                    labelStyle: TextStyle(
                      color: p.accent,
                      fontSize: OxType.caption,
                    ),
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
          if (u.traps.isNotEmpty) ...[
            _heading('Common traps for Bangla speakers'),
            for (final t in u.traps) _Trap(p: p, t: t),
          ],
        ],
      ),
    );
  }

  TextStyle _label() => TextStyle(color: p.muted, fontSize: OxType.caption);

  Widget _heading(String t) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(
      t,
      style: TextStyle(
        color: p.ink,
        fontSize: OxType.subtitle,
        fontWeight: FontWeight.w500,
      ),
    ),
  );

  Widget _row(String sign, String text) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 18,
          child: Text(
            sign,
            style: TextStyle(color: p.muted, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: p.ink, fontSize: OxType.small),
          ),
        ),
      ],
    ),
  );

  Widget _box(Color bg, Color line, Widget child) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: bg,
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(14),
    ),
    child: child,
  );
}

/// A trap card: the wrong sentence first; tap to reveal the fix and the reason.
class _Trap extends StatefulWidget {
  final OxPalette p;
  final ({String wrong, String right, String why, String bn}) t;
  const _Trap({required this.p, required this.t});
  @override
  State<_Trap> createState() => _TrapState();
}

class _TrapState extends State<_Trap> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    final p = widget.p, t = widget.t;
    return InkWell(
      onTap: () => setState(() => _open = !_open),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.surface,
          border: Border.all(color: _open ? p.green : p.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.close, size: 16, color: p.red),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    t.wrong,
                    style: TextStyle(
                      color: legible(p.red, p),
                      decoration: TextDecoration.lineThrough,
                      fontSize: OxType.body,
                    ),
                  ),
                ),
              ],
            ),
            if (!_open)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'What is wrong? Think, then tap to check.',
                  style: TextStyle(color: p.muted, fontSize: OxType.caption),
                ),
              )
            else ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.check, size: 16, color: p.green),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      t.right,
                      style: TextStyle(color: p.ink, fontSize: OxType.body),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                t.why,
                style: TextStyle(color: p.muted, fontSize: OxType.small),
              ),
              if (t.bn.isNotEmpty)
                Text(
                  t.bn,
                  style: TextStyle(color: p.muted, fontSize: OxType.small),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Draws past ← now → future with the unit's marks.
class LabTimeline extends StatelessWidget {
  final OxPalette p;
  final List<TimelineMark> marks;
  const LabTimeline({super.key, required this.p, required this.marks});

  static const _colors = [0, 1, 2];

  @override
  Widget build(BuildContext context) {
    final cols = [p.accent, p.orange, p.green];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 34.0 + marks.length * 16,
          width: double.infinity,
          child: CustomPaint(painter: _TimelinePainter(p, marks, cols)),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < marks.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: cols[i % _colors.length],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    marks[i].label,
                    style: TextStyle(color: p.ink, fontSize: OxType.small),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TimelinePainter extends CustomPainter {
  final OxPalette p;
  final List<TimelineMark> marks;
  final List<Color> cols;
  _TimelinePainter(this.p, this.marks, this.cols);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final axisY = size.height - 16;
    double x(double v) => 12 + (v + 1) / 2 * (w - 24);
    final axis = Paint()
      ..color = p.muted
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(4, axisY), Offset(w - 4, axisY), axis);
    // Arrow head toward the future.
    canvas.drawLine(Offset(w - 4, axisY), Offset(w - 10, axisY - 4), axis);
    canvas.drawLine(Offset(w - 4, axisY), Offset(w - 10, axisY + 4), axis);
    // "Now" tick.
    final nowPaint = Paint()
      ..color = p.ink
      ..strokeWidth = 2;
    canvas.drawLine(Offset(x(0), axisY - 6), Offset(x(0), axisY + 6), nowPaint);
    _text(canvas, 'past', Offset(6, axisY + 3), p.muted);
    _text(canvas, 'now', Offset(x(0) - 10, axisY + 3), p.ink);
    _text(canvas, 'future', Offset(w - 40, axisY + 3), p.muted);

    for (var i = 0; i < marks.length; i++) {
      final m = marks[i];
      final c = cols[i % cols.length];
      final y = axisY - 12 - i * 16.0;
      final paint = Paint()
        ..color = c
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final dot = Paint()..color = c;
      switch (m.kind) {
        case 'point':
          canvas.drawCircle(Offset(x(m.from), axisY), 6, dot);
          canvas.drawLine(
            Offset(x(m.from), axisY),
            Offset(x(m.from), y),
            Paint()
              ..color = c.withValues(alpha: 0.4)
              ..strokeWidth = 1,
          );
          canvas.drawCircle(Offset(x(m.from), y), 3, dot);
        case 'span':
          canvas.drawLine(Offset(x(m.from), y), Offset(x(m.to), y), paint);
        case 'arrow':
          canvas.drawLine(Offset(x(m.from), y), Offset(x(m.to), y), paint);
          canvas.drawCircle(Offset(x(m.from), y), 4, dot);
          canvas.drawLine(
            Offset(x(m.to), y),
            Offset(x(m.to) - 7, y - 5),
            paint,
          );
          canvas.drawLine(
            Offset(x(m.to), y),
            Offset(x(m.to) - 7, y + 5),
            paint,
          );
        case 'wave':
          final path = Path()..moveTo(x(m.from), y);
          final a = x(m.from), b = x(m.to);
          for (var px = a; px <= b; px += 2) {
            path.lineTo(px, y + sin((px - a) / 4) * 3);
          }
          canvas.drawPath(path, paint..strokeWidth = 2.5);
        case 'repeat':
          final a = x(m.from), b = x(m.to);
          for (var px = a; px <= b; px += (b - a) / 8) {
            canvas.drawLine(
              Offset(px, y - 4),
              Offset(px, y + 4),
              paint..strokeWidth = 3,
            );
          }
      }
    }
  }

  void _text(Canvas canvas, String t, Offset o, Color c) {
    final tp = TextPainter(
      text: TextSpan(
        text: t,
        style: TextStyle(color: c, fontSize: 10.4),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, o);
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter old) => old.marks != marks;
}

/// Runs drills with XP, combos, a second chance on missed drills, listen and speak practice,
/// and a star result. With [seconds] it is a speed round: countdown, endless drills, score = correct.
class LabDrillScreen extends StatefulWidget {
  final AppState state;
  final OxPalette p;
  final String title;
  final List<LabDrill> drills;
  final String labKey;
  final String unitId;
  final int? seconds;
  final int? limit;
  final int bonusXp;
  final VoidCallback? onFinished;
  const LabDrillScreen({
    super.key,
    required this.state,
    required this.p,
    required this.title,
    required this.drills,
    required this.labKey,
    required this.unitId,
    this.seconds,
    this.limit,
    this.bonusXp = 0,
    this.onFinished,
  });

  @override
  State<LabDrillScreen> createState() => _LabDrillScreenState();
}

class _Item {
  final LabDrill d;
  final bool retry;
  _Item(this.d, this.retry);
}

class _LabDrillScreenState extends State<LabDrillScreen> {
  final _rng = Random();
  final _input = TextEditingController();
  final _focus = FocusNode();
  late List<_Item> _items;
  int _firstPass = 0;
  final List<String> _given = [];
  final List<bool> _ok = [];
  int _index = 0;
  String? _chosen;
  bool _lastOk = false;
  bool _finished = false;
  Timer? _timer;
  int _left = 0;
  int _xp = 0;
  int _combo = 0;
  int _bestCombo = 0;
  String _praise = '';
  bool _spoke = false;
  bool _listening = false;
  String _heard = '';

  OxPalette get p => widget.p;
  bool get _speed => widget.seconds != null;

  static const _praises = [
    'Nice!',
    'Spot on!',
    'Exactly right.',
    'Great job!',
    'You nailed it.',
    'Native-level!',
    'Perfect.',
  ];
  static const _comfort = [
    'Almost! Read why below.',
    'Good try. This one is tricky.',
    'Not yet. You will see it again.',
  ];

  late final QuizVoice _voice = QuizVoice(
    s: widget.state,
    options: () =>
        _finished || _index >= _items.length || _items[_index].d.typed
        ? const []
        : _items[_index].d.options,
    lang: () => 'en',
    canAnswer: () =>
        !_finished &&
        _chosen == null &&
        _index < _items.length &&
        !_items[_index].d.typed,
    onPick: _answer,
  );

  @override
  void initState() {
    super.initState();
    _start();
    if (widget.state.voiceAnswers) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _voice.listen());
    }
  }

  LabDrill _shuffled(LabDrill d) => LabDrill(
    type: d.type,
    prompt: d.prompt,
    sentence: d.sentence,
    hint: d.hint,
    options: [...d.options]..shuffle(_rng),
    answers: d.answers,
    explain: d.explain,
    advanced: d.advanced,
  );

  void _start() {
    _timer?.cancel();
    var pool = [...widget.drills]..shuffle(_rng);
    if (widget.limit != null && pool.length > widget.limit!) {
      pool = pool.sublist(0, widget.limit!);
    }
    _items = [for (final d in pool) _Item(_shuffled(d), false)];
    _firstPass = _items.length;
    _given.clear();
    _ok.clear();
    _index = 0;
    _chosen = null;
    _finished = false;
    _xp = 0;
    _combo = 0;
    _bestCombo = 0;
    _input.clear();
    _resetSpeak();
    if (_speed) {
      _left = widget.seconds!;
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _left--);
        if (_left <= 0) _finish();
      });
    }
  }

  void _resetSpeak() {
    _spoke = false;
    _heard = '';
    _listening = false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _voice.dispose();
    Speech.stop();
    VoiceAnswer.stop();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// First-attempt results only (retries do not change the score).
  int get _score => [
    for (var i = 0; i < _ok.length && i < _firstPass; i++)
      if (_ok[i]) 1,
  ].length;

  int get _pct => _firstPass == 0 ? 0 : (_score / _firstPass * 100).round();

  void _finish() {
    _timer?.cancel();
    if (_finished) return;
    final score = _speed ? _score : _pct;
    if (!_speed && _pct >= 80) _xp += widget.bonusXp;
    widget.state.saveLabResult(widget.labKey, widget.unitId, score, _xp);
    widget.onFinished?.call();
    HapticFeedback.mediumImpact();
    _voice.stop();
    setState(() => _finished = true);
  }

  void _answer(String v) {
    if (_chosen != null || v.trim().isEmpty) return;
    final it = _items[_index];
    final ok = it.d.isCorrect(v);
    _voice.stop();
    setState(() {
      _chosen = v;
      _lastOk = ok;
      _given.add(v);
      _ok.add(ok);
      if (ok) {
        _combo++;
        _bestCombo = max(_bestCombo, _combo);
        _xp += _speed ? 5 : (it.retry ? 3 : 10);
        if (_combo >= 3 && !_speed) _xp += 5;
        _praise = _combo >= 3
            ? 'Combo x$_combo! +5 bonus'
            : _praises[_rng.nextInt(_praises.length)];
      } else {
        _combo = 0;
        _praise = _comfort[_rng.nextInt(_comfort.length)];
        // Second chance at the end of the lesson (not in speed rounds or retries).
        if (!_speed && !it.retry) _items.add(_Item(_shuffled(it.d), true));
      }
    });
    ok ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();
    if (_speed) {
      Future.delayed(Duration(milliseconds: ok ? 450 : 1400), () {
        if (mounted && !_finished) _next();
      });
    }
  }

  void _next() {
    Speech.stop();
    VoiceAnswer.stop();
    if (_index + 1 >= _items.length) {
      if (_speed) {
        _items.addAll([
          for (final d in [...widget.drills]..shuffle(_rng))
            _Item(_shuffled(d), false),
        ]);
        _firstPass = _items.length;
      } else {
        _finish();
        return;
      }
    }
    setState(() {
      _index++;
      _chosen = null;
      _input.clear();
      _resetSpeak();
    });
    if (_items[_index].d.typed) {
      _focus.requestFocus();
    } else {
      _voice.listen();
    }
  }

  /// The full correct sentence, for listening and speaking.
  String _target(LabDrill d) {
    if (d.sentence.isEmpty) return d.answer;
    final a = d.answer == '—' ? '' : d.answer;
    return d.sentence
        .replaceFirst('___', a)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static List<String> _words(String s) =>
      LabDrill.norm(s).split(' ').where((w) => w.isNotEmpty).toList();

  /// Share of the target's words that were heard (order ignored).
  static double _match(String target, String heard) {
    final t = _words(target), h = _words(heard).toSet();
    if (t.isEmpty) return 0;
    return t.where(h.contains).length / t.length;
  }

  Future<void> _sayIt(LabDrill d) async {
    if (_listening) {
      await VoiceAnswer.stop();
      setState(() => _listening = false);
      return;
    }
    Speech.stop();
    final target = _target(d);
    setState(() {
      _listening = true;
      _heard = '';
    });
    final r = await VoiceAnswer.listen(
      'en',
      match: (g) => g.any((x) => _match(target, x) >= 0.8) ? 'ok' : null,
      onPartial: (t) {
        if (mounted) setState(() => _heard = t);
      },
    );
    if (!mounted) return;
    final good = r.option != null;
    setState(() {
      _listening = false;
      _heard = r.heard;
      if (good && !_spoke) {
        _spoke = true;
        _xp += 5;
        HapticFeedback.lightImpact();
      }
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
        actions: [
          if (!_finished) VoiceToggleChip(voice: _voice, p: p),
          if (!_finished)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(child: _xpBadge()),
            ),
        ],
      ),
      body: SafeArea(child: _finished ? _result() : _drill()),
    );
  }

  Widget _xpBadge() => AnimatedSwitcher(
    duration: const Duration(milliseconds: 250),
    transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
    child: Container(
      key: ValueKey(_xp),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: p.accentSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$_xp XP',
        style: TextStyle(
          color: p.accent,
          fontWeight: FontWeight.w700,
          fontSize: OxType.small,
        ),
      ),
    ),
  );

  static const _typeLabel = {
    'choose': 'Choose the right form',
    'type': 'Type the missing words',
    'fix': 'Find the correct sentence',
    'bn': 'Bangla to English',
  };

  Widget _drill() {
    final it = _items[_index];
    final d = it.d;
    final answered = _chosen != null;
    final right = answered && _lastOk;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _speed
                    ? 'Correct $_score · Answered ${_ok.length}'
                    : it.retry
                    ? 'Second chance · fix the ones you missed'
                    : 'Question ${_index + 1} of $_firstPass',
                style: TextStyle(
                  color: it.retry ? legible(p.orange, p) : p.muted,
                  fontSize: OxType.small,
                ),
              ),
            ),
            if (_combo >= 2)
              Row(
                children: [
                  Icon(
                    Icons.local_fire_department,
                    size: 18,
                    color: legible(p.orange, p),
                  ),
                  Text(
                    'x$_combo',
                    style: TextStyle(
                      color: legible(p.orange, p),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            if (_speed)
              Text(
                '${_left}s',
                style: TextStyle(
                  color: _left <= 10 ? p.red : p.ink,
                  fontWeight: FontWeight.w600,
                  fontSize: OxType.subtitle,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _speed
                ? _left / widget.seconds!
                : (_index / _items.length).clamp(0.0, 1.0),
            minHeight: 8,
            color: _speed && _left <= 10 ? p.red : p.green,
            backgroundColor: p.surface2,
          ),
        ),
        const SizedBox(height: 12),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: p.surface,
            border: Border.all(
              color: !answered ? p.line : (right ? p.green : p.red),
              width: answered ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_typeLabel[d.type] ?? ''}${d.advanced ? ' · Advanced' : ''}',
                style: TextStyle(
                  color: p.accent,
                  fontSize: OxType.caption,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              if (d.prompt.isNotEmpty)
                Text(
                  d.prompt,
                  style: TextStyle(
                    color: d.type == 'bn' ? p.ink : p.muted,
                    fontSize: d.type == 'bn' ? OxType.title : OxType.body,
                  ),
                ),
              if (d.sentence.isNotEmpty) ...[
                const SizedBox(height: 12),
                _sentence(d),
              ],
              if (d.typed) ...[
                const SizedBox(height: 8),
                Text(
                  'Hint: ${d.hint}',
                  style: TextStyle(color: p.muted, fontSize: OxType.small),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _input,
                  focusNode: _focus,
                  autofocus: true,
                  enabled: !answered,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: _answer,
                  style: TextStyle(color: p.ink, fontSize: OxType.subtitle),
                  decoration: InputDecoration(
                    hintText: 'Type here',
                    filled: true,
                    fillColor: answered
                        ? (right ? p.greenSoft : p.redSoft)
                        : p.blankBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: answered
                        ? null
                        : IconButton(
                            icon: Icon(Icons.send, color: p.accent),
                            onPressed: () => _answer(_input.text),
                          ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 14),
                for (final o in d.options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _option(o, d),
                  ),
                if (widget.state.voiceAnswers && !answered)
                  VoicePanel(voice: _voice, p: p),
              ],
              if (answered) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      right ? Icons.check_circle : Icons.info,
                      color: right ? p.green : p.red,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        right ? _praise : '$_praise  Answer: ${d.answer}',
                        style: TextStyle(
                          color: legible(right ? p.green : p.red, p),
                          fontWeight: FontWeight.w600,
                          fontSize: OxType.small,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  d.explain,
                  style: TextStyle(color: p.muted, fontSize: OxType.small),
                ),
                if (!_speed) ...[const SizedBox(height: 10), _speakRow(d)],
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton(
              onPressed: _speed ? _finish : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: p.accent,
                side: BorderSide(color: p.accent),
              ),
              child: Text(_speed ? 'Stop' : 'Exit'),
            ),
            const Spacer(),
            if (!_speed)
              FilledButton(
                onPressed: answered ? _next : null,
                style: FilledButton.styleFrom(
                  backgroundColor: p.brand,
                  foregroundColor: p.onBrand,
                ),
                child: Text(
                  _index + 1 == _items.length ? 'See result' : 'Continue',
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Listen to the correct sentence, then say it aloud (+5 XP when it matches).
  Widget _speakRow(LabDrill d) {
    final target = _target(d);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: p.surface2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Say it aloud',
            style: TextStyle(color: p.muted, fontSize: OxType.caption),
          ),
          Text(
            target,
            style: TextStyle(color: p.ink, fontSize: OxType.body),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.accent,
                  side: BorderSide(color: p.line),
                ),
                onPressed: () => Speech.speak(target),
                icon: Icon(Icons.volume_up, size: 16, color: p.accent),
                label: const Text('Listen'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.accent,
                  side: BorderSide(color: p.line),
                ),
                onPressed: _spoke ? null : () => _sayIt(d),
                icon: Icon(
                  _spoke ? Icons.check : (_listening ? Icons.stop : Icons.mic),
                  size: 16,
                  color: _spoke ? p.green : p.accent,
                ),
                label: Text(
                  _spoke
                      ? 'Great! +5 XP'
                      : (_listening ? 'Listening…' : 'Say it'),
                ),
              ),
            ],
          ),
          if (_heard.isNotEmpty && !_spoke)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _listening
                    ? 'Heard: $_heard'
                    : 'Heard: "$_heard". Try once more, a little slower.',
                style: TextStyle(color: p.muted, fontSize: OxType.caption),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sentence(LabDrill d) {
    final parts = d.sentence.split('___');
    final style = TextStyle(
      color: p.ink,
      fontSize: 19.2,
      fontWeight: FontWeight.w500,
    );
    final filled = _chosen != null;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          Text(parts[i], style: style),
          if (i < parts.length - 1)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: p.accent, width: 2)),
              ),
              child: Text(
                filled ? d.answer : '      ',
                style: style.copyWith(
                  color: filled ? legible(p.green, p) : p.accent,
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _option(String o, LabDrill d) {
    final answered = _chosen != null;
    return QuizOptionTile(
      p: p,
      label: o,
      state: QuizOptionTile.stateFor(o, d.answer, _chosen),
      onTap: answered ? null : () => _answer(o),
    );
  }

  Widget _result() {
    final stars = _speed
        ? (_score >= 20
              ? 3
              : _score >= 12
              ? 2
              : _score >= 6
              ? 1
              : 0)
        : AppState.starsFor(_pct);
    final headline = _speed
        ? '$_score correct in ${widget.seconds} seconds'
        : 'Score: $_score of $_firstPass ($_pct%)';
    final band = _speed
        ? (_score >= 20
              ? 'Lightning fast. This is automatic for you now.'
              : 'Speed comes from the key words. Spot them first, then choose.')
        : _pct >= 95
        ? 'Flawless! You can use this without thinking.'
        : _pct >= 80
        ? 'Passed! One more round for three stars?'
        : _pct >= 60
        ? 'Good progress. Read the traps again, then go for 80%.'
        : 'Every expert started here. Read the lesson once more and try again.';
    final wrong = [
      for (var i = 0; i < _ok.length && i < _firstPass; i++)
        if (!_ok[i]) i,
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.3, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (c, v, child) => Transform.scale(scale: v, child: child),
            child: Stars(p: p, n: stars, size: 56),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            stars == 3
                ? 'Outstanding!'
                : stars >= 1
                ? 'Well done!'
                : 'Keep going!',
            style: TextStyle(
              fontSize: OxType.heading,
              fontWeight: FontWeight.w600,
              color: p.ink,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _stat('+$_xp', 'XP earned', p.accent),
            const SizedBox(width: 8),
            _stat('$_bestCombo', 'best combo', legible(p.orange, p)),
            const SizedBox(width: 8),
            _stat(
              _speed ? '$_score' : '$_pct%',
              _speed ? 'correct' : 'accuracy',
              legible(p.green, p),
            ),
          ],
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
                headline,
                style: TextStyle(fontWeight: FontWeight.w500, color: p.ink),
              ),
              const SizedBox(height: 4),
              Text(
                band,
                style: TextStyle(color: p.muted, fontSize: OxType.small),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton(
              onPressed: () {
                setState(_start);
                _voice.listen();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: p.accent,
                side: BorderSide(color: p.accent),
              ),
              child: const Text('Play again'),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: p.brand,
                foregroundColor: p.onBrand,
              ),
              child: const Text('Continue'),
            ),
          ],
        ),
        if (wrong.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Review your mistakes',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: OxType.subtitle,
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
                  if (_items[i].d.prompt.isNotEmpty)
                    Text(
                      _items[i].d.prompt,
                      style: TextStyle(
                        color: p.muted,
                        fontSize: OxType.caption,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(_target(_items[i].d), style: TextStyle(color: p.ink)),
                  Text(
                    'Your answer: ${_given[i]}',
                    style: TextStyle(
                      color: legible(p.red, p),
                      fontSize: OxType.small,
                    ),
                  ),
                  Text(
                    _items[i].d.explain,
                    style: TextStyle(color: p.muted, fontSize: OxType.small),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _stat(String v, String label, Color c) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            v,
            style: TextStyle(
              color: c,
              fontSize: OxType.title,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: p.muted, fontSize: OxType.caption),
          ),
        ],
      ),
    ),
  );
}
