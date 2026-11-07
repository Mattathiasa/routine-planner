import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
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
        child: todayAsync.when(
          data: (data) => ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              112,
            ),
            children: [
              const TodayHeader(),
              const SizedBox(height: AppSpacing.xl),
              WeekStrip(week: data.week),
              const SizedBox(height: AppSpacing.xl),
              const ResinHeroCard(),
              const SizedBox(height: AppSpacing.xl),
              TodaysFarmSection(farmCards: data.farmCards),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
        ),
      ),
    );
  }
}
