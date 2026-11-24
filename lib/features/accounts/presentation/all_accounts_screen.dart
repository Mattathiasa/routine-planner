import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_profile_provider.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_status_views.dart';
import '../application/account_view_models.dart';
import '../application/accounts_overview_controller.dart';
import '../data/accounts_refresh_providers.dart';
import 'account_card.dart';

/// Every account in full, side by side, with the totals across them.
///
/// A pushed screen rather than a nav tab, like Settings: it's somewhere you
/// go to compare and tidy up, not one of the four places you live in. The
/// Today strip stays the at-a-glance view.
class AllAccountsScreen extends ConsumerWidget {
  const AllAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final accounts = ref.watch(accountsOverviewControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(refreshAllAccountsProvider(force: true).future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.xl,
              AppSpacing.xxl,
            ),
            children: [
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.chevron_left, color: context.colors.primary),
                label: Text(
                  'Back',
                  style: textTheme.titleMedium?.copyWith(
                    color: context.colors.primary,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                  minimumSize: const Size(0, 48),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text('All accounts', style: textTheme.displayMedium),
              const SizedBox(height: AppSpacing.xxl),
              accounts.when(
                loading: () => const AppLoadingView(height: 240),
                error: (error, _) => AppErrorView(error: error),
                data: (data) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (data.length > 1) ...[
                      _Totals(accounts: data),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                    for (final account in data) ...[
                      _Account(data: account),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the accounts add up to.
///
/// Only shown with more than one account: with a single account every row
/// would just repeat the card below it.
class _Totals extends StatelessWidget {
  const _Totals({required this.accounts});

  final List<AccountOverviewData> accounts;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final commissionsDone = accounts.fold<int>(
      0,
      (sum, a) => sum + a.commissions.completed,
    );
    final commissionsTotal = accounts.fold<int>(
      0,
      (sum, a) => sum + a.commissions.total,
    );
    final nearCap = accounts
        .where((a) => a.resin >= a.resinCap * 0.8)
        .length;
    final primogems = accounts
        .map((a) => a.primogems)
        .nonNulls
        .fold<int>(0, (sum, value) => sum + value);
    final wishes = accounts
        .map((a) => a.wishesAffordable)
        .nonNulls
        .fold<int>(0, (sum, value) => sum + value);
    final tracked = accounts.where((a) => a.primogems != null).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Across ${accounts.length} accounts', style: textTheme.headlineLarge),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            children: [
              _TotalRow(
                label: 'Commissions',
                value: '$commissionsDone/$commissionsTotal done',
              ),
              _TotalRow(
                label: 'Near resin cap',
                value: nearCap == 0
                    ? 'none'
                    : '$nearCap of ${accounts.length}',
                // The one row worth flagging: resin at the cap is resin
                // being wasted.
                highlight: nearCap > 0,
              ),
              if (tracked > 0)
                _TotalRow(
                  label: 'Primogems',
                  value: tracked == accounts.length
                      ? '$primogems · $wishes wishes'
                      : '$primogems · $wishes wishes (of $tracked tracked)',
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: textTheme.titleMedium)),
          Text(
            value,
            style: textTheme.labelLarge?.copyWith(
              color: highlight
                  ? context.colors.warning
                  : context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Account extends ConsumerWidget {
  const _Account({required this.data});

  final AccountOverviewData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(accountsOverviewControllerProvider.notifier);

    return AccountCard(
      data: data,
      fillWidth: true,
      onSelect: () async {
        await ref
            .read(profileRepositoryProvider)
            .selectProfile(data.profileId);
        ref.invalidate(currentProfileProvider);
      },
      onBumpCommissions: () => controller.bumpManualCommissions(data.profileId),
      onToggleBonus: () => controller.toggleManualBonus(data.profileId),
    );
  }
}
