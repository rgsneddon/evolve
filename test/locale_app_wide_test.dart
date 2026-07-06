import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/providers/locale_provider.dart';
import 'package:evolve/services/locale_store_memory.dart';
import 'package:evolve/l10n/app_localizations.dart';

void main() {
  test('analysis UI strings resolve for all supported languages', () {
    for (final code in ['en', 'es', 'fr', 'de', 'pt', 'ar', 'zh', 'hi', 'ja']) {
      final strings = AppLocalizations.of(
        LocaleProvider(store: LocaleStoreMemory()).config.copyWith(
          languageCode: code,
        ),
      );
      expect(strings.t('nav_analysis'), isNot(equals('nav_analysis')));
      expect(strings.t('scenario_section'), isNot(equals('scenario_section')));
      expect(strings.t('splash_tagline'), isNotEmpty);
    }
  });
}