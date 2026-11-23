import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/wish_view_models.dart';
import '../application/wishes_controller.dart';

/// Types in one banner's pity by hand, for accounts with no imported history.
///
/// Getting the wish-history link is awkward on a phone, so an account that
/// can't produce one is still worth tracking — it just has to be told the
/// numbers. Imported history always wins over this, which is why the dialog
/// says so when there is any.
class ManualPityDialog extends ConsumerStatefulWidget {
  const ManualPityDialog({super.key, required this.card});

  final BannerPityCard card;

  @override
  ConsumerState<ManualPityDialog> createState() => _ManualPityDialogState();
}

class _ManualPityDialogState extends ConsumerState<ManualPityDialog> {
  late final TextEditingController _fiveController;
  late final TextEditingController _fourController;
  late bool _guaranteed;
  String? _error;

  @override
  void initState() {
    super.initState();
    final card = widget.card;
    final manual = card.source == PitySource.manual;
    _fiveController = TextEditingController(
      text: manual ? '${card.pity}' : '',
    );
    _fourController = TextEditingController(
      text: manual ? '${card.pityFour}' : '',
    );
    _guaranteed = manual && card.guaranteedNextFive;
  }

  @override
  void dispose() {
    _fiveController.dispose();
    _fourController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final five = _parse(_fiveController.text, max: widget.card.hardPity);
    final four = _parse(_fourController.text, max: 10);
    if (five == null) {
      setState(() {
        _error = 'Enter a 5★ pity between 0 and ${widget.card.hardPity}.';
      });
      return;
    }

    final navigator = Navigator.of(context);
    await ref
        .read(wishesControllerProvider.notifier)
        .setManualPity(
          widget.card.banner,
          pityFive: five,
          pityFour: four ?? 0,
          guaranteed: _guaranteed,
        );
    if (mounted) navigator.pop();
  }

  Future<void> _clear() async {
    final navigator = Navigator.of(context);
    await ref
        .read(wishesControllerProvider.notifier)
        .setManualPity(
          widget.card.banner,
          pityFive: null,
          pityFour: null,
          guaranteed: null,
        );
    if (mounted) navigator.pop();
  }

  int? _parse(String raw, {required int max}) {
    final value = int.tryParse(raw.trim());
    if (value == null || value < 0 || value > max) return null;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final card = widget.card;
    final hasImported = card.source == PitySource.imported;

    return AlertDialog(
      title: Text('${card.label} pity'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasImported)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  'This banner already has imported history, which is used '
                  'instead of anything entered here.',
                  style: textTheme.bodyLarge?.copyWith(
                    color: context.colors.warning,
                  ),
                ),
              ),
            TextField(
              controller: _fiveController,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Wishes since your last 5★',
                helperText: 'Guarantee at ${card.hardPity}',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _fourController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Wishes since your last 4★',
                helperText: 'Optional',
              ),
            ),
            if (card.banner.showsFiftyFifty) ...[
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _guaranteed,
                onChanged: (value) => setState(() => _guaranteed = value),
                title: const Text('Next 5★ is guaranteed'),
                subtitle: const Text('Your last 5★ was off-banner'),
              ),
            ],
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
        if (card.source == PitySource.manual)
          TextButton(onPressed: _clear, child: const Text('Clear')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
