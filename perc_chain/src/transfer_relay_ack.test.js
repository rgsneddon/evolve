import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  acknowledgeRelayTransfers,
  blockHasTransfer,
  cloneTransferBlockForCanonicalTip,
  collectTransferTxIds,
} from './transfer_relay_ack.js';

describe('acknowledgeRelayTransfers', () => {
  it('re-indexes relay transfer to canonical tip preserving tx.id', () => {
    const canonical = {
      networkGenesisRevision: 2,
      blocks: [
        { index: 0, transactions: [] },
        { index: 1, transactions: [{ id: 'a', kind: 'scenarioReward' }] },
        { index: 2, transactions: [{ id: 'b', kind: 'scenarioReward' }] },
      ],
    };
    const relay = {
      networkGenesisRevision: 2,
      blocks: [
        {
          index: 1,
          timestamp: '2026-07-06T12:00:00.000Z',
          triggerUsername: 'alice',
          chronofluxFingerprint: 'fp-transfer-1',
          transactions: [
            {
              id: 'tx-1',
              kind: 'transfer',
              fromUsername: 'alice',
              toUsername: 'bob',
              amount: { microUnits: 5 },
              blockIndex: 1,
              timestamp: '2026-07-06T12:00:00.000Z',
            },
          ],
        },
      ],
    };

    const result = acknowledgeRelayTransfers(canonical, relay);
    assert.equal(result.ok, true);
    assert.equal(result.acknowledged, 1);
    assert.deepEqual(result.transferIds, ['tx-1']);
    assert.deepEqual(result.canonicalIndices, [3]);
    assert.equal(canonical.blocks.length, 4);

    const promoted = canonical.blocks[3];
    assert.equal(promoted.index, 3);
    assert.equal(promoted.relaySourceBlockIndex, 1);
    assert.equal(promoted.chronofluxFingerprint, 'fp-transfer-1');
    assert.equal(promoted.transactions[0].id, 'tx-1');
    assert.equal(promoted.transactions[0].blockIndex, 3);
    assert.equal(blockHasTransfer(promoted), true);
    assert.deepEqual([...collectTransferTxIds(canonical)], ['tx-1']);
  });

  it('cloneTransferBlockForCanonicalTip assigns monotonic index', () => {
    const relayBlock = {
      index: 2,
      transactions: [{ id: 'tx-9', kind: 'transfer', blockIndex: 2 }],
    };
    const cloned = cloneTransferBlockForCanonicalTip(relayBlock, 7);
    assert.equal(cloned.index, 7);
    assert.equal(cloned.relaySourceBlockIndex, 2);
    assert.equal(cloned.transactions[0].blockIndex, 7);
    assert.equal(cloned.transactions[0].id, 'tx-9');
  });

  it('skips duplicate transfer ids already on canonical chain', () => {
    const canonical = {
      networkGenesisRevision: 2,
      blocks: [
        {
          index: 0,
          transactions: [{ id: 'tx-dup', kind: 'transfer', blockIndex: 0 }],
        },
      ],
    };
    const relay = {
      networkGenesisRevision: 2,
      blocks: [
        {
          index: 0,
          transactions: [{ id: 'tx-dup', kind: 'transfer', blockIndex: 0 }],
        },
      ],
    };

    const result = acknowledgeRelayTransfers(canonical, relay);
    assert.equal(result.ok, false);
    assert.equal(canonical.blocks.length, 1);
  });

  it('skips relay block when any transfer id already exists on canonical chain', () => {
    const canonical = {
      networkGenesisRevision: 2,
      blocks: [
        {
          index: 0,
          transactions: [{ id: 'tx-old', kind: 'transfer', blockIndex: 0 }],
        },
      ],
    };
    const relay = {
      networkGenesisRevision: 2,
      blocks: [
        {
          index: 1,
          transactions: [
            { id: 'tx-old', kind: 'transfer', blockIndex: 1 },
            { id: 'tx-new', kind: 'transfer', blockIndex: 1 },
          ],
        },
      ],
    };

    const result = acknowledgeRelayTransfers(canonical, relay);
    assert.equal(result.ok, false);
    assert.equal(canonical.blocks.length, 1);
    assert.deepEqual([...collectTransferTxIds(canonical)], ['tx-old']);
  });

  it('rejects genesis revision mismatch', () => {
    const canonical = { networkGenesisRevision: 2, blocks: [] };
    const relay = { networkGenesisRevision: 3, blocks: [] };
    const result = acknowledgeRelayTransfers(canonical, relay);
    assert.equal(result.ok, false);
  });
});