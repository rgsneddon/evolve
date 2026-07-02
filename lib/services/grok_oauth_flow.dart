import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../models/grok_session.dart';
import 'grok_auth_client.dart';
import 'grok_oauth_redirect.dart';
import 'grok_proxy_launcher.dart';

/// Completes X OAuth on mobile via a custom-scheme callback into the embedded proxy.
class GrokOAuthFlow {
  const GrokOAuthFlow._();

  static bool get usesMobileDeepLink => GrokOAuthRedirect.usesMobileRedirect;

  static Future<GrokSession> completeAuthorization({
    required Uri authorizeUrl,
    required GrokAuthClient auth,
  }) async {
    if (!usesMobileDeepLink) {
      throw UnsupportedError('Mobile OAuth flow is not available on this platform');
    }
    try {
      final scheme = GrokOAuthRedirect.callbackScheme;
      if (scheme == null || scheme.isEmpty) {
        return const GrokSession(oauthError: 'missing_callback_scheme');
      }
      final result = await FlutterWebAuth2.authenticate(
        url: authorizeUrl.toString(),
        callbackUrlScheme: scheme,
      );
      return sessionFromCallbackUri(Uri.parse(result), auth);
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') return const GrokSession();
      return GrokSession(oauthError: e.message ?? e.code);
    } catch (e) {
      return GrokSession(oauthError: '$e');
    }
  }

  @visibleForTesting
  static Future<GrokSession> sessionFromCallbackUri(
    Uri callback,
    GrokAuthClient auth,
  ) async {
    final oauthError = callback.queryParameters['error'];
    if (oauthError != null && oauthError.isNotEmpty) {
      final description = callback.queryParameters['error_description'];
      return GrokSession(
        oauthError: (description != null && description.isNotEmpty)
            ? description
            : oauthError,
      );
    }

    final code = callback.queryParameters['code'];
    if (code == null || code.isEmpty) {
      return const GrokSession(oauthError: 'missing_code');
    }
    final state = callback.queryParameters['state'];

    if (GrokProxyLauncher.instance.isEmbedded) {
      return GrokProxyLauncher.instance.completeOAuthInProcess(code, state);
    }

    await auth.triggerOAuthCallback(callback);
    return auth.fetchStatus();
  }
}