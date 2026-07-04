/** 100M PERC treasury emission per seed anchor block. */
export const PERC_PER_SEED_BLOCK = 100_000_000;
export const MICRO_UNITS_PER_PERC = 100_000_000;

export function treasuryMintedMicroUnits(ledger) {
  const minted = ledger?.cumulativeTreasuryMinted;
  if (!minted) return 0;
  if (minted.microUnits != null) return Number(minted.microUnits);
  const whole = minted.whole ?? 0;
  const fraction = minted.fraction ?? 0;
  return whole * MICRO_UNITS_PER_PERC + fraction;
}

/** Seed block 1 until 100M PERC emitted, then block 2 at 100M, block 3 at 200M, … */
export function seedBlockHeightFromLedger(ledger) {
  const micro = treasuryMintedMicroUnits(ledger);
  const thresholdMicro = PERC_PER_SEED_BLOCK * MICRO_UNITS_PER_PERC;
  if (thresholdMicro <= 0) return 1;
  return Math.floor(micro / thresholdMicro) + 1;
}