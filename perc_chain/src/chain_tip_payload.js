/**
 * Canonical block tip payload for chain sync — excludes narrative fields
 * (scenarioLabel, memo) and identity fields (usernames) so seed compaction
 * and public ledger sanitization do not break tip alignment.
 */

export function txTipPayload(tx) {
  if (!tx || typeof tx !== 'object') return null;
  return {
    id: tx.id,
    kind: tx.kind,
    amount: tx.amount ?? null,
    timestamp: tx.timestamp ?? null,
    percentChance: tx.percentChance ?? null,
    blockIndex: tx.blockIndex ?? null,
    confirmations: tx.confirmations ?? null,
    continuumScs: tx.continuumScs ?? null,
    vortexScs: tx.vortexScs ?? null,
    shearScs: tx.shearScs ?? null,
    resistanceScs: tx.resistanceScs ?? null,
    flowScs: tx.flowScs ?? null,
    microblockIndex: tx.microblockIndex ?? null,
    chronofluxFingerprint: tx.chronofluxFingerprint ?? null,
  };
}

export function blockTipPayload(block) {
  if (!block || typeof block !== 'object') return null;
  return {
    index: block.index,
    timestamp: block.timestamp,
    treasuryEmitted: block.treasuryEmitted ?? null,
    treasuryCycle: block.treasuryCycle ?? 1,
    isGenesisRenewal: block.isGenesisRenewal ?? false,
    confirmations: block.confirmations ?? null,
    microblockSeal: block.microblockSeal ?? false,
    chronofluxFingerprint: block.chronofluxFingerprint ?? null,
    microblocksSealed: block.microblocksSealed ?? null,
    transactions: (block.transactions ?? [])
      .map((tx) => txTipPayload(tx))
      .filter(Boolean),
  };
}