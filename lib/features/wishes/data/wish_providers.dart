import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/database_providers.dart';
import 'wish_repository.dart';

part 'wish_providers.g.dart';

@Riverpod(keepAlive: true)
WishRepository wishRepository(Ref ref) {
  return WishRepository(ref.watch(userDatabaseProvider));
}
