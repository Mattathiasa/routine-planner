import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/clock_providers.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/providers/hoyolab_providers.dart';
import 'wish_import_service.dart';
import 'wish_repository.dart';

part 'wish_providers.g.dart';

@Riverpod(keepAlive: true)
WishRepository wishRepository(Ref ref) {
  return WishRepository(ref.watch(userDatabaseProvider));
}

@Riverpod(keepAlive: true)
WishImportService wishImportService(Ref ref) {
  return WishImportService(
    client: ref.watch(gachaLogClientProvider),
    repository: ref.watch(wishRepositoryProvider),
    clock: ref.watch(clockProvider),
  );
}
