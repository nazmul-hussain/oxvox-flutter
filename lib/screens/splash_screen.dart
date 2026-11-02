import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/app_state.dart';

/// Loads local data first, then hands off. Also initialises AppState once.
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
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Ox',
                style: TextStyle(color: p.brand),
              ),
              TextSpan(
                text: 'Vox',
                style: TextStyle(color: p.brand),
              ),
            ],
          ),
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
