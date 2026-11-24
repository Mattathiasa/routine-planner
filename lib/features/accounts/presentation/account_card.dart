import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/percent_ring_gauge.dart';
import '../../../core/widgets/rolling_number.dart';
import '../../resin/presentation/resin_formatting.dart';
import '../application/account_view_models.dart';

/// One account on the all-accounts strip: its resin, its daily commission
/// progress, and whatever live extras that account reports.
///
/// Deliberately a white [AppCard]-style surface rather than a second
/// gradient — Today already has exactly one gradient hero card (the resin
/// card), per the approved design.
class AccountCard extends StatelessWidget {
  const AccountCard({
    super.key,
    required this.data,
    required this.onSelect,
    required this.onBumpCommissions,
    required this.onToggleBonus,
  });

  static const width = 212.0;

  final AccountOverviewData data;
  final VoidCallback onSelect;
  final VoidCallback onBumpCommissions;
  final VoidCallback onToggleBonus;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final selected = data.isSelected;

    return SizedBox(
      width: width,
      // explicitChildNodes, not ExcludeSemantics: the card names itself
      // for the switch gesture while its own controls (log a commission,
      // claim the bonus) keep their separate, reachable nodes.
      child: Semantics(
        selected: selected,
        button: !selected,
        explicitChildNodes: true,
        label: selected
            ? '${data.displayName}, ${data.serverLabel} server, selected'
            : 'Switch to ${data.displayName}, ${data.serverLabel} server',
        child: Builder(
          builder: (context) => Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: AppRadius.cardRadius,
              onTap: selected ? null : onSelect,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: AppRadius.cardRadius,
                  boxShadow: AppShadows.card,
                  border: selected
                      ? Border.fromBorderSide(
                          BorderSide(color: context.colors.primary, width: 2),
                        )
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.mlg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Header(data: data),
                      const SizedBox(height: AppSpacing.md),
                      _ResinLine(data: data),
                      const SizedBox(height: AppSpacing.md),
                      _CommissionsRow(
                        data: data,
                        onBumpCommissions: onBumpCommissions,
                        onToggleBonus: onToggleBonus,
                      ),
                      ..._extras(context, textTheme),
                      if (data.refreshError != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          data.refreshError!,
                          style: textTheme.bodySmall?.copyWith(
                            color: context.colors.warning,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      Text(_footerLabel(), style: textTheme.labelSmall),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _extras(BuildContext context, TextTheme textTheme) {
    final lines = <String>[
      if (data.finishedExpeditions != null && data.totalExpeditions != null)
        'Expeditions ${data.finishedExpeditions}/${data.totalExpeditions} back',
      if (data.remainBossDiscounts != null && data.bossDiscountLimit != null)
        'Boss discounts ${data.remainBossDiscounts}/${data.bossDiscountLimit} left',
      if (data.realmCurrency != null && data.realmCurrencyCap != null)
        'Realm ${data.realmCurrency}/${data.realmCurrencyCap}',
      // Wishes and primogems are tracked per account too, so they belong on
      // every card and not only the selected account's screen.
      if (data.characterPity != null && data.characterHardPity != null)
        'Pity ${data.characterPity}/${data.characterHardPity}'
            '${data.pityIsManual ? ' (by hand)' : ''}',
      if (data.primogems != null && data.wishesAffordable != null)
        '${data.primogems} primogems · ${data.wishesAffordable} wishes',
    ];
    if (lines.isEmpty) return const [];

    return [
      const SizedBox(height: AppSpacing.sm),
      for (final line in lines)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            line,
            style: textTheme.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ];
  }

  String _footerLabel() {
    if (!data.connected) return 'Tracked manually';
    final updated = data.lastUpdated;
    if (updated == null) return 'Not synced yet';
    return 'Updated ${formatTime(updated)}';
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.data});

  final AccountOverviewData data;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            data.displayName,
            style: textTheme.titleLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (data.isSelected)
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: context.colors.primary,
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }
}

class _ResinLine extends StatelessWidget {
  const _ResinLine({required this.data});

  final AccountOverviewData data;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final fullAt = data.resinFullAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: RollingNumber(
                  data.resin,
                  style: textTheme.displaySmall?.copyWith(
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xxs),
            Text('/ ${data.resinCap}', style: textTheme.bodyLarge),
          ],
        ),
        Text(
          fullAt == null ? 'Resin is full' : 'Full at ${formatTime(fullAt)}',
          style: textTheme.bodyMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _CommissionsRow extends StatelessWidget {
  const _CommissionsRow({
    required this.data,
    required this.onBumpCommissions,
    required this.onToggleBonus,
  });

  final AccountOverviewData data;
  final VoidCallback onBumpCommissions;
  final VoidCallback onToggleBonus;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final commissions = data.commissions;
    final manual = commissions.source == CommissionSource.manual;

    final gauge = PercentRingGauge(
      percent: commissions.percent,
      semanticLabel:
          '${commissions.completed} of ${commissions.total} commissions done',
    );

    return Row(
      children: [
        // A manual account's gauge is the control: tapping advances the
        // count. A live one only reports what HoYoLab says.
        if (manual)
          _TapTarget(
            onTap: () {
              unawaitedHaptic();
              onBumpCommissions();
            },
            semanticLabel: 'Log a commission for ${data.displayName}',
            child: gauge,
          )
        else
          gauge,
        const SizedBox(width: AppSpacing.smd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${commissions.completed}/${commissions.total} commissions',
                style: textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              _BonusLine(
                data: data,
                manual: manual,
                onToggleBonus: onToggleBonus,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static void unawaitedHaptic() {
    unawaited(HapticFeedback.selectionClick());
  }
}

class _BonusLine extends StatelessWidget {
  const _BonusLine({
    required this.data,
    required this.manual,
    required this.onToggleBonus,
  });

  final AccountOverviewData data;
  final bool manual;
  final VoidCallback onToggleBonus;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final commissions = data.commissions;

    if (commissions.bonusClaimed) {
      return _ClaimedPill(onTap: manual ? onToggleBonus : null);
    }
    if (!commissions.isComplete) {
      return Text(
        '${commissions.total - commissions.completed} to go',
        style: textTheme.bodyMedium,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    if (manual) {
      return _TapTarget(
        onTap: onToggleBonus,
        semanticLabel: 'Mark the bonus claimed for ${data.displayName}',
        child: Text(
          'Claim bonus',
          style: textTheme.bodyMedium?.copyWith(
            color: context.colors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return Text('Bonus unclaimed', style: textTheme.bodyMedium);
  }
}

/// The "all four done and claimed" badge — same success tokens and shape
/// as the farm card's "Open" pill.
class _ClaimedPill extends StatelessWidget {
  const _ClaimedPill({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.colors.successContainer,
        borderRadius: AppRadius.pillRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: context.colors.successDot,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            'Claimed',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.colors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return pill;
    return _TapTarget(
      onTap: onTap!,
      semanticLabel: 'Unmark the claimed bonus',
      child: pill,
    );
  }
}

/// Wraps a small control in a 48dp-minimum hit area without changing how
/// it draws.
class _TapTarget extends StatelessWidget {
  const _TapTarget({
    required this.onTap,
    required this.semanticLabel,
    required this.child,
  });

  final VoidCallback onTap;
  final String semanticLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pillRadius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Center(widthFactor: 1, heightFactor: 1, child: child),
        ),
      ),
    );
  }
}
