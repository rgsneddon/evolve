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