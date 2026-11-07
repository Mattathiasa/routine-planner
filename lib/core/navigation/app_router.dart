import 'package:go_router/go_router.dart';

import '../../features/planner/presentation/planner_screen.dart';
import '../../features/resin/presentation/resin_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/today/presentation/today_screen.dart';
import 'app_shell.dart';

/// 3 branches (Today/Resin/Planner) share the floating pill nav via
/// [AppShell]; Settings is a sibling route outside the shell entirely —
/// no nav tab, pushed over everything, exits via its own back link —
/// matching the approved design exactly (confirmed: no `<nav>` element
/// anywhere in `SettingsV3.dc.html`).
final appRouter = GoRouter(
  initialLocation: '/today',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/today', builder: (context, state) => const TodayScreen())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/resin', builder: (context, state) => const ResinScreen())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/planner', builder: (context, state) => const PlannerScreen())],
        ),
      ],
    ),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
  ],
);
