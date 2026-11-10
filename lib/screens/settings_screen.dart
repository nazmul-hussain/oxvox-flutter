import 'package:flutter/material.dart';

import '../core/languages.dart';
import '../core/plan.dart';
import '../core/theme.dart';
import '../data/app_state.dart';
import '../services/backup_service.dart';
import '../services/speech.dart';
import '../services/voice_answer.dart';
import '../services/reminder_service.dart';
import '../widgets/confirm_dialog.dart';
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
  State<SettingsScreen> createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  String _section = 'menu';

  /// The plan as it was when the Study plan page opened. Leaving the page with a
  /// different plan asks whether to reset "days done" and start again from Day 1
  /// (old day numbers no longer match). Null while the page is not open.
  String? _planSigOnOpen;
  // Whether the device currently allows notifications (re-checked when the app comes back).
  bool _notifAllowed = true;

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
    WidgetsBinding.instance.addObserver(this);
    _checkNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _setMessage(String text) {
    if (!mounted) return;
    setState(() => _message = text);
  }

  /// Levels, days and the topics switch: the parts of the plan that change which
  /// words fall on which day.
  String _planSig(AppState s) =>
      '${(List.of(s.levels)..sort()).join(',')}|${s.planDays}|${s.includeTopics}';

  void _openSection(String id) {
    setState(() {
      _section = id;
      _planSigOnOpen = id == 'plan' ? _planSig(widget.state) : null;
    });
  }

  /// Web Settings.confirmPlanChange: leaving the Study plan page with a changed
  /// plan offers to reset "days done" and start again from Day 1. Called by
  /// HomeShell before it navigates away, as well as by Back and Close here.
  Future<void> confirmPlanChange() async {
    final s = widget.state;
    final before = _planSigOnOpen;
    if (_section != 'plan' || before == null || before == _planSig(s)) return;
    _planSigOnOpen = _planSig(s);
    if (s.completedDays.isEmpty && s.currentDay <= 1) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: const Text(
          'You changed your study plan. Reset "days done" and start again from Day 1?\n\n'
          'Words you have learned and quiz history are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep my days'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok == true) await s.resetPlanProgress();
  }

  /// Runs [fn] after the plan-change question has been answered.
  Future<void> _leave(VoidCallback fn) async {
    await confirmPlanChange();
    if (mounted) fn();
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
          onPressed: () => _leave(() => _openSection('menu')),
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
        onPressed: () => _leave(widget.onClose),
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
                onTap: () => _openSection(id),
                child: Ink(
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
                              style: TextStyle(
                                color: p.muted,
                                fontSize: OxType.caption,
                              ),
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
                      checkmarkColor: p.accentInk,
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
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120),
      child: Material(
        color: on ? p.accentSoft : p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: on ? p.accent : p.line, width: on ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            final next = [...s.levels];
            if (on) {
              next.remove(id);
            } else {
              next.add(id);
            }
            s.setLevels(next);
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
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
              if (langByCode(s.primaryLang) != null) ...[
                const SizedBox(height: 10),
                _MeaningVoicePicker(
                  key: ValueKey('voice-main-${s.primaryLang}'),
                  lang: langByCode(s.primaryLang)!,
                  p: p,
                ),
              ],
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
              if (langByCode(s.secondaryLang) != null) ...[
                const SizedBox(height: 10),
                _MeaningVoicePicker(
                  key: ValueKey('voice-${s.secondaryLang}'),
                  lang: langByCode(s.secondaryLang)!,
                  p: p,
                ),
              ],
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
                      checkmarkColor: p.accentInk,
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
                  Text(
                    'A',
                    style: TextStyle(color: p.muted, fontSize: OxType.caption),
                  ),
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
                  Text(
                    'A',
                    style: TextStyle(color: p.muted, fontSize: OxType.heading),
                  ),
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
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: p.ink,
                      ),
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
          if (s.reminderEnabled && !_notifAllowed) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: p.noticeBg,
                border: Border.all(color: p.noticeLine),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Notifications are off, so reminders will not show.',
                      style: TextStyle(color: p.noticeInk, fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: _allowNotifications,
                    child: const Text('Allow'),
                  ),
                ],
              ),
            ),
          ],
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
                        child: Ink(
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
                              Icon(
                                Icons.edit_outlined,
                                color: p.accent,
                                size: 18,
                              ),
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

  // Returning from system settings: check again so the warning goes away.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkNotifications();
  }

  Future<void> _checkNotifications() async {
    final ok = await ReminderService.notificationsAllowed();
    if (mounted && ok != _notifAllowed) setState(() => _notifAllowed = ok);
  }

  Future<void> _toggleReminders(bool on) async {
    final s = widget.state;
    if (on) {
      final granted = await ReminderService.requestPermission();
      await _checkNotifications();
      if (!granted) {
        _setMessage(
          'Notifications are off for oxvox. Tap Allow to turn them on in your phone settings.',
        );
        return;
      }
    }
    await s.setReminderEnabled(on);
  }

  Future<void> _allowNotifications() async {
    final granted = await ReminderService.requestPermission();
    await _checkNotifications();
    if (granted && !widget.state.reminderEnabled) {
      await widget.state.setReminderEnabled(true);
    }
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
    final signedIn = widget.state.isSignedIn;
    final go = await confirmAction(
      context,
      message:
          'Importing a backup replaces your current progress'
          '${signedIn ? ', including the progress saved in your account' : ''}. '
          'Export a backup first if you may want it back.',
      confirmLabel: 'Choose file',
    );
    if (!go || !mounted) return;
    final message = await BackupService.importBackup(widget.state);
    if (message != null) _setMessage(message);
  }

  Future<void> _confirmReset() async {
    final signedIn = widget.state.isSignedIn;
    final ok = await confirmAction(
      context,
      message:
          'Reset all progress? Your settings are kept.'
          '${signedIn ? ' This also clears the progress saved in your account.' : ''}',
      confirmLabel: 'Reset',
    );
    if (!ok || !mounted) return;
    await widget.state.resetProgress();
    _setMessage('Progress reset.');
  }
}

/// Pick which phone voice reads a meaning language (main or second). Android does not
/// say which voices are male, so the learner listens and chooses.
class _MeaningVoicePicker extends StatefulWidget {
  final MeaningLang lang;
  final OxPalette p;
  const _MeaningVoicePicker({super.key, required this.lang, required this.p});

  @override
  State<_MeaningVoicePicker> createState() => _MeaningVoicePickerState();
}

class _MeaningVoicePickerState extends State<_MeaningVoicePicker> {
  static const _auto = '';
  List<Map<String, String>>? _voices;
  String _chosen = _auto;

  String get _tag => VoiceAnswer.tagFor(widget.lang.code);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final voices = await Speech.voicesFor(_tag);
    final chosen = await Speech.chosenVoice(_tag);
    if (!mounted) return;
    setState(() {
      _voices = voices;
      _chosen = voices.any((v) => v['name'] == chosen) ? chosen! : _auto;
    });
  }

  Future<void> _pick(String name) async {
    setState(() => _chosen = name);
    await Speech.setChosenVoice(_tag, name == _auto ? null : name);
    await _preview();
  }

  /// Says the language's own name in the chosen voice (Automatic uses the
  /// phone's default voice for the language).
  Future<void> _preview() async {
    final voice = _voices?.where((v) => v['name'] == _chosen).firstOrNull;
    if (voice != null) {
      await Speech.speakWithVoice(widget.lang.native, voice);
    } else {
      await Speech.speakLang(widget.lang.native, _tag);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final voices = _voices;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${widget.lang.name} voice',
          style: TextStyle(fontWeight: FontWeight.w500, color: p.ink),
        ),
        const SizedBox(height: 2),
        Text(
          voices == null || voices.isNotEmpty
              ? 'Pick a voice to hear it. Tap the speaker to hear it again.'
              : 'No ${widget.lang.name} voice on this phone yet. Tap the speaker on a word to download one.',
          style: TextStyle(color: p.muted, fontSize: OxType.small),
        ),
        if (voices != null && voices.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('voice-${widget.lang.code}-$_chosen'),
                  initialValue: _chosen,
                  isExpanded: true,
                  dropdownColor: p.surface,
                  style: TextStyle(color: p.ink, fontSize: OxType.body),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: _auto,
                      child: Text('Automatic'),
                    ),
                    for (var i = 0; i < voices.length; i++)
                      DropdownMenuItem(
                        value: voices[i]['name'],
                        child: Text('Voice ${i + 1}'),
                      ),
                  ],
                  onChanged: (name) {
                    if (name != null) _pick(name);
                  },
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Hear this voice',
                onPressed: _preview,
                icon: Icon(Icons.volume_up_rounded, color: p.accent),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
