import 'package:flutter/material.dart';

import 'locale_config.dart';

/// Flutter Material bindings for [LocaleConfig] (not used by VM-only tooling).
extension LocaleConfigUi on LocaleConfig {
  Locale get materialLocale => regionId == 'global'
      ? Locale(languageCode)
      : Locale(languageCode, regionId);

  TextDirection get textDirection =>
      languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr;
}