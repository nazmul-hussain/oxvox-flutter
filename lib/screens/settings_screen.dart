import 'package:flutter/material.dart';

import '../core/languages.dart';
import '../core/plan.dart';
import '../core/theme.dart';
import '../data/app_state.dart';
import '../services/backup_service.dart';
import '../services/reminder_service.dart';
import '../widgets/join_groups_bar.dart';
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
            fontSize: OxType.heading,
            fontWeight: FontWeight.w500,
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
            fontSize: OxType.small,
            fontWeight: FontWeight.w500,
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
                                fontWeight: FontWeight.w500,
                                color: p.ink,
                                fontSize: OxType.body,
                              ),
                            ),
                            Text(
                              sub,
                              style: TextStyle(color: p.muted, fontSize: OxType.caption),
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
        JoinGroupsBar(p: p),
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
                        fontWeight: FontWeight.w500,
                        color: p.ink,
                      ),
                    ),
                    Text(
                      '40 questions. Finds your starting level. Retakes use new words.',
                      style: TextStyle(color: p.muted, fontSize: OxType.small),
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
                style: TextStyle(fontWeight: FontWeight.w500, color: p.ink),
              ),
              Text(
                'Tap to pick one or more. All selected levels are mixed into one plan.',
                style: TextStyle(color: p.muted, fontSize: OxType.small),
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
                        fontWeight: FontWeight.w500,
                        color: p.ink,
                      ),
                    ),
                  ),
                  Text(
                    '${s.perDayText} words per day',
                    style: TextStyle(color: p.muted, fontSize: OxType.small),
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
                        fontWeight: FontWeight.w400,
                      ),
                      onSelected: (_) => s.setPlanDays(d),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${_fmtNum(s.planWords.length)} words in ${s.totalDays} days, ${s.perDayText} per day.',
                style: TextStyle(color: p.muted, fontSize: OxType.small),
              ),
              Text(
                'All levels together: ${_fmtNum(total)} words.',
                style: TextStyle(color: p.muted, fontSize: OxType.small),
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
                        fontWeight: FontWeight.w500,
                        color: p.ink,
                      ),
                    ),
                    Text(
                      'Includes phrasal verbs, idioms, fillers, collocations, linkers, and hedging. Mixed into daily words, study, and quizzes.',
                      style: TextStyle(color: p.muted, fontSize: OxType.small),
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
      borderRadius: BorderRadius.circular(999),
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
                text: '  ${l['name'] as String}',
                style: TextStyle(color: p.ink, fontSize: 12.8),
              ),
              if (s.placementSuggested == id)
                TextSpan(
                  text: '  · test',
                  style: TextStyle(color: p.accent, fontSize: 11),
                ),
            ],
          ),
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

  Widget _langChips({
    required String selected,
    required ValueChanged<String> onPick,
    bool includeNone = false,
  }) {
    final p = widget.p;
    final value = (selected == secondaryNone || langByCode(selected) != null)
        ? selected
        : (includeNone ? secondaryNone : fallbackPrimaryLang);
    return DropdownButtonFormField<String>(
      key: ValueKey('lang-$includeNone-$value'),
      initialValue: value,
      isExpanded: true,
      dropdownColor: p.surface,
      style: TextStyle(color: p.ink, fontSize: OxType.body),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: [
        if (includeNone)
          const DropdownMenuItem(value: secondaryNone, child: Text('None')),
        for (final l in meaningLangs)
          DropdownMenuItem(
            value: l.code,
            child: Text('${l.native} (${l.name})'),
          ),
      ],
      onChanged: (code) {
        if (code != null) onPick(code);
      },
    );
  }

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
                'Meaning language',
                style: TextStyle(fontWeight: FontWeight.w500, color: p.ink),
              ),
              const SizedBox(height: 2),
              Text(
                'Shown on every word card, under the English word.',
                style: TextStyle(color: p.muted, fontSize: OxType.small),
              ),
              const SizedBox(height: 8),
              _langChips(
                selected: s.primaryLang,
                onPick: (code) => s.setPrimaryLang(code),
              ),
              const SizedBox(height: 14),
              Text(
                'Second language',
                style: TextStyle(fontWeight: FontWeight.w500, color: p.ink),
              ),
              const SizedBox(height: 2),
              Text(
                'Shown as a second line next to the meaning. Choose None to hide it.',
                style: TextStyle(color: p.muted, fontSize: OxType.small),
              ),
              const SizedBox(height: 8),
              _langChips(
                selected: s.secondaryLang,
                includeNone: true,
                onPick: (code) => s.setSecondaryLang(code),
              ),
            ],
          ),
        ),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Theme',
                style: TextStyle(fontWeight: FontWeight.w500, color: p.ink),
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
                        fontWeight: FontWeight.w400,
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
              Row(
                children: [
                  Text(
                    'Font size',
                    style: TextStyle(fontWeight: FontWeight.w500, color: p.ink),
                  ),
                  const Spacer(),
                  Text(
                    fontSizeLabel(s.fontScale),
                    style: TextStyle(color: p.muted, fontSize: OxType.small),
                  ),
                ],
              ),
              Row(
                children: [
                  Text('A', style: TextStyle(color: p.muted, fontSize: OxType.caption)),
                  Expanded(
                    child: Slider(
                      value: s.fontScale,
                      min: kMinFontScale,
                      max: kMaxFontScale,
                      divisions: kFontScaleDivisions,
                      label: fontSizeLabel(s.fontScale),
                      activeColor: p.accent,
                      onChanged: (v) => s.setFontScale(v),
                    ),
                  ),
                  Text('A', style: TextStyle(color: p.muted, fontSize: OxType.heading)),
                ],
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.bg,
                  border: Border.all(color: p.line),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'The quick brown fox jumps over the lazy dog.',
                      style: TextStyle(color: p.ink, fontSize: OxType.body),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ox Vox helps you learn a new word every day.',
                      style: TextStyle(color: p.ink, fontSize: OxType.body),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'abundant · curious · reliable',
                      style: TextStyle(
                        color: p.accent,
                        fontWeight: FontWeight.w500,
                        fontSize: OxType.subtitle,
                      ),
                    ),
                  ],
                ),
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
                style: TextStyle(fontWeight: FontWeight.w500, color: p.ink),
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
                    style: TextStyle(color: p.muted, fontSize: OxType.small),
                  ),
                ),
            ],
          ),
        ),
        _reminders(s),
      ],
    );
  }

  Widget _reminders(AppState s) {
    final p = widget.p;
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Study reminders',
                      style: TextStyle(fontWeight: FontWeight.w500, color: p.ink),
                    ),
                    Text(
                      'Get a notification at each time to study.',
                      style: TextStyle(color: p.muted, fontSize: 13.6),
                    ),
                  ],
                ),
              ),
              Switch(
                value: s.reminderEnabled,
                activeThumbColor: p.accent,
                onChanged: _toggleReminders,
              ),
            ],
          ),
          if (s.reminderEnabled) ...[
            const SizedBox(height: 8),
            Text(
              'Tap a time to change it',
              style: TextStyle(color: p.muted, fontSize: 12.8),
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < s.reminderTimes.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _editReminder(s, i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: p.accentSoft,
                            border: Border.all(color: p.accent, width: 1.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.schedule, color: p.accent, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _formatForDisplay(s.reminderTimes[i]),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: p.accent,
                                  ),
                                ),
                              ),
                              Icon(Icons.edit_outlined, color: p.accent, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove time',
                      onPressed: () => s.removeReminderTime(i),
                      icon: Icon(Icons.close, color: p.muted),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _editReminder(s, null),
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.accent,
                  side: BorderSide(color: p.accent),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add time'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _toggleReminders(bool on) async {
    final s = widget.state;
    if (on) {
      final granted = await ReminderService.requestPermission();
      if (!granted) {
        _setMessage('Allow notifications in your device settings to get reminders.');
        return;
      }
    }
    await s.setReminderEnabled(on);
  }

  Future<void> _editReminder(AppState s, int? index) async {
    final current = index == null
        ? const TimeOfDay(hour: 20, minute: 0)
        : _parseTime(s.reminderTimes[index]);
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked == null) return;
    final time = AppState.formatReminderTime(picked.hour, picked.minute);
    await s.setReminderTime(index: index, time: time);
  }

  static TimeOfDay _parseTime(String t) {
    final parts = t.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 20,
      minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );
  }

  String _formatForDisplay(String t) {
    final tod = _parseTime(t);
    return tod.format(context);
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
