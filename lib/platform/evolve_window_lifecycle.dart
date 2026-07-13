import 'dart:async';

import 'package:evolve_tunnel/evolve_tunnel.dart';
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

/// Intercepts WM_CLOSE, awaits VPN teardown, then destroys the window.
class EvolveWindowLifecycle with WindowListener {
  EvolveWindowLifecycle(
    this.tunnel, {
    EvolveWindowOps? windowOps,
  }) : _windowOps = windowOps ?? WindowManagerOps();

  final EvolveTunnelController tunnel;
  final EvolveWindowOps _windowOps;
  bool _closeInProgress = false;

  static EvolveWindowLifecycle? instance;

  Future<void> teardownIfNeeded() => tunnel.teardownOnAppClose();

  /// window_manager invokes this synchronously; teardown must run async then
  /// [EvolveWindowOps.destroy] after [setPreventClose](true) blocked native exit.
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

Future<void> registerEvolveWindowLifecycle(
  EvolveTunnelController tunnel, {
  EvolveWindowOps? windowOps,
  bool? enabled,
}) async {
  final active = enabled ?? isDesktopWindows;
  if (!active) return;
  final ops = windowOps ?? WindowManagerOps();
  final lifecycle = EvolveWindowLifecycle(tunnel, windowOps: ops);
  EvolveWindowLifecycle.instance = lifecycle;
  await ops.setPreventClose(true);
  ops.addListener(lifecycle);
}