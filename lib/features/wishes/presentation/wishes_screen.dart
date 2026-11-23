import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_status_views.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../application/wish_view_models.dart';
import '../application/wishes_controller.dart';
import 'banner_pity_section.dart';
import 'import_wish_history_sheet.dart';
import 'wish_history_section.dart';
import 'wish_import_row.dart';
import 'wish_stats_section.dart';

bool _hasManualPity(WishesViewData data) =>
    data.banners.any((card) => card.source == PitySource.manual);

class WishesScreen extends ConsumerWidget {
  const WishesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final wishes = ref.watch(wishesControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            // Clears the floating pill nav.
            112,
          ),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // The longest title of the four screens, so at 320dp and
                // large text scale it has to give way rather than overflow.
                // Scaling down beats an ellipsis on a single word.
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text('Wishes', style: textTheme.displayMedium),
                  ),
                ),
                CircleIconButton(
                  icon: Icons.settings_outlined,
                  semanticLabel: 'Settings',
                  onPressed: () => context.push('/settings'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            wishes.when(
              loading: () => const AppLoadingView(height: 240),
              error: (error, _) => AppErrorView(error: error),
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!data.hasHistory && !_hasManualPity(data))
                    AppEmptyView(
                      icon: Icons.auto_awesome_outlined,
                      title: 'No wishes yet',
                      caption:
                          'Import your wish history to see pity, your 5★ '
                          'list and what it all cost.',
                      actionLabel: 'Import wish history',
                      onAction: () => startWishImportFlow(context, ref),
                    )
                  else ...[
                    BannerPitySection(banners: data.banners),
                    const SizedBox(height: AppSpacing.sm),
                    WishImportRow(data: data),
                    if (data.hasHistory) ...[
                      const SizedBox(height: AppSpacing.xl),
                      WishStatsSection(stats: data.stats),
                      const SizedBox(height: AppSpacing.xl),
                      WishHistorySection(entries: data.recentHistory),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
