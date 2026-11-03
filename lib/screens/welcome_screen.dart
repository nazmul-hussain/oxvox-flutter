import 'package:flutter/material.dart';

import '../core/plan.dart';
import '../core/theme.dart';
import '../data/app_state.dart';
import 'auth_screen.dart';
import 'placement_screen.dart';

/// Web: components/Welcome.js. First-visit setup: levels and days to finish.
/// Shown once (AppState.onboarded). Place it inside a Stack, it fills the parent.
class WelcomeScreen extends StatefulWidget {
  final AppState state;
  final OxPalette p;

  /// Called from the level test's "Set my study plan" button.
  final VoidCallback? onOpenPlan;
  const WelcomeScreen({
    super.key,
    required this.state,
    required this.p,
    this.onOpenPlan,
  });

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  // Web Welcome starts from DEFAULT_LEVELS and DEFAULT_DAYS (60).
  List<String> _levels = List.of(defaultLevels);
  int _days = 60;
  bool _starting = false;

  static const _presets = [
    (30, '30 days'),
    (90, '3 months'),
    (180, '6 months'),
    (365, '1 year'),
  ];

  void _toggleLevel(String id) {
    final next = _levels.contains(id)
        ? _levels.where((x) => x != id).toList()
        : [..._levels, id];
    if (next.isNotEmpty) setState(() => _levels = next);
  }

  /// Web start(): levels, days, topics on (the preview assumes them), day 1, then onboarded.
  Future<void> _start() async {
    if (_starting) return;
    _starting = true;
    final s = widget.state;
    await s.setLevels(_levels);
    await s.setPlanDays(_days);
    await s.setIncludeTopics(true);
    await s.setDay(1);
    await s.setOnboarded();
  }

  static String _fmt(int n) {
    final digits = '$n';
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
      out.write(digits[i]);
    }
    return out.toString();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final s = widget.state;
    final options = s.levelOptions.where((l) => (l['count'] as int) > 0);
    final perDay = s.previewPerDayText(_levels, _days);

    return Positioned.fill(
      child: Container(
        color: const Color(0x730F172A),
        padding: EdgeInsets.fromLTRB(
          12,
          56 + MediaQuery.paddingOf(context).top,
          12,
          12 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              decoration: BoxDecoration(
                color: p.surface,
                border: Border.all(color: p.line),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: p.shadow,
                    offset: const Offset(0, 10),
                    blurRadius: 30,
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!s.isSignedIn)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 24),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => openAuth(context, widget.state, p),
                        child: Text(
                          'Already have an account? Log in',
                          style: TextStyle(color: p.accent, fontSize: 13.6),
                        ),
                      ),
                    ),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Welcome to OxVox',
                            style: TextStyle(
                              color: p.accent,
                              fontSize: 18.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Pick your levels and how many days to finish. You can change them anytime in Settings.',
                            style: TextStyle(color: p.muted, fontSize: 13.6),
                          ),
                          const SizedBox(height: 12),
                          _bold('Levels'),
                          const SizedBox(height: 6),
                          _levelGrid([
                            for (final l in options)
                              (
                                l['id'] as String,
                                l['name'] as String,
                                l['count'] as int,
                              ),
                          ]),
                          const SizedBox(height: 12),
                          _bold('Finish in'),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '$_days days',
                                  style: TextStyle(color: p.ink),
                                ),
                              ),
                              Text(
                                '$perDay words per day',
                                style: TextStyle(
                                  color: p.muted,
                                  fontSize: 13.6,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: _days.toDouble(),
                            min: minPlanDays.toDouble(),
                            max: maxPlanDays.toDouble(),
                            label: '$_days days',
                            onChanged: (v) => setState(() => _days = v.round()),
                          ),
                          Row(
                            children: [
                              for (final (days, label) in _presets) ...[
                                Expanded(child: _preset(days, label)),
                                if (days != _presets.last.$1)
                                  const SizedBox(width: 6),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PlacementScreen(
                          state: widget.state,
                          p: p,
                          onOpenPlan: widget.onOpenPlan,
                        ),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.accent,
                      side: BorderSide(color: p.accent),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Take a level test'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _start,
                    style: FilledButton.styleFrom(
                      backgroundColor: p.brand,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15.2,
                      ),
                    ),
                    child: const Text('Start learning'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bold(String text) => Text(
    text,
    style: TextStyle(
      fontWeight: FontWeight.w500,
      fontSize: 13.6,
      color: widget.p.ink,
    ),
  );

  /// Compact pills in a wrapping row, so all levels fit in one or two lines.
  Widget _levelGrid(List<(String, String, int)> items) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [for (final (id, name, count) in items) _levelChip(id, name, count)],
    );
  }

  /// Compact level pill: CEFR code and level name (same look as Settings > Study plan).
  Widget _levelChip(String id, String name, int count) {
    final p = widget.p;
    final on = _levels.contains(id);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => _toggleLevel(id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: on ? p.accentSoft : p.surface,
          border: Border.all(
            color: on ? p.accent : p.line,
            width: on ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: id,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: on ? p.accent : p.muted,
                ),
              ),
              TextSpan(
                text: '  $name',
                style: TextStyle(color: p.ink, fontSize: 12.8),
              ),
              TextSpan(
                text: '\n${_fmt(count)} words',
                style: TextStyle(color: p.muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Web .seg button for the day presets.
  Widget _preset(int days, String label) {
    final p = widget.p;
    final on = _days == days;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _days = days),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? p.accent : p.surface,
          border: Border.all(color: on ? p.accent : p.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.8,
            fontWeight: FontWeight.w500,
            color: on ? p.accentInk : p.muted,
          ),
        ),
      ),
    );
  }
}
