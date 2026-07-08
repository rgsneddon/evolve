import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

Future<void> writeBackupFile(String path, Uint8List bytes) async {
  await File(path).writeAsBytes(bytes);
}

/// Native/desktop save-as dialog for encrypted backup bytes.
Future<bool> exportBackupToDevice({
  required String suggestedName,
  required Uint8List bytes,
}) async {
  final location = await getSaveLocation(
    suggestedName: suggestedName,
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'PERC Backup',
        extensions: ['percbackup'],
      ),
    ],
  );
  if (location == null) return false;
  await writeBackupFile(location.path, bytes);
  return true;
}