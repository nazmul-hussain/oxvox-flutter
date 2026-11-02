import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../services/reminder_service.dart';

class SettingsScreen extends StatelessWidget {
  final AppState state;
  const SettingsScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          ListTile(
            title: const Text('Display name'),
            subtitle: Text(state.displayName?.isNotEmpty == true ? state.displayName! : 'Not set'),
            trailing: const Icon(Icons.edit),
            onTap: () => _editName(context),
          ),
          ListTile(
            title: const Text('Daily goal'),
            subtitle: Text('${state.dailyGoal} words per day'),
            trailing: DropdownButton<int>(
              value: state.dailyGoal,
              items: const [5, 10, 20, 30, 50]
                  .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                  .toList(),
              onChanged: (v) => state.setDailyGoal(v!),
            ),
          ),
          ListTile(
            title: const Text('Theme'),
            trailing: DropdownButton<String>(
              value: state.themeSetting,
              items: const [
                DropdownMenuItem(value: 'auto', child: Text('Auto')),
                DropdownMenuItem(value: 'day', child: Text('Day')),
                DropdownMenuItem(value: 'afternoon', child: Text('Afternoon')),
                DropdownMenuItem(value: 'night', child: Text('Night')),
              ],
              onChanged: (v) => state.setTheme(v!),
            ),
          ),
          const Divider(height: 32),
          SwitchListTile(
            title: const Text('Daily reminder'),
            subtitle: Text(state.reminderEnabled
                ? 'Every day at ${_fmtTime(state.reminderHour, state.reminderMinute)}'
                : 'Off'),
            value: state.reminderEnabled,
            onChanged: (on) => _toggleReminder(context, on),
          ),
          ListTile(
            enabled: state.reminderEnabled,
            title: const Text('Reminder time'),
            trailing: const Icon(Icons.schedule),
            onTap: () => _pickTime(context),
          ),
        ]),
      ),
    );
  }

  static String _fmtTime(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  Future<void> _toggleReminder(BuildContext context, bool on) async {
    if (on) {
      final granted = await ReminderService.requestPermission();
      if (!granted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Allow notifications in Android settings to get reminders.')),
          );
        }
        return;
      }
      await state.setReminder(enabled: true);
      await ReminderService.schedule(hour: state.reminderHour, minute: state.reminderMinute);
    } else {
      await state.setReminder(enabled: false);
      await ReminderService.cancel();
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: state.reminderHour, minute: state.reminderMinute),
    );
    if (t == null) return;
    await state.setReminder(hour: t.hour, minute: t.minute);
    await ReminderService.schedule(hour: t.hour, minute: t.minute);
  }

  Future<void> _editName(BuildContext context) async {
    final c = TextEditingController(text: state.displayName ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(controller: c, autofocus: true, maxLength: 30),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (result != null) await state.setDisplayName(result);
  }
}
