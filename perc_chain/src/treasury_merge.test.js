import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createGenesisLedger } from './genesis.js';
import {
  mergeTreasuryStateFromPeer,
  sumAccountBalancesMicro,
} from './treasury_merge.js';
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

/** Shared canonical seed with known treasury + bob balance before any peer payout. */
function canonicalSeedBase({ treasuryMicro = 200_000_000_000, bobMicro = 50_000_000 } = {}) {
  let tall = launchLedger(createGenesisLedger({ genesisRevision: 2, chainId: CHAIN_ID }));
  tall.accounts[TREASURY].balance = { microUnits: treasuryMicro };
  tall.accounts.bob = {
    username: 'bob',
    passwordHash: 'hash',
    salt: 'salt',
    address: 'percpriv1bobseed',
    passwordSet: true,
    balance: { microUnits: bobMicro },
    cumulativeStakingEarned: { microUnits: 0 },
    transactions: [],
  };
  tall.lastScenarioAt = '2026-07-06T09:00:00.000Z';
  for (let i = 0; i < 3; i += 1) {
    tall = {
      ...tall,
      blocks: [
        ...tall.blocks,
        {
          index: tall.blocks.length,
          timestamp: `2026-07-06T11:0${i}:00.000Z`,
          transactions: [{ id: `seed-filler-${i}`, kind: 'scenarioReward' }],
        },
      ],
    };
  }
  return tall;
}

/** Shorter peer gossip ledger carrying one new scenario payout (not yet on seed). */
function peerGossipWithPayout({ percent = 10, user = 'bob', txId = 'tx-peer-payout-new' } = {}) {
  const rewardMicro = percent * 1_000_000;
  const peer = launchLedger(createGenesisLedger({ genesisRevision: 2, chainId: CHAIN_ID }));
  peer.lastScenarioAt = '2026-07-07T12:00:00.000Z';
  peer.accounts[user] = {
    username: user,
    passwordHash: 'hash',
    salt: 'salt',
    address: `percpriv1${user}peer`,
    passwordSet: true,
    balance: { microUnits: rewardMicro },
    cumulativeStakingEarned: { microUnits: 0 },
    transactions: [],
  };
  peer.blocks.push({
    index: peer.blocks.length,
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
  });
  return { peer, rewardMicro, txId };
}

describe('mergeTreasuryStateFromPeer conservation', () => {
  it('applies payout delta on canonical pre-balances without clobbering totals', () => {
    const tall = canonicalSeedBase();
    const preTreasury = tall.accounts[TREASURY].balance.microUnits;
    const preBob = tall.accounts.bob.balance.microUnits;
    const preSum = sumAccountBalancesMicro(tall);

    const { peer, rewardMicro } = peerGossipWithPayout({ percent: 10, user: 'bob' });

    assert.ok(peer.blocks.length < tall.blocks.length);

    const canonical = structuredClone(tall);
    const result = mergeTreasuryStateFromPeer(canonical, peer);
    const miner = 'percpriv1a2e59c690fa6ad8efb206a40743342fad429823a';

    assert.equal(result.payoutBlocksMerged, 1);
    assert.equal(result.recipientsCredited, 2);
    assert.equal(result.treasuryDebitedMicro, rewardMicro * 2);
    assert.equal(canonical.accounts[TREASURY].balance.microUnits, preTreasury - rewardMicro * 2);
    assert.equal(canonical.accounts.bob.balance.microUnits, preBob + rewardMicro);
    assert.equal(canonical.accounts[miner].balance.microUnits, rewardMicro);
    assert.equal(sumAccountBalancesMicro(canonical), preSum);
  });

  it('LedgerStore.importLedger conserves supply: pre canonical total unchanged after shorter peer payout', () => {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'perc-treasury-merge-'));
    try {
      const tall = canonicalSeedBase({ treasuryMicro: 200_000_000_000, bobMicro: 50_000_000 });
      const preTreasury = tall.accounts[TREASURY].balance.microUnits;
      const preBob = tall.accounts.bob.balance.microUnits;
      const preSum = sumAccountBalancesMicro(tall);

      const store = new LedgerStore(tmpDir);
      store.forceReplaceLedger(tall);

      const { peer, rewardMicro } = peerGossipWithPayout({
        percent: 25,
        user: 'bob',
        txId: 'tx-import-payout',
      });

      const miner = 'percpriv1a2e59c690fa6ad8efb206a40743342fad429823a';
      assert.equal(store.importLedger(peer), true);
      assert.equal(store.ledger.accounts[TREASURY].balance.microUnits, preTreasury - rewardMicro * 2);
      assert.equal(store.ledger.accounts.bob.balance.microUnits, preBob + rewardMicro);
      assert.equal(store.ledger.accounts[miner].balance.microUnits, rewardMicro);
      assert.equal(sumAccountBalancesMicro(store.ledger), preSum);
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  });

  it('mirrors initiator unit to other registered users and the pool miner', () => {
    const tall = canonicalSeedBase();
    tall.accounts.alice = {
      username: 'alice',
      passwordHash: 'hash',
      salt: 'salt',
      address: 'percpriv1aliceseed',
      passwordSet: true,
      balance: { microUnits: 0 },
      cumulativeStakingEarned: { microUnits: 0 },
      transactions: [],
    };
    const miner = 'percpriv1a2e59c690fa6ad8efb206a40743342fad429823a';
    const preAlice = 0;
    const preBob = tall.accounts.bob.balance.microUnits;
    const preTreasury = tall.accounts[TREASURY].balance.microUnits;
    const { peer, rewardMicro } = peerGossipWithPayout({
      percent: 10,
      user: 'alice',
      txId: 'tx-alice-only',
    });
    const canonical = structuredClone(tall);
    const result = mergeTreasuryStateFromPeer(canonical, peer);
    assert.equal(result.payoutBlocksMerged, 1);
    assert.equal(result.recipientsCredited, 3);
    assert.equal(canonical.accounts.alice.balance.microUnits, preAlice + rewardMicro);
    assert.equal(canonical.accounts.bob.balance.microUnits, preBob + rewardMicro);
    assert.equal(canonical.accounts[miner].balance.microUnits, rewardMicro);
    assert.equal(
      canonical.accounts[TREASURY].balance.microUnits,
      preTreasury - rewardMicro * 3,
    );
    const minerTx = canonical.blocks
      .flatMap((b) => b.transactions ?? [])
      .find((tx) => tx.kind === 'minerReward' && tx.toUsername === miner);
    assert.ok(minerTx);
  });

  it('keeps a peer minerReward without double-paying that miner', () => {
    const tall = canonicalSeedBase();
    const miner = 'percpriv1a2e59c690fa6ad8efb206a40743342fad429823a';
    const { peer, rewardMicro } = peerGossipWithPayout({
      percent: 10,
      user: 'bob',
      txId: 'tx-bob-scenario',
    });
    peer.blocks[peer.blocks.length - 1].transactions.push({
      id: 'tx-miner-already',
      kind: 'minerReward',
      amount: { microUnits: rewardMicro },
      fromUsername: TREASURY,
      toUsername: miner,
      percentChance: 10,
      timestamp: '2026-07-07T12:00:00.000Z',
    });
    const canonical = structuredClone(tall);
    const result = mergeTreasuryStateFromPeer(canonical, peer);
    assert.equal(result.recipientsCredited, 2);
    assert.equal(canonical.accounts.bob.balance.microUnits, 50_000_000 + rewardMicro);
    assert.equal(canonical.accounts[miner].balance.microUnits, rewardMicro);
  });

  it('credits the existing wallet whose address is the pool miner', () => {
    const tall = canonicalSeedBase();
    const minerAddr = 'percpriv1a2e59c690fa6ad8efb206a40743342fad429823a';
    tall.accounts.XbghQ = {
      username: 'XbghQ',
      passwordHash: 'hash',
      salt: 'salt',
      address: minerAddr,
      passwordSet: true,
      balance: { microUnits: 10 },
      cumulativeStakingEarned: { microUnits: 0 },
      transactions: [],
    };
    const preMiner = 10;
    const preBob = tall.accounts.bob.balance.microUnits;
    const { peer, rewardMicro } = peerGossipWithPayout({
      percent: 10,
      user: 'bob',
      txId: 'tx-bob-to-xbghq',
    });
    const canonical = structuredClone(tall);
    const result = mergeTreasuryStateFromPeer(canonical, peer);
    assert.equal(result.recipientsCredited, 2);
    assert.equal(canonical.accounts.bob.balance.microUnits, preBob + rewardMicro);
    assert.equal(canonical.accounts.XbghQ.balance.microUnits, preMiner + rewardMicro);
    assert.equal(canonical.accounts[minerAddr], undefined);
    const minerTx = canonical.blocks
      .flatMap((b) => b.transactions ?? [])
      .find((tx) => tx.kind === 'minerReward' && tx.toUsername === 'XbghQ');
    assert.ok(minerTx);
  });
});