import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';

import 'perc_wallet_backup_clipboard.dart';

/// Web: clipboard `PERCBACKUP1:` paste first, then file picker fallback.
Future<Uint8List?> resolveBackupBytesFromPlatform() async {
  final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
  final fromClipboard = PercWalletBackupClipboard.decode(clipboard?.text ?? '');
  if (fromClipboard != null) return fromClipboard;

  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(label: 'PERC Backup', extensions: ['percbackup', 'json']),
    ],
  );
  if (file == null) return null;
  return file.readAsBytes();
}