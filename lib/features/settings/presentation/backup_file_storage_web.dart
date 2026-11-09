String? _webBackupCache;

Future<String> saveBackupFile(String jsonContent) async {
  _webBackupCache = jsonContent;
  return 'Browser storage';
}

Future<String> readBackupFile() async {
  if (_webBackupCache == null) {
    throw StateError('No backup found in browser session.');
  }
  return _webBackupCache!;
}

