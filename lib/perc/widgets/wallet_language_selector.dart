import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/locale_config.dart';
import '../../providers/evolve_provider.dart';
import '../../providers/locale_provider.dart';

/// Language picker for the wallet login / registration screen.
class WalletLanguageSelector extends StatelessWidget {
  const WalletLanguageSelector({super.key, this.compact = true});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final localeProv = context.watch<LocaleProvider>();
    final evolve = context.read<EvolveProvider>();
    final strings = AppLocalizations.of(localeProv.config);
    final config = localeProv.config;

    return InputDecorator(
      decoration: InputDecoration(
        labelText: strings.t('wallet_login_language_label'),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFF1A2030),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: config.languageCode,
          items: LocaleConfig.languages
              .map(
                (lang) => DropdownMenuItem(
                  value: lang.code,
                  child: Text(
                    strings.t(lang.nameKey),
                    style: TextStyle(fontSize: compact ? 12 : 14),
                  ),
                ),
              )
              .toList(),
          onChanged: (code) {
            if (code == null) return;
            localeProv.setLanguage(code);
            evolve.setLocale(localeProv.config);
          },
        ),
      ),
    );
  }
}