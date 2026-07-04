import { formatPercAmount } from './explorer_api.js';
import { blockHeight } from './ledger_store.js';

const UNITS_PER_PERC = 100_000_000;
const REGEN_THRESHOLD_MICRO = Math.round(0.66 * UNITS_PER_PERC);
const TARGET_MICRO = UNITS_PER_PERC;

function amount(microUnits) {
  return { microUnits };
}

function addAmount(a, b) {
  return amount((a?.microUnits ?? 0) + (b?.microUnits ?? 0));
}

function subAmount(a, b) {
  return amount((a?.microUnits ?? 0) - (b?.microUnits ?? 0));
}

/**
 * When evolve_treasury balance drops below 0.66 PERC, mint toward 1 PERC.
 * Returns true when a regeneration block was appended.
 */
export function regenerateTreasuryIfLow(store, treasuryUsername = 'evolve_treasury') {
  const ledger = store.ledger;
  if (!ledger?.blockchainLaunched) return false;

  const treasury = ledger.accounts?.[treasuryUsername];
  if (!treasury) return false;

  const balanceMicro = treasury.balance?.microUnits ?? 0;
  if (balanceMicro >= REGEN_THRESHOLD_MICRO) return false;

  const shortfallMicro = TARGET_MICRO - balanceMicro;
  if (shortfallMicro <= 0) return false;

  const now = new Date().toISOString();
  const shortfall = amount(shortfallMicro);
  const txId = `tx-${ledger.nextTxId ?? 1}`;

  treasury.balance = addAmount(treasury.balance ?? amount(0), shortfall);
  const tx = {
    id: txId,
    kind: 'treasuryEmission',
    amount: shortfall,
    timestamp: now,
    toUsername: treasuryUsername,
    memo: 'Treasury regeneration — balance below 0.66 PERC',
    blockIndex: blockHeight(ledger),
    confirmations: 1,
  };
  treasury.transactions = [tx, ...(treasury.transactions ?? [])];

  ledger.cumulativeTreasuryMinted = addAmount(
    ledger.cumulativeTreasuryMinted ?? amount(0),
    shortfall,
  );
  ledger.lastScenarioAt = now;
  ledger.nextTxId = (ledger.nextTxId ?? 1) + 1;
  ledger.blocks = [
    ...(ledger.blocks ?? []),
    {
      index: blockHeight(ledger),
      timestamp: now,
      transactions: [tx],
      treasuryEmitted: shortfall,
      scenarioLabel: 'Treasury regeneration',
      triggerUsername: treasuryUsername,
      treasuryCycle: ledger.treasuryCycle ?? 1,
    },
  ];

  store.forceReplaceLedger(ledger);
  return true;
}

export function treasuryRegenerationStatus(ledger, treasuryUsername = 'evolve_treasury') {
  const treasury = ledger?.accounts?.[treasuryUsername];
  const balanceMicro = treasury?.balance?.microUnits ?? 0;
  return {
    threshold: '0.66',
    target: '1',
    needsRegeneration: Boolean(ledger?.blockchainLaunched && balanceMicro < REGEN_THRESHOLD_MICRO),
    balance: formatPercAmount(treasury?.balance),
  };
}