import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_profile_provider.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/planner_controller.dart';
import '../data/planner_providers.dart';

/// Every catalog material with an editable count — the only place in the
/// app `MaterialInventory` rows can be written, which is what every
/// target's "% in hand" and the "Most needed" list's `have` column are
/// computed from. A transient workflow, not a bookmarkable destination —
/// pushed with a plain `Navigator.push`, same reasoning as
/// `AddTargetScreen`.
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _controllers = <String, TextEditingController>{};

  TextEditingController _controllerFor(InventoryRow row) {
    return _controllers.putIfAbsent(
      row.materialId,
      () => TextEditingController(text: '${row.count}'),
    );
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit(InventoryRow row, String text) async {
    final value = int.tryParse(text);
    if (value == null) return;
    final clamped = value < 0 ? 0 : value;

    final profileId = (await ref.read(currentProfileProvider.future)).id;
    await ref.read(plannerRepositoryProvider).setInventoryCount(profileId, row.materialId, clamped);
    ref.invalidate(inventoryRowsProvider);
    // The one invalidation that actually matters — without it, Planner
    // keeps showing stale percentages until some unrelated mutation
    // happens to invalidate it first.
    ref.invalidate(plannerControllerProvider);
  }

  @override
  Widget build(BuildContext context) {
    final rowsAsync = ref.watch(inventoryRowsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: SafeArea(
        child: rowsAsync.when(
          data: (rows) => ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              ClipRRect(
                borderRadius: AppRadius.cardRadius,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    boxShadow: AppShadows.card,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0) const Divider(height: 1, color: AppColors.divider),
                        _InventoryRow(
                          row: rows[i],
                          controller: _controllerFor(rows[i]),
                          onSubmitted: (text) => _submit(rows[i], text),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
        ),
      ),
    );
  }
}

class _InventoryRow extends StatelessWidget {
  const _InventoryRow({required this.row, required this.controller, required this.onSubmitted});

  final InventoryRow row;
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          const SizedBox(width: AppSpacing.lg),
          Expanded(child: Text(row.label, style: Theme.of(context).textTheme.titleMedium)),
          SizedBox(
            width: 100,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.right,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(isDense: true, border: InputBorder.none),
              onSubmitted: onSubmitted,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
        ],
      ),
    );
  }
}
