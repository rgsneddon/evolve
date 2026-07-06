import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/providers/locale_provider.dart';
import 'package:evolve/services/locale_store_memory.dart';
void main() {
  test('first launch applies device locale when auto-detect enabled', () async {
    const deviceLocale = Locale('fr', 'FR');
    final provider = LocaleProvider(
      store: LocaleStoreMemory(),
      autoDetectFromDevice: true,
      deviceLocaleOverride: deviceLocale,
    );
    await provider.initialize();
    expect(provider.config.languageCode, 'fr');
    expect(provider.config.regionId, 'europe');
  });

  test('saved locale overrides device detection', () async {
    final store = LocaleStoreMemory();
    await store.save(
      const LocaleConfig(regionId: 'uk_ireland', languageCode: 'en'),
    );
    final provider = LocaleProvider(
      store: store,
      autoDetectFromDevice: true,
    );
    await provider.initialize();
    expect(provider.config.regionId, 'uk_ireland');
    expect(provider.config.languageCode, 'en');
  });

  test('auto-detect disabled keeps defaults on first launch', () async {
    final provider = LocaleProvider(
      store: LocaleStoreMemory(),
      autoDetectFromDevice: false,
    );
    await provider.initialize();
    expect(provider.config.regionId, 'global');
    expect(provider.config.languageCode, 'en');
  });
}