import { describe, it, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'fs';
import os from 'os';
import path from 'path';
import { LedgerStore } from './ledger_store.js';
import { createGenesisLedger } from './genesis.js';
import { buildTreasuryWalletView } from './treasury_api.js';
import { buildNetworkSnapshot } from './explorer_api.js';

const CHAIN_ID = 'evolve-chronoflux-principia-chain-1';
const TREASURY = 'evolve_treasury';

function launchLedger(base) {
  return {
    ...base,
    blockchainLaunched: true,
    treasuryGenesisDone: true,
    blocks: [
      ...(base.blocks ?? []),
      {
        index: base.blocks?.length ?? 0,
        timestamp: '2026-07-06T10:00:00.000Z',
        scenarioLabel: 'Blockchain launch',
        transactions: [],
      },
    ],
  };
}

function ledgerWithScenarioPayout(previous, { percent = 25, user = 'alice' } = {}) {
  const rewardMicro = percent * 1_000_000;
  const treasuryBefore = 100_000_000_000;
  const treasuryAfter = treasuryBefore - rewardMicro;
  const index = previous.blocks.length;
  return {
    ...previous,
    lastScenarioAt: '2026-07-06T12:00:00.000Z',
    accounts: {
      ...previous.accounts,
      [TREASURY]: {
        ...previous.accounts[TREASURY],
        balance: { microUnits: treasuryAfter },
      },
      [user]: {
        username: user,
        passwordHash: 'hash',
        salt: 'salt',
        address: `percpriv1${user}`,
        passwordSet: true,
        balance: { microUnits: rewardMicro },
        cumulativeStakingEarned: { microUnits: 0 },
        transactions: [],
      },
    },
    blocks: [
      ...previous.blocks,
      {
        index,
        timestamp: '2026-07-06T12:00:00.000Z',
        triggerUsername: user,
        scenarioLabel: 'Scenario analysis reward',
        transactions: [
          {
            id: `tx-scenario-${user}-${index}`,
            kind: 'scenarioReward',
            amount: { microUnits: rewardMicro },
            fromUsername: TREASURY,
            toUsername: user,
            percentChance: percent,
            timestamp: '2026-07-06T12:00:00.000Z',
          },
        ],
      },
    ],
  };
}

function ledgerWithStakingPayout(previous, { user = 'staker', rewardMicro = 5 } = {}) {
  const treasuryBefore = previous.accounts[TREASURY].balance.microUnits;
  const index = previous.blocks.length;
  return {
    ...previous,
    accounts: {
      ...previous.accounts,
      [TREASURY]: {
        ...previous.accounts[TREASURY],
        balance: { microUnits: treasuryBefore - rewardMicro },
      },
      [user]: {
        username: user,
        passwordHash: 'hash',
        salt: 'salt',
        address: `percpriv1${user}`,
        passwordSet: true,
        balance: { microUnits: rewardMicro },
        cumulativeStakingEarned: { microUnits: rewardMicro },
        transactions: [],
      },
    },
    blocks: [
      ...previous.blocks,
      {
        index,
        timestamp: '2026-07-06T12:05:00.000Z',
        triggerUsername: user,
        transactions: [
          {
            id: `tx-staking-${user}-${index}`,
            kind: 'stakingReward',
            amount: { microUnits: rewardMicro },
            fromUsername: TREASURY,
            toUsername: user,
            memo: 'Cumulative staking',
            timestamp: '2026-07-06T12:05:00.000Z',
          },
        ],
      },
    ],
  };
}

describe('treasury_api and explorer treasury truth', () => {
  let tmpDir;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'perc-treasury-api-'));
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it('buildTreasuryWalletView balance matches ledger after scenario payout', () => {
    const store = new LedgerStore(tmpDir);
    const peer = ledgerWithScenarioPayout(
      launchLedger(createGenesisLedger({ genesisRevision: 2, chainId: CHAIN_ID })),
      { percent: 42, user: 'alice' },
    );
    store.forceReplaceLedger(peer);

    const view = buildTreasuryWalletView(store);
    const treasury = store.treasuryAccount(TREASURY);

    assert.equal(view.ready, true);
    assert.equal(view.balanceMicroUnits, treasury.balance.microUnits);
    assert.equal(view.treasuryEmission.balance, view.balance);
    assert.equal(view.balanceMicroUnits, 100_000_000_000 - 42_000_000);
  });

  it('buildTreasuryWalletView balance matches ledger after staking payout', () => {
    let ledger = launchLedger(createGenesisLedger({ genesisRevision: 2, chainId: CHAIN_ID }));
    ledger.accounts[TREASURY].balance = { microUnits: 50_000_000 };
    ledger = ledgerWithStakingPayout(ledger, { user: 'staker', rewardMicro: 5 });

    const store = new LedgerStore(tmpDir);
    store.forceReplaceLedger(ledger);

    const view = buildTreasuryWalletView(store);
    assert.equal(view.balanceMicroUnits, 49_999_995);
    assert.equal(view.treasuryEmission.balance, '0.49999995');
  });

  it('seed import from shorter peer syncs depleted treasury for explorer snapshot', () => {
    const store = new LedgerStore(tmpDir);
    let tall = launchLedger(createGenesisLedger({ genesisRevision: 2, chainId: CHAIN_ID }));
    tall.accounts[TREASURY].balance = { microUnits: 200_000_000 };
    tall.lastScenarioAt = '2026-07-06T09:00:00.000Z';
    for (let i = 0; i < 3; i += 1) {
      tall = {
        ...tall,
        blocks: [
          ...tall.blocks,
          {
            index: tall.blocks.length,
            timestamp: `2026-07-06T11:0${i}:00.000Z`,
            scenarioLabel: `Seed filler ${i}`,
            transactions: [{ id: `seed-old-${i}`, kind: 'scenarioReward' }],
          },
        ],
      };
    }
    store.forceReplaceLedger(tall);

    const peer = ledgerWithScenarioPayout(
      launchLedger(createGenesisLedger({ genesisRevision: 2, chainId: CHAIN_ID })),
      { percent: 10, user: 'bob' },
    );
    assert.ok(peer.blocks.length < tall.blocks.length);

    const imported = store.importLedger(peer);
    assert.equal(imported, true);

    const treasury = store.treasuryAccount(TREASURY);
    assert.equal(treasury.balance.microUnits, 100_000_000_000 - 10_000_000);

    const snapshot = buildNetworkSnapshot({
      peers: new Map(),
      ledgers: new Map(),
      store,
      seedUsername: 'evolve_seed_node',
      endpoint: 'http://127.0.0.1:1',
      chainId: CHAIN_ID,
    });
    assert.equal(snapshot.treasuryEmission.balance, '999.9');
    assert.equal(snapshot.treasuryEmission.balance, buildTreasuryWalletView(store).balance);
  });
});