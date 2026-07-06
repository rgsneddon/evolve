import 'dart:convert';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import '../models/locale_config.dart';
import 'locale_store.dart';

LocaleStore createLocaleStore() => LocaleStoreWeb();

class LocaleStoreWeb implements LocaleStore {
  static const storageKey = 'evolve_locale_v1';

  @override
  Future<LocaleConfig?> load() async {
    final raw = html.window.localStorage[storageKey];
    if (raw == null || raw.trim().isEmpty) return null;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final region = json['regionId'] as String?;
    final language = json['languageCode'] as String?;
    if (region == null || language == null) return null;
    return LocaleConfig(regionId: region, languageCode: language);
  }

  @override
  Future<void> save(LocaleConfig config) async {
    html.window.localStorage[storageKey] = jsonEncode({
      'regionId': config.regionId,
      'languageCode': config.languageCode,
    });
  }
}