import 'dart:html' as html;

/// Web: open X OAuth via a real link click (works in DuckDuckGo and strict browsers).
class GrokOAuthLauncher {
  const GrokOAuthLauncher._();

  /// Opens a blank tab during the user gesture so it can be closed after OAuth.
  static OAuthLaunchHandle? prepareTab() {
    final win = html.window.open('about:blank', '_blank');
    if (win == null) return null;
    return OAuthLaunchHandle(win);
  }

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

  static Future<bool> launch(Uri url, {OAuthLaunchHandle? handle}) async {
    final tab = handle?._window;
    if (tab != null) {
      tab.location.href = url.toString();
      return true;
    }
    return openAuthorizeUrl(url);
  }
}

class OAuthLaunchHandle {
  OAuthLaunchHandle(this._window);

  final html.WindowBase? _window;

  void close() {
    try {
      _window?.close();
    } catch (_) {}
  }
}