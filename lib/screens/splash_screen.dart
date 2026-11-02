import 'package:flutter/material.dart';

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
    return Scaffold(
      body: Center(
        child: Text(
          'oxvox',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
