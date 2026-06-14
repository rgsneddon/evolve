import 'package:flutter/material.dart';

/// Global region + language selection for UI and PART THREE agent roles.
class LocaleConfig {
  const LocaleConfig({
    required this.regionId,
    required this.languageCode,
  });

  final String regionId;
  final String languageCode;

  static const defaults = LocaleConfig(regionId: 'global', languageCode: 'en');

  Locale get materialLocale => regionId == 'global'
      ? Locale(languageCode)
      : Locale(languageCode, regionId);

  TextDirection get textDirection =>
      languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr;

  static const regions = [
    (id: 'global', flag: '🌐', nameKey: 'region_global'),
    (id: 'uk_ireland', flag: '🇬🇧', nameKey: 'region_uk_ireland'),
    (id: 'usa', flag: '🇺🇸', nameKey: 'region_usa'),
    (id: 'americas', flag: '🌎', nameKey: 'region_americas'),
    (id: 'europe', flag: '🇪🇺', nameKey: 'region_europe'),
    (id: 'mena', flag: '🌍', nameKey: 'region_mena'),
    (id: 'sub_saharan_africa', flag: '🌍', nameKey: 'region_sub_saharan_africa'),
    (id: 'south_asia', flag: '🌏', nameKey: 'region_south_asia'),
    (id: 'east_asia', flag: '🌏', nameKey: 'region_east_asia'),
    (id: 'southeast_asia', flag: '🌏', nameKey: 'region_southeast_asia'),
    (id: 'oceania', flag: '🌏', nameKey: 'region_oceania'),
  ];

  static const languages = [
    (code: 'en', nameKey: 'lang_en'),
    (code: 'es', nameKey: 'lang_es'),
    (code: 'fr', nameKey: 'lang_fr'),
    (code: 'de', nameKey: 'lang_de'),
    (code: 'pt', nameKey: 'lang_pt'),
    (code: 'ar', nameKey: 'lang_ar'),
    (code: 'zh', nameKey: 'lang_zh'),
    (code: 'hi', nameKey: 'lang_hi'),
    (code: 'ja', nameKey: 'lang_ja'),
  ];

  LocaleConfig copyWith({String? regionId, String? languageCode}) => LocaleConfig(
        regionId: regionId ?? this.regionId,
        languageCode: languageCode ?? this.languageCode,
      );
}