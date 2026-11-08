import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/circle_icon_button.dart';
import '../../resin/domain/resin_engine.dart';
import '../application/today_controller.dart';
import '../application/today_view_models.dart';

String _subtitle(FarmTaskRowData row) {
  final cap = row.maxRunsPerPeriod;
  if (cap != null) {
    final left = cap - row.runsDone;
    final resetText = row.resetsWeekly ? ' · resets Monday' : '';
    return '$left of $cap left$resetText';
  }
  return '${row.runsDone} run${row.runsDone == 1 ? '' : 's'} logged today';
}

class FarmTaskRow extends ConsumerWidget {
  const FarmTaskRow({super.key, required this.row, required this.costResin});

  final FarmTaskRowData row;
  final int costResin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final controller = ref.read(todayControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Checkbox(
            value: row.checked,
            onChanged: (value) => controller.toggleTask(row.taskId, value ?? false),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.label, style: textTheme.titleLarge),
                Text(
                  _subtitle(row),
                  style: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          CircleIconButton(
            icon: Icons.add,
            size: 36,
            semanticLabel: 'Log a run: ${row.label}',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await controller.logRun(taskId: row.taskId, costResin: costResin);
              } on InsufficientResinException catch (e) {
                messenger.showSnackBar(SnackBar(content: Text(e.message)));
              }
            },
          ),
        ],
      ),
    );
  }
}
