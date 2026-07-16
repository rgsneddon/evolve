import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/outcome_registry.dart';
import 'l10n/app_localizations.dart';
import 'models/locale_config.dart';
import 'models/locale_config_ui.dart';
import 'providers/locale_provider.dart';
import 'models/analysis_mode.dart';
import 'fcg/providers/fcg_voting_provider.dart';
import 'models/evolve_result.dart';
import 'models/scenario_input.dart';
import 'providers/evolve_provider.dart';
import 'perc/providers/perc_wallet_provider.dart';
import 'perc/services/perc_network_coordinator.dart';
import 'platform/desktop_window_init.dart';
import 'platform/evolve_window_lifecycle.dart';
import 'screens/app_bootstrap_screen.dart';
import 'theme/app_theme.dart';
import 'platform/desktop_platform.dart';
import 'widgets/app_version_badge.dart';
import 'widgets/desktop_window_shell.dart';
import 'widgets/locale_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDesktopWindow();
  PercNetworkCoordinator.disableLiveNodesForTests = false;
  await OutcomeRegistry.ensureLoaded();
  final evolveProvider = EvolveProvider();
  final walletProvider = PercWalletProvider();
  final fcgProvider = FcgVotingProvider();
  final localeProvider = LocaleProvider();
  await registerEvolveWindowLifecycle();
  await Future.wait([
    evolveProvider.initialize(),
    fcgProvider.initialize(),
    localeProvider.initialize(),
  ]);
  evolveProvider.setLocale(localeProvider.config);
  evolveProvider.analysisRewardHandler = ({
    required AnalysisMode mode,
    required double outcomeScore,
    String? memo,
    double? continuumScs,
    double? vortexScs,
    double? shearScs,
    double? resistanceScs,
    double? flowScs,
  }) =>
      walletProvider.creditAnalysis(
        mode: mode,
        outcomeScore: outcomeScore,
        memo: memo,
        continuumScs: continuumScs,
        vortexScs: vortexScs,
        shearScs: shearScs,
        resistanceScs: resistanceScs,
        flowScs: flowScs,
      );
  evolveProvider.scenarioRunRecorder = ({
    required ScenarioInput input,
    required LocaleConfig locale,
    required AnalysisMode mode,
    required EvolveResult result,
  }) =>
      fcgProvider.recordScenarioRun(
        input: input,
        locale: locale,
        mode: mode,
        result: result,
      );
  runApp(EvolveApp(
    evolveProvider: evolveProvider,
    walletProvider: walletProvider,
    fcgProvider: fcgProvider,
    localeProvider: localeProvider,
  ));
}

class EvolveApp extends StatelessWidget {
  const EvolveApp({
    super.key,
    required this.evolveProvider,
    required this.walletProvider,
    required this.fcgProvider,
    required this.localeProvider,
  });

  final EvolveProvider evolveProvider;
  final PercWalletProvider walletProvider;
  final FcgVotingProvider fcgProvider;
  final LocaleProvider localeProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: localeProvider),
        ChangeNotifierProvider.value(value: evolveProvider),
        ChangeNotifierProvider.value(value: walletProvider),
        ChangeNotifierProvider.value(value: fcgProvider),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProv, _) {
          final strings = AppLocalizations.of(localeProv.config);

          return MaterialApp(
            title: strings.t('app_title'),
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark(),
            locale: localeProv.config.materialLocale,
            supportedLocales: LocaleConfig.languages
                .map((l) => Locale(l.code))
                .toList(),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) {
              final content = child ?? const SizedBox.shrink();
              return Directionality(
                textDirection: localeProv.config.textDirection,
                child: DesktopWindowShell(
                  title: strings.t('app_title'),
                  child: isDesktopWindows
                      ? content
                      : Stack(
                          clipBehavior: Clip.none,
                          children: [
                            content,
                            Positioned(
                              top: MediaQuery.paddingOf(context).top + 6,
                              right: 10,
                              child: const IgnorePointer(
                                child: AppVersionBadge(),
                              ),
                            ),
                          ],
                        ),
                ),
              );
            },
            home: LocaleSync(
              child: AppBootstrapScreen(walletProvider: walletProvider),
            ),
          );
        },
      ),
    );
  }
}