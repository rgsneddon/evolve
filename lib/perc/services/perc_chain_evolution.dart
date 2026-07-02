import '../../models/scenario_input.dart';
import '../models/perc_evolution_step.dart';
import '../perc_app_version.dart';
import '../perc_chain_constants.dart';
import 'perc_chronoflux_micro_verifier.dart';
import 'perc_ledger.dart';

/// Binds every app version to the same evolutionary Chronoflux Principia blockchain.
class PercChainEvolution {
  const PercChainEvolution({
    PercChronofluxMicroVerifier? verifier,
  }) : _verifier = verifier ?? const PercChronofluxMicroVerifier();

  final PercChronofluxMicroVerifier _verifier;

  /// Canonical Principia anchor — hydrodynamic evolution reference for the chain.
  static const ScenarioInput principiaAnchor = ScenarioInput(
    posedQuestion:
        'Chronoflux Principia — evolutionary Perccent blockchain continuity',
    topic: 'chronoflux-principia',
    vortexText: 'Roy D Herbert — hydrodynamic social-science Principia',
  );

  /// Ensures [ledger] belongs to the shared evolutionary chain and records this
  /// app version if not yet connected. Never resets blocks or balances.
  bool evolveLedger(
    PercLedger ledger, {
    String appVersion = PercAppVersion.current,
    DateTime? now,
  }) {
    ledger.repairForAppUpgrade();
    _assertEvolutionaryChain(ledger);
    ledger.evolutionaryChainId = PercChainConstants.evolutionaryChainId;
    ledger.chronofluxPrincipiaId = PercChainConstants.chronofluxPrincipiaId;
    ledger.mainChainId = PercChainConstants.chainId;
    ledger.sideChainId = PercChainConstants.sideChainId;
    ledger.connectedAppVersion = appVersion;

    if (ledger.evolvedAppVersions.contains(appVersion)) return false;

    final lastVersion = ledger.evolvedAppVersions.isEmpty
        ? null
        : ledger.evolvedAppVersions.last;
    if (lastVersion != null) {
      if (!PercAppVersion.isNewerThan(appVersion, lastVersion)) {
        return false;
      }
      if (PercAppVersion.sameReleaseLine(appVersion, lastVersion)) {
        ledger.connectedAppVersion = appVersion;
        return false;
      }
    }

    final verification = _verifier.verify(principiaAnchor);
    final parentStep =
        ledger.evolutionSteps.isEmpty ? null : ledger.evolutionSteps.last;
    final step = PercEvolutionStep(
      appVersion: appVersion,
      timestamp: (now ?? DateTime.now()).toUtc(),
      chronofluxFingerprint: verification.fingerprint,
      blockHeight: ledger.blockHeight,
      microblockHeight: ledger.totalMicroblocks,
      evolutionEpoch: ledger.evolutionEpoch,
      previousAppVersion: parentStep?.appVersion ?? lastVersion ?? '',
      parentChronofluxFingerprint: parentStep?.chronofluxFingerprint ?? '',
    );

    ledger.evolutionSteps = [...ledger.evolutionSteps, step];
    ledger.evolvedAppVersions = [...ledger.evolvedAppVersions, appVersion];
    ledger.evolutionEpoch++;
    ledger.lastChronofluxFingerprint = verification.fingerprint;
    return true;
  }

  void _assertEvolutionaryChain(PercLedger ledger) {
    if (ledger.evolutionaryChainId.isEmpty) return;
    if (ledger.evolutionaryChainId != PercChainConstants.evolutionaryChainId) {
      throw StateError(
        'Ledger belongs to evolutionary chain ${ledger.evolutionaryChainId} — '
        'expected ${PercChainConstants.evolutionaryChainId}',
      );
    }
  }
}