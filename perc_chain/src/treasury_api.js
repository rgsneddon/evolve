import { blockHeight, tipHash } from './ledger_store.js';
import { buildPublicTreasuryEmission, formatPercAmount } from './explorer_api.js';

const TREASURY_USERNAME = process.env.PERC_TREASURY_USERNAME ?? 'evolve_treasury';

export function buildTreasuryWalletView(store) {
  const ledger = store.ledger;
  const treasury = store.treasuryAccount(TREASURY_USERNAME);
  if (!ledger || !treasury) {
    return { ready: false, error: 'Treasury wallet not initialized' };
  }

  return {
    ready: true,
    username: TREASURY_USERNAME,
    address: treasury.address,
    addressShielded: shieldAddress(treasury.address),
    balance: formatPercAmount(treasury.balance),
    balanceMicroUnits: treasury.balance?.microUnits ?? 0,
    passwordSet: treasury.passwordSet ?? false,
    blockchainLaunched: ledger.blockchainLaunched ?? false,
    blockHeight: blockHeight(ledger),
    tipHash: tipHash(ledger),
    treasuryCycle: ledger.treasuryCycle ?? 1,
    cumulativeTreasuryMinted: formatPercAmount(ledger.cumulativeTreasuryMinted),
    cumulativeBurnedPerc: formatPercAmount(ledger.cumulativeBurnedPerc),
    networkGenesisRevision: store.getGenesisRevision(),
    revision: store.revision,
    transactionCount: treasury.transactions?.length ?? 0,
    treasuryEmission: buildPublicTreasuryEmission(ledger, TREASURY_USERNAME),
    recentTransactions: (treasury.transactions ?? []).slice(0, 20).map((tx) => ({
      id: tx.id,
      kind: tx.kind,
      amount: formatPercAmount(tx.amount),
      from: tx.fromUsername ?? tx.from ?? null,
      to: tx.toUsername ?? tx.to ?? null,
      memo: tx.memo ?? null,
      timestamp: tx.timestamp ?? null,
    })),
  };
}

function shieldAddress(address) {
  if (!address || address.length <= 16) return address ?? '';
  return `${address.substring(0, 10)}···${address.substring(address.length - 6)}`;
}