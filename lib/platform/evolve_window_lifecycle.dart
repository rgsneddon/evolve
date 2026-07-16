import 'dart:async';

import 'package:window_manager/window_manager.dart';

import 'desktop_platform.dart';

/// Injectable desktop window ops for tests (production uses [WindowManagerOps]).
abstract class EvolveWindowOps {
  Future<void> setPreventClose(bool value);
  Future<void> destroy();
  void addListener(WindowListener listener);
}

class WindowManagerOps implements EvolveWindowOps {
  @override
  Future<void> setPreventClose(bool value) =>
      windowManager.setPreventClose(value);

  @override
  Future<void> destroy() => windowManager.destroy();

  @override
  void addListener(WindowListener listener) =>
      windowManager.addListener(listener);
}

/// Intercepts WM_CLOSE on Windows desktop, then destroys the window.
class EvolveWindowLifecycle with WindowListener {
  EvolveWindowLifecycle({
    EvolveWindowOps? windowOps,
  }) : _windowOps = windowOps ?? WindowManagerOps();

  final EvolveWindowOps _windowOps;
  bool _closeInProgress = false;

  static EvolveWindowLifecycle? instance;

  Future<void> teardownIfNeeded() async {}

  @override
  void onWindowClose() {
    unawaited(_handleWindowClose());
  }

  Future<void> _handleWindowClose() async {
    if (_closeInProgress) return;
    _closeInProgress = true;
    try {
      await teardownIfNeeded();
      await _windowOps.destroy();
    } finally {
      _closeInProgress = false;
    }
  }
}

Future<void> registerEvolveWindowLifecycle({
  EvolveWindowOps? windowOps,
  bool? enabled,
}) async {
  final active = enabled ?? isDesktopWindows;
  if (!active) return;
  final ops = windowOps ?? WindowManagerOps();
  final lifecycle = EvolveWindowLifecycle(windowOps: ops);
  EvolveWindowLifecycle.instance = lifecycle;
  await ops.setPreventClose(true);
  ops.addListener(lifecycle);
}