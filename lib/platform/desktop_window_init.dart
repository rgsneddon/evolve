import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'desktop_platform.dart';

/// Frameless Windows shell — hidden native title bar, transparent backdrop.
Future<void> initDesktopWindow() async {
  if (!isDesktopWindows) return;

  await windowManager.ensureInitialized();

  const options = WindowOptions(
    size: Size(1280, 720),
    minimumSize: Size(720, 560),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );

  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}