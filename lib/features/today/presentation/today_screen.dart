import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/current_profile_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/circle_icon_button.dart';

/// Trivial stub — real content is built in the next commit, once the
/// provider graph + shell below is proven to work. Watching
/// [currentProfileProvider] here (rather than a plain StatelessWidget)
/// deliberately exercises the whole bootstrap chain: the catalog seeds
/// before `runApp`, `UserDatabase` resolves, and a default profile gets
/// created — not just that the app compiles and routes.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Today — coming soon', style: Theme.of(context).textTheme.headlineLarge),
                    const SizedBox(height: 8),
                    profile.when(
                      data: (p) => Text(
                        'Server: ${p.server}',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                      ),
                      loading: () => const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      error: (error, stack) => Text('Error: $error'),
                    ),
                  ],
                ),
              ),
              CircleIconButton(
                icon: Icons.settings_outlined,
                semanticLabel: 'Settings',
                onPressed: () => context.push('/settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
