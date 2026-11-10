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
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (_failed) setState(() => _failed = false);
    try {
      await widget.state.init();
    } catch (e, st) {
      // Never sit on the splash picture forever: say what happened and let the user retry.
      debugPrint('App start failed: $e\n$st');
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = paletteFor('afternoon');
    return Scaffold(
      backgroundColor: p.bg,
      body: Stack(
        children: [
          Center(
            // Same 360x500dp picture as the native launch screen, so there is one splash.
            child: Image.asset(
              'assets/images/splash.png',
              width: 360,
              height: 500,
              fit: BoxFit.contain,
            ),
          ),
          if (_failed)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Couldn't start the app. Check your connection and try again. "
                        'If it keeps happening, reinstall the app.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: p.ink),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _start,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
