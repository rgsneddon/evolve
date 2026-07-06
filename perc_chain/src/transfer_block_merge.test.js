import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  blockHasTransfer,
  collectTransferTxIds,
  mergeTransferBlocksFromPeer,
} from './transfer_block_merge.js';

describe('mergeTransferBlocksFromPeer', () => {
  it('appends unknown transfer blocks from shorter peer without replacing tip', () => {
    const local = {
      networkGenesisRevision: 2,
      blocks: [
        { index: 0, transactions: [] },
        { index: 1, transactions: [{ id: 'a', kind: 'scenarioReward' }] },
        { index: 2, transactions: [{ id: 'b', kind: 'scenarioReward' }] },
      ],
    };
    const remote = {
      networkGenesisRevision: 2,
      blocks: [
        { index: 0, transactions: [] },
        {
          index: 1,
          timestamp: '2026-07-06T12:00:00.000Z',
          triggerUsername: 'alice',
          transactions: [
            {
              id: 'tx-1',
              kind: 'transfer',
              fromUsername: 'alice',
              toUsername: 'bob',
              amount: { microUnits: 5 },
            },
          ],
        },
      ],
    };

    const result = mergeTransferBlocksFromPeer(local, remote);
    assert.equal(result.appended, 1);
    assert.equal(local.blocks.length, 4);
    assert.equal(blockHasTransfer(local.blocks[3]), true);
    assert.deepEqual([...collectTransferTxIds(local)], ['tx-1']);
  });

  it('skips duplicate transfer ids already on local chain', () => {
    const local = {
      networkGenesisRevision: 2,
      blocks: [
        {
          index: 0,
          transactions: [{ id: 'tx-dup', kind: 'transfer' }],
        },
      ],
    };
    const remote = {
      networkGenesisRevision: 2,
      blocks: [
        {
          index: 0,
          transactions: [{ id: 'tx-dup', kind: 'transfer' }],
        },
      ],
    };

    const result = mergeTransferBlocksFromPeer(local, remote);
    assert.equal(result.appended, 0);
    assert.equal(local.blocks.length, 1);
  });
});