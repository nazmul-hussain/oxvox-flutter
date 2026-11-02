import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/word.dart';

class WordsScreen extends StatefulWidget {
  final AppState state;
  const WordsScreen({super.key, required this.state});

  @override
  State<WordsScreen> createState() => _WordsScreenState();
}

class _WordsScreenState extends State<WordsScreen> {
  String _query = '';
  String? _cefr;

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final list = widget.state.words.where((w) {
      if (_cefr != null && w.cefr != _cefr) return false;
      return q.isEmpty || w.word.toLowerCase().contains(q) || w.meaning.contains(q);
    }).take(300).toList();

    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search word or meaning',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [null, 'A1', 'A2', 'B1', 'B2', 'C1', 'C2']
                .map((c) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c ?? 'All'),
                        selected: _cefr == c,
                        onSelected: (_) => setState(() => _cefr = c),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final w = list[i];
              return ListTile(
                title: Text(w.word, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(w.meaning),
                trailing: Text(w.cefr),
                onTap: () => _showDetail(context, w),
              );
            },
          ),
        ),
      ]),
    );
  }

  void _showDetail(BuildContext context, Word w) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(w.word, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              Text('${w.pos.join(', ')} · ${w.cefr}'),
              const SizedBox(height: 12),
              Text(w.meaning, style: const TextStyle(fontSize: 18)),
              if (w.usage != null) ...[const SizedBox(height: 12), Text('Usage: ${w.usage}')],
              const SizedBox(height: 12),
              ...w.examples.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• $e'),
                  )),
              if (w.synonyms.isNotEmpty) Text('Synonyms: ${w.synonyms.join(', ')}'),
              if (w.antonyms.isNotEmpty) Text('Antonyms: ${w.antonyms.join(', ')}'),
            ],
          ),
        ),
      ),
    );
  }
}
