import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createGenesisLedger } from './genesis.js';
import { mergeTreasuryStateFromPeer } from './treasury_merge.js';
import { LedgerStore } from './ledger_store.js';
import fs from 'fs';
import os from 'os';
import path from 'path';

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

function peerAfterScenarioPayout(base, { percent = 10, user = 'bob' } = {}) {
  const rewardMicro = percent * 1_000_000;
  const treasuryStart = 100_000_000_000;
  const index = base.blocks.length;
  const txId = `tx-scenario-${user}-${index}`;
  return {
    ledger: {
      ...base,
      lastScenarioAt: '2026-07-07T12:00:00.000Z',
      accounts: {
        ...base.accounts,
        [TREASURY]: {
          ...base.accounts[TREASURY],
          balance: { microUnits: treasuryStart - rewardMicro },
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
        ...base.blocks,
        {
          index,
          timestamp: '2026-07-07T12:00:00.000Z',
          triggerUsername: user,
          scenarioLabel: 'Scenario analysis reward',
          transactions: [
            {
              id: txId,
              kind: 'scenarioReward',
              amount: { microUnits: rewardMicro },
              fromUsername: TREASURY,
              toUsername: user,
              percentChance: percent,
              timestamp: '2026-07-07T12:00:00.000Z',
            },
          ],
        },
      ],
    },
    rewardMicro,
    txId,
    user,
    treasuryStart,
  };
}

describe('mergeTreasuryStateFromPeer conservation', () => {
  it('credits payout recipient and depletes treasury on canonical seed', () => {
    const genesis = launchLedger(
      createGenesisLedger({ genesisRevision: 2, chainId: CHAIN_ID }),
    );
    genesis.accounts[TREASURY].balance = { microUnits: 200_000_000_000 };

    let tall = { ...genesis };
    for (let i = 0; i < 3; i += 1) {
      tall = {
        ...tall,
        blocks: [
          ...tall.blocks,
          {
            index: tall.blocks.length,
            timestamp: `2026-07-06T11:0${i}:00.000Z`,
            transactions: [{ id: `seed-${i}`, kind: 'scenarioReward' }],
          },
        ],
      };
    }

    const { ledger: peer, rewardMicro, user, treasuryStart } = peerAfterScenarioPayout(
      launchLedger(createGenesisLedger({ genesisRevision: 2, chainId: CHAIN_ID })),
      { percent: 10, user: 'bob' },
    );
    assert.ok(peer.blocks.length < tall.blocks.length);

    const canonical = structuredClone(tall);
    const result = mergeTreasuryStateFromPeer(canonical, peer);

    assert.equal(result.payoutBlocksMerged, 1);
    assert.equal(result.recipientsMerged, 1);
    assert.equal(result.accountSynced, true);
    assert.equal(canonical.accounts[TREASURY].balance.microUnits, treasuryStart - rewardMicro);
    assert.equal(canonical.accounts[user].balance.microUnits, rewardMicro);
    assert.ok(
      canonical.blocks.some((b) =>
        (b.transactions ?? []).some((tx) => tx.toUsername === user && tx.kind === 'scenarioReward'),
      ),
    );
  });

  it('LedgerStore.importLedger preserves treasury debit and recipient credit', () => {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'perc-treasury-merge-'));
    try {
      const store = new LedgerStore(tmpDir);
      let tall = launchLedger(
        createGenesisLedger({ genesisRevision: 2, chainId: CHAIN_ID }),
      );
      tall.accounts[TREASURY].balance = { microUnits: 500_000_000 };
      for (let i = 0; i < 4; i += 1) {
        tall = {
          ...tall,
          blocks: [
            ...tall.blocks,
            {
              index: tall.blocks.length,
              timestamp: `2026-07-06T11:0${i}:00.000Z`,
              transactions: [{ id: `filler-${i}`, kind: 'scenarioReward' }],
            },
          ],
        };
      }
      store.forceReplaceLedger(tall);

      const { ledger: peer, rewardMicro, user } = peerAfterScenarioPayout(
        launchLedger(createGenesisLedger({ genesisRevision: 2, chainId: CHAIN_ID })),
        { percent: 25, user: 'alice' },
      );

      assert.equal(store.importLedger(peer), true);
      assert.equal(store.ledger.accounts[TREASURY].balance.microUnits, 100_000_000_000 - rewardMicro);
      assert.equal(store.ledger.accounts[user].balance.microUnits, rewardMicro);
      assert.equal(store.ledger.accounts[user].username, user);
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  });
});