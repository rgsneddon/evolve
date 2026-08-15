/** Matches PercChainConstants — treasury emission aligned with faucet scale. */
export const UNITS_PER_PERC = 100_000_000;
export const FAUCET_COOLDOWN_SECONDS = 7 * 60;
export const MAX_FAUCET_PAYOUT_MICRO = UNITS_PER_PERC;

/** Prior mint: one max faucet draw (1 PERC) per cooldown. Reduced by 2/3. */
export const TREASURY_MINT_PRIOR_MICRO_PER_COOLDOWN = MAX_FAUCET_PAYOUT_MICRO;
export const TREASURY_MINT_KEEP_NUMERATOR = 1;
export const TREASURY_MINT_KEEP_DENOMINATOR = 3;
export const TREASURY_MINT_MICRO_PER_COOLDOWN = Math.floor(
  (TREASURY_MINT_PRIOR_MICRO_PER_COOLDOWN * TREASURY_MINT_KEEP_NUMERATOR) /
    TREASURY_MINT_KEEP_DENOMINATOR,
);

/** One third of a max faucet draw accrues per cooldown window. */
export const EMISSION_MICRO_PER_MINUTE = Math.floor(
  (TREASURY_MINT_MICRO_PER_COOLDOWN * 60) / FAUCET_COOLDOWN_SECONDS,
);

export function emissionPerMinuteDisplay() {
  const whole = Math.floor(EMISSION_MICRO_PER_MINUTE / UNITS_PER_PERC);
  const frac = String(EMISSION_MICRO_PER_MINUTE % UNITS_PER_PERC)
    .padStart(8, '0')
    .replace(/0+$/, '');
  return frac.length ? `${whole}.${frac}` : String(whole);
}