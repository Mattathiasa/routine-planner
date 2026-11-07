import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/resin_controller.dart';

/// Only takes the resin value, not an optional "time until full" — a
/// second duration-picker input is real added complexity deferred for a
/// first pass. `ResinController.sync` still supports `fullIn`; omitting it
/// here just means the no-`fullIn` branch (`n = now + R/2`) is always
/// taken, which is correct, just less precise.
class SyncDialog extends ConsumerStatefulWidget {
  const SyncDialog({super.key});

  @override
  ConsumerState<SyncDialog> createState() => _SyncDialogState();
}

class _SyncDialogState extends ConsumerState<SyncDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final x = int.tryParse(_controller.text);
    if (x == null || x < 0) return;

    final navigator = Navigator.of(context);
    await ref.read(resinControllerProvider.notifier).sync(x);
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sync with game'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Current resin'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(onPressed: _submit, child: const Text('Sync')),
      ],
    );
  }
}
