import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/locale_config.dart';
import '../providers/locale_provider.dart';
import '../providers/evolve_provider.dart';
import 'region_flag.dart';

/// Region + language dropdowns — changing either refreshes localized output.
class LocaleSelector extends StatelessWidget {
  const LocaleSelector({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Consumer2<LocaleProvider, EvolveProvider>(
      builder: (context, localeProv, evolve, _) {
        final strings = AppLocalizations.of(localeProv.config);
        final config = localeProv.config;

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _dropdown(
                label: strings.t('region_label'),
                value: config.regionId,
                items: LocaleConfig.regions
                    .map((r) => DropdownMenuItem(
                          value: r.id,
                          child: _regionMenuRow(
                            r.id,
                            strings.t(r.nameKey),
                            compact: true,
                          ),
                        ))
                    .toList(),
                onChanged: (id) {
                  if (id == null) return;
                  localeProv.setRegion(id);
                  evolve.setLocale(localeProv.config);
                },
              ),
              const SizedBox(height: 8),
              _dropdown(
                label: strings.t('language_label'),
                value: config.languageCode,
                items: LocaleConfig.languages
                    .map((l) => DropdownMenuItem(
                          value: l.code,
                          child: Text(strings.t(l.nameKey),
                              style: const TextStyle(fontSize: 12)),
                        ))
                    .toList(),
                onChanged: (code) {
                  if (code == null) return;
                  localeProv.setLanguage(code);
                  evolve.setLocale(localeProv.config);
                },
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: _dropdown(
                label: strings.t('region_label'),
                value: config.regionId,
                items: LocaleConfig.regions
                    .map((r) => DropdownMenuItem(
                          value: r.id,
                          child: _regionMenuRow(r.id, strings.t(r.nameKey)),
                        ))
                    .toList(),
                onChanged: (id) {
                  if (id == null) return;
                  localeProv.setRegion(id);
                  evolve.setLocale(localeProv.config);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _dropdown(
                label: strings.t('language_label'),
                value: config.languageCode,
                items: LocaleConfig.languages
                    .map((l) => DropdownMenuItem(
                          value: l.code,
                          child: Text(strings.t(l.nameKey)),
                        ))
                    .toList(),
                onChanged: (code) {
                  if (code == null) return;
                  localeProv.setLanguage(code);
                  evolve.setLocale(localeProv.config);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  static Widget _regionMenuRow(
    String regionId,
    String label, {
    bool compact = false,
  }) {
    return Row(
      children: [
        RegionFlag(regionId: regionId, size: compact ? 16 : 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: compact ? 12 : 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}