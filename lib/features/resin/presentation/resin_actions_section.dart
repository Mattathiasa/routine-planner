import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/hoyolab/data/hoyolab_client.dart';
import '../../../core/hoyolab/domain/hoyolab_region.dart';
import '../../../core/providers/hoyolab_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/resin_controller.dart';
import '../domain/resin_engine.dart';
import '../domain/resin_state.dart';
import 'sync_dialog.dart';

/// A fresh profile has `condensed == fragile == 0` and `transient == []`,
/// so "Use Condensed"/"Use Fragile"/"Use Transient" *will* throw until the
/// player has inventory — every mutating button here goes through
/// [_runMutation], which catches [InsufficientResinException]/
/// [InvalidTransientBatchException]/[HoyolabException] and shows a
/// `SnackBar` instead of crashing.
class ResinActionsSection extends ConsumerWidget {
  const ResinActionsSection({super.key});

  Future<void> _runMutation(BuildContext context, Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } on InsufficientResinException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } on InvalidTransientBatchException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } on HoyolabException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } on UnknownHoyolabUidException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Fetches a live resin reading from HoYoLab's unofficial, reverse-
  /// engineered API and feeds it through the exact same `sync()` mutation
  /// the manual Sync dialog already uses — no new resin math needed.
  Future<void> _syncFromHoyolab(WidgetRef ref) async {
    final credentials = await ref.read(hoyolabCredentialsProvider.future);
    if (credentials == null) return;

    final region = hoyolabRegionForUid(credentials.uid);
    final notes = await ref
        .read(hoyolabClientProvider)
        .fetchNotes(cookie: credentials.cookie, uid: credentials.uid, region: region);

    await ref
        .read(resinControllerProvider.notifier)
        .sync(notes.currentResin, fullIn: Duration(seconds: notes.secondsUntilFull));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resinState = ref.watch(resinControllerProvider).value;
    final controller = ref.read(resinControllerProvider.notifier);
    final soonestTransient = _soonestExpiring(resinState?.transient);
    final hoyolabConnected = ref.watch(hoyolabCredentialsProvider).value != null;

    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: AppShadows.primaryButton,
          ),
          child: ElevatedButton.icon(
            onPressed: () => showDialog<void>(context: context, builder: (_) => const SyncDialog()),
            icon: const Icon(Icons.sync),
            label: const Text('Sync with game'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
            ),
          ),
        ),
        if (hoyolabConnected) ...[
          const SizedBox(height: AppSpacing.smd),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => _runMutation(context, () => _syncFromHoyolab(ref)),
              icon: const Icon(Icons.cloud_sync_outlined),
              label: const Text('Sync from HoYoLab'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.smd),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.smd,
          crossAxisSpacing: AppSpacing.smd,
          childAspectRatio: 2.6,
          children: [
            _ActionButton(
              label: 'Spend 20',
              sublabel: 'Domain run',
              onPressed: () =>
                  _runMutation(context, () => controller.spend(20, label: 'Domain run')),
            ),
            _ActionButton(
              label: 'Spend 40',
              sublabel: 'Boss run',
              onPressed: () =>
                  _runMutation(context, () => controller.spend(40, label: 'Boss run')),
            ),
            _ActionButton(
              label: 'Craft Condensed',
              sublabel: 'Uses 40',
              onPressed: () =>
                  _runMutation(context, () => controller.craftCondensed(cost: 40)),
            ),
            _ActionButton(
              label: 'Use Condensed',
              sublabel: 'Double rewards',
              onPressed: () => _runMutation(context, controller.useCondensed),
            ),
            _ActionButton(
              label: 'Use Fragile',
              sublabel: '+60, can pass cap',
              onPressed: () => _runMutation(context, controller.useFragile),
            ),
            _ActionButton(
              label: 'Use Transient',
              sublabel: '+60, expires first',
              onPressed: soonestTransient == null
                  ? null
                  : () => _runMutation(
                      context,
                      () => controller.useTransient(soonestTransient.id),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  TransientResinBatch? _soonestExpiring(List<TransientResinBatch>? batches) {
    if (batches == null || batches.isEmpty) return null;
    final sorted = [...batches]..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    return sorted.first;
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.sublabel, required this.onPressed});

  final String label;
  final String sublabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.mlg, vertical: AppSpacing.smd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleLarge),
          Text(
            sublabel,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
