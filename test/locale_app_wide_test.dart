import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/providers/locale_provider.dart';
import 'package:evolve/services/locale_store_memory.dart';
import 'package:evolve/l10n/app_localizations.dart';

void main() {
  const languages = ['en', 'es', 'fr', 'de', 'pt', 'ar', 'zh', 'hi', 'ja'];

  test('analysis UI strings resolve for all supported languages', () {
    for (final code in languages) {
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

  test('FCG voting tab strings resolve for all supported languages', () {
    for (final code in languages) {
      final strings = AppLocalizations.of(
        LocaleProvider(store: LocaleStoreMemory()).config.copyWith(
          languageCode: code,
        ),
      );
      expect(strings.t('fcg_title'), isNot(equals('fcg_title')));
      expect(strings.t('fcg_vote_support'), isNot(equals('fcg_vote_support')));
      expect(strings.t('fcg_initiate_button'), isNotEmpty);
    }
  });

  test('results panel strings resolve for all supported languages', () {
    for (final code in languages) {
      final strings = AppLocalizations.of(
        LocaleProvider(store: LocaleStoreMemory()).config.copyWith(
          languageCode: code,
        ),
      );
      expect(strings.t('synopsis_export_title'), isNot(equals('synopsis_export_title')));
      expect(strings.t('part_two_panel_title'), isNot(equals('part_two_panel_title')));
      expect(strings.t('grok_construe_label'), isNot(equals('grok_construe_label')));
      expect(strings.t('cohesion_part_one'), isNotEmpty);
    }
  });

  test('discourse output strings resolve for all supported languages', () {
    for (final code in languages) {
      final strings = AppLocalizations.of(
        LocaleProvider(store: LocaleStoreMemory()).config.copyWith(
          languageCode: code,
        ),
      );
      expect(
        strings.t('discourse_protest_context'),
        isNot(equals('discourse_protest_context')),
      );
      expect(
        strings.t('part3_slim_headline_scs'),
        isNot(equals('part3_slim_headline_scs')),
      );
    }
  });

  test('wallet strings still resolve for all supported languages', () {
    for (final code in languages) {
      final strings = AppLocalizations.of(
        LocaleProvider(store: LocaleStoreMemory()).config.copyWith(
          languageCode: code,
        ),
      );
      expect(strings.t('wallet_send'), isNot(equals('wallet_send')));
      expect(strings.t('wallet_receive'), isNotEmpty);
    }
  });
}