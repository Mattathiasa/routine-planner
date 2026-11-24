import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_profile_provider.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_status_views.dart';
import '../../../core/theme/app_motion.dart';
import '../application/account_view_models.dart';
import '../application/accounts_overview_controller.dart';
import 'account_card.dart';
import 'all_accounts_screen.dart';

/// Every local account's resin and daily commission progress, side by
/// side at the top of Today — the one place a multi-account player can see
/// all their accounts without switching between them.
class AccountsStrip extends ConsumerWidget {
  const AccountsStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsOverviewControllerProvider);
    final textTheme = Theme.of(context).textTheme;

    return accountsAsync.when(
      data: (accounts) {
        if (accounts.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The cards scroll edge to edge, so only the header carries
            // the screen's horizontal gutter.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      accounts.length == 1 ? 'Your account' : 'All accounts',
                      style: textTheme.headlineLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Only worth showing when it actually pools something;
                  // with one account it just repeats the card below.
                  if (accounts.length > 1)
                    Text(
                      _commissionSummary(accounts),
                      style: textTheme.bodyLarge,
                    ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      AppPageRoute<void>(
                        builder: (_) => const AllAccountsScreen(),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      minimumSize: const Size(0, 48),
                    ),
                    child: const Text('See all'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              // Cancels the screen's own horizontal padding so cards can
              // scroll off both edges instead of stopping short of them.
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              // IntrinsicHeight bounds the row so `stretch` can give every
              // card the tallest card's height; without it a horizontally
              // scrolling row has infinite height to stretch into.
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < accounts.length; i++) ...[
                      if (i > 0) const SizedBox(width: AppSpacing.md),
                      _Card(data: accounts[i]),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox(height: 180, child: AppLoadingView()),
      error: (error, stack) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: AppErrorView(error: error),
      ),
    );
  }

  /// "5/8 commissions" pooled across accounts — the number a multi-account
  /// player actually wants at a glance.
  String _commissionSummary(List<AccountOverviewData> accounts) {
    var done = 0;
    var total = 0;
    for (final account in accounts) {
      done += account.commissions.completed;
      total += account.commissions.total;
    }
    return '$done/$total commissions';
  }
}

class _Card extends ConsumerWidget {
  const _Card({required this.data});

  final AccountOverviewData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(accountsOverviewControllerProvider.notifier);
    return AccountCard(
      data: data,
      onSelect: () => _select(ref, data.profileId),
      onBumpCommissions: () => controller.bumpManualCommissions(data.profileId),
      onToggleBonus: () => controller.toggleManualBonus(data.profileId),
    );
  }

  Future<void> _select(WidgetRef ref, String profileId) async {
    await ref.read(profileRepositoryProvider).selectProfile(profileId);
    // Everything downstream watches currentProfileProvider, so this one
    // invalidation switches the whole app over.
    ref.invalidate(currentProfileProvider);
  }
}
