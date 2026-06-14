import 'package:flutter/foundation.dart';

import '../models/locale_config.dart';

class LocaleProvider extends ChangeNotifier {
  LocaleConfig config = LocaleConfig.defaults;

  void setRegion(String regionId) {
    if (config.regionId == regionId) return;
    config = config.copyWith(regionId: regionId);
    notifyListeners();
  }

  void setLanguage(String languageCode) {
    if (config.languageCode == languageCode) return;
    config = config.copyWith(languageCode: languageCode);
    notifyListeners();
  }
}