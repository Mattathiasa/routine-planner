import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/database_providers.dart';
import 'primogem_repository.dart';

part 'primogem_providers.g.dart';

@Riverpod(keepAlive: true)
PrimogemRepository primogemRepository(Ref ref) {
  return PrimogemRepository(ref.watch(userDatabaseProvider));
}
