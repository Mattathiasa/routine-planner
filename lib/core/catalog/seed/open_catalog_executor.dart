import 'package:drift/drift.dart';

import 'open_catalog_executor_stub.dart'
    if (dart.library.ffi) 'open_catalog_executor_native.dart'
    if (dart.library.js_interop) 'open_catalog_executor_web.dart';

QueryExecutor createSeedCatalogExecutor() => getSeedCatalogExecutor();

