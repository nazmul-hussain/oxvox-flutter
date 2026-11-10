import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../core/config.dart';
import '../core/listening.dart';
import '../core/theme.dart';
import '../data/app_state.dart';
import '../widgets/listen_thumb.dart';
import '../models/word.dart';
import '../widgets/quiz_kit.dart';

/// Web components/ListeningPractice.js LessonView.
class LessonScreen extends StatefulWidget {
  final AppState state;
  final OxPalette p;
  final String lessonId;
  const LessonScreen({
    super.key,
    required this.state,
    required this.p,
    required this.lessonId,
  });

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

enum _Mode { listen, quiz, done }

class _LessonScreenState extends State<LessonScreen> {
  late final ListeningLesson? lesson = getLesson(
    widget.state.lessons,
    widget.lessonId,
  );
  late final List<QuizQuestion> quiz = lesson == null
      ? const []
      : buildQuiz(widget.state.questions, widget.lessonId);

  _Mode mode = _Mode.listen;
  int qi = 0;
  final List<bool> answers = [];
  int? picked;
  bool showScript = false;

  OxPalette get p => widget.p;

  late final QuizVoice _voice = QuizVoice(
    s: widget.state,
    options: () => mode == _Mode.quiz && qi < quiz.length
        ? [for (final o in quiz[qi].options) o.label]
        : const [],
    lang: () => 'en',
    canAnswer: () => mode == _Mode.quiz && qi < quiz.length && picked == null,
    onPick: (label) {
      final i = quiz[qi].options.indexWhere((o) => o.label == label);
      if (i >= 0) _pick(i);
    },
  );

  @override
  void dispose() {
    _voice.dispose();
    super.dispose();
  }

  void _pick(int i) {
    if (picked != null) return;
    _voice.stop();
    setState(() => picked = i);
  }

  void _next() {
    answers.add(quiz[qi].options[picked!].correct);
    if (qi + 1 < quiz.length) {
      setState(() {
        qi += 1;
        picked = null;
      });
      _voice.listen();
    } else {
      _voice.stop();
      widget.state.saveListening(widget.lessonId, List<bool>.from(answers));
      setState(() => mode = _Mode.done);
    }
  }

  void _restart() {
    setState(() {
      mode = _Mode.quiz;
      qi = 0;
      answers.clear();
      picked = null;
    });
    _voice.listen();
  }

  @override
  Widget build(BuildContext context) {
    final l = lesson;
    final back = TextButton.icon(
      onPressed: () => Navigator.of(context).pop(),
      icon: Icon(Icons.chevron_left, size: 16, color: p.accent),
      label: Text(
        'Listening',
        style: TextStyle(color: p.accent, fontWeight: FontWeight.w500),
      ),
    );

    return Scaffold(
      backgroundColor: p.bg,
      appBar: null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: l == null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    back,
                    Text(
                      'This lesson is not available.',
                      style: TextStyle(color: p.muted),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        back,
                        Text(
                          'Lesson ${l.number} of ${widget.state.lessons.length}',
                          style: TextStyle(fontSize: 13.6, color: p.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ListenThumbView(title: l.title, num: l.number, big: true),
                    const SizedBox(height: 10),
                    Text(
                      l.title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        color: p.ink,
                      ),
                    ),
                    Text(
                      '${l.lines.length} lines',
                      style: TextStyle(fontSize: 13.6, color: p.muted),
                    ),
                    const SizedBox(height: 12),
                    _Player(
                      url:
                          '${AppConfig.contentBase}${l.audio.replaceFirst(RegExp(r'^/'), '')}',
                      title: 'Listen first, then answer',
                      duration: l.duration,
                      p: p,
                    ),
                    const SizedBox(height: 12),
                    if (mode == _Mode.listen)
                      _FullButton(
                        p: p,
                        label: 'Answer questions',
                        onTap: () {
                          setState(() => mode = _Mode.quiz);
                          _voice.listen();
                        },
                      ),
                    if (mode == _Mode.quiz && qi < quiz.length)
                      _QuizCard(
                        p: p,
                        q: quiz[qi],
                        index: qi,
                        total: quiz.length,
                        picked: picked,
                        voice: _voice,
                        onPick: _pick,
                        onNext: _next,
                      ),
                    if (mode == _Mode.done)
                      _Card(
                        p: p,
                        child: Column(
                          children: [
                            Text(
                              'Result',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: p.ink,
                              ),
                            ),
                            Text(
                              '${answers.where((e) => e).length} / ${quiz.length}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                                color: p.ink,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _GhostButton(
                                  p: p,
                                  label: 'Try again',
                                  icon: Icons.replay,
                                  onTap: _restart,
                                ),
                                _FullButton(
                                  p: p,
                                  label: 'Back to lessons',
                                  wide: false,
                                  onTap: () => Navigator.of(context).pop(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    _Card(
                      p: p,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _GhostButton(
                            p: p,
                            label: showScript ? 'Hide script' : 'Show script',
                            onTap: () =>
                                setState(() => showScript = !showScript),
                          ),
                          if (showScript)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final line in l.lines)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Text(
                                        '•  $line',
                                        style: TextStyle(
                                          fontSize: 15,
                                          height: 1.4,
                                          color: p.ink,
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
                ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final OxPalette p;
  final Widget child;
  const _Card({required this.p, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(vertical: 6),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: p.surface,
      border: Border.all(color: p.line),
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );
}

class _QuizCard extends StatelessWidget {
  final OxPalette p;
  final QuizQuestion q;
  final int index;
  final int total;
  final int? picked;
  final QuizVoice voice;
  final ValueChanged<int> onPick;
  final VoidCallback onNext;
  const _QuizCard({
    required this.voice,
    required this.p,
    required this.q,
    required this.index,
    required this.total,
    required this.picked,
    required this.onPick,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      p: p,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Question ${index + 1} of $total',
                  style: TextStyle(fontSize: 13.6, color: p.muted),
                ),
              ),
              VoiceToggleChip(voice: voice, p: p),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            q.prompt,
            style: TextStyle(
              fontSize: 16.8,
              fontWeight: FontWeight.w500,
              color: p.ink,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < q.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: QuizOptionTile(
                p: p,
                label: q.options[i].label,
                state: picked == null
                    ? QuizOptState.idle
                    : q.options[i].correct
                    ? QuizOptState.good
                    : i == picked
                    ? QuizOptState.bad
                    : QuizOptState.idle,
                onTap: picked == null ? () => onPick(i) : null,
              ),
            ),
          if (picked == null)
            ListenableBuilder(
              listenable: voice,
              builder: (_, _) => voice.on
                  ? VoicePanel(voice: voice, p: p)
                  : const SizedBox.shrink(),
            ),
          if (picked != null) ...[
            const SizedBox(height: 4),
            _FullButton(
              p: p,
              label: index + 1 < total ? 'Next question' : 'See result',
              onTap: onNext,
            ),
          ],
        ],
      ),
    );
  }
}

class _FullButton extends StatelessWidget {
  final OxPalette p;
  final String label;
  final VoidCallback onTap;
  final bool wide;
  const _FullButton({
    required this.p,
    required this.label,
    required this.onTap,
    this.wide = true,
  });

  @override
  Widget build(BuildContext context) {
    final btn = FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: p.action,
        foregroundColor: p.onBrand,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15.2),
      ),
      child: Text(label),
    );
    return wide ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

class _GhostButton extends StatelessWidget {
  final OxPalette p;
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  const _GhostButton({
    required this.p,
    required this.label,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon ?? Icons.article_outlined, size: 14, color: p.accent),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      foregroundColor: p.accent,
      side: BorderSide(color: p.accent),
      backgroundColor: p.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      textStyle: const TextStyle(fontSize: 13.6, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

const _speeds = [0.75, 1.0, 1.25];

String _speedLabel(double v) =>
    v == v.roundToDouble() ? v.round().toString() : v.toString();

class _Player extends StatefulWidget {
  final String url;
  final String title;
  final double duration;
  final OxPalette p;
  const _Player({
    required this.url,
    required this.title,
    required this.duration,
    required this.p,
  });

  @override
  State<_Player> createState() => _PlayerState();
}

class _PlayerState extends State<_Player> {
  final AudioPlayer _audio = AudioPlayer();
  int _speedIndex = 1;
  bool _loaded = false;

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_audio.playing) {
      await _audio.pause();
      return;
    }
    if (!_loaded) {
      await _audio.setUrl(widget.url);
      _loaded = true;
    }
    await _audio.play();
  }

  Future<void> _cycleSpeed() async {
    _speedIndex = (_speedIndex + 1) % _speeds.length;
    await _audio.setSpeed(_speeds[_speedIndex]);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: StreamBuilder<PlayerState>(
        stream: _audio.playerStateStream,
        builder: (context, snap) {
          final playing = snap.data?.playing ?? false;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: TextStyle(fontWeight: FontWeight.w500, color: p.ink),
              ),
              const SizedBox(height: 10),
              StreamBuilder<Duration>(
                stream: _audio.positionStream,
                builder: (context, pos) => StreamBuilder<Duration?>(
                  stream: _audio.durationStream,
                  builder: (context, dur) {
                    final total = (dur.data?.inMilliseconds ?? 0) > 0
                        ? dur.data!.inMilliseconds / 1000
                        : widget.duration;
                    final now = (pos.data?.inMilliseconds ?? 0) / 1000;
                    return Row(
                      children: [
                        InkWell(
                          onTap: _toggle,
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: p.action,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              playing ? Icons.pause : Icons.play_arrow,
                              color: p.onBrand,
                              size: 26,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            children: [
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: p.accent,
                                  thumbColor: p.accent,
                                  inactiveTrackColor: p.line,
                                ),
                                child: Slider(
                                  min: 0,
                                  max: total > 0 ? total : 1,
                                  value: now
                                      .clamp(0, total > 0 ? total : 1)
                                      .toDouble(),
                                  onChanged: (v) => _audio.seek(
                                    Duration(milliseconds: (v * 1000).round()),
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _fmt(now),
                                    style: TextStyle(
                                      fontSize: 13.6,
                                      color: p.muted,
                                    ),
                                  ),
                                  Text(
                                    _fmt(total),
                                    style: TextStyle(
                                      fontSize: 13.6,
                                      color: p.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        _GhostButton(
                          p: p,
                          // Web shows 0.75x, 1x, 1.25x (not 1.0x).
                          label: '${_speedLabel(_speeds[_speedIndex])}x',
                          icon: Icons.speed,
                          onTap: _cycleSpeed,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _fmt(double s) {
    if (!s.isFinite || s <= 0) return '0:00';
    final m = s ~/ 60;
    final r = s.floor() % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }
}
