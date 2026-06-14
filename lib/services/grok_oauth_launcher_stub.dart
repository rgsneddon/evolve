import 'dart:io' show Platform, Process;

import 'package:url_launcher/url_launcher.dart';

/// Desktop / mobile: open OAuth in the system default browser (e.g. DuckDuckGo).
class GrokOAuthLauncher {
  const GrokOAuthLauncher._();

  static OAuthLaunchHandle? prepareTab() => null;

  static Future<bool> openAuthorizeUrl(Uri url) => launch(url);

  static Future<bool> launch(Uri url, {OAuthLaunchHandle? handle}) async {
    final uri = url;
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return true;
    }
    if (await launchUrl(uri, mode: LaunchMode.platformDefault)) {
      return true;
    }
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', uri.toString()]);
      return true;
    }
    return false;
  }
}

class OAuthLaunchHandle {
  const OAuthLaunchHandle();

  void close() {}
}