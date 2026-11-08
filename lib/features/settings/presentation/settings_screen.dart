import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import 'data_section.dart';
import 'game_server_section.dart';
import 'hoyolab_account_section.dart';
import 'notifications_section.dart';
import 'planner_settings_section.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.xxl),
          children: [
            TextButton.icon(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.chevron_left, color: AppColors.primary),
              label: Text('Today', style: textTheme.titleMedium?.copyWith(color: AppColors.primary)),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
                minimumSize: const Size(0, 44),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('Settings', style: textTheme.displayMedium),
            const SizedBox(height: AppSpacing.xxl),
            const GameServerSection(),
            const SizedBox(height: AppSpacing.xl),
            const PlannerSettingsSection(),
            const SizedBox(height: AppSpacing.xl),
            const NotificationsSection(),
            const SizedBox(height: AppSpacing.xl),
            const HoyolabAccountSection(),
            const SizedBox(height: AppSpacing.xl),
            const DataSection(),
            const SizedBox(height: AppSpacing.xxl),
            const _Footer(),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Text(
          'Routine Planner 0.1.0',
          style: textTheme.headlineMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          "Unofficial fan-made companion. Not affiliated with or endorsed by the game's publisher.",
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
      ],
    );
  }
}
