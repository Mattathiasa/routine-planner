import 'dart:io';
import 'package:path_provider/path_provider.dart';

const _backupFileName = 'routine_planner_backup.json';

Future<String> saveBackupFile(String jsonContent) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$_backupFileName');
  await file.writeAsString(jsonContent);
  return file.path;
}

Future<String> readBackupFile() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$_backupFileName');
  return file.readAsString();
}

