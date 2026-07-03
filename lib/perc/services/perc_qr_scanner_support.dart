import 'package:flutter/foundation.dart';

import '../../services/platform_detect_stub.dart'
    if (dart.library.io) '../../services/platform_detect_io.dart' as platform;

/// Platforms where [mobile_scanner] exposes a live camera.
bool get percQrScannerSupported {
  if (kIsWeb) return true;
  return platform.platformIsMobile || platform.platformIsMacOS;
}