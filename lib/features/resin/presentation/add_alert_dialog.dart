import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_profile_provider.dart';
import '../../../core/providers/repository_providers.dart';
import '../data/resin_providers.dart';

class AddAlertDialog extends ConsumerStatefulWidget {
  const AddAlertDialog({super.key});

  @override
  ConsumerState<AddAlertDialog> createState() => _AddAlertDialogState();
}

class _AddAlertDialogState extends ConsumerState<AddAlertDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final threshold = int.tryParse(_controller.text);
    if (threshold == null || threshold <= 0) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final profileId = (await ref.read(currentProfileProvider.future)).id;
      await ref.read(settingsRepositoryProvider).addAlertThreshold(profileId, threshold);
      ref.invalidate(resinAlertsProvider);
      if (mounted) navigator.pop();
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('That alert already exists.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add an alert'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Resin value'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
