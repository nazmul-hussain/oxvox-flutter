import 'package:flutter/material.dart';

import '../core/plan.dart';
import '../core/theme.dart';
import '../data/app_state.dart';
import '../services/backup_service.dart';
import '../services/reminder_service.dart';
import 'account_panel.dart';
import 'placement_screen.dart';

/// Web: components/Settings.js. Menu (Study plan, Profile, App settings) and each sub-page.
class SettingsScreen extends StatefulWidget {
  final AppState state;
  final OxPalette p;
  final VoidCallback onClose;
  const SettingsScreen({
    super.key,
    required this.state,
    required this.p,
    required this.onClose,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _section = 'menu';
  // Web: message under the Data card (backup downloaded / restored, progress reset).
  String? _message;

  // Web THEMES (utils/theme.js), same order and labels.
  static const _themes = [
    ('auto', 'Auto'),
    ('day', 'Day'),
    ('afternoon', 'Afternoon'),
    ('night', 'Night'),
  ];

  @override
  void initState() {
    super.initState();
    // Web has no daily reminders; cancel one an older build may have scheduled.
    ReminderService.cancelLegacyReminder().catchError((_) {});
  }

  void _setMessage(String text) {
    if (!mounted) return;
    setState(() => _message = text);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(_titleFor(_section)),
          const SizedBox(height: 8),
          switch (_section) {
            'plan' => _plan(s),
            'profile' => _profile(s),
            'app' => _app(s),
            _ => _menu(s),
          },
        ],
      ),
    );
  }

  String _titleFor(String section) => switch (section) {
    'plan' => 'Study plan',
    'profile' => 'Profile',
    'app' => 'App settings',
    _ => 'Settings',
  };

  // Web header: back chevron on sub-pages, title, and a Close button on every page.
  Widget _header(String title) => Row(
    children: [
      if (_section != 'menu')
        IconButton(
          onPressed: () => setState(() => _section = 'menu'),
          icon: Icon(Icons.chevron_left, color: widget.p.accent),
          tooltip: 'Back to settings',
        ),
      Expanded(
        child: Text(
          title,
          style: TextStyle(
            fontSize: 22.4,
            fontWeight: FontWeight.w700,
            color: widget.p.ink,
          ),
        ),
      ),
      OutlinedButton(
        onPressed: widget.onClose,
        style: OutlinedButton.styleFrom(
          foregroundColor: widget.p.accent,
          side: BorderSide(color: widget.p.accent),
          textStyle: const TextStyle(
            fontSize: 13.6,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: const Text('Close'),
      ),
    ],
  );

  Widget _card(Widget child) => Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(vertical: 6),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: widget.p.surface,
      border: Border.all(color: widget.p.line),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: widget.p.shadow,
          offset: const Offset(0, 1),
          blurRadius: 2,
        ),
      ],
    ),
    child: child,
  );

  Widget _menu(AppState s) {
    final p = widget.p;
    final rows = [
      (
        'plan',
        'Study plan',
        '${s.levels.join(', ')} · ${s.planDays} days',
        Icons.calendar_month,
      ),
      (
        'profile',
        'Profile',
        s.accountName != null
            ? 'Signed in and synced'
            : 'Sign in to sync your progress',
        Icons.person_outline,
      ),
      ('app', 'App settings', 'Theme, backup, install, reset', Icons.tune),
    ];
    return Column(
      children: [
        for (final (id, title, sub, icon) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: p.surface,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() => _section = id),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: p.line),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: p.accentSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: p.accent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: p.ink,
                                fontSize: 15.2,
                              ),
                            ),
                            Text(
                              sub,
                              style: TextStyle(color: p.muted, fontSize: 12.8),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: p.muted),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _plan(AppState s) {
    final p = widget.p;
    final total = s.levelOptions.fold<int>(
      0,
      (n, l) => n + (l['count'] as int),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _card(
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level test',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                      ),
                    ),
                    Text(
                      '40 questions. Finds your starting level. Retakes use new words.',
                      style: TextStyle(color: p.muted, fontSize: 13.6),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PlacementScreen(state: s, p: p),
                  ),
                ),
                style: FilledButton.styleFrom(backgroundColor: p.brand),
                child: const Text('Start'),
              ),
            ],
          ),
        ),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Levels',
                style: TextStyle(fontWeight: FontWeight.w700, color: p.ink),
              ),
              Text(
                'Tap to pick one or more. All selected levels are mixed into one plan.',
                style: TextStyle(color: p.muted, fontSize: 13.6),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final l in s.levelOptions.where(
                    (l) => (l['count'] as int) > 0,
                  ))
                    _levelChip(s, l, s.levels.contains(l['id'])),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Finish in ${s.planDays} days',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                      ),
                    ),
                  ),
                  Text(
                    '${s.perDayText} words per day',
                    style: TextStyle(color: p.muted, fontSize: 13.6),
                  ),
                ],
              ),
              Slider(
                value: s.planDays.toDouble(),
                min: minPlanDays.toDouble(),
                max: maxPlanDays.toDouble(),
                divisions: maxPlanDays - minPlanDays,
                label: '${s.planDays} days',
                activeColor: p.accent,
                onChanged: (v) => s.setPlanDays(v.round()),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in AppState.planPresets)
                    ChoiceChip(
                      label: Text(_presetLabel(d)),
                      selected: s.planDays == d,
                      selectedColor: p.accent,
                      labelStyle: TextStyle(
                        color: s.planDays == d ? p.accentInk : p.ink,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) => s.setPlanDays(d),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${_fmtNum(s.planWords.length)} words in ${s.totalDays} days, ${s.perDayText} per day.',
                style: TextStyle(color: p.muted, fontSize: 13.6),
              ),
              Text(
                'All levels together: ${_fmtNum(total)} words.',
                style: TextStyle(color: p.muted, fontSize: 13.6),
              ),
            ],
          ),
        ),
        _card(
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Native-speech topics',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                      ),
                    ),
                    Text(
                      'Includes phrasal verbs, idioms, fillers, collocations, linkers, and hedging. Mixed into daily words, study, and quizzes.',
                      style: TextStyle(color: p.muted, fontSize: 13.6),
                    ),
                  ],
                ),
              ),
              Switch(
                value: s.includeTopics,
                activeThumbColor: p.accent,
                onChanged: (v) => s.setIncludeTopics(v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _levelChip(AppState s, Map<String, dynamic> l, bool on) {
    final p = widget.p;
    final id = l['id'] as String;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        final next = [...s.levels];
        if (on) {
          next.remove(id);
        } else {
          next.add(id);
        }
        s.setLevels(next);
      },
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: on ? p.accentSoft : p.surface,
          border: Border.all(color: on ? p.accent : p.line, width: on ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              id,
              style: TextStyle(fontWeight: FontWeight.w700, color: p.ink),
            ),
            Text(
              l['name'] as String,
              style: TextStyle(color: p.ink, fontSize: 12.8),
            ),
            if (s.placementSuggested == id)
              Text(
                'Level test',
                style: TextStyle(color: p.accent, fontSize: 12),
              ),
            Text(
              '${_fmtNum(l['count'] as int)} words',
              style: TextStyle(color: p.muted, fontSize: 12.8),
            ),
          ],
        ),
      ),
    );
  }

  static String _presetLabel(int d) => switch (d) {
    7 => '7 days',
    30 => '30 days',
    60 => '2 months',
    90 => '3 months',
    180 => '6 months',
    365 => '1 year',
    _ => '$d days',
  };

  // Thousands separators, like toLocaleString() on the web.
  static String _fmtNum(int n) {
    final digits = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  Widget _profile(AppState s) => AccountPanel(state: s, p: widget.p);

  Widget _app(AppState s) {
    final p = widget.p;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Theme',
                style: TextStyle(fontWeight: FontWeight.w700, color: p.ink),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (id, label) in _themes)
                    ChoiceChip(
                      label: Text(label),
                      selected: s.themeSetting == id,
                      selectedColor: p.accent,
                      labelStyle: TextStyle(
                        color: s.themeSetting == id ? p.accentInk : p.ink,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) => s.setTheme(id),
                    ),
                ],
              ),
            ],
          ),
        ),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Data',
                style: TextStyle(fontWeight: FontWeight.w700, color: p.ink),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _export,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.accent,
                      side: BorderSide(color: p.accent),
                    ),
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Export backup'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _import,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.accent,
                      side: BorderSide(color: p.accent),
                    ),
                    icon: const Icon(Icons.upload, size: 16),
                    label: const Text('Import backup'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _confirmReset,
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.red,
                  side: BorderSide(color: p.red),
                ),
                icon: const Icon(Icons.restart_alt, size: 16),
                label: const Text('Reset progress'),
              ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _message!,
                    style: TextStyle(color: p.muted, fontSize: 13.6),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _export() async {
    try {
      await BackupService.exportBackup(widget.state);
      _setMessage('Backup downloaded.');
    } catch (_) {
      _setMessage('Could not create the backup.');
    }
  }

  Future<void> _import() async {
    final message = await BackupService.importBackup(widget.state);
    if (message != null) _setMessage(message);
  }

  // Web: window.confirm with OK / Cancel.
  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: const Text('Reset all progress? Your settings are kept.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.state.resetProgress();
    _setMessage('Progress reset.');
  }
}
