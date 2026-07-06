import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  acknowledgeRelayTransfers,
  blockHasTransfer,
  collectTransferTxIds,
} from './transfer_relay_ack.js';

describe('acknowledgeRelayTransfers', () => {
  it('appends transfer block preserving original index and blockIndex', () => {
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
          index: 2,
          timestamp: '2026-07-06T12:00:00.000Z',
          triggerUsername: 'alice',
          chronofluxFingerprint: 'fp-transfer-2',
          transactions: [
            {
              id: 'tx-1',
              kind: 'transfer',
              fromUsername: 'alice',
              toUsername: 'bob',
              amount: { microUnits: 5 },
              blockIndex: 2,
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
    assert.equal(canonical.blocks.length, 4);

    const promoted = canonical.blocks[3];
    assert.equal(promoted.index, 2);
    assert.equal(promoted.chronofluxFingerprint, 'fp-transfer-2');
    assert.equal(promoted.transactions[0].blockIndex, 2);
    assert.equal(blockHasTransfer(promoted), true);
    assert.deepEqual([...collectTransferTxIds(canonical)], ['tx-1']);
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

  it('rejects genesis revision mismatch', () => {
    const canonical = { networkGenesisRevision: 2, blocks: [] };
    const relay = { networkGenesisRevision: 3, blocks: [] };
    const result = acknowledgeRelayTransfers(canonical, relay);
    assert.equal(result.ok, false);
  });
});