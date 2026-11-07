import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock/game_server.dart';
import '../../../core/providers/clock_providers.dart';
import '../../../core/providers/current_profile_provider.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import 'settings_formatting.dart';

String _formatUtcOffset(Duration offset) {
  final sign = offset.isNegative ? '-' : '+';
  return 'UTC$sign${offset.inHours.abs()}';
}

class GameServerSection extends ConsumerWidget {
  const GameServerSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final now = ref.watch(clockProvider).nowUtc();
    final localOffset = DateTime.now().timeZoneOffset;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Game server', style: textTheme.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        profileAsync.when(
          data: (profile) {
            final selected = GameServer.values.byName(profile.server);
            return RadioGroup<GameServer>(
              groupValue: selected,
              onChanged: (server) async {
                if (server == null) return;
                await ref.read(profileRepositoryProvider).updateServer(profile.id, server.name);
                ref.invalidate(currentProfileProvider);
              },
              child: ClipRRect(
                borderRadius: AppRadius.cardRadius,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    boxShadow: AppShadows.card,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < GameServer.values.length; i++) ...[
                        if (i > 0) const Divider(height: 1, color: AppColors.divider),
                        _ServerRow(server: GameServer.values[i], now: now, localOffset: localOffset),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
          loading: () => const SizedBox(
            height: 56,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (error, stack) => Text('Error: $error'),
        ),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'Reset times are shown in your time zone (${_formatUtcOffset(localOffset)}).',
            style: textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _ServerRow extends StatelessWidget {
  const _ServerRow({required this.server, required this.now, required this.localOffset});

  final GameServer server;
  final DateTime now;
  final Duration localOffset;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final caption = resetCaption(server: server, nowUtc: now, localOffset: localOffset);
    final resetLabel =
        '${_formatUtcOffset(server.utcOffset)} · resets ${caption.time}'
        '${caption.dayBefore ? ' the day before' : ''}';

    return InkWell(
      // The whole row is tappable, not just the Radio itself — matches the
      // mock's `<label>`-wraps-everything behavior.
      onTap: () => RadioGroup.maybeOf<GameServer>(context)?.onChanged(server),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(server.label, style: textTheme.titleMedium),
                  Text(resetLabel, style: textTheme.bodyMedium),
                ],
              ),
            ),
            Radio<GameServer>(value: server),
            const SizedBox(width: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
