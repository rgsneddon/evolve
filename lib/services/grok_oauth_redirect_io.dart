import 'dart:io';

import 'package:flutter/foundation.dart';

/// Platform-specific X OAuth redirect for embedded Grok proxy.
class GrokOAuthRedirect {
  const GrokOAuthRedirect._();

  /// Custom scheme registered in X Developer Portal for Android/iOS builds.
  static const String callbackScheme = 'evolve';

  static const String mobileRedirectUri = '$callbackScheme://auth/callback';

  static bool get usesMobileRedirect {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  static String? get redirectUri =>
      usesMobileRedirect ? mobileRedirectUri : null;
}