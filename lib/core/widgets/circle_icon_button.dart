import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';

/// The 44px circular icon-button chrome used for the settings gear and the
/// "+" log-a-run button.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.semanticLabel,
    this.size = 44,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    // The drawn circle stays at the design's 44px; the transparent padding
    // ring brings the tappable area up to the 48dp minimum.
    final hitPadding = size < 48 ? (48 - size) / 2 : 0.0;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: EdgeInsets.all(hitPadding),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: context.colors.surface,
                shape: BoxShape.circle,
                boxShadow: AppShadows.iconButton,
              ),
              child: Icon(
                icon,
                size: size * 0.5,
                color: context.colors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
