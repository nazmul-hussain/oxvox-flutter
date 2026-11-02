import 'package:flutter/material.dart';

import '../core/theme.dart';

/// .card from App.css
class WebCard extends StatelessWidget {
  final OxPalette p;
  final Widget child;
  const WebCard({super.key, required this.p, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(vertical: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: p.surface,
      border: Border.all(color: p.line),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(color: p.shadow, offset: const Offset(0, 1), blurRadius: 2),
      ],
    ),
    child: child,
  );
}

/// .notice from App.css
class WebNotice extends StatelessWidget {
  final OxPalette p;
  final String text;
  const WebNotice({super.key, required this.p, required this.text});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(vertical: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: p.noticeBg,
      border: Border.all(color: p.noticeLine),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(text, style: TextStyle(color: p.noticeInk)),
  );
}

/// .day-bar / .today-hero style title band (web: page h2 band).
class WebTitleBand extends StatelessWidget {
  final OxPalette p;
  final String title;
  const WebTitleBand({super.key, required this.p, required this.title});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(0, 0, 0, 14),
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
    decoration: BoxDecoration(
      gradient: heroGradient(p),
      boxShadow: [
        BoxShadow(color: p.shadow, offset: const Offset(0, 10), blurRadius: 24),
      ],
    ),
    child: Text(
      title,
      style: TextStyle(
        color: p.heroInk,
        fontSize: 20.8,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// .btn (primary, brand colour)
class WebButton extends StatelessWidget {
  final OxPalette p;
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool ghost;
  const WebButton({
    super.key,
    required this.p,
    required this.label,
    this.icon,
    this.onPressed,
    this.ghost = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 17.6, vertical: 11.2),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      backgroundColor: WidgetStatePropertyAll(ghost ? p.surface : p.brand),
      foregroundColor: WidgetStatePropertyAll(ghost ? p.accent : p.onBrand),
      side: WidgetStatePropertyAll(
        ghost ? BorderSide(color: p.accent) : BorderSide.none,
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w700, fontSize: 15.2),
      ),
    );
    final child = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 6),
              Text(label),
            ],
          );
    return ElevatedButton(onPressed: onPressed, style: style, child: child);
  }
}

/// Full-bleed: the child spans the whole screen width, like the web's negative-margin hero.
class FullBleed extends StatelessWidget {
  final double horizontal;
  final Widget child;
  const FullBleed({super.key, required this.horizontal, required this.child});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => Transform.translate(
      offset: Offset(-horizontal, 0),
      child: SizedBox(width: c.maxWidth + horizontal * 2, child: child),
    ),
  );
}

/// Web .today-hero-wave: SVG path (viewBox 600x44, width 200%) drifting left every 20s.
class HeroWave extends StatefulWidget {
  final Color color;
  const HeroWave({super.key, required this.color});

  @override
  State<HeroWave> createState() => _HeroWaveState();
}

class _HeroWaveState extends State<HeroWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        painter: _WavePainter(progress: _c.value, color: widget.color),
        size: Size.infinite,
      ),
    ),
  );
}

class _WavePainter extends CustomPainter {
  final double progress;
  final Color color;
  _WavePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Web .today-hero-wave: the SVG is 200% wide (viewBox 600x44) and drifts left by 50% every 20s.
    // The wave repeats every 300 viewBox units, so the path is drawn over a much wider range than
    // the screen. That keeps the fill covering the strip at every point of the drift.
    final sx = (size.width * 2) / 600;
    final sy = size.height / 44;
    final dx = -progress * size.width * 2 * 0.5;

    Offset pt(double x, double y) => Offset(dx + x * sx, y * sy);

    final path = Path()..moveTo(pt(-600, 30).dx, pt(-600, 30).dy);
    // Segments of 150 units. Even segments bulge up (control y 16), odd ones dip (control y 44).
    for (var i = -4; i < 8; i++) {
      final x0 = 150.0 * i;
      final ctrlY = i.isEven ? 16.0 : 44.0;
      final c1 = pt(x0 + 50, ctrlY);
      final c2 = pt(x0 + 100, ctrlY);
      final end = pt(x0 + 150, 30);
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
    }
    path
      ..lineTo(pt(1200, 44).dx, pt(1200, 44).dy)
      ..lineTo(pt(-600, 44).dx, pt(-600, 44).dy)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      old.progress != progress || old.color != color;
}

/// Hero whose bottom edge is the moving wave. Gradient above the curve, body colour below it.
class WaveHero extends StatefulWidget {
  final OxPalette p;
  final Widget child;
  const WaveHero({super.key, required this.p, required this.child});

  @override
  State<WaveHero> createState() => _WaveHeroState();
}

class _WaveHeroState extends State<WaveHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) => ClipPath(
      clipper: _WaveClip(_c.value),
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: heroGradient(widget.p)),
        child: child,
      ),
    ),
    child: widget.child,
  );
}

class _WaveClip extends CustomClipper<Path> {
  final double progress;
  _WaveClip(this.progress);

  @override
  Path getClip(Size size) {
    // Same wave as the web SVG: 600x44 viewBox, drawn 200% wide, drifting left by 50% of its width.
    final base = size.height - 44;
    final sx = (size.width * 2) / 600;
    final dx = -progress * size.width;
    Offset pt(double x, double y) => Offset(dx + x * sx, base + y);

    final path = Path()..moveTo(pt(-600, 0).dx, 0);
    path.lineTo(pt(-600, 30).dx, pt(-600, 30).dy);
    for (var i = -4; i < 8; i++) {
      final x0 = 150.0 * i;
      final ctrlY = i.isEven ? 16.0 : 44.0;
      final c1 = pt(x0 + 50, ctrlY);
      final c2 = pt(x0 + 100, ctrlY);
      final end = pt(x0 + 150, 30);
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
    }
    path
      ..lineTo(pt(1200, 0).dx, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant _WaveClip old) => old.progress != progress;
}
