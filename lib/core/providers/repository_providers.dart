import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../catalog/catalog_repository.dart';
import '../database/repositories/planner_repository.dart';
import '../database/repositories/profile_repository.dart';
import '../database/repositories/settings_repository.dart';
import 'database_providers.dart';

part 'repository_providers.g.dart';

@Riverpod(keepAlive: true)
ProfileRepository profileRepository(Ref ref) {
  return ProfileRepository(ref.watch(userDatabaseProvider));
}

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) {
  return SettingsRepository(ref.watch(userDatabaseProvider));
}

@Riverpod(keepAlive: true)
PlannerRepository plannerRepository(Ref ref) {
  return PlannerRepository(ref.watch(userDatabaseProvider));
}

@Riverpod(keepAlive: true)
CatalogRepository catalogRepository(Ref ref) {
  return CatalogRepository(ref.watch(catalogDatabaseProvider));
}
