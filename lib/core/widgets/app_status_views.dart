import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_card.dart';

/// Designed loading state: the same indigo ring everywhere, sized for
/// in-card (small) or whole-screen (regular) use.
class AppLoadingView extends StatelessWidget {
  const AppLoadingView({super.key, this.compact = false, this.height});

  final bool compact;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final indicator = SizedBox(
      width: compact ? 18 : 32,
      height: compact ? 18 : 32,
      child: CircularProgressIndicator(
        strokeWidth: compact ? 2 : 3,
        color: context.colors.primary,
      ),
    );
    final child = Center(child: indicator);
    return height != null ? SizedBox(height: height, child: child) : child;
  }
}

/// Designed error state: honest about what broke, with an optional retry.
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    required this.error,
    this.title = 'Something went wrong',
    this.onRetry,
  });

  final Object error;
  final String title;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 32, color: context.colors.warning),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$error',
            style: textTheme.bodyMedium,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    );
  }
}

/// Designed empty state: icon in a soft primary-container circle, a short
/// headline, a caption, and an optional call-to-action.
class AppEmptyView extends StatelessWidget {
  const AppEmptyView({
    super.key,
    required this.icon,
    required this.title,
    required this.caption,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String caption;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: context.colors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 26, color: context.colors.primary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          Text(
            caption,
            style: textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
