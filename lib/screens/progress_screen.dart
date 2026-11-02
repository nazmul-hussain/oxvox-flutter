import 'package:flutter/material.dart';

import '../data/app_state.dart';

/// Badge definitions. Later these move to the Atlas `badges` collection.
class _Badge {
  final String title;
  final String description;
  final IconData icon;
  final bool Function(AppState s) earned;
  const _Badge(this.title, this.description, this.icon, this.earned);
}

final _badges = <_Badge>[
  _Badge('First word', 'Learn your first word', Icons.looks_one, (s) => s.wordsLearned >= 1),
  _Badge('100 words', 'Learn 100 words', Icons.menu_book, (s) => s.wordsLearned >= 100),
  _Badge('1000 words', 'Learn 1000 words', Icons.auto_stories, (s) => s.wordsLearned >= 1000),
  _Badge('First lesson', 'Finish a listening lesson', Icons.headphones, (s) => s.lessonsDone >= 1),
  _Badge('3-day streak', 'Study 3 days in a row', Icons.local_fire_department, (s) => s.streak >= 3),
  _Badge('7-day streak', 'Study 7 days in a row', Icons.whatshot, (s) => s.streak >= 7),
  _Badge('30-day streak', 'Study 30 days in a row', Icons.emoji_events, (s) => s.streak >= 30),
  _Badge('Mastered', 'Master 50 words', Icons.workspace_premium, (s) => s.masteredWords >= 50),
];

class ProgressScreen extends StatelessWidget {
  final AppState state;
  const ProgressScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final earned = _badges.where((b) => b.earned(state)).length;
        return SafeArea(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Text('Your progress', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 12, children: [
              _stat('Streak', '${state.streak} d'),
              _stat('XP', '${state.totalXp}'),
              _stat('Words', '${state.wordsLearned}'),
              _stat('Mastered', '${state.masteredWords}'),
              _stat('Lessons', '${state.lessonsDone}'),
            ]),
            const SizedBox(height: 24),
            Text('Badges ($earned/${_badges.length})', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: _badges.map((b) {
                final ok = b.earned(state);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Opacity(
                      opacity: ok ? 1 : 0.4,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(b.icon, size: 32),
                          const SizedBox(height: 6),
                          Text(b.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(b.description, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ]),
        );
      },
    );
  }

  Widget _stat(String label, String value) => SizedBox(
        width: 150,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      );
}
