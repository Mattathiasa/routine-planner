import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import 'add_target_screen.dart';
import 'inventory_screen.dart';

class PlannerHeader extends StatelessWidget {
  const PlannerHeader({super.key, required this.targetCount, required this.materialsShortCount});

  final int targetCount;
  final int materialsShortCount;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Planner', style: textTheme.displayMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$targetCount targets · $materialsShortCount materials short',
                style: textTheme.bodyLarge,
              ),
              TextButton(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const InventoryScreen())),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  alignment: Alignment.centerLeft,
                ),
                child: const Text('Edit inventory', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        _AddTargetButton(),
      ],
    );
  }
}

class _AddTargetButton extends StatelessWidget {
  const _AddTargetButton();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.all(Radius.circular(999)),
        boxShadow: AppShadows.primaryButton,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(999)),
          onTap: () =>
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddTargetScreen())),
          child: const Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 16, 0),
            child: SizedBox(
              height: 44,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: Colors.white, size: 18),
                  SizedBox(width: AppSpacing.xs),
                  Text(
                    'Add target',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
