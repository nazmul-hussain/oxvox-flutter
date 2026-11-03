import 'package:flutter/material.dart';

import 'core/config.dart';
import 'core/theme.dart';
import 'data/app_state.dart';
import 'data/content_repository.dart';
import 'screens/home_shell.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(
                  textScaler: TextScaler.linear(
                    kBaseTextScale * state.fontScale,
                  ),
                ),
            child: child!,
          ),
          home: state.loading
              ? SplashScreen(state: state)
              : HomeShell(state: state),
        );
      },
    );
  }
}
