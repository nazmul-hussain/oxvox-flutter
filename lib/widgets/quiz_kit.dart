import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/app_state.dart';
import '../screens/quiz_screen.dart' show checkVoiceLanguages;
import '../services/voice_answer.dart';

/// Shared look and voice answering for every multiple-choice quiz
/// (word quiz, level test, topic context quiz, listening lesson quiz).

enum QuizOptState { idle, good, bad }

/// One answer option, styled like the main word quiz.
class QuizOptionTile extends StatelessWidget {
  final OxPalette p;
  final String label;
  final QuizOptState state;
  final VoidCallback? onTap;
  final String? second;
  final bool rtl;
  final bool secondRtl;
  final double fontSize;
  const QuizOptionTile({
    super.key,
    required this.p,
    required this.label,
    required this.state,
    required this.onTap,
    this.second,
    this.rtl = false,
    this.secondRtl = false,
    this.fontSize = 17.6,
  });

  /// State for [opt] given the correct [answer] and the learner's [chosen] one.
  static QuizOptState stateFor<T>(
    T opt,
    T answer,
    T? chosen, {
    bool reveal = false,
  }) {
    if (chosen == null && !reveal) return QuizOptState.idle;
    if (opt == answer) return QuizOptState.good;
    if (opt == chosen) return QuizOptState.bad;
    return QuizOptState.idle;
  }

  @override
  Widget build(BuildContext context) {
    final (bg, border, fg) = switch (state) {
      QuizOptState.good => (p.greenSoft, p.green, p.green),
      QuizOptState.bad => (p.redSoft, p.red, p.red),
      QuizOptState.idle => (p.surface2, p.line, p.ink),
    };
    return InkWell(
      onTap: onTap,
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
                label,
                textDirection: rtl ? TextDirection.rtl : null,
                style: TextStyle(
                  fontSize: fontSize,
                  color: fg,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (second != null)
              Text(
                second!,
                textDirection: secondRtl ? TextDirection.rtl : null,
                style: TextStyle(fontSize: 16, color: fg),
              ),
          ],
        ),
      ),
    );
  }
}

/// Hands-free voice answering for a quiz screen. The screen supplies the current
/// options, the language they are spoken in, and whether the question is open.
class QuizVoice extends ChangeNotifier with WidgetsBindingObserver {
  final AppState s;
  final List<String> Function() options;
  final String Function() lang;
  final bool Function() canAnswer;
  final void Function(String option) onPick;

  QuizVoice({
    required this.s,
    required this.options,
    required this.lang,
    required this.canAnswer,
    required this.onPick,
  }) {
    WidgetsBinding.instance.addObserver(this);
    _callWatch = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_disposed || !s.voiceAnswers) return;
      final inCall = await SpeechLangs.inCall();
      if (inCall != _interrupted) {
        _interrupted = inCall;
        _onSuspendChanged();
      }
    });
  }

  bool listening = false;
  String heard = '';
  String? msg;
  final level = ValueNotifier<double>(0);
  int _token = 0;
  bool _disposed = false;
  bool _backgrounded = false;
  bool _interrupted = false;
  bool get _suspended => _backgrounded || _interrupted;
  Timer? _callWatch;

  bool get on => s.voiceAnswers;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _backgrounded = state != AppLifecycleState.resumed;
    _onSuspendChanged();
  }

  void _onSuspendChanged() {
    if (_disposed) return;
    if (_suspended) {
      stop();
    } else {
      listen();
    }
  }

  /// Listens until an option matches, restarting whenever Android stops the
  /// recognizer, for as long as voice is on and the question is open.
  Future<void> listen() async {
    if (_disposed || !s.voiceAnswers || !canAnswer() || listening) return;
    if (_suspended) {
      msg = _interrupted
          ? 'Paused during a call. Listening resumes when it ends.'
          : null;
      _notify();
      return;
    }
    if (!await VoiceAnswer.init()) {
      msg = 'Speech recognition is not available. Allow the microphone for OxVox and install "Speech Recognition and Synthesis from Google".';
      _notify();
      return;
    }
    if (_disposed || listening) return;
    final token = ++_token;
    final opts = options();
    listening = true;
    heard = '';
    msg = null;
    _notify();
    bool still() =>
        !_disposed &&
        token == _token &&
        !_suspended &&
        s.voiceAnswers &&
        canAnswer() &&
        _sameOptions(options(), opts);
    while (still()) {
      final r = await VoiceAnswer.listen(
        lang(),
        match: (g) => matchSpokenOption(g, opts),
        onPartial: (t) {
          if (token == _token) {
            heard = t;
            _notify();
          }
        },
        onLevel: (l) {
          if (token == _token && !_disposed) level.value = l;
        },
      );
      if (!still()) break;
      if (r.option != null) {
        listening = false;
        heard = '';
        _notify();
        onPick(r.option!);
        return;
      }
      if (r.heard.isNotEmpty) {
        heard = '';
        msg = 'Heard "${r.heard}". No option matched. Say it again.';
        _notify();
      }
      await Future.delayed(const Duration(milliseconds: 250));
    }
    if (token == _token) {
      listening = false;
      _notify();
    }
  }

  static bool _sameOptions(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Stops listening and clears what was heard (call when an answer is picked).
  void stop() {
    if (!_disposed) level.value = 0;
    _token++;
    VoiceAnswer.stop();
    heard = '';
    if (listening) listening = false;
    _notify();
  }

  void reset() {
    msg = null;
    stop();
  }

  Future<void> toggle(BuildContext context, OxPalette p) async {
    final turnOn = !s.voiceAnswers;
    if (turnOn && !await VoiceAnswer.init()) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Voice answers need the microphone and a speech recognizer on this phone.',
          ),
        ),
      );
      return;
    }
    await s.setVoiceAnswers(turnOn);
    if (turnOn && context.mounted) await checkVoiceLanguages(context, s, p);
    msg = null;
    if (turnOn) {
      listen();
    } else {
      stop();
    }
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _callWatch?.cancel();
    _token++;
    VoiceAnswer.stop();
    level.dispose();
    super.dispose();
  }
}

/// "Voice answer" pill for the app bar.
class VoiceToggleChip extends StatelessWidget {
  final QuizVoice voice;
  final OxPalette p;
  const VoiceToggleChip({super.key, required this.voice, required this.p});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: voice,
      builder: (context, _) {
        final on = voice.on;
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Material(
            color: on ? p.accentSoft : Colors.transparent,
            shape: StadiumBorder(
              side: BorderSide(color: on ? p.accent : p.line),
            ),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => voice.toggle(context, p),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      on ? Icons.mic_rounded : Icons.mic_off_rounded,
                      size: 18,
                      color: on ? p.accent : p.muted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Voice answer',
                      style: TextStyle(
                        fontSize: 13.6,
                        fontWeight: FontWeight.w500,
                        color: on ? p.accent : p.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Mic panel shown under the options while voice answers are on.
class VoicePanel extends StatelessWidget {
  final QuizVoice voice;
  final OxPalette p;
  const VoicePanel({super.key, required this.voice, required this.p});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: voice,
      builder: (context, _) {
        final live = voice.listening;
        final heard = live && voice.heard.isNotEmpty;
        final status = live
            ? (heard ? '“${voice.heard}”' : 'Listening…')
            : (voice.msg ?? 'Tap the mic to answer by voice');
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
                              fontWeight: heard
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (live && !heard)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Say the answer, or its number 1–${voice.options().length}',
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
      },
    );
  }

  Widget _micOrb(bool live) {
    return SizedBox(
      width: 60,
      height: 60,
      child: ValueListenableBuilder<double>(
        valueListenable: voice.level,
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
            onTap: live ? voice.stop : voice.listen,
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
}
