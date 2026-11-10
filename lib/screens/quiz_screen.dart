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
import '../services/voice_answer.dart';

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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: widget.state.voiceAnswers,
            activeThumbColor: p.accent,
            secondary: Icon(Icons.mic, color: p.accent),
            title: Text('Answer by voice', style: TextStyle(color: p.ink)),
            subtitle: Text(
              'Say the answer instead of tapping it',
              style: TextStyle(color: p.muted, fontSize: 12.8),
            ),
            onChanged: (v) async {
              if (v && !await VoiceAnswer.init()) return;
              await widget.state.setVoiceAnswers(v);
              if (mounted) setState(() {});
              if (v && context.mounted) {
                await checkVoiceLanguages(context, widget.state, p);
              }
            },
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

/// Run when voice answers are turned on: checks that the phone can recognise
/// English and the learner's meaning language, and offers to download any that
/// are missing. Voice stays on either way; questions in a missing language just
/// will not be heard until it is installed.
Future<void> checkVoiceLanguages(
  BuildContext context,
  AppState s,
  OxPalette p,
) async {
  final langs = <(String, String)>[
    ('en', 'English'),
    if (s.primaryMeaningLang.code != 'en')
      (s.primaryMeaningLang.code, s.primaryMeaningLang.name),
  ];
  final toDownload = <(String, String)>[];
  final onlineOnly = <String>[];
  final missing = <String>[];
  final downloading = <String>[];
  for (final (code, name) in langs) {
    switch (await SpeechLangs.status(code)) {
      case SpeechLangStatus.downloadable:
        toDownload.add((code, name));
      case SpeechLangStatus.onlineOnly:
        onlineOnly.add(name);
      case SpeechLangStatus.missing:
        missing.add(name);
      case SpeechLangStatus.downloading:
        downloading.add(name);
      case SpeechLangStatus.ready:
      case SpeechLangStatus.unknown:
        break;
    }
  }
  if (toDownload.isEmpty && missing.isEmpty && onlineOnly.isEmpty) {
    if (downloading.isNotEmpty && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${downloading.join(' and ')} speech is downloading.'),
        ),
      );
    }
    return;
  }
  if (!context.mounted) return;
  final lines = <String>[
    if (toDownload.isNotEmpty)
      '${toDownload.map((l) => l.$2).join(' and ')} speech is not downloaded on this phone. Download it so voice answers work, even offline.',
    if (onlineOnly.isNotEmpty)
      '${onlineOnly.join(' and ')} speech works only with internet on this phone.',
    if (missing.isNotEmpty)
      "This phone's speech service doesn't support ${missing.join(' and ')}. In voice input settings, choose Speech Recognition and Synthesis from Google, then add the language.",
    if (downloading.isNotEmpty)
      '${downloading.join(' and ')} speech is already downloading.',
  ];
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: p.surface,
      title: Text('Voice languages', style: TextStyle(color: p.ink)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(l, style: TextStyle(color: p.ink)),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Not now', style: TextStyle(color: p.muted)),
        ),
        if (missing.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'settings'),
            child: Text('Open settings', style: TextStyle(color: p.accent)),
          ),
        if (toDownload.isNotEmpty)
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'download'),
            style: FilledButton.styleFrom(backgroundColor: p.brand),
            child: const Text('Download'),
          ),
      ],
    ),
  );
  if (choice == 'settings') {
    await SpeechLangs.openSettings();
  } else if (choice == 'download') {
    var failed = false;
    for (final (code, _) in toDownload) {
      if (!await SpeechLangs.download(code)) failed = true;
    }
    if (failed) await SpeechLangs.openSettings();
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

class _QuizScreenState extends State<QuizScreen> with WidgetsBindingObserver {
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

  // Voice answers.
  bool _listening = false;
  String _heard = '';
  final _level = ValueNotifier<double>(0);
  String? _voiceMsg;
  int _listenToken = 0;

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

  /// True while the app is in the background or another app (a phone or
  /// WhatsApp call) holds the audio. The mic stays off until both clear.
  bool _backgrounded = false;
  bool _interrupted = false;
  bool get _suspended => _backgrounded || _interrupted;
  Timer? _callWatch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _watchInterruptions();
    if (s.voiceAnswers) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _listen());
    }
  }

  /// Checks Android's call state every second: ringing, a phone call, or a
  /// WhatsApp/other internet call. The mic is released while any is active.
  void _watchInterruptions() {
    _callWatch = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!s.voiceAnswers) return;
      final inCall = await SpeechLangs.inCall();
      if (inCall != _interrupted) {
        _interrupted = inCall;
        _onSuspendChanged();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // inactive covers the call screen sliding over the app; paused/hidden is background.
    _backgrounded = state != AppLifecycleState.resumed;
    _onSuspendChanged();
  }

  void _onSuspendChanged() {
    if (!mounted) return;
    if (_suspended) {
      _stopListening();
    } else {
      _listen();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _callWatch?.cancel();
    _level.dispose();
    _timer?.cancel();
    VoiceAnswer.stop();
    super.dispose();
  }

  bool get _canAnswer =>
      !_reviewing &&
      !_finished &&
      _index == _frontier &&
      !(_answers.length > _index && _answers[_index] != null);

  /// Language the answer is spoken in: the meaning language for en2bn, else English.
  String get _answerLang =>
      _questions[_index].dir == 'en2bn' ? s.primaryMeaningLang.code : 'en';

  /// Hands-free loop: listens until an option matches, restarting the recognizer
  /// whenever Android stops it, for as long as voice is on and the question is open.
  Future<void> _listen() async {
    if (!mounted || !s.voiceAnswers || !_canAnswer || _listening) return;
    if (_suspended) {
      setState(
        () => _voiceMsg = _interrupted
            ? 'Paused during a call. Listening resumes when it ends.'
            : null,
      );
      return;
    }
    if (!await VoiceAnswer.init()) {
      if (mounted) {
        setState(
          () => _voiceMsg = 'Speech recognition is not available. Allow the microphone for OxVox and install "Speech Recognition and Synthesis from Google".',
        );
      }
      return;
    }
    if (!mounted || _listening) return;
    final token = ++_listenToken;
    final q = _questions[_index];
    setState(() {
      _listening = true;
      _heard = '';
      _voiceMsg = null;
    });
    bool still() =>
        mounted &&
        token == _listenToken &&
        !_suspended &&
        s.voiceAnswers &&
        _canAnswer &&
        _questions[_index] == q;
    try {
      while (still()) {
        final started = DateTime.now();
        final r = await VoiceAnswer.listen(
          _answerLang,
          match: (g) => matchSpokenOption(g, q.options),
          onPartial: (t) {
            if (mounted && token == _listenToken) setState(() => _heard = t);
          },
          onLevel: (l) {
            if (token == _listenToken) _level.value = l;
          },
        );
        if (!still()) break;
        if (r.option != null) {
          setState(() => _listening = false);
          _pick(r.option!);
          return;
        }
        if (r.heard.isNotEmpty) {
          setState(() {
            _heard = '';
            _voiceMsg = 'Heard "${r.heard}". No option matched. Say it again.';
          });
        }
        // Back off when the recognizer ended at once (busy/error) so it can recover.
        final quick = DateTime.now().difference(started).inMilliseconds < 1500;
        await Future.delayed(Duration(milliseconds: quick ? 1000 : 250));
      }
    } finally {
      // Never leave _listening stuck true, or the next question never listens.
      if (mounted && token == _listenToken && _listening) {
        setState(() => _listening = false);
      }
    }
  }

  void _stopListening() {
    _level.value = 0;
    _listenToken++;
    VoiceAnswer.stop();
    if (_listening) setState(() => _listening = false);
  }

  Future<void> _toggleVoice() async {
    final on = !s.voiceAnswers;
    if (on && !await VoiceAnswer.init()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Voice answers need the microphone and a speech recognizer on this phone.',
          ),
        ),
      );
      return;
    }
    await s.setVoiceAnswers(on);
    if (!mounted) return;
    if (on) await checkVoiceLanguages(context, s, p);
    if (!mounted) return;
    setState(() => _voiceMsg = null);
    if (on) {
      _listen();
    } else {
      _stopListening();
    }
  }

  void _pick(String option) {
    if (_reviewing || _finished || _index != _frontier) return;
    if (_answers.length > _index && _answers[_index] != null) return;
    final q = _questions[_index];
    final correct = option == q.answer;
    _stopListening();
    setState(() {
      _heard = '';
      _voiceMsg = null;
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
      _listen();
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
        actions: [
          if (!_finished)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Material(
                color: s.voiceAnswers ? p.accentSoft : Colors.transparent,
                shape: StadiumBorder(
                  side: BorderSide(color: s.voiceAnswers ? p.accent : p.line),
                ),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: _toggleVoice,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          s.voiceAnswers
                              ? Icons.mic_rounded
                              : Icons.mic_off_rounded,
                          size: 18,
                          color: s.voiceAnswers ? p.accent : p.muted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Voice answer',
                          style: TextStyle(
                            fontSize: 13.6,
                            fontWeight: FontWeight.w500,
                            color: s.voiceAnswers ? p.accent : p.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
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
              if (s.voiceAnswers && !locked) _voicePanel(),
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
              onPressed: _index <= 0
                  ? null
                  : () {
                      _stopListening();
                      setState(() => _index -= 1);
                    },
              style: _ghost(),
              child: const Text('Back'),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: _reviewing
                  ? (_index >= n - 1 ? null : () => setState(() => _index += 1))
                  : (_index >= _frontier
                        ? null
                        : () {
                            setState(() => _index += 1);
                            if (_index == _frontier) _listen();
                          }),
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

  Widget _voicePanel() {
    final live = _listening;
    final heard = live && _heard.isNotEmpty;
    final status = live
        ? (heard ? '\u201c$_heard\u201d' : 'Listening\u2026')
        : (_voiceMsg ?? 'Tap the mic to answer by voice');
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(10, 10, 16, 12),
      decoration: BoxDecoration(
        color: live ? p.accentSoft : p.surface2,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: live ? p.accent : p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _micOrb(live),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Text(
                        status,
                        key: ValueKey(status),
                        style: TextStyle(
                          fontSize: heard ? 17 : 14,
                          height: 1.35,
                          color: heard ? p.ink : p.muted,
                          fontWeight: heard ? FontWeight.w500 : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (live && !heard)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Say the answer, or its number 1\u20134',
                          style: TextStyle(fontSize: 12.5, color: p.muted),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Round mic button with a halo that swells with the voice level.
  Widget _micOrb(bool live) {
    return SizedBox(
      width: 60,
      height: 60,
      child: ValueListenableBuilder<double>(
        valueListenable: _level,
        builder: (_, l, child) => Stack(
          alignment: Alignment.center,
          children: [
            if (live)
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 48 + 12 * l,
                height: 48 + 12 * l,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.accent.withValues(alpha: 0.18 + 0.2 * l),
                ),
              ),
            child!,
          ],
        ),
        child: Material(
          color: live ? p.accent : p.surface,
          shape: CircleBorder(side: BorderSide(color: p.accent)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: live ? _stopListening : _listen,
            child: SizedBox(
              width: 46,
              height: 46,
              child: Icon(
                live ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: live ? p.surface : p.accent,
              ),
            ),
          ),
        ),
      ),
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
    final second = q.dir != 'en2bn'
        ? s.secondaryForId(opt.toLowerCase())
        : null;
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
          for (final i in wrong) _reviewItem(i),
        ],
      ],
    );
  }

  /// Web quiz-review-item: the whole question again, with every option shown and
  /// marked, so the learner sees what was asked and not just the two words.
  Widget _reviewItem(int i) {
    final q = _questions[i];
    final ask = q.dir == 'gap'
        ? 'Choose the word that fits the gap'
        : q.dir == 'bn2en'
        ? 'Choose the English word for'
        : 'Choose the ${s.primaryMeaningLang.name} meaning of';
    final promptRtl = q.dir == 'bn2en' && s.primaryMeaningLang.rtl;
    final optionRtl = q.dir == 'en2bn' && s.primaryMeaningLang.rtl;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(
          top: BorderSide(color: p.line),
          right: BorderSide(color: p.line),
          bottom: BorderSide(color: p.line),
          left: BorderSide(color: p.red, width: 4),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Question ${i + 1} · $ask',
            style: TextStyle(fontSize: OxType.small, color: p.muted),
          ),
          const SizedBox(height: 4),
          Text(
            q.prompt,
            textDirection: promptRtl ? TextDirection.rtl : null,
            style: TextStyle(
              fontSize: OxType.subtitle,
              fontWeight: FontWeight.w600,
              height: 1.5,
              color: p.ink,
            ),
          ),
          const SizedBox(height: 8),
          for (final opt in q.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: _reviewOption(q, opt, _answers[i], optionRtl),
            ),
          const SizedBox(height: 4),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 8,
            children: [
              Text(
                q.word.word,
                style: TextStyle(
                  fontSize: 17.6,
                  fontWeight: FontWeight.w500,
                  color: p.ink,
                ),
              ),
              Text(
                s.meaningOf(q.word),
                textDirection: s.primaryMeaningLang.rtl
                    ? TextDirection.rtl
                    : null,
                style: TextStyle(fontSize: 15.2, color: p.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// One option row in the review list: the right one is green, the picked one red.
  Widget _reviewOption(QuizQuestion q, String opt, String? picked, bool rtl) {
    final right = opt == q.answer;
    final chosen = opt == picked;
    final bg = right
        ? p.greenSoft
        : chosen
        ? p.redSoft
        : p.surface2;
    final fg = right
        ? p.green
        : chosen
        ? p.red
        : p.muted;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              opt,
              textDirection: rtl ? TextDirection.rtl : null,
              style: TextStyle(
                fontSize: OxType.small,
                fontWeight: FontWeight.w500,
                color: fg,
              ),
            ),
          ),
          if (right || chosen)
            Text(
              right ? '✓ Correct' : '✗ Your answer',
              style: TextStyle(
                fontSize: OxType.caption,
                fontWeight: FontWeight.w500,
                color: fg,
              ),
            ),
        ],
      ),
    );
  }
}
