import 'dart:typed_data';

export 'security_backup_files_io.dart'
    if (dart.library.html) 'security_backup_files_web.dart';

/// Default filename for exported wallet backups (`.percbackup` envelope).
String defaultBackupExportFilename() {
  final stamp = DateTime.now()
      .toUtc()
      .toIso8601String()
      .replaceAll(':', '-')
      .split('.')
      .first;
  return 'perccent-wallet-backup-$stamp.percbackup';
}