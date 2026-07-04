import 'package:flutter/foundation.dart';

import 'desktop_platform_io.dart'
    if (dart.library.html) 'desktop_platform_stub.dart' as platform_io;

/// True when running the Windows desktop executable (not web/mobile/tests).
bool get isDesktopWindows =>
    !kIsWeb &&
    defaultTargetPlatform == TargetPlatform.windows &&
    !platform_io.isFlutterTest;