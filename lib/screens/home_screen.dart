import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/analysis_mode.dart';
import '../providers/evolve_provider.dart';
import '../widgets/cohesion_report_panel.dart';
import '../widgets/evolve_banner.dart';
import '../widgets/construct_completion_banner.dart';
import '../widgets/grok_construal_bar.dart';
import '../widgets/framework_equations_panel.dart';
import '../widgets/license_attribution_panel.dart';
import '../widgets/framework_fields.dart';
import '../widgets/locale_selector.dart';
import '../widgets/mode_advisory_panel.dart';
import '../widgets/narrative_link_field.dart';
import '../widgets/part_three_conclusion_panel.dart';
import '../widgets/percent_chance_panel.dart';
import '../widgets/synopsis_export_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey _resultsSectionKey = GlobalKey();

  void _scrollToResults() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _resultsSectionKey.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<EvolveProvider>(
          builder: (context, provider, _) {
            final s = provider.strings;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t('app_title'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                Text(
                  s.t('app_subtitle'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF9BA3B8),
                  ),
                ),
              ],
            );
          },
        ),
        toolbarHeight: 56,
      ),
      body: Consumer<EvolveProvider>(
        builder: (context, provider, _) {
          final s = provider.strings;
          final width = MediaQuery.sizeOf(context).width;
          final compact = width < 600;
          final narrowButtons = width < 820;

          return SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                compact ? 12 : 20,
                12,
                compact ? 12 : 20,
                24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: FrameworkFieldsHost(
                    key: ValueKey(
                      '${provider.freshSession}_${provider.locale.regionId}_${provider.locale.languageCode}',
                    ),
                    input: provider.input,
                    onChanged: provider.updateInput,
                    onRegisterFlush: provider.registerFlush,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const EvolveBanner(),
                        const SizedBox(height: 16),
                        _startFreshButton(context, provider, s),
                        const SizedBox(height: 12),
                        _regionSelectAdvice(s.t('region_select_advice')),
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: LocaleSelector(compact: compact),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _sectionHeader(s.t('posed_question_section')),
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: PosedQuestionFields(
                              posedQuestionLabel: provider.mode == AnalysisMode.cohesionScore
                                  ? s.t('posed_question_label_cohesion')
                                  : s.t('posed_question_label'),
                              posedQuestionHint: provider.mode == AnalysisMode.cohesionScore
                                  ? s.t('posed_question_hint_cohesion')
                                  : s.t('posed_question_hint'),
                              topicHint: s.t('topic_hint'),
                              regionFocusBanner: provider.regionFocusBanner,
                              showOutcomeParts:
                                  provider.mode == AnalysisMode.percentChance,
                              strings: s,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const GrokConstrualBar(),
                        const SizedBox(height: 20),
                        _sectionHeader(s.t('scenario_section')),
                        const SizedBox(height: 8),
                        _modeSelector(provider, s),
                        const SizedBox(height: 10),
                        ModeAdvisoryPanel(
                          mode: provider.mode,
                          strings: s,
                          grokEnabled: provider.grokConstrualEnabled,
                        ),
                        const SizedBox(height: 12),
                        _constructInputs(provider, s),
                        const SizedBox(height: 12),
                        ConstructCompletionBanner(
                          grokEnabled: provider.grokConstrualEnabled,
                          isConstruing: provider.isConstruing,
                          missingLabels: provider.missingConstructLabels,
                          headline: s.t('constructs_missing_headline'),
                          body: provider.grokConstrualEnabled
                              ? s.t('grok_construing')
                              : s.t('constructs_missing_body'),
                          grokReadyMessage: provider.grokConstrualEnabled &&
                                  provider.input.hasAllConstructTexts
                              ? s.t('grok_fields_ready')
                              : null,
                        ),
                        const SizedBox(height: 12),
                        _calculateActions(provider, narrowButtons, s),
                        if (provider.statusMessage != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            provider.statusMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                          ),
                        ],
                        Column(
                          key: _resultsSectionKey,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 20),
                            _sectionHeader(s.t('results_section')),
                            const SizedBox(height: 8),
                            _output(provider, s),
                            if (provider.result != null) ...[
                              const SizedBox(height: 16),
                              SynopsisExportPanel(
                                input: provider.input,
                                result: provider.result!,
                                mode: provider.mode,
                                locale: provider.locale,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 20),
                        const FrameworkEquationsPanel(),
                        const SizedBox(height: 16),
                        LicenseAttributionPanel(strings: s),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _modeSelector(EvolveProvider provider, dynamic s) {
    return SegmentedButton<AnalysisMode>(
      segments: [
        ButtonSegment(
          value: AnalysisMode.percentChance,
          label: Text(s.t('mode_percent')),
        ),
        ButtonSegment(
          value: AnalysisMode.cohesionScore,
          label: Text(s.t('mode_cohesion')),
        ),
      ],
      selected: {provider.mode},
      onSelectionChanged: (sel) => provider.setMode(sel.first),
    );
  }

  Widget _startFreshButton(BuildContext context, EvolveProvider provider, dynamic s) {
    const accent = Color(0xFF22C55E);
    final busy = provider.isRunning || provider.isFetchingLink || provider.isConstruing;

    return FilledButton.icon(
      onPressed: busy ? null : () => provider.startFresh(),
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: accent.withOpacity(0.45),
        minimumSize: const Size.fromHeight(56),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.refresh_rounded, size: 26),
      label: Text(
        s.t('start_fresh'),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 0.6),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        color: Color(0xFF9BA3B8),
      ),
    );
  }

  Widget _regionSelectAdvice(String text) {
    const accent = Color(0xFFF59E0B);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.public, color: accent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                height: 1.35,
                color: accent,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _calculateActions(EvolveProvider provider, bool narrowLabels, dynamic s) {
    const accent = Color(0xFF00D9C0);
    final running = provider.isRunning;

    Future<void> run(AnalysisMode mode) async {
      if (running) return;
      if (provider.mode != mode) provider.setMode(mode);
      await provider.calculate();
      if (provider.result != null) {
        _scrollToResults();
      }
    }

    Widget buildButton({
      required AnalysisMode mode,
      required String label,
      required IconData icon,
    }) {
      final selected = provider.mode == mode;
      return FilledButton(
        onPressed: running ? null : () => run(mode),
        style: FilledButton.styleFrom(
          backgroundColor: selected ? accent : const Color(0xFF2A3142),
          foregroundColor: Colors.white,
          disabledBackgroundColor: selected
              ? accent.withOpacity(0.55)
              : const Color(0xFF2A3142).withOpacity(0.55),
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (running && selected)
              const Padding(
                padding: EdgeInsets.only(right: 10),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(icon, size: 22),
              ),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.25),
              ),
            ),
          ],
        ),
      );
    }

    final percentLabel =
        narrowLabels ? s.t('calc_percent_short') : s.t('calc_percent');
    final cohesionLabel =
        narrowLabels ? s.t('calc_cohesion_short') : s.t('calc_cohesion');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s.t('calc_actions_heading'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: Color(0xFF9BA3B8),
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final stack = constraints.maxWidth < 560;
                if (stack) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      buildButton(
                        mode: AnalysisMode.percentChance,
                        label: percentLabel,
                        icon: Icons.percent,
                      ),
                      const SizedBox(height: 10),
                      buildButton(
                        mode: AnalysisMode.cohesionScore,
                        label: cohesionLabel,
                        icon: Icons.groups_outlined,
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: buildButton(
                        mode: AnalysisMode.percentChance,
                        label: percentLabel,
                        icon: Icons.percent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: buildButton(
                        mode: AnalysisMode.cohesionScore,
                        label: cohesionLabel,
                        icon: Icons.groups_outlined,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _constructInputs(EvolveProvider provider, dynamic s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (provider.mode == AnalysisMode.cohesionScore) ...[
              NarrativeLinkField(
                key: ValueKey('link_${provider.freshSession}'),
                initialUrl: provider.input.sourceUrl,
                isLoading: provider.isFetchingLink,
                onFetch: provider.fetchNarrativeFromLink,
                strings: s,
              ),
              const SizedBox(height: 16),
            ],
            ConstructVariableFields(
              key: ValueKey('constructs_${provider.freshSession}_${provider.mode}'),
              vortexHint: s.constructHint('vortex'),
              constructsSectionTitle: s.t('constructs_section_title'),
              constructsSectionSubtitle: provider.grokConstrualEnabled
                  ? s.t('constructs_section_grok')
                  : s.t('constructs_section_manual'),
              grokEnabled: provider.grokConstrualEnabled,
              grokFilledFields: provider.grokFilledFields,
              highlightMissing:
                  !provider.grokConstrualEnabled && !provider.input.hasAllConstructTexts,
              grokFilledLabel: s.t('grok_filled_badge'),
              constructLabels: {
                'vortex': '${s.constructName('vortex')} (ω)',
                'shear': '${s.constructName('shear')} (σ)',
                'resistance': '${s.constructName('resistance')} (Iτ)',
                'flow': '${s.constructName('flow')} (Jμ)',
              },
              constructHints: {
                'vortex': s.constructHint('vortex'),
                'shear': s.constructHint('shear'),
                'resistance': s.constructHint('resistance'),
                'flow': s.constructHint('flow'),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _output(EvolveProvider provider, dynamic s) {
    final result = provider.result;
    if (result == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Text(
            provider.mode == AnalysisMode.percentChance
                ? s.t('empty_percent')
                : s.t('empty_cohesion'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Colors.white.withOpacity(0.45),
            ),
          ),
        ),
      );
    }

    final panel = provider.mode == AnalysisMode.percentChance
        ? PercentChancePanel(
            result: result,
            question: provider.input.posedQuestionLine ?? provider.input.scenarioQuery,
          )
        : CohesionReportPanel(result: result);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        panel,
        const SizedBox(height: 12),
        PartThreeConclusionPanel(conclusion: result.partThreeConclusion),
      ],
    );
  }
}