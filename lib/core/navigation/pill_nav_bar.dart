import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';

class _PillNavTab {
  const _PillNavTab(this.icon, this.label);

  final IconData icon;
  final String label;
}

const _tabs = [
  _PillNavTab(Icons.wb_sunny_rounded, 'Today'),
  _PillNavTab(Icons.water_drop_rounded, 'Resin'),
  _PillNavTab(Icons.track_changes, 'Planner'),
  _PillNavTab(Icons.auto_awesome_rounded, 'Wishes'),
];

/// The floating pill bottom nav — 4 tabs (Today/Resin/Planner/Wishes).
/// Settings still has no tab; it's reached via a gear icon on the other
/// screens' headers instead, matching the approved design.
///
/// The tabs stack their icon above their label rather than sitting side by
/// side. Four horizontal icon-and-label pairs do not fit a phone width: at
/// 320dp each tab gets about 64 logical pixels, which ellipsises every label
/// into nonsense. Stacking keeps all four readable at every supported width
/// and text scale, and leaves the pill's own styling untouched.
class PillNavBar extends StatelessWidget {
  const PillNavBar({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            // rgba(surface, .9) — white in light, deep neutral in dark.
            color: context.colors.surface.withValues(alpha: 0.9),
            boxShadow: AppShadows.pillNav,
          ),
          child: Row(
            children: [
              for (var i = 0; i < _tabs.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(child: _buildTab(context, i)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(BuildContext context, int index) {
    final tab = _tabs[index];
    final active = navigationShell.currentIndex == index;
    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: active
          ? context.colors.primaryHover
          : context.colors.textSecondary,
      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
    );

    return Material(
      color: active ? context.colors.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        child: ConstrainedBox(
          // 48dp minimum tap target for each nav destination.
          constraints: const BoxConstraints(minHeight: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                tab.icon,
                size: 20,
                color: active
                    ? context.colors.primaryHover
                    : context.colors.textSecondary,
              ),
              const SizedBox(height: 2),
              Text(
                tab.label,
                style: textStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
