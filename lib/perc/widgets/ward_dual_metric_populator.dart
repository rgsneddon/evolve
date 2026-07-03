import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/scenario_input.dart';
import '../../providers/locale_provider.dart';
import '../models/ward_conclusion_link.dart';
import '../services/ward_conclusion_bridge.dart';

/// Runs percent + SCS and populates ward voting fields with the combined payload.
class WardDualMetricPopulator extends StatefulWidget {
  const WardDualMetricPopulator({
    super.key,
    required this.strings,
    required this.onPopulate,
    this.compact = false,
  });

  final AppLocalizations strings;
  final ValueChanged<WardConclusionLink> onPopulate;
  final bool compact;

  @override
  State<WardDualMetricPopulator> createState() => _WardDualMetricPopulatorState();
}

class _WardDualMetricPopulatorState extends State<WardDualMetricPopulator> {
  final _topicController = TextEditingController();
  final _questionController = TextEditingController();
  bool _running = false;
  WardConclusionLink? _lastLink;
  String? _error;

  @override
  void dispose() {
    _topicController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _runDual() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      setState(() => _error = widget.strings.t('ward_scenario_need_question'));
      return;
    }

    setState(() {
      _running = true;
      _error = null;
      _lastLink = null;
    });

    final locale = context.read<LocaleProvider>().config;
    final input = ScenarioInput(
      topic: _topicController.text.trim(),
      posedQuestion: question,
    );

    try {
      final link = WardConclusionBridge.buildFromScenario(
        input: input,
        locale: locale,
        strings: widget.strings,
      );
      if (!mounted) return;
      setState(() {
        _lastLink = link;
        _running = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _running = false;
      });
    }
  }

  void _populateFields() {
    final link = _lastLink;
    if (link == null) return;
    widget.onPopulate(link);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.strings.t('ward_dual_populated_ok'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final link = _lastLink;

    return Card(
      color: const Color(0xFF6C63FF).withOpacity(0.08),
      child: Padding(
        padding: EdgeInsets.all(widget.compact ? 12 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.strings.t('ward_dual_populator_title'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              widget.strings.t('ward_dual_populator_note'),
              style: const TextStyle(fontSize: 11, color: Color(0xFF9BA3B8), height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _topicController,
              decoration: InputDecoration(
                labelText: widget.strings.t('ward_scenario_topic_label'),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _questionController,
              minLines: 2,
              maxLines: widget.compact ? 3 : 4,
              decoration: InputDecoration(
                labelText: widget.strings.t('ward_scenario_question_label'),
                hintText: widget.strings.t('ward_scenario_question_hint'),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _running ? null : _runDual,
              icon: _running
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.analytics_outlined, size: 18),
              label: Text(widget.strings.t('ward_dual_run_button')),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(fontSize: 11, color: Color(0xFFE74C3C))),
            ],
            if (link != null) ...[
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _metricChip(
                      title: widget.strings.t('ward_scenario_percent_title'),
                      value: '${link.percentChance!.round()}%',
                      subtitle: link.percentPhrase,
                      color: const Color(0xFF6C63FF),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _metricChip(
                      title: widget.strings.t('ward_scenario_scs_title'),
                      value: '${link.refinedScs!.round()}/100',
                      subtitle: link.scsLean,
                      color: const Color(0xFF00D9C0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _populateFields,
                icon: const Icon(Icons.input_outlined, size: 18),
                label: Text(widget.strings.t('ward_dual_populate_button')),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metricChip({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Color(0xFF9BA3B8), height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}