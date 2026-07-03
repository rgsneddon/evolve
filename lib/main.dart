import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/outcome_registry.dart';
import 'l10n/app_localizations.dart';
import 'models/locale_config.dart';
import 'models/locale_config_ui.dart';
import 'providers/locale_provider.dart';
import 'models/analysis_mode.dart';
import 'providers/evolve_provider.dart';
import 'perc/providers/perc_wallet_provider.dart';
import 'screens/evolve_shell_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OutcomeRegistry.ensureLoaded();
  final evolveProvider = EvolveProvider();
  final walletProvider = PercWalletProvider();
  await evolveProvider.initialize();
  await walletProvider.initialize();
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
  runApp(EvolveApp(
    evolveProvider: evolveProvider,
    walletProvider: walletProvider,
  ));
}

class EvolveApp extends StatelessWidget {
  const EvolveApp({
    super.key,
    required this.evolveProvider,
    required this.walletProvider,
  });

  final EvolveProvider evolveProvider;
  final PercWalletProvider walletProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider.value(value: evolveProvider),
        ChangeNotifierProvider.value(value: walletProvider),
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
            builder: (context, child) => Directionality(
              textDirection: localeProv.config.textDirection,
              child: child ?? const SizedBox.shrink(),
            ),
            home: const EvolveShellScreen(),
          );
        },
      ),
    );
  }
}