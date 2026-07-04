import '../services/perc_faucet.dart';

enum PercFaucetCreditStatus {
  credited,
  onCooldown,
  treasuryEmpty,
  notLoggedIn,
  blockchainNotLaunched,
}

class PercFaucetCreditResult {
  const PercFaucetCreditResult({
    required this.status,
    this.reward,
    this.cooldownRemaining,
    this.nextBlockEstimate,
    this.blockIndex,
    this.scenarioBlockHeight,
  });

  final PercFaucetCreditStatus status;
  final PercFaucetReward? reward;
  final Duration? cooldownRemaining;
  final Duration? nextBlockEstimate;
  final int? blockIndex;
  final int? scenarioBlockHeight;

  bool get showCooldownPopup => status == PercFaucetCreditStatus.onCooldown;
}