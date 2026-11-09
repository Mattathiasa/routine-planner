import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'repository_providers.dart';

part 'current_profile_provider.g.dart';

/// The currently active game account's id and server. Resolves whichever
/// profile is selected (see `ProfileRepository.getActiveProfile`), falling
/// back gracefully if nothing's selected yet or the selection was deleted.
/// Invalidate this after switching/creating/deleting a profile — same
/// manual-invalidation convention as every other provider in this app.
///
/// Exposed as a record rather than Drift's generated `Profile` row class:
/// `riverpod_generator` can't resolve a provider return type that's
/// declared entirely inside another builder's generated output (a known
/// upstream limitation, not fixable from this side — see
/// https://github.com/rrousselGit/riverpod/issues/4370).
@Riverpod(keepAlive: true)
Future<({String id, String server})> currentProfile(Ref ref) async {
  final profile = await ref.watch(profileRepositoryProvider).getActiveProfile();
  return (id: profile.id, server: profile.server);
}
