import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/notification_providers.dart';
import '../theme/app_colors.dart';
import 'pill_nav_bar.dart';

/// Hosts the 3 bottom-nav branches with the pill nav floating over them —
/// `Positioned`, not `Scaffold.bottomNavigationBar`, since the pill has
/// side margins and a blur that a full-width nav bar can't give.
///
/// Always mounted past initial routing (Settings is pushed over it, not
/// navigated to in its place), so watching the notification reconcile
/// provider here covers both "app start" and "after every mutation" for
/// free — no manual call-sites needed anywhere else.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(notificationReconcileProvider);

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
