import 'backup_file_storage_stub.dart'
    if (dart.library.io) 'backup_file_storage_native.dart'
    if (dart.library.js_interop) 'backup_file_storage_web.dart';

Future<String> exportBackupFile(String jsonContent) => saveBackupFile(jsonContent);
Future<String> importBackupFile() => readBackupFile();

