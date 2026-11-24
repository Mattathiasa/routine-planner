import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/primogem_view_models.dart';
import '../application/primogems_controller.dart';

/// Sets (or re-sets) the primogem balance.
///
/// This is an anchor, not a counter: the number entered here is taken as true
/// at this moment, and everything after it — diary income, wishes, manual
/// corrections — is applied on top. Re-anchoring is the way to fix a balance
/// that has drifted.
class SetBalanceDialog extends ConsumerStatefulWidget {
  const SetBalanceDialog({super.key, required this.data});

  final PrimogemViewData data;

  @override
  ConsumerState<SetBalanceDialog> createState() => _SetBalanceDialogState();
}

class _SetBalanceDialogState extends ConsumerState<SetBalanceDialog> {
  late final TextEditingController _balanceController;
  late final TextEditingController _fatesController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _balanceController = TextEditingController(
      text: widget.data.hasAnchor ? '${widget.data.balance}' : '',
    );
    _fatesController = TextEditingController(
      text: widget.data.hasAnchor ? '${widget.data.fates}' : '',
    );
  }

  @override
  void dispose() {
    _balanceController.dispose();
    _fatesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final balance = int.tryParse(_balanceController.text.trim());
    if (balance == null || balance < 0) {
      setState(() => _error = 'Enter your primogem balance as a whole number.');
      return;
    }
    final fates = int.tryParse(_fatesController.text.trim()) ?? 0;
    if (fates < 0) {
      setState(() => _error = "Fates can't be negative.");
      return;
    }

    final navigator = Navigator.of(context);
    await ref
        .read(primogemsControllerProvider.notifier)
        .setAnchor(balance: balance, fates: fates);
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: Text(
        widget.data.hasAnchor ? 'Update balance' : 'Set your balance',
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nothing reports your primogem balance, so this app tracks it '
              'from a number you give it — the way it tracks resin. After '
              "this, it follows along on its own: income you earn, wishes you "
              'make, and any corrections you add.',
              style: textTheme.bodyLarge?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _balanceController,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Primogems'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _fatesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Fates',
                helperText: 'Intertwined and Acquaint together. Optional.',
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
