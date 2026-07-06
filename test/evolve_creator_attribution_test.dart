import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/l10n/app_localizations.dart';
import 'package:evolve/models/locale_config.dart';
import 'package:evolve/widgets/evolve_creator_attribution.dart';

void main() {
  testWidgets('creator attribution renders linked party names', (tester) async {
    final strings = AppLocalizations.of(LocaleConfig.defaults);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EvolveCreatorAttribution(strings: strings),
        ),
      ),
    );

    final rich = tester.widget<RichText>(find.byType(RichText));
    final plain = rich.text.toPlainText();
    expect(plain, contains('CREATED BY RUSSELL G SNEDDON'));
    expect(plain, contains('CHRONOFLUX PRINCIPIA BY ROY D HERBERT'));
    expect(plain, contains('BEAMPRIVACY'));
  });
}