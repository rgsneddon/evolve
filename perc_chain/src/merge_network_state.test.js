import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  mergeNetworkStateFromPeer,
  listObservedPendingTransfers,
  seedObservesTransferInitiation,
  seedObservesScenarioSettlement,
} from './merge_network_state.js';

describe('mergeNetworkStateFromPeer', () => {
  it('seed observes pending transfer at send initiation', () => {
    const canonical = {
      networkGenesisRevision: 2,
      blocks: [{ index: 0, transactions: [] }],
      pendingInboundTransfers: [],
    };
    const relay = {
      networkGenesisRevision: 2,
      pendingInboundTransfers: [
        {
          id: 'tx-pending-1',
          fromUsername: 'alice',
          toUsername: 'bob',
          amount: { microUnits: 10 },
          fee: { microUnits: 1 },
          sentAt: '2026-07-07T12:00:00.000Z',
        },
      ],
      blocks: [
        {
          index: 1,
          timestamp: '2026-07-07T12:00:00.000Z',
          triggerUsername: 'alice',
          transactions: [
            {
              id: 'tx-pending-1',
              kind: 'transfer',
              fromUsername: 'alice',
              toUsername: 'bob',
              amount: { microUnits: 10 },
              confirmations: 0,
              blockIndex: 1,
              timestamp: '2026-07-07T12:00:00.000Z',
            },
          ],
        },
      ],
    };

    const observed = seedObservesTransferInitiation(canonical, relay);
    assert.equal(observed.observedAtInitiation, true);
    assert.equal(observed.pendingMerged, 1);
    assert.deepEqual(observed.pendingIds, ['tx-pending-1']);
    assert.ok(observed.transferBlockIds.includes('tx-pending-1'));

    const pending = listObservedPendingTransfers(canonical);
    assert.equal(pending.length, 1);
    assert.equal(pending[0].spendable, false);
    assert.equal(pending[0].confirmations, 0);
  });

  it('seed observes spendable settlement after scenario confirm', () => {
    const canonical = {
      networkGenesisRevision: 2,
      pendingInboundTransfers: [],
      blocks: [
        {
          index: 0,
          transactions: [
            {
              id: 'tx-settled-1',
              kind: 'transfer',
              fromUsername: 'alice',
              toUsername: 'bob',
              amount: { microUnits: 10 },
              confirmations: 1,
              blockIndex: 0,
            },
          ],
        },
      ],
    };

    const settlement = seedObservesScenarioSettlement(canonical);
    assert.equal(settlement.pendingCount, 0);
    assert.deepEqual(settlement.settledIds, ['tx-settled-1']);
    assert.equal(settlement.spendableSettled, true);
  });

  it('initiation merge then settlement relay transitions pending to settled', () => {
    const seed = {
      networkGenesisRevision: 2,
      blocks: [{ index: 0, transactions: [] }],
      pendingInboundTransfers: [],
    };
    const senderAtInitiation = {
      networkGenesisRevision: 2,
      pendingInboundTransfers: [
        {
          id: 'tx-flow-1',
          fromUsername: 'alice',
          toUsername: 'bob',
          amount: { microUnits: 10 },
          fee: { microUnits: 1 },
          sentAt: '2026-07-07T12:00:00.000Z',
        },
      ],
      blocks: [
        {
          index: 1,
          timestamp: '2026-07-07T12:00:00.000Z',
          triggerUsername: 'alice',
          transactions: [
            {
              id: 'tx-flow-1',
              kind: 'transfer',
              fromUsername: 'alice',
              toUsername: 'bob',
              amount: { microUnits: 10 },
              confirmations: 0,
              blockIndex: 1,
              timestamp: '2026-07-07T12:00:00.000Z',
            },
          ],
        },
      ],
    };

    const initiation = seedObservesTransferInitiation(seed, senderAtInitiation);
    assert.equal(initiation.observedAtInitiation, true);
    assert.equal(seed.pendingInboundTransfers.length, 1);

    const receiverAfterScenario = {
      networkGenesisRevision: 2,
      pendingInboundTransfers: [],
      blocks: [
        ...senderAtInitiation.blocks,
        {
          index: 2,
          timestamp: '2026-07-07T12:05:00.000Z',
          triggerUsername: 'bob',
          transactions: [
            {
              id: 'tx-flow-1',
              kind: 'transfer',
              fromUsername: 'alice',
              toUsername: 'bob',
              amount: { microUnits: 10 },
              confirmations: 1,
              blockIndex: 2,
              timestamp: '2026-07-07T12:05:00.000Z',
            },
          ],
        },
      ],
    };

    const settlementMerge = mergeNetworkStateFromPeer(seed, receiverAfterScenario);
    assert.equal(settlementMerge.acknowledged, 0);
    assert.equal(seed.pendingInboundTransfers.length, 1);

    for (const block of seed.blocks) {
      for (const tx of block.transactions ?? []) {
        if (tx.id === 'tx-flow-1' && tx.kind === 'transfer') {
          tx.confirmations = 1;
        }
      }
    }
    seed.pendingInboundTransfers = [];
    const settlement = seedObservesScenarioSettlement(seed);
    assert.equal(settlement.pendingCount, 0);
    assert.deepEqual(settlement.settledIds, ['tx-flow-1']);
    assert.equal(settlement.spendableSettled, true);
  });

  it('merges pending without replacing taller canonical tip', () => {
    const canonical = {
      networkGenesisRevision: 2,
      blocks: [
        { index: 0, transactions: [] },
        { index: 1, transactions: [{ id: 'seed-tx', kind: 'scenarioReward' }] },
      ],
      pendingInboundTransfers: [],
    };
    const relay = {
      networkGenesisRevision: 2,
      pendingInboundTransfers: [
        {
          id: 'tx-new',
          fromUsername: 'alice',
          toUsername: 'bob',
          amount: { microUnits: 5 },
          fee: { microUnits: 1 },
          sentAt: '2026-07-07T12:00:00.000Z',
        },
      ],
      blocks: [
        {
          index: 1,
          transactions: [
            {
              id: 'tx-new',
              kind: 'transfer',
              fromUsername: 'alice',
              toUsername: 'bob',
              amount: { microUnits: 5 },
              confirmations: 0,
            },
          ],
        },
      ],
    };

    const result = mergeNetworkStateFromPeer(canonical, relay);
    assert.equal(result.pendingMerged, 1);
    assert.equal(result.acknowledged, 1);
    assert.equal(canonical.blocks.length, 3);
    assert.equal(canonical.pendingInboundTransfers.length, 1);
  });
});