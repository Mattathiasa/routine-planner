import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_status_views.dart';
import '../../accounts/data/accounts_refresh_providers.dart';
import '../../accounts/presentation/accounts_strip.dart';
import '../application/today_controller.dart';
import 'resin_hero_card.dart';
import 'today_header.dart';
import 'todays_farm_section.dart';
import 'week_strip.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(todayControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          // An explicit pull forces past the freshness window — the user
          // asking for current numbers outranks the request throttle.
          onRefresh: () =>
              ref.read(refreshAllAccountsProvider(force: true).future),
          child: todayAsync.when(
            data: (data) => ListView(
              // The strip scrolls horizontally edge to edge, so it manages
              // its own horizontal padding; the list only insets the rest.
              padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: 112),
              children: [
                const _Inset(child: TodayHeader()),
                const SizedBox(height: AppSpacing.xl),
                _Inset(child: WeekStrip(week: data.week)),
                const SizedBox(height: AppSpacing.xl),
                const AccountsStrip(),
                const SizedBox(height: AppSpacing.xl),
                const _Inset(child: ResinHeroCard()),
                const SizedBox(height: AppSpacing.xl),
                _Inset(child: TodaysFarmSection(farmCards: data.farmCards)),
              ],
            ),
            loading: () => const AppLoadingView(),
            error: (error, stack) => Center(child: AppErrorView(error: error)),
          ),
        ),
      ),
    );
  }
}

/// The screen's standard horizontal gutter, applied per section so the
/// account strip can opt out of it.
class _Inset extends StatelessWidget {
  const _Inset({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: child,
    );
  }
}
