import '../grok_oauth_redirect.dart'
    if (dart.library.html) '../grok_oauth_redirect_stub.dart' as oauth_redirect;
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
    final mobile = oauth_redirect.GrokOAuthRedirect.redirectUri;
    if (mobile != null && mobile.isNotEmpty) return mobile;

    final public = publicBaseUrl?.trim();
    if (public != null && public.isNotEmpty) {
      final normalized =
          public.endsWith('/') ? public.substring(0, public.length - 1) : public;
      return '$normalized/auth/callback';
    }
    return '$baseUrl/auth/callback';
  }

  /// Native App (Android/iOS) must use PKCE without a client secret.
  String get effectiveClientSecret {
    if (oauth_redirect.GrokOAuthRedirect.usesMobileRedirect) return '';
    return xClientSecret?.trim() ?? '';
  }

  static GrokProxyConfig fromEnvironment({int port = 8787}) {
    final clientId = env.readEnv('X_CLIENT_ID');
    final hasClientId = clientId != null &&
        clientId.isNotEmpty &&
        !clientId.toLowerCase().contains('your_x_oauth');
    final forceMock = env.readEnv('GROK_PROXY_MOCK') == '1';
    final mock = forceMock || !hasClientId;
    final publicBase = env.readEnv('GROK_PROXY_PUBLIC_URL');

    return GrokProxyConfig(
      port: port,
      mock: mock,
      xClientId: hasClientId ? clientId : null,
      xClientSecret: env.readEnv('X_CLIENT_SECRET'),
      xaiApiKey: env.readEnv('XAI_API_KEY'),
      xaiConstrualModel: env.readEnv('XAI_CONSTRUAL_MODEL') ?? 'grok-2-latest',
      publicBaseUrl: publicBase,
    );
  }
}