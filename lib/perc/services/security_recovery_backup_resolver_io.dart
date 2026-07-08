import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

/// Native/desktop: open a backup file via the platform file picker.
Future<Uint8List?> resolveBackupBytesFromPlatform() async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'PERC Backup',
        extensions: ['percbackup'],
      ),
    ],
  );
  if (file == null) return null;
  return file.readAsBytes();
}