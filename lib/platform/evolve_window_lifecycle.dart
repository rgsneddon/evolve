import 'package:evolve_tunnel/evolve_tunnel.dart';
import 'package:window_manager/window_manager.dart';

import 'desktop_platform.dart';

/// Awaits VPN teardown before the Windows desktop process exits.
class EvolveWindowLifecycle with WindowListener {
  EvolveWindowLifecycle(this.tunnel);

  final EvolveTunnelController tunnel;

  static EvolveWindowLifecycle? instance;

  Future<void> teardownIfNeeded() => tunnel.teardownOnAppClose();

  @override
  Future<bool> onWindowClose() async {
    await teardownIfNeeded();
    return true;
  }
}

Future<void> registerEvolveWindowLifecycle(EvolveTunnelController tunnel) async {
  if (!isDesktopWindows) return;
  final lifecycle = EvolveWindowLifecycle(tunnel);
  EvolveWindowLifecycle.instance = lifecycle;
  windowManager.addListener(lifecycle);
}