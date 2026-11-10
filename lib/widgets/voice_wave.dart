import 'dart:math';

import 'package:flutter/material.dart';

/// Live voice waveform: rounded bars that rise with the mic level and gently
/// breathe while it is quiet. [level] is 0..1; it is smoothed so bars glide.
class VoiceWave extends StatefulWidget {
  final ValueNotifier<double> level;
  final Color color;
  final Color quietColor;
  final bool active;
  final int bars;
  final double height;
  const VoiceWave({
    super.key,
    required this.level,
    required this.color,
    required this.quietColor,
    this.active = true,
    this.bars = 32,
    this.height = 44,
  });

  @override
  State<VoiceWave> createState() => _VoiceWaveState();
}

class _VoiceWaveState extends State<VoiceWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tick = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();
  late List<double> _heights = List.filled(widget.bars, 0.08);
  double _smooth = 0;
  final _rng = Random();
  late final List<double> _phase = List.generate(
    widget.bars,
    (_) => _rng.nextDouble() * pi * 2,
  );

  @override
  void initState() {
    super.initState();
    _tick.addListener(_step);
  }

  void _step() {
    final target = widget.active ? widget.level.value : 0.0;
    // Rise fast, fall slower, like a VU meter.
    _smooth += (target - _smooth) * (target > _smooth ? 0.45 : 0.12);
    final t = _tick.lastElapsedDuration?.inMilliseconds ?? 0;
    final n = widget.bars;
    final next = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      // Taller in the middle, shorter at the edges.
      final x = (i / (n - 1)) * 2 - 1;
      final envelope = 0.35 + 0.65 * (1 - x * x);
      final idle = 0.08 + 0.05 * sin(t / 380 + _phase[i]);
      final jitter = 0.55 + 0.45 * sin(t / 90 + _phase[i] * 3);
      final h = idle + _smooth * envelope * jitter;
      next[i] = _heights[i] + (h - _heights[i]) * 0.35;
    }
    setState(() => _heights = next);
  }

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _WavePainter(
          _heights,
          Color.lerp(
            widget.quietColor,
            widget.color,
            (_smooth * 2.5).clamp(0, 1),
          )!,
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final List<double> heights;
  final Color color;
  _WavePainter(this.heights, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final n = heights.length;
    final slot = size.width / n;
    final w = slot * 0.55;
    final paint = Paint()..color = color;
    for (var i = 0; i < n; i++) {
      final h = (heights[i].clamp(0.06, 1.0)) * size.height;
      final cx = slot * i + slot / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx, size.height / 2),
            width: w,
            height: h,
          ),
          Radius.circular(w / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => true;
}
