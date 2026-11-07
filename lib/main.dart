import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Routine Planner',
      theme: AppTheme.light(),
      home: const _Placeholder(),
    );
  }
}

/// A real home screen doesn't exist until the Today screen is built.
class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Routine Planner', style: Theme.of(context).textTheme.displayMedium),
      ),
    );
  }
}
