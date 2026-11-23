import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock/game_server.dart';
import '../../../core/providers/current_profile_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/wishes_controller.dart';
import '../data/wish_providers.dart';
import '../domain/gacha_url.dart';

/// Starts the import: disclaimer first, then the paste dialog.
///
/// The disclaimer comes before anything else, for the same reason connecting
/// a HoYoLab account shows one — this talks to an unofficial, reverse-
/// engineered endpoint, and the player should decide that knowingly.
Future<void> startWishImportFlow(BuildContext context, WidgetRef ref) async {
  final acknowledged = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Import wish history?'),
      content: const Text(
        'This reads your wish history from the game using the link the game '
        "itself hands out. That link isn't an official API: it's "
        "reverse-engineered, it isn't supported, and collecting account data "
        'this way is broadly against the terms of service, with a small but '
        'real risk of action against your account.\n\n'
        'The link contains a temporary key, not your password, and this app '
        "never stores it — it's used for this one import and then discarded.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('I understand, continue'),
        ),
      ],
    ),
  );
  if (acknowledged != true || !context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const ImportWishHistoryDialog(),
  );
}

class ImportWishHistoryDialog extends ConsumerStatefulWidget {
  const ImportWishHistoryDialog({super.key});

  @override
  ConsumerState<ImportWishHistoryDialog> createState() =>
      _ImportWishHistoryDialogState();
}

class _ImportWishHistoryDialogState
    extends ConsumerState<ImportWishHistoryDialog> {
  final _controller = TextEditingController();
  bool _running = false;
  String? _error;
  String? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final GachaAuth auth;
    try {
      auth = parseGachaUrl(_controller.text);
    } on InvalidGachaUrlException catch (e) {
      setState(() => _error = e.message);
      return;
    }

    setState(() {
      _running = true;
      _error = null;
      _result = null;
    });

    final profile = await ref.read(currentProfileProvider.future);
    final outcome = await ref
        .read(wishImportServiceProvider)
        .importAll(
          profileId: profile.id,
          auth: auth,
          // The endpoint timestamps wishes in the account's own server time.
          serverOffset: GameServer.values.byName(profile.server).utcOffset,
        );

    ref.invalidate(wishesControllerProvider);
    if (!mounted) return;

    setState(() {
      _running = false;
      _error = outcome.error;
      _result = _summaryFor(outcome.imported);
    });
  }

  String _summaryFor(int imported) {
    if (imported == 0) return 'Already up to date — nothing new to import.';
    if (imported == 1) return 'Imported 1 wish.';
    return 'Imported $imported wishes.';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final done = _result != null && _error == null;

    return AlertDialog(
      title: const Text('Import wish history'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'In the game, open Wish → History, then copy the page link. On a '
              'phone the link is easiest to grab from the PC client or a '
              'browser.',
              style: textTheme.bodyLarge?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _controller,
              autofocus: true,
              enabled: !_running,
              minLines: 2,
              maxLines: 4,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Wish history link',
                hintText: 'https://…authkey=…',
              ),
            ),
            if (_running) ...[
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Reading your history…', style: textTheme.bodyLarge),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                style: textTheme.bodyLarge?.copyWith(
                  color: context.colors.warning,
                ),
              ),
            ],
            if (done) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _result!,
                style: textTheme.bodyLarge?.copyWith(
                  color: context.colors.success,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _running ? null : () => Navigator.of(context).pop(),
          child: Text(done ? 'Done' : 'Cancel'),
        ),
        TextButton(
          onPressed: _running ? null : _import,
          child: Text(done ? 'Import again' : 'Import'),
        ),
      ],
    );
  }
}
