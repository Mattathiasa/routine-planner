import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../application/planner_controller.dart';
import 'add_target_screen.dart';
import 'most_needed_section.dart';
import 'planner_header.dart';
import 'target_card.dart';
import '../../../core/widgets/app_status_views.dart';
import '../../../core/theme/app_motion.dart';

class PlannerScreen extends ConsumerWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plannerAsync = ref.watch(plannerControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: plannerAsync.when(
          data: (data) => ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              112,
            ),
            children: [
              PlannerHeader(
                targetCount: data.targets.length,
                materialsShortCount: data.materialsShortCount,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Targets', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: AppSpacing.md),
              if (data.targets.isEmpty)
                AppEmptyView(
                  icon: Icons.flag_outlined,
                  title: 'No targets yet',
                  caption: 'Add a character or weapon to see every material it still needs.',
                  actionLabel: 'Add target',
                  onAction: () => Navigator.of(context).push(
                    AppPageRoute<void>(builder: (_) => const AddTargetScreen()),
                  ),
                )
              else
                for (final target in data.targets) ...[
                  TargetCard(data: target),
                  const SizedBox(height: AppSpacing.md),
                ],
              const SizedBox(height: AppSpacing.sm),
              MostNeededSection(rows: data.mostNeeded),
            ],
          ),
          loading: () => const AppLoadingView(),
          error: (error, stack) => Center(child: AppErrorView(error: error)),
        ),
      ),
    );
  }
}
