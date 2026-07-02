import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/scenario_input.dart';
import 'framework_fields.dart';

/// Pathway fields under the posed question — one row per outcome part.
class OutcomePartFields extends StatelessWidget {
  const OutcomePartFields({
    super.key,
    required this.strings,
  });

  final AppLocalizations strings;

  String _t(String key) => strings.t(key);

  @override
  Widget build(BuildContext context) {
    final host = FrameworkFieldsHost.of(context).host;
    const accent = Color(0xFF00D9C0);
    final enabled = host.multiPartOutcomeEnabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        CheckboxListTile(
          value: enabled,
          onChanged: (v) => host.setMultiPartOutcomeEnabled(v ?? false),
          contentPadding: EdgeInsets.zero,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            _t('outcome_part_enable_multi'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            enabled ? _t('outcome_parts_hint') : _t('outcome_part_enable_hint'),
            style: const TextStyle(fontSize: 11.5, height: 1.4, color: Color(0xFF6B7280)),
          ),
          activeColor: accent,
        ),
        if (enabled) ...[
          const SizedBox(height: 8),
          Text(
            _t('outcome_parts_section'),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: Color(0xFF9BA3B8),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: host.outcomeContextController,
            decoration: InputDecoration(
              labelText: _t('outcome_context_label'),
              hintText: _t('outcome_context_hint'),
              filled: true,
              fillColor: accent.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (_) => host.onFieldKeystroke(),
          ),
          const SizedBox(height: 10),
          ...List.generate(host.outcomePartControllers.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                    controller: host.outcomePartControllers[index],
                      maxLength: kFieldMaxLength,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      decoration: InputDecoration(
                        labelText: _t('outcome_part_label').replaceAll('{n}', '${index + 1}'),
                        hintText: _t('outcome_part_hint'),
                        counterText: '',
                        filled: true,
                        fillColor: accent.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (_) => host.onFieldKeystroke(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: _t('outcome_part_remove'),
                    onPressed: () => host.removeOutcomePartField(index),
                    icon: const Icon(Icons.close, size: 18, color: Color(0xFF9BA3B8)),
                  ),
                ],
              ),
            );
          }),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: host.addOutcomePartField,
              icon: const Icon(Icons.add, size: 18, color: accent),
              label: Text(
                _t('outcome_part_add'),
                style: const TextStyle(color: accent, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ],
    );
  }
}