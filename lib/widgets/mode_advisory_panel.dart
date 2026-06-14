import 'package:flutter/material.dart';

import '../models/analysis_mode.dart';

/// Readable mode-specific instructions above the input panel.
class ModeAdvisoryPanel extends StatelessWidget {
  const ModeAdvisoryPanel({
    super.key,
    required this.mode,
    required this.strings,
    this.grokEnabled = false,
  });

  final AnalysisMode mode;
  final dynamic strings;
  final bool grokEnabled;

  @override
  Widget build(BuildContext context) {
    final isPercent = mode == AnalysisMode.percentChance;
    final accent = isPercent ? const Color(0xFF00D9C0) : const Color(0xFF6C63FF);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isPercent ? Icons.help_outline : Icons.link,
                color: accent,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isPercent
                      ? strings.t('advisory_percent_headline')
                      : strings.t('advisory_cohesion_headline'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                    color: accent,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._steps(isPercent).map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: accent, fontSize: 13)),
                  Expanded(
                    child: Text(
                      step,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Color(0xFFD8DCE8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _steps(bool isPercent) {
    if (isPercent) {
      return [
        strings.t('advisory_percent_step1'),
        grokEnabled
            ? strings.t('advisory_percent_step2_grok')
            : strings.t('advisory_percent_step2'),
        strings.t('advisory_percent_step3'),
      ];
    }
    return [
      strings.t('advisory_cohesion_step1'),
      strings.t('advisory_cohesion_step2'),
      grokEnabled
          ? strings.t('advisory_cohesion_step3_grok')
          : strings.t('advisory_cohesion_step3'),
    ];
  }
}