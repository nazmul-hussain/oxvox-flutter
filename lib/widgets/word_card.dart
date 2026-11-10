import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/languages.dart';
import '../models/word.dart';
import '../services/speech.dart';
import '../services/voice_answer.dart';
import '../services/pronunciation.dart';

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
        style: TextStyle(color: hl, fontWeight: FontWeight.w500),
      ),
    );
    last = m.end;
  }
  if (last < sentence.length) {
    spans.add(TextSpan(text: sentence.substring(last)));
  }
  return TextSpan(style: base, children: spans);
}

/// Word title line: word, POS tags and the secondary meaning (web: .word-text, .pos-tag, .arabic-inline).
class _WordTitle extends StatefulWidget {
  final Word w;
  final OxPalette p;
  final WordMeanings lines;
  final double size;
  const _WordTitle({
    required this.w,
    required this.p,
    required this.lines,
    required this.size,
  });

  @override
  State<_WordTitle> createState() => _WordTitleState();
}

class _WordTitleState extends State<_WordTitle> {
  bool _speaking = false;
  bool _meaningPlaying = false;

  Future<void> _toggleMeaning(String code, String text) async {
    if (_meaningPlaying) {
      await Speech.stop();
      if (mounted) setState(() => _meaningPlaying = false);
      return;
    }
    final tag = VoiceAnswer.tagFor(code);
    final status = await Speech.langStatus(tag);
    if (!mounted) return;
    if (status != TtsLangStatus.ready) {
      await _askForVoice(code, status);
      return;
    }
    setState(() {
      _speaking = false;
      _meaningPlaying = true;
    });
    await Speech.speakLang(
      text,
      tag,
      onEnd: () {
        if (mounted) setState(() => _meaningPlaying = false);
      },
    );
  }

  /// The phone has no voice for [code] yet: ask the learner to download one.
  Future<void> _askForVoice(String code, TtsLangStatus status) async {
    final p = widget.p;
    final name = langByCode(code)?.name ?? code;
    final missing = status == TtsLangStatus.missing;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: Text('$name voice', style: TextStyle(color: p.ink)),
        content: Text(
          missing
              ? "This phone's speech engine has no $name voice. Open the voice settings, choose Speech Services by Google as the engine, then download $name."
              : 'The $name voice is not downloaded on this phone. Download it to hear meanings read aloud, even offline.',
          style: TextStyle(color: p.ink),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Not now', style: TextStyle(color: p.muted)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: p.brand),
            child: Text(missing ? 'Open settings' : 'Download'),
          ),
        ],
      ),
    );
    if (ok == true) await SpeechLangs.installTtsVoice();
  }

  Future<void> _toggleSpeak() async {
    _meaningPlaying = false;
    if (_speaking) {
      await Pronunciation.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    setState(() => _speaking = true);
    await Pronunciation.speak(
      widget.w.word,
      onEnd: () {
        if (mounted) setState(() => _speaking = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.w;
    final p = widget.p;
    final lines = widget.lines;
    final size = widget.size;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          w.word,
          style: TextStyle(
            color: p.accent,
            fontWeight: FontWeight.w500,
            fontSize: size,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Tooltip(
            message: _speaking ? 'Stop' : 'Listen to pronunciation',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _toggleSpeak,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.accentSoft,
                ),
                child: Icon(
                  _speaking ? Icons.stop : Icons.volume_up,
                  size: 17,
                  color: p.accent,
                ),
              ),
            ),
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
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        if (lines.secondary != null)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              lines.secondary!,
              textDirection: lines.secondaryRtl ? TextDirection.rtl : null,
              style: TextStyle(
                color: p.accent,
                fontSize: 22.2,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        if (lines.secondary != null && lines.secondaryLang != null)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Tooltip(
              message: _meaningPlaying ? 'Stop' : 'Listen to meaning',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () =>
                    _toggleMeaning(lines.secondaryLang!, lines.secondary!),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p.accentSoft,
                  ),
                  child: Icon(
                    _meaningPlaying ? Icons.stop : Icons.volume_up,
                    size: 17,
                    color: p.accent,
                  ),
                ),
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
  final WordMeanings lines;
  final bool showSynonyms;

  /// Small line under the word, e.g. "Missed 2×" or "Day 4" (web WordCard meta).
  final String? meta;

  const WordCard({
    super.key,
    required this.w,
    required this.onTap,
    required this.p,
    required this.lines,
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
                    _WordTitle(w: w, p: p, lines: lines, size: 19.8),
                    Text(
                      lines.primary,
                      style: TextStyle(color: p.muted, fontSize: 17.6),
                    ),
                    if (showSynonyms)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.4),
                        child: Text(
                          syn,
                          style: TextStyle(color: p.muted, fontSize: 12.5),
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
                            fontWeight: FontWeight.w400,
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
  required WordMeanings lines,
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
                            _WordTitle(w: w, p: p, lines: lines, size: 19.8),
                            Text(
                              lines.primary,
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
                        fontWeight: FontWeight.w500,
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
                          fontWeight: FontWeight.w500,
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
    final bold = ink.copyWith(fontWeight: FontWeight.w500);
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
