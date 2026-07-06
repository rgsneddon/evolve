import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/locale_config.dart';
import '../services/device_locale_resolver.dart';
import '../services/locale_store.dart';
import '../services/locale_store_factory.dart';
import 'evolve_provider.dart';

class LocaleProvider extends ChangeNotifier {
  LocaleProvider({
    LocaleStore? store,
    this.autoDetectFromDevice = true,
    Locale? deviceLocaleOverride,
  })  : _store = store ?? createLocaleStore(),
        _deviceLocaleOverride = deviceLocaleOverride;

  final LocaleStore _store;

  /// When true, first launch (no saved locale) uses OS language/region prefs.
  final bool autoDetectFromDevice;

  /// Test-only injection; production uses [PlatformDispatcher] via resolver.
  final Locale? _deviceLocaleOverride;

  LocaleConfig config = LocaleConfig.defaults;
  var _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    final saved = await _store.load();
    if (saved != null) {
      config = saved;
    } else if (autoDetectFromDevice) {
      config = DeviceLocaleResolver.resolve(
        deviceLocale: _deviceLocaleOverride,
      );
      unawaited(_store.save(config));
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