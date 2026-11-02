import 'word.dart';

/// Web: a context question in a topic quiz (modal verbs): a situation, a sentence with a blank,
/// four modal options and the explanation shown after answering.
class ContextQuestion {
  final String context;
  final String sentence;
  final List<String> options;
  final String answer;
  final String explain;
  const ContextQuestion({
    required this.context,
    required this.sentence,
    required this.options,
    required this.answer,
    required this.explain,
  });

  factory ContextQuestion.fromJson(Map<String, dynamic> j) => ContextQuestion(
    context: j['context'] as String,
    sentence: j['sentence'] as String,
    options: [for (final o in j['options'] as List) o.toString()],
    answer: j['answer'] as String,
    explain: (j['explain'] ?? '') as String,
  );
}

/// Web: grammar narration shown on a topic (title and sections of paragraphs).
class TopicNarration {
  final String title;
  final List<({String heading, List<String> text})> sections;
  const TopicNarration({required this.title, required this.sections});

  factory TopicNarration.fromJson(Map<String, dynamic> j) => TopicNarration(
    title: j['title'] as String,
    sections: [
      for (final s in j['sections'] as List)
        (
          heading: (s as Map)['heading'] as String,
          text: [for (final t in s['text'] as List) t.toString()],
        ),
    ],
  );
}

/// Web: data/topics (one native-speech group: phrasal verbs, idioms, fillers, ...).
class TopicItem {
  final String id;
  final String label;
  final String description;
  final List<Word> words;
  final List<ContextQuestion>? questions;
  final TopicNarration? narration;
  const TopicItem({
    required this.id,
    required this.label,
    required this.description,
    required this.words,
    this.questions,
    this.narration,
  });

  factory TopicItem.fromJson(Map<String, dynamic> j) => TopicItem(
    id: j['id'] as String,
    label: j['label'] as String,
    description: (j['description'] ?? '') as String,
    words: [
      for (final w in (j['words'] as List))
        Word.fromJson(w as Map<String, dynamic>),
    ],
    questions: j['questions'] == null
        ? null
        : [
            for (final q in j['questions'] as List)
              ContextQuestion.fromJson(q as Map<String, dynamic>),
          ],
    narration: j['narration'] == null
        ? null
        : TopicNarration.fromJson(j['narration'] as Map<String, dynamic>),
  );
}
