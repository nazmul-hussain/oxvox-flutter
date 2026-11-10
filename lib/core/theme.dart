import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Exact copies of the CSS variables in the web app's App.css.
class OxPalette {
  final Color bg,
      surface,
      surface2,
      ink,
      muted,
      faint,
      line,
      accent,
      accentSoft,
      accentInk,
      green,
      greenSoft,
      red,
      redSoft,
      orange,
      headerBg,
      noticeBg,
      noticeLine,
      noticeInk,
      blankBg,
      shadow,
      brand,
      brand2,
      onBrand,
      heroFrom,
      heroTo,
      heroInk;
  const OxPalette({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.ink,
    required this.muted,
    required this.faint,
    required this.line,
    required this.accent,
    required this.accentSoft,
    required this.accentInk,
    required this.green,
    required this.greenSoft,
    required this.red,
    required this.redSoft,
    required this.orange,
    required this.headerBg,
    required this.noticeBg,
    required this.noticeLine,
    required this.noticeInk,
    required this.blankBg,
    required this.shadow,
    required this.brand,
    required this.brand2,
    required this.onBrand,
    required this.heroFrom,
    required this.heroTo,
    required this.heroInk,
  });
}

extension OxPaletteX on OxPalette {
  /// Solid action colour (buttons, play circle). Night stays black and white: brand is near-white.
  Color get action => brand;
}

/// Text or icon colour that stays readable on [bg] (dark ink on light fills, white on dark).
Color readableOn(Color bg) => bg.computeLuminance() > 0.45
    ? const Color(0xFF1F212D)
    : const Color(0xFFFFFFFF);

/// Star colour for scores; darker on light themes so it stays visible on white.
Color starColor(OxPalette p) => p.surface.computeLuminance() > 0.5
    ? const Color(0xFFE09A00)
    : const Color(0xFFFFC53D);

double _contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (max(x, y) + 0.05) / (min(x, y) + 0.05);
}

/// [c] moved toward [p.ink] just enough to reach 4.5:1 on [p.surface], for coloured text.
Color legible(Color c, OxPalette p) {
  for (var w = 0.0; w <= 1.0; w += 0.05) {
    final v = Color.lerp(c, p.ink, w)!;
    if (_contrast(v, p.surface) >= 4.5) return v;
  }
  return p.ink;
}

/// color-mix(in srgb, a w%, b)
Color mix(Color a, Color b, double w) => Color.lerp(b, a, w)!;

/// Hero and title band gradient (web: --hero-from to --hero-to).
LinearGradient heroGradient(OxPalette p) => LinearGradient(
  begin: const Alignment(-0.34, -1),
  end: const Alignment(0.34, 1),
  colors: [p.heroFrom, p.heroTo],
);

// Day: sky light blue. Buttons and hero use the blue brand colours.
const dayPalette = OxPalette(
  bg: Color(0xFFEAF6FD),
  surface: Color(0xFFFFFFFF),
  surface2: Color(0xFFDCEFFB),
  ink: Color(0xFF0C2A3F),
  muted: Color(0xFF56758C),
  faint: Color(0xFF8AA6B9),
  line: Color(0xFFCFE6F4),
  accent: Color(0xFF0284C7),
  accentSoft: Color(0xFFDFF1FC),
  accentInk: Color(0xFFFFFFFF),
  green: Color(0xFF16A34A),
  greenSoft: Color(0xFFDCFCE7),
  red: Color(0xFFDC2626),
  redSoft: Color(0xFFFEE2E2),
  orange: Color(0xFFF97316),
  headerBg: Color(0xFFF5FBFF),
  noticeBg: Color(0xFFFFF7ED),
  noticeLine: Color(0xFFFED7AA),
  noticeInk: Color(0xFF9A3412),
  blankBg: Color(0xFFFEF9C3),
  shadow: Color(0x1A025682),
  brand: Color(0xFF0284C7),
  brand2: Color(0xFF0EA5E9),
  onBrand: Color(0xFFFFFFFF),
  heroFrom: Color(0xFF0284C7),
  heroTo: Color(0xFF0EA5E9),
  heroInk: Color(0xFFFFFFFF),
);

// Afternoon: warm cream with terracotta brand colours (palette unchanged).
const afternoonPalette = OxPalette(
  bg: Color(0xFFFBF6EC),
  surface: Color(0xFFFFFDF8),
  surface2: Color(0xFFF6ECD9),
  ink: Color(0xFF3B2A14),
  muted: Color(0xFF8A6D46),
  faint: Color(0xFFB59C75),
  line: Color(0xFFEAD9BB),
  accent: Color(0xFFC2410C),
  accentSoft: Color(0xFFFDE9D6),
  accentInk: Color(0xFFFFFFFF),
  green: Color(0xFF4D7C0F),
  greenSoft: Color(0xFFECF6D6),
  red: Color(0xFFB91C1C),
  redSoft: Color(0xFFFDE2E0),
  orange: Color(0xFFD97706),
  headerBg: Color(0xFFFFFAF0),
  noticeBg: Color(0xFFFFF4DC),
  noticeLine: Color(0xFFF0CF8A),
  noticeInk: Color(0xFF7C4A06),
  blankBg: Color(0xFFFDE68A),
  shadow: Color(0x1F5C3D14),
  brand: Color(0xFFC2410C),
  brand2: Color(0xFFEA580C),
  onBrand: Color(0xFFFFFFFF),
  heroFrom: Color(0xFFC2410C),
  heroTo: Color(0xFFEA580C),
  heroInk: Color(0xFFFFFFFF),
);

// Night: slate. Buttons are near-white with dark text; hero is dark slate.
const nightPalette = OxPalette(
  bg: Color(0xFF222533),
  surface: Color(0xFF2A2D3C),
  surface2: Color(0xFF323647),
  ink: Color(0xFFF4F5F9),
  muted: Color(0xFF8D93A8),
  faint: Color(0xFF7A8099),
  line: Color(0xFF383C4F),
  accent: Color(0xFFF4F5F9),
  accentSoft: Color(0xFF343848),
  accentInk: Color(0xFF1F212D),
  green: Color(0xFF7FD6A0),
  greenSoft: Color(0xFF1F3329),
  red: Color(0xFFF08A8A),
  redSoft: Color(0xFF3A2328),
  orange: Color(0xFFF3A766),
  headerBg: Color(0xFF222533),
  noticeBg: Color(0xFF33302A),
  noticeLine: Color(0xFF5C5232),
  noticeInk: Color(0xFFF2D98A),
  blankBg: Color(0xFF3B3824),
  shadow: Color(0x59000000),
  brand: Color(0xFFF4F5F9),
  brand2: Color(0xFFD9DCE6),
  onBrand: Color(0xFF1F212D),
  heroFrom: Color(0xFF2F3548),
  heroTo: Color(0xFF3D4661),
  heroInk: Color(0xFFF4F5F9),
);

/// 'auto' picks by local time, same rule as the web app.
String resolveThemeId(String setting, [DateTime? now]) {
  if (setting != 'auto') return setting;
  final h = (now ?? DateTime.now()).hour;
  if (h >= 5 && h < 12) return 'day';
  if (h >= 12 && h < 17) return 'afternoon';
  return 'night';
}

OxPalette paletteFor(String themeId) => switch (themeId) {
  'day' => dayPalette,
  'night' => nightPalette,
  _ => afternoonPalette,
};

/// One typography scale for the whole app (logical sizes, before the user's font scale).
class OxType {
  OxType._();
  static const double micro = 10.4; // tiny labels, nav captions
  static const double caption = 12.8; // hints, meta text
  static const double small = 13.6; // secondary text, buttons
  static const double body = 15.2; // main reading text
  static const double subtitle = 16; // card titles, list words
  static const double title = 20.8; // hero titles
  static const double heading = 22.4; // page titles
  static const double appName = 22; // "Ox Vox" logo in the header
}

/// Global text scale the app was designed with (the old hardcoded 1.12).
const double kBaseTextScale = 1.12;

/// Font size slider: free range from smaller than default up to the old Large.
/// Values move in 0.05 steps; the multiplier is applied on top of kBaseTextScale.
const double kMinFontScale = 0.7;
const double kMaxFontScale = 1.15;
const double kFontScaleStep = 0.05;

/// The standard size, shown as "Default".
const double kDefaultFontScale = 0.9;

/// Keeps a value in range and on the 0.05 grid.
double snapFontScale(double scale) {
  final clamped = scale.clamp(kMinFontScale, kMaxFontScale).toDouble();
  final steps = ((clamped - kMinFontScale) / kFontScaleStep).round();
  return double.parse(
    (kMinFontScale + steps * kFontScaleStep).toStringAsFixed(2),
  );
}

/// Slider divisions between min and max.
int get kFontScaleDivisions =>
    ((kMaxFontScale - kMinFontScale) / kFontScaleStep).round();

/// Label for a font scale: "Default", or "Smaller/Larger" with the percent of default.
String fontSizeLabel(double scale) {
  if ((scale - kDefaultFontScale).abs() < 0.001) return 'Default';
  final percent = (scale / kDefaultFontScale * 100).round();
  return scale < kDefaultFontScale
      ? 'Smaller ($percent%)'
      : 'Larger ($percent%)';
}

/// Web: font-family 'Hind Siliguri' for all UI text.
ThemeData buildTheme(OxPalette p, Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: p.accent,
    brightness: brightness,
    primary: p.accent,
    onPrimary: p.accentInk,
    surface: p.surface,
    onSurface: p.ink,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    fontFamily: GoogleFonts.hindSiliguri().fontFamily,
    appBarTheme: AppBarTheme(
      backgroundColor: p.headerBg,
      foregroundColor: p.ink,
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      indicatorColor: p.accentSoft,
    ),
  );
}
