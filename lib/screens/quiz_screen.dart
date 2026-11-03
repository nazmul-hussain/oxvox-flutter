import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/quiz.dart';
import 'auth_screen.dart';
import '../core/theme.dart';
import '../data/app_state.dart';
import '../models/word.dart';

/// Web: components/CountPicker.js (slider plus number box).
class CountPicker extends StatelessWidget {
  final OxPalette p;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  const CountPicker({
    super.key,
    required this.p,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: max > min
              ? Slider(
                  value: value.clamp(min, max).toDouble(),
                  min: min.toDouble(),
                  max: max.toDouble(),
                  divisions: (max - min) > 0 ? max - min : null,
                  activeColor: p.accent,
                  onChanged: (v) => onChanged(v.round()),
                )
              : Text('Only $max', style: TextStyle(color: p.muted)),
        ),
        _CountBox(p: p, value: value, min: min, max: max, onChanged: onChanged),
        const SizedBox(width: 6),
        Text('questions', style: TextStyle(fontSize: 12.8, color: p.muted)),
      ],
    );
  }
}

/// Web CountPicker number box: typing clamps to [min, max] (empty or invalid falls back to min).
class _CountBox extends StatefulWidget {
  final OxPalette p;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  const _CountBox({
    required this.p,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  State<_CountBox> createState() => _CountBoxState();
}

class _CountBoxState extends State<_CountBox> {
  late final TextEditingController _c = TextEditingController(
    text: '${widget.value}',
  );

  @override
  void didUpdateWidget(covariant _CountBox old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && _c.text != '${widget.value}') {
      _c.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    return SizedBox(
      width: 64,
      height: 36,
      child: TextField(
        controller: _c,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 16,
          color: p.ink,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.all(8),
          filled: true,
          fillColor: p.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: p.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: p.line),
          ),
        ),
        onChanged: (v) {
          final n = int.tryParse(v) ?? widget.min;
          widget.onChanged(n.clamp(widget.min, widget.max));
        },
      ),
    );
  }
}

/// "How many questions?" card with Start and Cancel. Used by Today, Words and Topics.
class QuizSetupCard extends StatefulWidget {
  final AppState state;
  final OxPalette p;
  final String title;
  final int? day;
  final List<Word> pool;
  final List<Word> distractPool;
  final VoidCallback? onCancel;
  const QuizSetupCard({
    super.key,
    required this.state,
    required this.p,
    required this.title,
    required this.pool,
    this.day,
    this.distractPool = const [],
    this.onCancel,
  });

  @override
  State<QuizSetupCard> createState() => _QuizSetupCardState();
}

class _QuizSetupCardState extends State<QuizSetupCard> {
  late int _count = defaultQuizCount(widget.pool.length);

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final n = widget.pool.length;
    final min = quizMinCount(n);
    final value = _count.clamp(min, n);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How many questions? · ${widget.title}',
            style: TextStyle(fontWeight: FontWeight.w500, color: p.ink),
          ),
          CountPicker(
            p: p,
            value: value,
            min: min,
            max: n,
            onChanged: (v) => setState(() => _count = v),
          ),
          Row(
            children: [
              FilledButton(
                onPressed: n == 0
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => QuizScreen(
                              state: widget.state,
                              p: p,
                              title: widget.title,
                              day: widget.day,
                              pool: widget.pool,
                              count: value,
                              distractPool: widget.distractPool.isEmpty
                                  ? widget.pool
                                  : widget.distractPool,
                            ),
                          ),
                        );
                      },
                style: FilledButton.styleFrom(backgroundColor: p.brand),
                child: const Text('Start quiz'),
              ),
              const SizedBox(width: 8),
              if (widget.onCancel != null)
                OutlinedButton(
                  onPressed: widget.onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: p.accent,
                    side: BorderSide(color: p.accent),
                  ),
                  child: const Text('Cancel'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet to pick the question count for a day quiz, then start it.
/// Uses the same count rules as the rest of the app (quizMinCount / defaultQuizCount).
Future<void> showDayQuizCountSheet(
  BuildContext context, {
  required AppState state,
  required OxPalette p,
  required int day,
  required List<Word> pool,
  List<Word> distractPool = const [],
}) async {
  final n = pool.length;
  if (n == 0) return;
  final min = quizMinCount(n);
  final count = await showModalBottomSheet<int>(
    context: context,
    backgroundColor: p.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _QuizCountSheet(
      p: p,
      title: 'Day $day quiz',
      min: min,
      max: n,
      initial: defaultQuizCount(n).clamp(min, n).toInt(),
    ),
  );
  if (count == null || !context.mounted) return;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => QuizScreen(
        state: state,
        p: p,
        title: 'Day $day quiz',
        day: day,
        pool: pool,
        count: count,
        distractPool: distractPool.isEmpty ? pool : distractPool,
      ),
    ),
  );
}

class _QuizCountSheet extends StatefulWidget {
  final OxPalette p;
  final String title;
  final int min;
  final int max;
  final int initial;
  const _QuizCountSheet({
    required this.p,
    required this.title,
    required this.min,
    required this.max,
    required this.initial,
  });

  @override
  State<_QuizCountSheet> createState() => _QuizCountSheetState();
}

class _QuizCountSheetState extends State<_QuizCountSheet> {
  late int _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final canSlide = widget.max > widget.min;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 18,
                color: p.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'How many questions?',
              style: TextStyle(color: p.muted, fontSize: 13.6),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                '$_value',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 36,
                  color: p.accent,
                ),
              ),
            ),
            if (canSlide)
              Slider(
                value: _value.toDouble(),
                min: widget.min.toDouble(),
                max: widget.max.toDouble(),
                divisions: widget.max - widget.min,
                label: '$_value',
                activeColor: p.accent,
                onChanged: (v) => setState(() => _value = v.round()),
              )
            else
              Center(
                child: Text(
                  'Only ${widget.max} questions available',
                  style: TextStyle(color: p.muted),
                ),
              ),
            Text(
              '${widget.min} to ${widget.max} questions',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.muted, fontSize: 12.8),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_value),
              style: FilledButton.styleFrom(
                backgroundColor: p.accent,
                foregroundColor: p.accentInk,
                minimumSize: const Size.fromHeight(46),
              ),
              child: const Text('Start'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Web: components/Quiz.js. Auto-advances 0.9s after each answer, saves the result,
/// updates spaced repetition, and offers a review of all answers.
class QuizScreen extends StatefulWidget {
  final AppState state;
  final OxPalette p;
  final String title;
  final int? day;
  final List<Word> pool;
  final int count;
  final List<Word> distractPool;
  const QuizScreen({
    super.key,
    required this.state,
    required this.p,
    required this.title,
    required this.pool,
    required this.count,
    required this.distractPool,
    this.day,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late final List<QuizQuestion> _questions = buildQuizQuestions(
    widget.pool,
    widget.count,
    widget.distractPool,
    widget.state.meaningOf,
  );
  final List<String?> _answers = [];
  int _index = 0;
  int _frontier = 0;
  bool _finished = false;
  bool _reviewing = false;
  bool _saved = false;
  Timer? _timer;

  OxPalette get p => widget.p;
  AppState get s => widget.state;

  int get _score {
    var n = 0;
    for (var i = 0; i < _answers.length; i++) {
      if (_answers[i] == _questions[i].answer) n++;
    }
    return n;
  }

  bool _isWrong(int i) =>
      i < _answers.length &&
      _answers[i] != null &&
      _answers[i] != _questions[i].answer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _pick(String option) {
    if (_reviewing || _finished || _index != _frontier) return;
    if (_answers.length > _index && _answers[_index] != null) return;
    final q = _questions[_index];
    final correct = option == q.answer;
    setState(() {
      while (_answers.length <= _index) {
        _answers.add(null);
      }
      _answers[_index] = option;
    });
    s.answerQuiz(q.word, correct, widget.title);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 900), _advance);
  }

  void _advance() {
    if (!mounted) return;
    if (_frontier + 1 >= _questions.length) {
      setState(() => _finished = true);
      if (!_saved) {
        _saved = true;
        s.saveQuizResult(
          day: widget.day,
          title: widget.title,
          score: _score,
          total: _questions.length,
        );
      }
    } else {
      setState(() {
        _frontier += 1;
        _index += 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!s.isSignedIn) {
      return Scaffold(
        backgroundColor: p.bg,
        appBar: AppBar(backgroundColor: p.bg, title: Text(widget.title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Log in to take quizzes',
                  style: TextStyle(
                    color: p.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Quizzes need an account. Log in and the quiz starts right after.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.muted),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      openAuth(context, s, p, onAuthed: () => setState(() {})),
                  style: FilledButton.styleFrom(backgroundColor: p.brand),
                  child: const Text('Log in'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: p.bg,
        appBar: AppBar(backgroundColor: p.bg, title: Text(widget.title)),
        body: Center(
          child: Text(
            'No words available for this quiz.',
            style: TextStyle(color: p.ink),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.bg,
        foregroundColor: p.ink,
        elevation: 0,
        title: Text(
          widget.title,
          style: TextStyle(color: p.ink, fontWeight: FontWeight.w500),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: _finished && !_reviewing ? _resultView() : _questionView(),
        ),
      ),
    );
  }

  Widget _questionView() {
    final n = _questions.length;
    final q = _questions[_index];
    final chosen = _index < _answers.length ? _answers[_index] : null;
    final answered = chosen != null;
    final locked = _reviewing || answered || _index != _frontier;
    final header = _reviewing
        ? '${widget.title} · Review · ${_index + 1} of $n'
        : '${widget.title} · Question ${_index + 1} of $n · Score $_score';
    final bn2en = q.dir == 'bn2en';
    final gap = q.dir == 'gap';
    // Second language line under an English prompt (en2bn shows the English word).
    final promptSecond = q.dir == 'en2bn' ? s.secondaryForId(q.word.id) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_reviewing)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() => _reviewing = false),
              child: Text(
                'Done',
                style: TextStyle(color: p.accent, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        Text(header, style: TextStyle(fontSize: 13.6, color: p.muted)),
        if (!_reviewing) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _index / n,
              minHeight: 6,
              backgroundColor: p.surface2,
              valueColor: AlwaysStoppedAnimation(p.accent),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: p.surface,
            border: Border.all(color: p.line),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gap
                    ? 'Choose the word that fits the gap'
                    : bn2en
                    ? 'Choose the English word for'
                    : 'Choose the ${s.primaryMeaningLang.name} meaning of',
                style: TextStyle(fontSize: 13.6, color: p.muted),
              ),
              const SizedBox(height: 6),
              Text(
                q.prompt,
                style: TextStyle(
                  fontSize: gap ? 18.4 : (bn2en ? 22 : 28),
                  height: gap ? 1.6 : null,
                  fontWeight: FontWeight.w500,
                  color: gap || bn2en ? p.ink : p.accent,
                ),
              ),
              if (promptSecond != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    promptSecond,
                    textDirection: s.secondaryMeaningLang?.rtl ?? false
                        ? TextDirection.rtl
                        : null,
                    style: TextStyle(fontSize: 19.2, color: p.accent),
                  ),
                ),
              const SizedBox(height: 14),
              for (final opt in q.options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _option(opt, q, chosen, locked, bn2en),
                ),
              if (answered)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    chosen == q.answer ? 'Correct' : 'Your answer: $chosen',
                    style: TextStyle(fontSize: 13.6, color: p.muted),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton(
              onPressed: _index <= 0 ? null : () => setState(() => _index -= 1),
              style: _ghost(),
              child: const Text('Back'),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: _reviewing
                  ? (_index >= n - 1 ? null : () => setState(() => _index += 1))
                  : (_index >= _frontier
                        ? null
                        : () => setState(() => _index += 1)),
              style: _ghost(),
              child: const Text('Next'),
            ),
          ],
        ),
        if (!_reviewing)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Back shows your earlier answers. They cannot be changed.',
              style: TextStyle(fontSize: 13.6, color: p.muted),
            ),
          ),
      ],
    );
  }

  ButtonStyle _ghost() => OutlinedButton.styleFrom(
    foregroundColor: p.accent,
    side: BorderSide(color: p.accent),
  );

  Widget _option(
    String opt,
    QuizQuestion q,
    String? chosen,
    bool locked,
    bool bn2en,
  ) {
    final answered = chosen != null;
    Color bg = p.surface2;
    Color border = p.line;
    Color fg = p.ink;
    if (answered || _reviewing) {
      if (opt == q.answer) {
        bg = p.greenSoft;
        border = p.green;
        fg = p.green;
      } else if (opt == chosen) {
        bg = p.redSoft;
        border = p.red;
        fg = p.red;
      }
    }
    // Second language on options for bn2en and gap questions, not en2bn.
    final second = q.dir != 'en2bn' ? s.secondaryForId(opt.toLowerCase()) : null;
    final optRtl = q.dir == 'en2bn' && s.primaryMeaningLang.rtl;
    return InkWell(
      onTap: locked ? null : () => _pick(opt),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                opt,
                textDirection: optRtl ? TextDirection.rtl : null,
                style: TextStyle(
                  fontSize: bn2en ? 16.8 : 17.6,
                  color: fg,
                  fontWeight: (answered || _reviewing) && opt == q.answer
                      ? FontWeight.w500
                      : FontWeight.w500,
                ),
              ),
            ),
            if (second != null)
              Text(
                second,
                textDirection: (s.secondaryMeaningLang?.rtl ?? false)
                    ? TextDirection.rtl
                    : null,
                style: TextStyle(fontSize: 16, color: fg),
              ),
          ],
        ),
      ),
    );
  }

  final _cardKey = GlobalKey();

  /// Web: window.location.origin (the deployed app address).
  static const _siteUrl = 'https://oxvox.netlify.app';

  /// Web shareCard: the result card goes out as a PNG through the phone's share sheet.
  Future<void> _shareCard(int score, int n, int pct) async {
    final text =
        'I scored $score/$n ($pct%) on ${widget.title} in OxVox! Practice here: $_siteUrl';
    final boundary =
        _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    final image = await boundary?.toImage(pixelRatio: 3);
    final data = await image?.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      await SharePlus.instance.share(ShareParams(text: text));
      return;
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/oxvox-result.png')
      ..writeAsBytesSync(data.buffer.asUint8List());
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        files: [XFile(file.path, mimeType: 'image/png')],
      ),
    );
  }

  Widget _resultView() {
    final n = _questions.length;
    final score = _score;
    final pct = (score / n * 100).round();
    final wrong = [
      for (var i = 0; i < n; i++)
        if (_isWrong(i)) i,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${widget.title} finished',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22.4,
            fontWeight: FontWeight.w500,
            color: p.ink,
          ),
        ),
        const SizedBox(height: 16),
        // Mirrors web utils/shareCard.js: OxVox, quiz title, score, percent,
        // the share message and the site address.
        Text(
          'Practice here: ${_siteUrl.replaceFirst('https://', '')}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.6, color: p.muted),
        ),
        const SizedBox(height: 12),
        RepaintBoundary(
          key: _cardKey,
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: heroGradient(p),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'OxVox',
                    style: TextStyle(
                      color: Color(0xFFFDE68A),
                      fontSize: 26,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$score/$n',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 56,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '$pct%',
                    style: const TextStyle(
                      color: Color(0xFFFDE68A),
                      fontSize: 26,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Practice here and beat your score!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _siteUrl.replaceFirst('https://', ''),
                    style: const TextStyle(
                      color: Color(0xFFFDE68A),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _shareCard(score, n, pct),
          icon: Icon(Icons.share, size: 16, color: p.accent),
          label: const Text('Share result'),
          style: _ghost(),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            OutlinedButton(
              onPressed: () => setState(() {
                _index = 0;
                _reviewing = true;
              }),
              style: _ghost(),
              child: const Text('Review all answers'),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(backgroundColor: p.brand),
              child: const Text('Back'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (wrong.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: p.noticeBg,
              border: Border.all(color: p.noticeLine),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'No wrong answers. Well done!',
              style: TextStyle(color: p.noticeInk),
            ),
          )
        else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Words to review',
                style: TextStyle(
                  fontSize: 16.8,
                  fontWeight: FontWeight.w500,
                  color: p.ink,
                ),
              ),
              Text(
                '${wrong.length} wrong',
                style: TextStyle(fontSize: 13.6, color: p.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final i in wrong)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.surface,
                border: Border.all(color: p.line),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.end,
                    spacing: 8,
                    children: [
                      Text(
                        _questions[i].word.word,
                        style: TextStyle(
                          fontSize: 17.6,
                          fontWeight: FontWeight.w500,
                          color: p.ink,
                        ),
                      ),
                      Text(
                        s.meaningOf(_questions[i].word),
                        style: TextStyle(fontSize: 15.2, color: p.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _pill('Your answer: ${_answers[i]}', p.redSoft, p.red),
                      _pill(
                        'Correct: ${_questions[i].answer}',
                        p.greenSoft,
                        p.green,
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _pill(String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: fg),
    ),
  );
}
