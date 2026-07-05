import 'package:flutter/foundation.dart';

/// Canonical URL for the compiled FCG white paper (HTML + equation images).
class FcgGovernancePaper {
  FcgGovernancePaper._();

  static const hostedUrl =
      'https://rgsneddon.github.io/evolve/fcg_white_paper.html';

  /// Resolves to the gh-pages copy on web; hosted URL elsewhere.
  static String get url {
    if (kIsWeb) {
      return Uri.base.resolve('fcg_white_paper.html').toString();
    }
    return hostedUrl;
  }
}