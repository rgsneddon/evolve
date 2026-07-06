import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/services/device_locale_resolver.dart';

void main() {
  test('France maps to French and Europe', () {
    final config = DeviceLocaleResolver.resolve(
      deviceLocale: const Locale('fr', 'FR'),
    );
    expect(config.languageCode, 'fr');
    expect(config.regionId, 'europe');
  });

  test('UK maps to English and UK & Ireland', () {
    final config = DeviceLocaleResolver.resolve(
      deviceLocale: const Locale('en', 'GB'),
    );
    expect(config.languageCode, 'en');
    expect(config.regionId, 'uk_ireland');
  });

  test('US maps to English and USA', () {
    final config = DeviceLocaleResolver.resolve(
      deviceLocale: const Locale('en', 'US'),
    );
    expect(config.languageCode, 'en');
    expect(config.regionId, 'usa');
  });

  test('Germany maps to German and Europe', () {
    final config = DeviceLocaleResolver.resolve(
      deviceLocale: const Locale('de', 'DE'),
    );
    expect(config.languageCode, 'de');
    expect(config.regionId, 'europe');
  });

  test('Brazil maps to Portuguese and Americas', () {
    final config = DeviceLocaleResolver.resolve(
      deviceLocale: const Locale('pt', 'BR'),
    );
    expect(config.languageCode, 'pt');
    expect(config.regionId, 'americas');
  });

  test('Japan maps to Japanese and East Asia', () {
    final config = DeviceLocaleResolver.resolve(
      deviceLocale: const Locale('ja', 'JP'),
    );
    expect(config.languageCode, 'ja');
    expect(config.regionId, 'east_asia');
  });

  test('unsupported language falls back to English', () {
    final config = DeviceLocaleResolver.resolve(
      deviceLocale: const Locale('sv', 'SE'),
    );
    expect(config.languageCode, 'en');
    expect(config.regionId, 'europe');
  });

  test('language-only French locale infers Europe', () {
    final config = DeviceLocaleResolver.resolve(
      deviceLocale: const Locale('fr'),
    );
    expect(config.languageCode, 'fr');
    expect(config.regionId, 'europe');
  });
}