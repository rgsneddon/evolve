import '../models/analysis_mode.dart';
import '../models/locale_config.dart';
import '../models/part_three_conclusion.dart';
import '../models/scenario_input.dart';
import '../models/evolve_result.dart';
import '../l10n/localized_output.dart';

/// Builds a complete Markdown synopsis (MarkdownBin-style) for the posed scenario.
class SynopsisExporter {
  const SynopsisExporter();

  String export({
    required ScenarioInput input,
    required EvolveResult result,
    required AnalysisMode mode,
    required LocaleConfig locale,
    DateTime? createdAt,
  }) {
    final output = LocalizedOutput.of(locale);
    final strings = output.strings;
    final stamp = createdAt ?? DateTime.now();
    final report = result.cohesionReport;
    final cycleMarker = output.cohesionCycleComplete;

    final buf = StringBuffer();
    final outcome = _outcomeSection(result, mode, output);
    final agentSection = _agentSection(result.partThreeConclusion, strings.t('synopsis_agent_actions'));
    final metadata = _metadataSection(
      locale: locale,
      mode: mode,
      stamp: stamp,
      output: output,
      strings: strings,
    );

    if (outcome.isNotEmpty) {
      final partOneIdx = report.indexOf(strings.t('cohesion_part_one'));
      if (partOneIdx > 0) {
        buf
          ..write(report.substring(0, partOneIdx).trimRight())
          ..writeln()
          ..writeln()
          ..writeln(outcome.trimRight())
          ..writeln()
          ..write(report.substring(partOneIdx));
      } else {
        buf
          ..writeln(report.trimRight())
          ..writeln()
          ..writeln(outcome.trimRight());
      }
    } else {
      buf.write(report.trimRight());
    }

    var text = buf.toString().trimRight();
    final cycleIdx = text.lastIndexOf(cycleMarker);
    if (cycleIdx >= 0) {
      text =
          '${text.substring(0, cycleIdx).trimRight()}\n\n$agentSection\n\n${text.substring(cycleIdx).trimRight()}';
    } else {
      text = '$text\n\n$agentSection';
    }

    return '$text\n\n---\n$metadata';
  }

  String _outcomeSection(
    EvolveResult result,
    AnalysisMode mode,
    LocalizedOutput output,
  ) {
    final strings = output.strings;
    final buf = StringBuffer();

    if (mode == AnalysisMode.percentChance) {
      buf
        ..writeln(strings.t('synopsis_percent_header'))
        ..writeln()
        ..writeln(
          '**${result.percentChance.round()}%** — ${output.percentOutcomeSubtitle(lean: output.leanLabel(result.core.lean), regressive: result.core.lean == 'REGRESSIVE')}',
        )
        ..writeln(output.percentOutcomePhraseLine(
          percentPhrase: result.percentPhrase,
          regressive: result.core.lean == 'REGRESSIVE',
        ))
        ..writeln()
        ..writeln(result.forecast.forecastLine)
        ..writeln();
      final breakdown = result.partBreakdown;
      if (breakdown != null && breakdown.isNotEmpty) {
        buf
          ..writeln(output.synopsisPartBreakdownHeader())
          ..writeln();
        if (breakdown.outcomeContext.isNotEmpty) {
          buf.writeln(output.partBreakdownOutcome(breakdown.outcomeContext));
        }
        for (final part in breakdown.parts) {
          buf.writeln(
            '- **${part.label}**: ${part.percentChance.round()}% share — ${part.percentPhrase}',
          );
          buf.writeln(
            '  ${output.partBreakdownLeanLine(lean: output.leanLabel(part.lean), regressive: part.isRegressive, regressivePct: part.regressivePct.round(), progressivePct: part.progressivePct.round())}',
          );
        }
        buf.writeln(output.partBreakdownTotal(breakdown.partitionTotal));
        buf.writeln();
      }
      buf.writeln('${output.grokConclusionMarker} ${result.continuumConclusion}');
      return buf.toString();
    }

    buf
      ..writeln(strings.t('synopsis_cohesion_header'))
      ..writeln()
      ..writeln(
        strings.t('synopsis_cohesion_line').replaceAll(
          '{scs}',
          '${result.core.refinedScs.round()}',
        ),
      )
      ..writeln(
        strings.t('cohesion_split')
            .replaceAll('{reg}', '${result.core.regressivePct.round()}')
            .replaceAll('{prog}', '${result.core.progressivePct.round()}'),
      );

    final partyRefinement = result.partyRefinement;
    if (partyRefinement != null && partyRefinement.applied) {
      buf
        ..writeln()
        ..writeln(strings.t('party_response_section'))
        ..writeln()
        ..writeln(partyRefinement.summary);
      for (final response in partyRefinement.responses) {
        buf
          ..writeln()
          ..writeln(
            strings.t('party_response_line').replaceAll('{party}', response.party),
          )
          ..writeln(
            strings
                .t('party_response_scs')
                .replaceAll('{scs}', '${response.scs.round()}')
                .replaceAll('{reg}', '${response.regressivePct.round()}')
                .replaceAll('{prog}', '${response.progressivePct.round()}')
                .replaceAll('{lean}', output.leanLabel(response.lean)),
          )
          ..writeln('* "${response.excerpt}"');
      }
      buf
        ..writeln()
        ..writeln(
          strings
              .t('party_response_refined')
              .replaceAll('{before}', '${partyRefinement.narrativeScsBefore.round()}')
              .replaceAll('{after}', '${partyRefinement.refinedNarrativeScs.round()}'),
        );
    }

    return buf.toString();
  }

  String _agentSection(PartThreeConclusion conclusion, String heading) {
    final buf = StringBuffer()
      ..writeln(heading)
      ..writeln()
      ..writeln(conclusion.headline)
      ..writeln()
      ..writeln(conclusion.contextLine)
      ..writeln(conclusion.targetLabel)
      ..writeln();

    for (var i = 0; i < conclusion.actions.length; i++) {
      buf.writeln('${i + 1}. ${conclusion.actions[i].action}');
    }

    buf
      ..writeln()
      ..writeln(conclusion.projectedImpact);

    return buf.toString().trimRight();
  }

  String _metadataSection({
    required LocaleConfig locale,
    required AnalysisMode mode,
    required DateTime stamp,
    required LocalizedOutput output,
    required dynamic strings,
  }) {
    final modeLabel = mode == AnalysisMode.percentChance
        ? strings.t('synopsis_mode_percent')
        : strings.t('synopsis_mode_cohesion');
    final date = _formatTimestamp(stamp, locale.languageCode);

    return [
      strings.t('synopsis_created').replaceAll('{date}', date),
      strings.t('synopsis_region').replaceAll('{region}', output.regionName(locale.regionId)),
      modeLabel,
      strings.t('synopsis_footer'),
    ].join('\n');
  }

  String _formatTimestamp(DateTime stamp, String languageCode) {
    final local = stamp.toLocal();
    final y = local.year;
    final m = local.month;
    final d = local.day;
    final h = local.hour;
    final min = local.minute.toString().padLeft(2, '0');
    final ampm = h >= 12 ? 'PM' : 'AM';
    final hour12 = h % 12 == 0 ? 12 : h % 12;

    if (languageCode == 'en') {
      return '$m/$d/$y, $hour12:$min $ampm';
    }
    return local.toIso8601String();
  }
}