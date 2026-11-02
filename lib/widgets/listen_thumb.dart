import 'package:flutter/material.dart';

import '../core/listening.dart';

/// Web Thumb: gradient tile with a waveform and a number badge.
/// `inRow` = the small list-row version (no number, narrower wave).
class ListenThumbView extends StatelessWidget {
  final String title;
  final int num;
  final bool big;
  final bool inRow;
  const ListenThumbView({
    super.key,
    required this.title,
    required this.num,
    this.big = false,
    this.inRow = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = thumbFor(title);
    return AspectRatio(
      aspectRatio: big ? 16 / 7 : 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [t.from, t.to],
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: FractionallySizedBox(
                widthFactor: inRow ? 0.8 : 0.84,
                heightFactor: inRow ? 0.5 : 0.55,
                child: CustomPaint(painter: _BarsPainter(t.bars)),
              ),
            ),
            if (!inRow)
              Positioned(
                top: 5,
                left: 5,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 22,
                    minHeight: 22,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0x59000000),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$num',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.8,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Waveform bars: 32 bars with 3px gaps, like the web's flex layout (bars shrink to fit).
class _BarsPainter extends CustomPainter {
  final List<double> bars;
  _BarsPainter(this.bars);

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 3.0;
    final n = bars.length;
    final barW = ((size.width - gap * (n - 1)) / n).clamp(0.0, double.infinity);
    final paint = Paint()..color = const Color(0xD9FFFFFF);
    for (var i = 0; i < n; i++) {
      final h = size.height * bars[i];
      final x = i * (barW + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, (size.height - h) / 2, barW, h),
          const Radius.circular(3),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) => old.bars != bars;
}
