import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';
import '../data/app_state.dart';
import 'lesson_screen.dart';

class TodayScreen extends StatelessWidget {
  final AppState state;
  const TodayScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final done = state.todayWords;
    final goal = state.dailyGoal;
    final progress = goal == 0 ? 0.0 : (done / goal).clamp(0.0, 1.0);
    final name = state.displayName;

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              name == null || name.isEmpty ? 'Hello!' : 'Hello, $name',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text('Streak: ${state.streak} day(s)'),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: Stack(alignment: Alignment.center, children: [
                        CircularProgressIndicator(value: progress, strokeWidth: 7),
                        Text('$done/$goal', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ]),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Today\'s goal', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('${state.dueWords.length} words due for review'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Listening lessons', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...state.lessons.take(10).map((l) => Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${l.number}')),
                    title: Text(l.title),
                    subtitle: Text('${l.lines.length} lines'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => LessonScreen(state: state, lesson: l),
                    )),
                  ),
                )),
            const SizedBox(height: 16),
            Text('Community', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.chat),
              label: const Text('Join WhatsApp group'),
              onPressed: () => launchUrl(Uri.parse(AppConfig.whatsappGroupUrl), mode: LaunchMode.externalApplication),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.groups),
              label: const Text('Join Facebook group'),
              onPressed: () => launchUrl(Uri.parse(AppConfig.facebookGroupUrl), mode: LaunchMode.externalApplication),
            ),
          ],
        ),
      ),
    );
  }
}
