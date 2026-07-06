import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import '../models/locale_config.dart';

/// Maps the OS locale (language + country preferences) to [LocaleConfig].
///
/// Synchronous — reads [PlatformDispatcher] only; no network or GPS.
class DeviceLocaleResolver {
  DeviceLocaleResolver._();

  static const _supportedLanguages = {
    'en',
    'es',
    'fr',
    'de',
    'pt',
    'ar',
    'zh',
    'hi',
    'ja',
  };

  /// Resolve region + language from device settings.
  static LocaleConfig resolve({Locale? deviceLocale}) {
    final locale = deviceLocale ?? _primaryDeviceLocale();
    final language = _mapLanguage(locale.languageCode);
    final region = _mapRegion(locale.countryCode, language);
    return LocaleConfig(regionId: region, languageCode: language);
  }

  /// Prefer a locale entry that includes a country code when available.
  static Locale _primaryDeviceLocale() {
    final dispatcher = PlatformDispatcher.instance;
    final primary = dispatcher.locale;
    final primaryCountry = primary.countryCode;
    if (primaryCountry != null && primaryCountry.isNotEmpty) {
      return primary;
    }
    for (final locale in dispatcher.locales) {
      final country = locale.countryCode;
      if (country != null && country.isNotEmpty) {
        return locale;
      }
    }
    return primary;
  }

  static String _mapLanguage(String code) {
    final normalized = code.toLowerCase();
    if (_supportedLanguages.contains(normalized)) {
      return normalized;
    }
    return 'en';
  }

  static String _mapRegion(String? countryCode, String languageCode) {
    if (countryCode != null && countryCode.isNotEmpty) {
      final region = _regionForCountry(countryCode.toUpperCase());
      if (region != null) return region;
    }
    return _regionFromLanguage(languageCode);
  }

  static String? _regionForCountry(String country) {
    switch (country) {
      case 'GB':
      case 'IE':
        return 'uk_ireland';
      case 'US':
        return 'usa';
      case 'CA':
      case 'MX':
      case 'BR':
      case 'AR':
      case 'CL':
      case 'CO':
      case 'PE':
      case 'VE':
      case 'EC':
      case 'BO':
      case 'PY':
      case 'UY':
      case 'CR':
      case 'PA':
      case 'GT':
      case 'HN':
      case 'NI':
      case 'SV':
      case 'DO':
      case 'CU':
      case 'JM':
      case 'TT':
      case 'BZ':
      case 'GY':
      case 'SR':
      case 'HT':
        return 'americas';
      case 'FR':
      case 'DE':
      case 'IT':
      case 'ES':
      case 'PT':
      case 'NL':
      case 'BE':
      case 'AT':
      case 'CH':
      case 'PL':
      case 'SE':
      case 'NO':
      case 'DK':
      case 'FI':
      case 'GR':
      case 'CZ':
      case 'SK':
      case 'HU':
      case 'RO':
      case 'BG':
      case 'HR':
      case 'SI':
      case 'LT':
      case 'LV':
      case 'EE':
      case 'LU':
      case 'MT':
      case 'CY':
      case 'IS':
      case 'UA':
      case 'RS':
      case 'BA':
      case 'MK':
      case 'AL':
      case 'MD':
        return 'europe';
      case 'SA':
      case 'AE':
      case 'EG':
      case 'IQ':
      case 'IR':
      case 'IL':
      case 'JO':
      case 'KW':
      case 'LB':
      case 'MA':
      case 'OM':
      case 'QA':
      case 'SY':
      case 'TN':
      case 'YE':
      case 'DZ':
      case 'BH':
      case 'LY':
      case 'PS':
        return 'mena';
      case 'NG':
      case 'ZA':
      case 'KE':
      case 'GH':
      case 'ET':
      case 'TZ':
      case 'UG':
      case 'RW':
      case 'SN':
      case 'CI':
      case 'CM':
      case 'AO':
      case 'MZ':
      case 'ZW':
      case 'ZM':
      case 'BW':
      case 'NA':
      case 'MU':
      case 'SD':
      case 'SS':
        return 'sub_saharan_africa';
      case 'IN':
      case 'PK':
      case 'BD':
      case 'LK':
      case 'NP':
      case 'AF':
        return 'south_asia';
      case 'CN':
      case 'JP':
      case 'KR':
      case 'TW':
      case 'HK':
      case 'MO':
      case 'MN':
        return 'east_asia';
      case 'TH':
      case 'VN':
      case 'ID':
      case 'MY':
      case 'SG':
      case 'PH':
      case 'MM':
      case 'KH':
      case 'LA':
      case 'BN':
      case 'TL':
        return 'southeast_asia';
      case 'AU':
      case 'NZ':
      case 'FJ':
      case 'PG':
      case 'NC':
      case 'SB':
      case 'VU':
      case 'WS':
      case 'TO':
        return 'oceania';
      default:
        return null;
    }
  }

  static String _regionFromLanguage(String languageCode) {
    switch (languageCode) {
      case 'fr':
      case 'de':
      case 'es':
      case 'pt':
        return 'europe';
      case 'ar':
        return 'mena';
      case 'zh':
      case 'ja':
        return 'east_asia';
      case 'hi':
        return 'south_asia';
      default:
        return 'global';
    }
  }
}