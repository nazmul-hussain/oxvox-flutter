import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/word.dart';

/// Short part-of-speech tags, same map as the web WordCard.
const _posShort = {
  'n.': 'n',
  'v.': 'v',
  'adj.': 'adj',
  'adv.': 'adv',
  'prep.': 'prep',
  'conj.': 'conj',
  'pron.': 'pron',
  'det.': 'det',
  'det./pron.': 'det/pron',
  'number': 'num',
  'exclam.': 'excl',
  'modal v.': 'modal',
  'phr v.': 'phr v',
};

List<String> posTags(Word w) {
  final out = <String>{};
  for (final p in w.pos) {
    out.add(_posShort[p] ?? p.replaceAll(RegExp(r'\.$'), ''));
  }
  return out.toList();
}

/// Bold the target word (and -s, -ed, -ing forms) inside an example (web: .hl).
TextSpan highlight(String sentence, String word, TextStyle base, Color hl) {
  final re = RegExp(
    '\\b(${RegExp.escape(word)})(s|es|ed|d|ing|ly|er|ers)?\\b',
    caseSensitive: false,
  );
  final spans = <TextSpan>[];
  var last = 0;
  for (final m in re.allMatches(sentence)) {
    if (m.start > last) {
      spans.add(TextSpan(text: sentence.substring(last, m.start)));
    }
    spans.add(
      TextSpan(
        text: m.group(0),
        style: TextStyle(color: hl, fontWeight: FontWeight.w700),
      ),
    );
    last = m.end;
  }
  if (last < sentence.length) {
    spans.add(TextSpan(text: sentence.substring(last)));
  }
  return TextSpan(style: base, children: spans);
}

/// Word title line: word, POS tags and Arabic (web: .word-text, .pos-tag, .arabic-inline).
class _WordTitle extends StatelessWidget {
  final Word w;
  final OxPalette p;
  final String? arabic;
  final double size;
  const _WordTitle({
    required this.w,
    required this.p,
    required this.arabic,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          w.word,
          style: TextStyle(
            color: p.accent,
            fontWeight: FontWeight.w700,
            fontSize: size,
          ),
        ),
        for (final tag in posTags(w))
          Padding(
            padding: const EdgeInsets.only(left: 5.6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5.6),
              decoration: BoxDecoration(
                border: Border.all(color: p.line),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                tag,
                style: TextStyle(
                  color: p.muted,
                  fontSize: 11.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        if (arabic != null)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              arabic!,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: p.accent,
                fontSize: 22.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

/// One word row. Tapping it opens the detail bottom sheet (web: same behaviour).
class WordCard extends StatelessWidget {
  final Word w;
  final VoidCallback onTap;
  final OxPalette p;
  final String? arabic;
  final bool showSynonyms;

  /// Small line under the word, e.g. "Missed 2×" or "Day 4" (web WordCard meta).
  final String? meta;

  const WordCard({
    super.key,
    required this.w,
    required this.onTap,
    required this.p,
    this.arabic,
    this.showSynonyms = true,
    this.meta,
  });

  @override
  Widget build(BuildContext context) {
    final syn = [
      if (w.synonyms.isNotEmpty) '≈ ${w.synonyms.join(', ')}',
      '≠ ${w.antonyms.isNotEmpty ? w.antonyms.join(', ') : '—'}',
    ].join('   ');
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12.8, 16, 12.8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _WordTitle(w: w, p: p, arabic: arabic, size: 19.8),
                    Text(
                      w.meaning,
                      style: TextStyle(color: p.muted, fontSize: 17.6),
                    ),
                    if (showSynonyms)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.4),
                        child: Text(
                          syn,
                          style: TextStyle(color: p.faint, fontSize: 11.5),
                        ),
                      ),
                    if (meta != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.4),
                        child: Text(
                          meta!,
                          style: TextStyle(
                            color: p.accent,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.accentSoft,
                ),
                child: Icon(Icons.expand_more, size: 20, color: p.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet with the word details (web: .sheet, .sheet-head, .word-detail, .info).
Future<void> showWordSheet(
  BuildContext context,
  Word w,
  OxPalette p, {
  required String? arabic,
  required Map<String, String> exampleBn,
  required bool saved,
  required VoidCallback onToggleSave,
}) {
  var isSaved = saved;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: p.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: p.line,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _WordTitle(w: w, p: p, arabic: arabic, size: 19.8),
                            Text(
                              w.meaning,
                              style: TextStyle(color: p.muted, fontSize: 17.6),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: p.surface2,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.pop(ctx),
                          child: SizedBox(
                            width: 34,
                            height: 34,
                            child: Icon(Icons.close, size: 18, color: p.muted),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    child: _Info(w: w, p: p),
                  ),
                  if (w.examples.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    // Web: <p class="small bold">Examples</p>
                    Text(
                      'Examples',
                      style: TextStyle(
                        fontSize: 13.6,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    for (final ex in w.examples)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 17.6,
                              child: Text(
                                '•',
                                style: TextStyle(color: p.ink, fontSize: 14.7),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text.rich(
                                    highlight(
                                      ex,
                                      w.word,
                                      TextStyle(color: p.ink, fontSize: 14.7),
                                      p.red,
                                    ),
                                  ),
                                  if (exampleBn[ex] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2.4),
                                      child: Text(
                                        exampleBn[ex]!,
                                        style: TextStyle(
                                          color: p.muted,
                                          fontSize: 14.4,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                      onPressed: () {
                        onToggleSave();
                        isSaved = !isSaved;
                        setSheet(() {});
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: p.accent,
                        side: BorderSide(color: p.accent),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.8,
                          vertical: 6.4,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13.6,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text(isSaved ? '★ Saved' : '☆ Save'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// The info box: scenario, intent, type and usage (web: .info, 14.4px, accent-soft background).
class _Info extends StatelessWidget {
  final Word w;
  final OxPalette p;
  const _Info({required this.w, required this.p});

  @override
  Widget build(BuildContext context) {
    final ink = TextStyle(color: p.ink, fontSize: 14.4, height: 1.45);
    final bold = ink.copyWith(fontWeight: FontWeight.w700);
    final lines = <Widget>[
      if (w.scenario != null && w.scenario!.isNotEmpty)
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Scenario: ', style: bold),
              TextSpan(text: w.scenario),
            ],
            style: ink,
          ),
        ),
      if (w.intent != null && w.intent!.isNotEmpty)
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Intent: ', style: bold),
              TextSpan(text: w.intent),
            ],
            style: ink,
          ),
        ),
      if (w.type.isNotEmpty)
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Type: ', style: bold),
              TextSpan(text: w.type),
            ],
            style: ink,
          ),
        ),
      if (w.usage != null && w.usage!.isNotEmpty) Text(w.usage!, style: ink),
    ];
    if (lines.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.accentSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final l in lines)
            Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: l),
        ],
      ),
    );
  }
}
