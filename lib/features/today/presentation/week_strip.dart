import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/today_view_models.dart';

const _dayAbbreviations = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class WeekStrip extends StatelessWidget {
  const WeekStrip({super.key, required this.week});

  final List<WeekDayInfo> week;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < week.length; i++)
          Expanded(child: _WeekDayCell(day: week[i], index: i)),
      ],
    );
  }
}

class _WeekDayCell extends StatelessWidget {
  const _WeekDayCell({required this.day, required this.index});

  final WeekDayInfo day;
  final int index;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dotCount = day.openDomainCount.clamp(0, 4);

    return Semantics(
      label:
          '${day.openDomainCount} domain${day.openDomainCount == 1 ? '' : 's'}',
      child: Column(
        children: [
          Text(
            _dayAbbreviations[index],
            style: textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '${day.date.day}',
            style: day.isToday
                ? textTheme.titleLarge?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800)
                : textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < dotCount; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
