import 'package:flutter/material.dart';

/// Palettes copied from the web app's App.css (day / afternoon / night).
class OxPalette {
  final Color bg, surface, ink, muted, faint, line, accent, accentSoft,
      accentInk, green, greenSoft, red, redSoft, orange, headerBg;
  const OxPalette({
    required this.bg, required this.surface, required this.ink, required this.muted,
    required this.faint, required this.line, required this.accent, required this.accentSoft,
    required this.accentInk, required this.green, required this.greenSoft, required this.red,
    required this.redSoft, required this.orange, required this.headerBg,
  });
}

const dayPalette = OxPalette(
  bg: Color(0xFFF4F8FF), surface: Color(0xFFFFFFFF), ink: Color(0xFF0F172A),
  muted: Color(0xFF64748B), faint: Color(0xFF94A3B8), line: Color(0xFFDBE4F0),
  accent: Color(0xFF2563EB), accentSoft: Color(0xFFE8F0FF), accentInk: Color(0xFFFFFFFF),
  green: Color(0xFF16A34A), greenSoft: Color(0xFFDCFCE7), red: Color(0xFFDC2626),
  redSoft: Color(0xFFFEE2E2), orange: Color(0xFFF97316), headerBg: Color(0xFFFFFFFF),
);

const afternoonPalette = OxPalette(
  bg: Color(0xFFFBF6EC), surface: Color(0xFFFFFDF8), ink: Color(0xFF3B2A14),
  muted: Color(0xFF8A6D46), faint: Color(0xFFB59C75), line: Color(0xFFEAD9BB),
  accent: Color(0xFFC2410C), accentSoft: Color(0xFFFDE9D6), accentInk: Color(0xFFFFFFFF),
  green: Color(0xFF4D7C0F), greenSoft: Color(0xFFECF6D6), red: Color(0xFFB91C1C),
  redSoft: Color(0xFFFDE2E0), orange: Color(0xFFD97706), headerBg: Color(0xFFFFFAF0),
);

const nightPalette = OxPalette(
  bg: Color(0xFF1F212D), surface: Color(0xFF262937), ink: Color(0xFFF1F2F6),
  muted: Color(0xFF9CA1B5), faint: Color(0xFF6B7088), line: Color(0xFF363A4D),
  accent: Color(0xFFF1F2F6), accentSoft: Color(0xFF343849), accentInk: Color(0xFF1F212D),
  green: Color(0xFF7FD6A0), greenSoft: Color(0xFF1F3329), red: Color(0xFFF08A8A),
  redSoft: Color(0xFF3A2328), orange: Color(0xFFF3A766), headerBg: Color(0xFF232634),
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
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    appBarTheme: AppBarTheme(backgroundColor: p.headerBg, foregroundColor: p.ink, elevation: 0),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: p.line),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.headerBg,
      indicatorColor: p.accentSoft,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(backgroundColor: p.accent, foregroundColor: p.accentInk),
    ),
  );
}
