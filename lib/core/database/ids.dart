import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Generates a new UUID string for a user.db row's `id` column.
String newId() => _uuid.v4();
