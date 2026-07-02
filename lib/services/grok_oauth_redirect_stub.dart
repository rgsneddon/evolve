/// Web builds use remote proxy or in-browser flow — no custom scheme redirect.
class GrokOAuthRedirect {
  const GrokOAuthRedirect._();

  static const String? callbackScheme = null;
  static const String? mobileRedirectUri = null;
  static bool get usesMobileRedirect => false;
  static String? get redirectUri => null;
}