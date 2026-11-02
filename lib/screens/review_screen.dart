import 'package:flutter/material.dart';

import '../core/srs.dart';
import '../data/app_state.dart';
import '../models/word.dart';

class ReviewScreen extends StatefulWidget {
  final AppState state;
  const ReviewScreen({super.key, required this.state});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  List<Word>? _queue;
  int _index = 0;
  bool _revealed = false;

  void _start() => setState(() {
        _queue = widget.state.dueWords;
        _index = 0;
        _revealed = false;
      });

  Future<void> _rate(Rating r) async {
    await widget.state.rate(_queue![_index], r);
    setState(() {
      _index++;
      _revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListenableBuilder(
          listenable: widget.state,
          builder: (context, _) {
            if (_queue == null) {
              final due = widget.state.dueWords.length;
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$due words due', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: due == 0 ? null : _start, child: const Text('Start review')),
                ]),
              );
            }
            if (_index >= _queue!.length) {
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.check_circle, size: 64, color: Colors.green),
                  const SizedBox(height: 12),
                  const Text('Review complete!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  OutlinedButton(onPressed: () => setState(() => _queue = null), child: const Text('Done')),
                ]),
              );
            }
            final w = _queue![_index];
            return Column(children: [
              LinearProgressIndicator(value: _index / _queue!.length),
              const SizedBox(height: 24),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(w.word, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        if (_revealed) ...[
                          Text(w.meaning, style: const TextStyle(fontSize: 20)),
                          const SizedBox(height: 16),
                          if (w.example.isNotEmpty) Text(w.example, textAlign: TextAlign.center),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!_revealed)
                FilledButton(onPressed: () => setState(() => _revealed = true), child: const Text('Show meaning'))
              else
                Wrap(spacing: 8, children: [
                  _ratingBtn('Again', Rating.again),
                  _ratingBtn('Hard', Rating.hard),
                  _ratingBtn('Good', Rating.good),
                  _ratingBtn('Easy', Rating.easy),
                ]),
            ]);
          },
        ),
      ),
    );
  }

  Widget _ratingBtn(String label, Rating r) =>
      OutlinedButton(onPressed: () => _rate(r), child: Text(label));
}
