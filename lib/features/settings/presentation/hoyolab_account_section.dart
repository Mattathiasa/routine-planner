import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_profile_provider.dart';
import '../../../core/providers/hoyolab_providers.dart';
import '../../../core/providers/profile_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';

/// Connects/disconnects a HoYoLab account for Resin's "Sync from HoYoLab"
/// action. This is the one place the ToS/account-risk disclaimer actually
/// gets surfaced — not buried in subtext — since connecting is the one
/// action in this whole app that touches a real external account.
///
/// Scoped to the selected local account: the header names it, and
/// connecting here leaves every other account's login untouched.
class HoyolabAccountSection extends ConsumerWidget {
  const HoyolabAccountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credentialsAsync = ref.watch(hoyolabCredentialsProvider);
    final textTheme = Theme.of(context).textTheme;
    final heading = _headingFor(ref);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(heading, style: textTheme.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: AppRadius.cardRadius,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.colors.surface,
              boxShadow: AppShadows.card,
            ),
            // Secure-storage reads resolve near-instantly on a real device,
            // so "not yet known" and "not connected" look the same to the
            // user — deliberately not an indeterminate spinner here, which
            // would animate forever if the read is ever slow to resolve.
            child: credentialsAsync.maybeWhen(
              data: (credentials) => credentials != null
                  ? _ConnectedRow(
                      uid: credentials.uid,
                      onDisconnect: () => _disconnect(ref),
                    )
                  : _DisconnectedRow(
                      onConnect: () => _startConnectFlow(context, ref),
                    ),
              orElse: () => _DisconnectedRow(
                onConnect: () => _startConnectFlow(context, ref),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Names the account this section acts on, but only once there is more
  /// than one — with a single account the plain heading reads better.
  String _headingFor(WidgetRef ref) {
    final profiles = ref.watch(profileListProvider).value;
    if (profiles == null || profiles.length < 2) return 'HoYoLab account';
    final currentId = ref.watch(currentProfileProvider).value?.id;
    for (final profile in profiles) {
      if (profile.id == currentId) {
        return 'HoYoLab account for ${profile.displayName}';
      }
    }
    return 'HoYoLab account';
  }

  Future<void> _disconnect(WidgetRef ref) async {
    final profileId = (await ref.read(currentProfileProvider.future)).id;
    await ref.read(hoyolabCredentialsStoreProvider).clear(profileId);
    ref.invalidate(hoyolabCredentialsForProvider(profileId));
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
          'your password, only the session it creates, which stays on this device. '
          "You'll be signed out of HoYoLab in the app's browser first, so you can pick which "
          'account to connect — each of your accounts keeps its own separate login.',
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

    // Sign out first, so the login page can't hand back the previously
    // connected account's still-valid session instead of the one being
    // connected now.
    await ref.read(hoyolabWebLoginProvider).clearSession();
    if (!context.mounted) return;

    final cookie = await ref
        .read(hoyolabWebLoginProvider)
        .captureCookie(context);
    if (cookie == null || !context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (_) => _ConnectFormDialog(cookie: cookie),
    );
  }
}

class _DisconnectedRow extends StatelessWidget {
  const _DisconnectedRow({required this.onConnect});

  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Not connected', style: textTheme.titleMedium),
                Text(
                  'Auto-fill resin from your HoYoLab account',
                  style: textTheme.bodyMedium,
                ),
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
  String? _error;

  @override
  void dispose() {
    _uidController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final uid = _uidController.text.trim();
    if (uid.isEmpty || int.tryParse(uid) == null) {
      setState(() => _error = 'Enter your in-game UID, digits only.');
      return;
    }

    final profileId = (await ref.read(currentProfileProvider.future)).id;

    // Two local accounts pointing at the same game UID would race each
    // other: both would sync the same resin into two separate anchors, and
    // every number on both cards would look almost-right and never agree.
    // Easier to refuse than to explain afterwards.
    final clash = await _profileAlreadyUsing(uid, besides: profileId);
    if (clash != null) {
      if (!mounted) return;
      setState(() {
        _error =
            'UID $uid is already connected to "$clash". Each account needs '
            'its own UID.';
      });
      return;
    }

    if (!mounted) return;
    final navigator = Navigator.of(context);
    await ref
        .read(hoyolabCredentialsStoreProvider)
        .save(profileId: profileId, cookie: widget.cookie, uid: uid);
    ref.invalidate(hoyolabCredentialsForProvider(profileId));
    ref.invalidate(hoyolabCredentialsProvider);
    if (mounted) navigator.pop();
  }

  /// The display name of another account already connected to [uid], or null.
  Future<String?> _profileAlreadyUsing(
    String uid, {
    required String besides,
  }) async {
    final profiles = await ref.read(profileListProvider.future);
    final store = ref.read(hoyolabCredentialsStoreProvider);
    for (final profile in profiles) {
      if (profile.id == besides) continue;
      final credentials = await store.read(profile.id);
      if (credentials?.uid == uid) return profile.displayName;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Connect HoYoLab'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "You're logged in. Enter your in-game UID to finish connecting.",
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _uidController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Game UID'),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: context.colors.warning,
              ),
            ),
          ],
        ],
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
