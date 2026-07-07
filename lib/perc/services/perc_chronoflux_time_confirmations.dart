import '../perc_chain_constants.dart';

/// Chronoflux Principia TIME permutations mapped to blockchain confirmations.
class PercTimeConfirmationPermutation {
  const PercTimeConfirmationPermutation({
    required this.name,
    required this.interval,
    required this.confirmationsToSettle,
    required this.principiaBinding,
  });

  final String name;
  final Duration interval;
  final int confirmationsToSettle;
  final String principiaBinding;
}

class PercChronofluxTimeConfirmations {
  const PercChronofluxTimeConfirmations._();

  /// Treasury inflation epoch — emission aligned with faucet cooldown (Chronoflux time).
  static const Duration inflationEpoch = Duration(minutes: 1);

  /// Side-chain seal cadence — 100M microblocks per main block.
  static const int microblocksPerMainBlock =
      PercChainConstants.microblocksPerBlock;

  /// Faucet draw interval.
  static const Duration faucetEpoch = PercChainConstants.faucetCooldown;

  /// Full settlement — one main-chain block (Chronoflux Principia).
  static const int settlementConfirmations =
      PercChainConstants.confirmationsRequired;

  static List<PercTimeConfirmationPermutation> allPermutations() => [
        PercTimeConfirmationPermutation(
          name: 'Inflation epoch',
          interval: inflationEpoch,
          confirmationsToSettle: 1,
          principiaBinding:
              'Treasury continuum emission — dynamic PERC / minute (block time × wallet load)',
        ),
        PercTimeConfirmationPermutation(
          name: 'Side-chain seal',
          interval: Duration(seconds: 1),
          confirmationsToSettle: 1,
          principiaBinding:
              '100,000,000 microblocks → main-chain block confirmation',
        ),
        PercTimeConfirmationPermutation(
          name: 'Faucet draw',
          interval: faucetEpoch,
          confirmationsToSettle: 1,
          principiaBinding: 'Scenario analysis reward epoch — 7 minutes',
        ),
        PercTimeConfirmationPermutation(
          name: 'Transfer settlement',
          interval: Duration.zero,
          confirmationsToSettle: settlementConfirmations,
          principiaBinding:
              'Main-chain block — ${PercChainConstants.confirmationsRequired} confirmation fully settles PERC',
        ),
        PercTimeConfirmationPermutation(
          name: 'Staking settlement',
          interval: Duration.zero,
          confirmationsToSettle: PercChainConstants.stakingConfirmationsRequired,
          principiaBinding:
              'Held PERC confirms in ${PercChainConstants.stakingConfirmationsRequired} block — staking pays 0.00000005 PERC per 1 PERC held',
        ),
        PercTimeConfirmationPermutation(
          name: 'Chronoflux inputs',
          interval: const Duration(seconds: 1),
          confirmationsToSettle: 1,
          principiaBinding:
              'Five construct inputs (ρt, ω, σ, Iτ, Jμ) — one second per point',
        ),
      ];

  static String formatInterval(Duration d) {
    if (d == Duration.zero) return 'instant';
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    if (d.inSeconds > 0) return '${d.inSeconds}s';
    return '${d.inMilliseconds}ms';
  }
}