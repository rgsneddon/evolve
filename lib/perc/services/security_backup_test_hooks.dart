import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Test-only hooks for Security tab backup flows (widget/integration tests).
class SecurityBackupTestHooks {
  const SecurityBackupTestHooks._();

  @visibleForTesting
  static Future<Uint8List?> Function()? backupBytesPicker;

  @visibleForTesting
  static Uint8List? lastExportedBytes;

  @visibleForTesting
  static void reset() {
    backupBytesPicker = null;
    lastExportedBytes = null;
  }
}