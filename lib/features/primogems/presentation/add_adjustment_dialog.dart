import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/primogems_controller.dart';

/// Records primogems gained or spent outside what the app can see.
///
/// The escape hatch that keeps the balance honest: top-ups, primogems spent
/// on resin, and every account whose diary can't be reached all land here
/// instead of forcing a re-anchor.
class AddAdjustmentDialog extends ConsumerStatefulWidget {
  const AddAdjustmentDialog({super.key});

  @override
  ConsumerState<AddAdjustmentDialog> createState() =>
      _AddAdjustmentDialogState();
}

class _AddAdjustmentDialogState extends ConsumerState<AddAdjustmentDialog> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _spent = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter how many primogems, as a whole number.');
      return;
    }

    final note = _noteController.text.trim();
    final navigator = Navigator.of(context);
    await ref
        .read(primogemsControllerProvider.notifier)
        .addAdjustment(
          delta: _spent ? -amount : amount,
          note: note.isEmpty ? null : note,
        );
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: const Text('Adjust balance'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Gained')),
                ButtonSegment(value: true, label: Text('Spent')),
              ],
              selected: {_spent},
              onSelectionChanged: (selection) =>
                  setState(() => _spent = selection.first),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _amountController,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Primogems'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note',
                helperText: 'Optional — "bought Welkin", "spent on resin"',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                style: textTheme.bodyLarge?.copyWith(
                  color: context.colors.warning,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
