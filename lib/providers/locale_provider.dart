import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/locale_config.dart';
import '../services/locale_store.dart';
import '../services/locale_store_factory.dart';
import 'evolve_provider.dart';

class LocaleProvider extends ChangeNotifier {
  LocaleProvider({LocaleStore? store}) : _store = store ?? createLocaleStore();

  final LocaleStore _store;
  LocaleConfig config = LocaleConfig.defaults;
  var _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    final saved = await _store.load();
    if (saved != null) {
      config = saved;
    }
    _initialized = true;
    notifyListeners();
  }

  void apply(LocaleConfig next, {EvolveProvider? evolve}) {
    if (config.regionId == next.regionId &&
        config.languageCode == next.languageCode) {
      return;
    }
    config = next;
    evolve?.setLocale(config);
    notifyListeners();
    unawaited(_store.save(config));
  }

  void setRegion(String regionId, {EvolveProvider? evolve}) {
    apply(config.copyWith(regionId: regionId), evolve: evolve);
  }

  void setLanguage(String languageCode, {EvolveProvider? evolve}) {
    apply(config.copyWith(languageCode: languageCode), evolve: evolve);
  }
}