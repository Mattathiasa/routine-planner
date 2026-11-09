import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/hoyolab_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';

/// Connects/disconnects a HoYoLab account for Resin's "Sync from HoYoLab"
/// action. This is the one place the ToS/account-risk disclaimer actually
/// gets surfaced — not buried in subtext — since connecting is the one
/// action in this whole app that touches a real external account.
class HoyolabAccountSection extends ConsumerWidget {
  const HoyolabAccountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credentialsAsync = ref.watch(hoyolabCredentialsProvider);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('HoYoLab account', style: textTheme.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: AppRadius.cardRadius,
          child: DecoratedBox(
            decoration: const BoxDecoration(color: AppColors.surface, boxShadow: AppShadows.card),
            // Secure-storage reads resolve near-instantly on a real device,
            // so "not yet known" and "not connected" look the same to the
            // user — deliberately not an indeterminate spinner here, which
            // would animate forever if the read is ever slow to resolve.
            child: credentialsAsync.maybeWhen(
              data: (credentials) => credentials != null
                  ? _ConnectedRow(uid: credentials.uid, onDisconnect: () => _disconnect(ref))
                  : _DisconnectedRow(onConnect: () => _startConnectFlow(context, ref)),
              orElse: () => _DisconnectedRow(onConnect: () => _startConnectFlow(context, ref)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _disconnect(WidgetRef ref) async {
    await ref.read(hoyolabCredentialsStoreProvider).clear();
    ref.invalidate(hoyolabCredentialsProvider);
  }

  Future<void> _startConnectFlow(BuildContext context, WidgetRef ref) async {
    final acknowledged = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Connect HoYoLab account?'),
        content: const Text(
          "This uses an unofficial, reverse-engineered HoYoLab API — not something HoYoverse "
          'sanctions. Their Terms of Service broadly prohibit third-party tools that collect '
          'account data, and violating it can mean account suspension. That risk is real, even '
          'if small for a read-only resin check, and only you can decide whether to take it. '
          "You'll log in on HoYoLab's own site, shown inside the app — this app never sees "
          'your password, only the session it creates, which stays on this device.',
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

    final cookie = await ref.read(hoyolabWebLoginProvider).captureCookie(context);
    if (cookie == null || !context.mounted) return;

    await showDialog<void>(context: context, builder: (_) => _ConnectFormDialog(cookie: cookie));
  }
}

class _DisconnectedRow extends StatelessWidget {
  const _DisconnectedRow({required this.onConnect});

  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Not connected', style: textTheme.titleMedium),
                Text('Auto-fill resin from your HoYoLab account', style: textTheme.bodyMedium),
              ],
            ),
          ),
          TextButton(onPressed: onConnect, child: const Text('Connect')),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
    );
  }
}

class _ConnectedRow extends StatelessWidget {
  const _ConnectedRow({required this.uid, required this.onDisconnect});

  final String uid;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Connected', style: textTheme.titleMedium),
                Text('UID $uid', style: textTheme.bodyMedium),
              ],
            ),
          ),
          TextButton(onPressed: onDisconnect, child: const Text('Disconnect')),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
    );
  }
}

/// Shown after [HoyolabWebLogin] has already captured a session cookie —
/// this just asks for the in-game UID, which identifies which character
/// to fetch resin for and isn't part of the HoYoLab login session itself.
class _ConnectFormDialog extends ConsumerStatefulWidget {
  const _ConnectFormDialog({required this.cookie});

  final String cookie;

  @override
  ConsumerState<_ConnectFormDialog> createState() => _ConnectFormDialogState();
}

class _ConnectFormDialogState extends ConsumerState<_ConnectFormDialog> {
  final _uidController = TextEditingController();

  @override
  void dispose() {
    _uidController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final uid = _uidController.text.trim();
    if (uid.isEmpty || int.tryParse(uid) == null) return;

    final navigator = Navigator.of(context);
    await ref.read(hoyolabCredentialsStoreProvider).save(cookie: widget.cookie, uid: uid);
    ref.invalidate(hoyolabCredentialsProvider);
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Connect HoYoLab'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("You're logged in. Enter your in-game UID to finish connecting."),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _uidController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Game UID'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
