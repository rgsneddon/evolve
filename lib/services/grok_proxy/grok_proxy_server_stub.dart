import '../../models/grok_session.dart';

/// Web and other non-IO platforms cannot host the embedded Grok proxy.
class GrokProxyLauncher {
  GrokProxyLauncher._();

  static final GrokProxyLauncher instance = GrokProxyLauncher._();

  static const defaultPort = 8787;

  bool get supportsEmbeddedProxy => false;
  bool get isRunning => false;
  bool get isEmbedded => false;
  bool get usesMockConfig => false;
  int get port => defaultPort;

  GrokSession get embeddedSession => const GrokSession();

  Future<GrokSession> completeOAuthInProcess(String code, String? state) async {
    throw UnsupportedError('Embedded Grok proxy is not available on this platform');
  }

  Future<void> ensureRunning({int port = defaultPort}) async {
    // Web uses in-browser heuristic construal or an optional remote proxy URL.
  }

  Future<void> stop() async {}
}