import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/part_three_conclusion.dart';
import '../providers/evolve_provider.dart';
class PartThreeConclusionPanel extends StatelessWidget {
  const PartThreeConclusionPanel({super.key, required this.conclusion});

  final PartThreeConclusion conclusion;

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<EvolveProvider>().strings;
    final copyText = _copyPayload();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up, size: 18, color: Color(0xFF6C63FF)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  conclusion.headline,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFFB8B5FF),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_outlined, size: 18),
                tooltip: strings.t('part3_copy'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: copyText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(strings.t('part3_copied'))),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            conclusion.contextLine,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF9BA3B8)),
          ),
          const SizedBox(height: 6),
          Text(
            conclusion.targetLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8BDFD4),
            ),
          ),
          const SizedBox(height: 10),
          ...conclusion.actions.asMap().entries.map((e) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${e.key + 1}.',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Color(0xFF6C63FF),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          e.value.action,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: Color(0xFFB8BFD0),
                          ),
                        ),
                        if (e.value.rationale.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          SelectableText(
                            e.value.rationale,
                            style: const TextStyle(
                              fontSize: 10.5,
                              height: 1.35,
                              color: Color(0xFF7A8296),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          Text(
            conclusion.projectedImpact,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: Color(0xFF7A8296),
            ),
          ),
        ],
      ),
    );
  }

  String _copyPayload() {
    final buf = StringBuffer()
      ..writeln(conclusion.headline)
      ..writeln(conclusion.contextLine)
      ..writeln(conclusion.targetLabel)
      ..writeln();
    for (var i = 0; i < conclusion.actions.length; i++) {
      final a = conclusion.actions[i];
      buf.writeln('${i + 1}. ${a.action}');
      if (a.rationale.isNotEmpty) buf.writeln('   ${a.rationale}');
    }
    buf.writeln();
    buf.writeln(conclusion.projectedImpact);
    return buf.toString();
  }
}