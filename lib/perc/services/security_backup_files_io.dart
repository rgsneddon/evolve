import 'dart:io';
import 'dart:typed_data';

Future<void> writeBackupFile(String path, Uint8List bytes) async {
  await File(path).writeAsBytes(bytes);
}