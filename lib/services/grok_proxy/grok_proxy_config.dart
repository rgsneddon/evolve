import 'grok_proxy_env_stub.dart'
    if (dart.library.io) 'grok_proxy_env_io.dart' as env;

/// Runtime configuration for the embedded Grok proxy.
class GrokProxyConfig {
  const GrokProxyConfig({
    required this.port,
    required this.mock,
    this.xClientId,
    this.xClientSecret,
    this.xaiApiKey,
    this.xaiConstrualModel = 'grok-2-latest',
    this.publicBaseUrl,
  });

  final int port;
  final bool mock;
  final String? xClientId;
  final String? xClientSecret;
  final String? xaiApiKey;
  final String xaiConstrualModel;
  final String? publicBaseUrl;

  String get baseUrl => 'http://127.0.0.1:$port';

  String get redirectUri {
    final public = publicBaseUrl?.trim();
    if (public != null && public.isNotEmpty) {
      final normalized = public.endsWith('/') ? public.substring(0, public.length - 1) : public;
      return '$normalized/auth/callback';
    }
    return '$baseUrl/auth/callback';
  }

  static GrokProxyConfig fromEnvironment({int port = 8787}) {
    final clientId = env.readEnv('X_CLIENT_ID');
    final forceMock = env.readEnv('GROK_PROXY_MOCK') == '1';
    final mock = forceMock || clientId == null;
    final publicBase = env.readEnv('GROK_PROXY_PUBLIC_URL');

    return GrokProxyConfig(
      port: port,
      mock: mock,
      xClientId: clientId,
      xClientSecret: env.readEnv('X_CLIENT_SECRET'),
      xaiApiKey: env.readEnv('XAI_API_KEY'),
      xaiConstrualModel: env.readEnv('XAI_CONSTRUAL_MODEL') ?? 'grok-2-latest',
      publicBaseUrl: publicBase,
    );
  }
}