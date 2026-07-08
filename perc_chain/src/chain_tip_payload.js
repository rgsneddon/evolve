/**
 * Canonical block tip payload for chain sync — mirrors PercChainTip in the
 * Evolve wallet (sparse JSON, no narrative or identity fields).
 */

const CONFIRMATIONS_REQUIRED = 1;

export function txTipPayload(tx) {
  if (!tx || typeof tx !== 'object') return null;
  const out = {
    id: tx.id,
    kind: tx.kind,
    amount: tx.amount ?? null,
    timestamp: tx.timestamp ?? null,
  };
  if (tx.percentChance != null) out.percentChance = tx.percentChance;
  if (tx.blockIndex != null) out.blockIndex = tx.blockIndex;
  if (tx.confirmations != null && tx.confirmations !== 0) {
    out.confirmations = tx.confirmations;
  }
  if (tx.continuumScs != null) out.continuumScs = tx.continuumScs;
  if (tx.vortexScs != null) out.vortexScs = tx.vortexScs;
  if (tx.shearScs != null) out.shearScs = tx.shearScs;
  if (tx.resistanceScs != null) out.resistanceScs = tx.resistanceScs;
  if (tx.flowScs != null) out.flowScs = tx.flowScs;
  if (tx.microblockIndex != null) out.microblockIndex = tx.microblockIndex;
  if (tx.chronofluxFingerprint != null) {
    out.chronofluxFingerprint = tx.chronofluxFingerprint;
  }
  return out;
}

export function blockTipPayload(block) {
  if (!block || typeof block !== 'object') return null;
  const out = {
    index: block.index,
    timestamp: block.timestamp,
    treasuryEmitted: block.treasuryEmitted ?? null,
    transactions: (block.transactions ?? [])
      .map((tx) => txTipPayload(tx))
      .filter(Boolean),
  };
  const treasuryCycle = block.treasuryCycle ?? 1;
  if (treasuryCycle !== 1) out.treasuryCycle = treasuryCycle;
  if (block.isGenesisRenewal) out.isGenesisRenewal = block.isGenesisRenewal;
  const confirmations = block.confirmations ?? CONFIRMATIONS_REQUIRED;
  if (confirmations !== CONFIRMATIONS_REQUIRED) out.confirmations = confirmations;
  if (block.microblockSeal) out.microblockSeal = block.microblockSeal;
  if (block.chronofluxFingerprint != null) {
    out.chronofluxFingerprint = block.chronofluxFingerprint;
  }
  if (block.microblocksSealed != null) out.microblocksSealed = block.microblocksSealed;
  return out;
}