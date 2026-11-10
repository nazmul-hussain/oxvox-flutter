import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/config.dart';
import 'core/theme.dart';
import 'data/app_state.dart';
import 'data/content_repository.dart';
import 'screens/home_shell.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw behind the status and navigation bars on every Android version
  // (Android 15+ forces this for targetSdk 35); screens pad themselves.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final state = AppState(ContentRepository());
  runApp(OxvoxApp(state: state));
}

class OxvoxApp extends StatelessWidget {
  final AppState state;
  const OxvoxApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final themeId = resolveThemeId(state.themeSetting);
        final palette = paletteFor(themeId);
        return MaterialApp(
          title: AppConfig.appName,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(palette, Brightness.light),
          darkTheme: buildTheme(palette, Brightness.dark),
          themeMode: themeId == 'night' ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) {
            final dark = themeId == 'night';
            return AnnotatedRegion<SystemUiOverlayStyle>(
              // Transparent system bars with icons readable on the palette.
              value: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarDividerColor: Colors.transparent,
                systemNavigationBarContrastEnforced: false,
                statusBarIconBrightness: dark
                    ? Brightness.light
                    : Brightness.dark,
                statusBarBrightness: dark ? Brightness.dark : Brightness.light,
                systemNavigationBarIconBrightness: dark
                    ? Brightness.light
                    : Brightness.dark,
              ),
              child: ColoredBox(
                color: palette.bg,
                // Keep every screen, sheet and dialog clear of the navigation
                // bar, gesture area and landscape camera cutouts. The top inset
                // stays with each screen so AppBars still fill the status bar.
                // Text scale first, then SafeArea, so the SafeArea's removed
                // insets are not re-added by a MediaQuery read from outside it.
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(
                      kBaseTextScale * state.fontScale,
                    ),
                  ),
                  child: SafeArea(top: false, child: child!),
                ),
              ),
            );
          },
          home: state.loading
              ? SplashScreen(state: state)
              : HomeShell(state: state),
        );
      },
    );
  }
}
