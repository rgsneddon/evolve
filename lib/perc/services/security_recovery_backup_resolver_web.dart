import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';

import 'perc_wallet_backup_clipboard.dart';

/// Web: file picker first; clipboard paste is optional fallback only.
Future<Uint8List?> resolveBackupBytesFromPlatform() async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'PERC Backup',
        extensions: ['txt', 'percbackup', 'json'],
      ),
    ],
  );
  if (file != null) {
    return file.readAsBytes();
  }

  final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
  return PercWalletBackupClipboard.decode(clipboard?.text ?? '');
}