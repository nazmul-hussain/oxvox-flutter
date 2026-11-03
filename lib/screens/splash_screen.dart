import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/app_state.dart';

/// The one splash screen: same picture as the native launch screen (orange icon
/// and a short description), so the app opens with no second splash.
/// Loads local data, then hands off to the home screen.
class SplashScreen extends StatefulWidget {
  final AppState state;
  const SplashScreen({super.key, required this.state});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    widget.state.init();
  }

  @override
  Widget build(BuildContext context) {
    final p = paletteFor('afternoon');
    return Scaffold(
      backgroundColor: p.bg,
      body: Center(
        // Same 360x500dp picture as the native launch screen, so there is one splash.
        child: Image.asset(
          'assets/images/splash.png',
          width: 360,
          height: 500,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
