import '../l10n/localized_output.dart';
import '../models/scenario_input.dart';
import '../models/evolve_result.dart';
import 'question_semantics.dart';

/// PART TWO narratives — anchored on the posed question, not σ/Iτ/Jμ field replays.
class PartTwoNarrativeBuilder {
  const PartTwoNarrativeBuilder();

  PartTwoNarratives build({
    required ScenarioInput input,
    required QuestionSemantics sem,
    required LocalizedOutput out,
    required List<double> normalizedWeights,
    required HydrodynamicCore core,
  }) {
    final question = _questionLine(input, sem);
    final wPct = normalizedWeights.map((w) => (w * 100).round()).toList();

    return PartTwoNarratives(
      expandedVortex: out.partTwoExpandedVortex(
        question: question,
        subject: sem.displaySubject,
        topic: input.topic.trim(),
        weightPct: wPct[4],
        scs: core.vortexScs.round(),
        frame: sem.frame,
      ),
      shearRefinement: out.partTwoShearRefinement(
        question: question,
        subject: sem.displaySubject,
        weightPct: wPct[2],
        scs: core.shearScs.round(),
        frame: sem.frame,
        polarity: sem.polarity,
        dominantHint: _dominantHint(sem, construct: 'shear'),
      ),
      resistanceFlow: out.partTwoResistanceFlow(
        question: question,
        subject: sem.displaySubject,
        resistanceWeightPct: wPct[3],
        flowWeightPct: wPct[1],
        resistanceScs: core.resistanceScs.round(),
        flowScs: core.flowScs.round(),
        lean: core.lean,
        polarity: sem.polarity,
        dominantHint: _dominantHint(sem, construct: 'transport'),
      ),
    );
  }

  String _questionLine(ScenarioInput input, QuestionSemantics sem) {
    final posed = input.posedQuestionLine;
    if (posed != null && posed.isNotEmpty) return posed;
    if (sem.raw.isNotEmpty) return sem.raw;
    return sem.displaySubject;
  }

  String _dominantHint(QuestionSemantics sem, {required String construct}) {
    if (sem.hintSignals.isEmpty) return '';
    final label = sem.hintSignals.first;
    final lower = label.toLowerCase();
    if (construct == 'shear') {
      if (lower.contains('disorder') ||
          lower.contains('narrative') ||
          lower.contains('electoral')) {
        return label;
      }
      return '';
    }
    if (construct == 'transport') {
      if (lower.contains('economic') ||
          lower.contains('institutional') ||
          lower.contains('narrative')) {
        return label;
      }
      return '';
    }
    return '';
  }
}

class PartTwoNarratives {
  const PartTwoNarratives({
    required this.expandedVortex,
    required this.shearRefinement,
    required this.resistanceFlow,
  });

  final String expandedVortex;
  final String shearRefinement;
  final String resistanceFlow;
}