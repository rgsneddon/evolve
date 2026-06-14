import 'dart:html' as html;

/// Web: open X OAuth via a real link click (works in DuckDuckGo and strict browsers).
class GrokOAuthLauncher {
  const GrokOAuthLauncher._();

  static OAuthLaunchHandle? prepareTab() => null;

  /// Synchronous link click — call directly from a button [onPressed].
  static bool openAuthorizeUrl(Uri url) {
    final anchor = html.AnchorElement(href: url.toString())
      ..target = '_blank'
      ..rel = 'noopener noreferrer';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    return true;
  }

  static Future<bool> launch(Uri url, {OAuthLaunchHandle? handle}) async =>
      openAuthorizeUrl(url);
}

class OAuthLaunchHandle {
  const OAuthLaunchHandle();

  void close() {}
}