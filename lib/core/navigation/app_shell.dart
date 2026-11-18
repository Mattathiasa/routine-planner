import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/data/accounts_refresh_providers.dart';
import '../providers/hoyolab_providers.dart';
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
/// free — no manual call-sites needed anywhere else. The same holds for
/// the legacy-credential adoption and the app-open account refresh.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // App start counts as a resume for refresh purposes.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAccounts());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshAccounts();
  }

  /// Not forced: the service's freshness window decides whether this
  /// actually hits the network, so flicking in and out of the app doesn't
  /// hammer an unofficial endpoint.
  void _refreshAccounts() {
    if (!mounted) return;
    ref.read(refreshAllAccountsProvider(force: false).future).ignore();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(notificationReconcileProvider);
    ref.watch(hoyolabLegacyCredentialAdoptionProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(
        children: [
          widget.navigationShell,
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            height: 64,
            child: PillNavBar(navigationShell: widget.navigationShell),
          ),
        ],
      ),
    );
  }
}
