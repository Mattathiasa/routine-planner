import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import 'pill_nav_bar.dart';

/// Hosts the 3 bottom-nav branches with the pill nav floating over them —
/// `Positioned`, not `Scaffold.bottomNavigationBar`, since the pill has
/// side margins and a blur that a full-width nav bar can't give.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          navigationShell,
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            height: 64,
            child: PillNavBar(navigationShell: navigationShell),
          ),
        ],
      ),
    );
  }
}
