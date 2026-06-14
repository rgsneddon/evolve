import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/evolve_result.dart';
import '../providers/evolve_provider.dart';

/// PART TWO — Broader Political Continuum Integration (shown after Calculate).
class PartTwoPanel extends StatelessWidget {
  const PartTwoPanel({super.key, required this.partTwo});

  final PartTwoSection partTwo;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EvolveProvider>();
    final strings = provider.strings;
    final out = provider.output;
    final copyText = _copyPayload(strings);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub_outlined, size: 18, color: Color(0xFF60A5FA)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.t('part_two_panel_title'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF93C5FD),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_outlined, size: 18),
                tooltip: strings.t('part_two_copy'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: copyText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(strings.t('part_two_copied'))),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            strings
                .t('part_two_refined_line')
                .replaceAll('{scs}', '${partTwo.refinedScs.round()}')
                .replaceAll('{reg}', '${partTwo.regressivePct.round()}')
                .replaceAll('{prog}', '${partTwo.progressivePct.round()}')
                .replaceAll('{lean}', out.leanLabel(partTwo.lean)),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8BDFD4),
            ),
          ),
          const SizedBox(height: 10),
          _bullet(strings.t('cohesion_expanded_vortex'), partTwo.expandedVortex),
          const SizedBox(height: 8),
          _bullet(strings.t('cohesion_shear_refine'), partTwo.shearRefinement),
          const SizedBox(height: 8),
          _bullet(strings.t('cohesion_resistance_flow'), partTwo.resistanceFlow),
        ],
      ),
    );
  }

  Widget _bullet(String label, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.replaceAll('### ', ''),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF7A8296),
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(
          body,
          style: const TextStyle(fontSize: 12.5, height: 1.45, color: Color(0xFFB8BFD0)),
        ),
      ],
    );
  }

  String _copyPayload(dynamic strings) {
    final buf = StringBuffer()
      ..writeln(strings.t('part_two_panel_title'))
      ..writeln(strings
          .t('part_two_refined_line')
          .replaceAll('{scs}', '${partTwo.refinedScs.round()}')
          .replaceAll('{reg}', '${partTwo.regressivePct.round()}')
          .replaceAll('{prog}', '${partTwo.progressivePct.round()}')
          .replaceAll('{lean}', partTwo.lean))
      ..writeln()
      ..writeln(partTwo.expandedVortex)
      ..writeln(partTwo.shearRefinement)
      ..writeln(partTwo.resistanceFlow);
    return buf.toString();
  }
}