import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../clock/clock.dart';
import '../clock/game_server.dart';
import '../clock/server_clock.dart';
import '../clock/system_clock.dart';
import 'current_profile_provider.dart';

part 'clock_providers.g.dart';

/// The one override seam for a [FakeClock] in tests.
@Riverpod(keepAlive: true)
Clock clock(Ref ref) => const SystemClock();

@Riverpod(keepAlive: true)
Future<ServerClock> serverClock(Ref ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  return ServerClock(ref.watch(clockProvider), GameServer.values.byName(profile.server));
}
