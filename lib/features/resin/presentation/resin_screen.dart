import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/circle_icon_button.dart';
import 'resin_actions_section.dart';
import 'resin_activity_section.dart';
import 'resin_forecast_section.dart';
import 'resin_ring_section.dart';
import 'resin_stock_section.dart';

class ResinScreen extends StatelessWidget {
  const ResinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 112),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Resin', style: Theme.of(context).textTheme.displayMedium),
                CircleIconButton(
                  icon: Icons.settings_outlined,
                  semanticLabel: 'Settings',
                  onPressed: () => context.push('/settings'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            const ResinRingSection(),
            const SizedBox(height: AppSpacing.xl),
            const ResinForecastSection(),
            const SizedBox(height: AppSpacing.xl),
            const ResinStockSection(),
            const SizedBox(height: AppSpacing.xl),
            const ResinActionsSection(),
            const SizedBox(height: AppSpacing.xl),
            const ResinActivitySection(),
          ],
        ),
      ),
    );
  }
}
