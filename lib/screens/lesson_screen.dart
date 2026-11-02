import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/word.dart';

class LessonScreen extends StatelessWidget {
  final AppState state;
  final ListeningLesson lesson;
  const LessonScreen({super.key, required this.state, required this.lesson});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Lesson ${lesson.number}: ${lesson.title}')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: lesson.lines.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) => Text('${i + 1}. ${lesson.lines[i]}', style: const TextStyle(fontSize: 17)),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: () async {
              await state.completeLesson();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lesson complete (+10 XP)')));
                Navigator.of(context).pop();
              }
            },
            child: const Text('Mark as complete'),
          ),
        ),
      ),
    );
  }
}
