import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../application/planner_controller.dart';
import 'most_needed_section.dart';
import 'planner_header.dart';
import 'target_card.dart';

class PlannerScreen extends ConsumerWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plannerAsync = ref.watch(plannerControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: plannerAsync.when(
          data: (data) => ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 112),
            children: [
              PlannerHeader(
                targetCount: data.targets.length,
                materialsShortCount: data.materialsShortCount,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Targets', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: AppSpacing.md),
              for (final target in data.targets) ...[
                TargetCard(data: target),
                const SizedBox(height: AppSpacing.md),
              ],
              const SizedBox(height: AppSpacing.sm),
              MostNeededSection(rows: data.mostNeeded),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
        ),
      ),
    );
  }
}
