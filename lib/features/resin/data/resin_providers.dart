import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/database_providers.dart';
import 'resin_repository.dart';

part 'resin_providers.g.dart';

@Riverpod(keepAlive: true)
ResinRepository resinRepository(Ref ref) {
  return ResinRepository(ref.watch(userDatabaseProvider));
}
