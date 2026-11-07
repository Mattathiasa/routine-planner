import 'package:flutter/material.dart';

class ResinScreen extends StatelessWidget {
  const ResinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Resin — coming soon', style: Theme.of(context).textTheme.headlineLarge),
      ),
    );
  }
}
