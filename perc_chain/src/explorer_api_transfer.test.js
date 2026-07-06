import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { genericBlockLabel } from './block_display_label.js';
import { blockAtIndex, getBlockDetail, summarizeBlock } from './explorer_api.js';

const transferLedger = {
  blocks: [
    {
      index: 0,
      timestamp: '2026-07-06T12:00:00.000Z',
      treasuryEmitted: { microUnits: 0 },
      triggerUsername: 'alice',
      transactions: [
        {
          id: 'tx-transfer-1',
          kind: 'transfer',
          fromUsername: 'alice',
          toUsername: 'bob',
          amount: { microUnits: 10 },
          memo: 'Pilot payment',
          timestamp: '2026-07-06T12:00:00.000Z',
        },
        {
          id: 'tx-fee-1',
          kind: 'feeBurn',
          fromUsername: 'alice',
          amount: { microUnits: 1 },
          memo: 'Burned network fee',
        },
      ],
    },
  ],
};

describe('explorer transfer API', () => {
  it('summarizeBlock labels transfers as Manual tx', () => {
    const summary = summarizeBlock(transferLedger.blocks[0], transferLedger);
    assert.equal(summary.displayLabel, 'Manual tx');
    assert.equal(genericBlockLabel(transferLedger.blocks[0]), 'Manual tx');
  });

  it('getBlockDetail exposes kind transfer with formatted amount and parties', () => {
    const detail = getBlockDetail(transferLedger, 0);
    assert.ok(detail);
    assert.equal(detail.displayLabel, 'Manual tx');
    const transfer = detail.transactions.find((tx) => tx.kind === 'transfer');
    assert.ok(transfer);
    assert.equal(transfer.from, 'alice');
    assert.equal(transfer.to, 'bob');
    assert.equal(transfer.amount, '0.0000001');
    assert.equal(transfer.memo, 'Pilot payment');
  });

  it('blockAtIndex resolves relay-promoted transfer by sender relaySourceBlockIndex', () => {
    const ledger = {
      blocks: [
        { index: 0, transactions: [] },
        { index: 1, transactions: [{ id: 's', kind: 'scenarioReward' }] },
        {
          index: 5,
          relaySourceBlockIndex: 2,
          timestamp: '2026-07-06T12:00:00.000Z',
          transactions: [
            {
              id: 'tx-relay',
              kind: 'transfer',
              fromUsername: 'alice',
              toUsername: 'bob',
              amount: { microUnits: 5 },
              blockIndex: 5,
            },
          ],
        },
      ],
    };
    assert.equal(blockAtIndex(ledger, 5)?.index, 5);
    assert.equal(blockAtIndex(ledger, 2)?.index, 5);
    assert.equal(blockAtIndex(ledger, 2)?.relaySourceBlockIndex, 2);
    const detail = getBlockDetail(ledger, 2);
    assert.equal(detail.transactions.find((tx) => tx.kind === 'transfer').id, 'tx-relay');
    assert.equal(detail.relaySourceBlockIndex, 2);
  });

  it('getBlockDetail uses canonical index for relay-promoted canonical tip block', () => {
    const ledger = {
      blocks: [
        { index: 0, transactions: [] },
        { index: 1, transactions: [{ id: 's', kind: 'scenarioReward' }] },
        {
          index: 2,
          timestamp: '2026-07-06T12:00:00.000Z',
          transactions: [
            {
              id: 'tx-relay',
              kind: 'transfer',
              fromUsername: 'alice',
              toUsername: 'bob',
              amount: { microUnits: 5 },
              blockIndex: 2,
            },
          ],
        },
      ],
    };
    const detail = getBlockDetail(ledger, 2);
    assert.equal(detail.transactions.find((tx) => tx.kind === 'transfer').id, 'tx-relay');
    assert.equal(detail.index, 2);
  });
});