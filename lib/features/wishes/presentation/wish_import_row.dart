import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../application/wish_view_models.dart';
import 'import_wish_history_sheet.dart';

/// When this account's history was last imported, and the way to import it.
class WishImportRow extends ConsumerWidget {
  const WishImportRow({super.key, required this.data});

  final WishesViewData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final lastImported = data.lastImportedAt;

    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.labelAccount
                      ? 'Wish history · ${data.accountLabel}'
                      : 'Wish history',
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  lastImported == null
                      ? 'Never imported'
                      : '${data.stats.totalPulls} wishes · imported '
                            '${_relativeDay(lastImported, data.stats.lastPullAt)}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => startWishImportFlow(context, ref),
            child: Text(lastImported == null ? 'Import' : 'Update'),
          ),
        ],
      ),
    );
  }
}

/// Deliberately coarse. The exact minute an import ran is noise; what matters
/// is whether it was recent.
String _relativeDay(DateTime importedAt, DateTime? lastPullAt) {
  final reference = lastPullAt ?? importedAt;
  final days = reference.difference(importedAt).inDays.abs();
  if (days == 0) return 'today';
  if (days == 1) return 'yesterday';
  return '$days days ago';
}
