import crypto from 'crypto';
import { formatPercAmount } from './explorer_api.js';
import { blockHeight } from './ledger_store.js';

const TREASURY_USERNAME = process.env.PERC_TREASURY_USERNAME ?? 'evolve_treasury';
/** Genesis mint — 1 PERC launch allocation; ongoing rate matches PercChainConstants. */
const LAUNCH_ALLOCATION_MICRO_UNITS = 100_000_000;

function hashPassword(password, salt) {
  return crypto.createHash('sha256').update(`${salt}:${password}`).digest('hex');
}

function amount(microUnits) {
  return { microUnits };
}

/**
 * One-time blockchain launch when rgsnedds signs into the seed treasury tab.
 * Secures evolve_treasury with the admin password and mints the genesis emission block.
 */
export function launchBlockchainFromTreasuryLogin(store, { adminPassword, launchedBy }) {
  const ledger = store.ledger;
  if (!ledger) {
    return { ok: false, error: 'Ledger not initialized' };
  }
  if (ledger.blockchainLaunched) {
    return { ok: true, alreadyLaunched: true, blockHeight: blockHeight(ledger) };
  }

  const treasury = ledger.accounts?.[TREASURY_USERNAME];
  if (!treasury) {
    return { ok: false, error: 'Treasury wallet missing on seed node' };
  }
  if (!adminPassword || adminPassword.length < 8) {
    return { ok: false, error: 'Password must be at least 8 characters' };
  }

  const now = new Date().toISOString();
  const emission = amount(LAUNCH_ALLOCATION_MICRO_UNITS);

  treasury.passwordHash = hashPassword(adminPassword, treasury.salt);
  treasury.passwordSet = true;
  treasury.balance = emission;
  treasury.transactions = [
    {
      id: `tx-${ledger.nextTxId ?? 1}`,
      kind: 'treasuryEmission',
      amount: emission,
      timestamp: now,
      toUsername: TREASURY_USERNAME,
      blockIndex: 0,
      confirmations: 1,
    },
  ];

  const launchTx = treasury.transactions[0];
  const block = {
    index: 0,
    timestamp: now,
    transactions: [launchTx],
    treasuryEmitted: emission,
    scenarioLabel: 'Blockchain launch — treasury emission',
    triggerUsername: launchedBy,
    treasuryCycle: 1,
  };

  ledger.blocks = [block];
  ledger.blockchainLaunched = true;
  ledger.treasuryGenesisDone = true;
  ledger.cumulativeTreasuryMinted = emission;
  ledger.lastScenarioAt = now;
  ledger.nextTxId = (ledger.nextTxId ?? 1) + 1;
  ledger.sessionUsername = null;

  store.forceReplaceLedger(ledger);

  return {
    ok: true,
    launched: true,
    blockHeight: blockHeight(ledger),
    treasuryBalance: formatPercAmount(treasury.balance),
    emissionPerMinute: '0.00000001',
    disclaimer: 'Manual sends from evolve_treasury are disabled; emission and faucet payouts continue.',
  };
}