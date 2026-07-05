import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { blockTipPayload } from './chain_tip_payload.js';
import {
  compactLedgerForSeed,
  truncateScenarioText,
} from './ledger_compact.js';

describe('truncateScenarioText', () => {
  it('leaves short labels unchanged', () => {
    assert.equal(truncateScenarioText('Percent chance: rain?', 120), 'Percent chance: rain?');
  });

  it('truncates long labels with ellipsis', () => {
    const long = `Social cohesion score: ${'x'.repeat(200)}`;
    const out = truncateScenarioText(long, 40);
    assert.equal(out.length, 40);
    assert.ok(out.endsWith('…'));
    assert.ok(out.startsWith('Social cohesion score:'));
  });
});

describe('compactLedgerForSeed', () => {
  it('truncates block scenario text and clears account histories', () => {
    const ledger = {
      blocks: [
        {
          index: 0,
          scenarioLabel: `Percent chance: ${'y'.repeat(300)}`,
          transactions: [
            {
              id: 'tx-1',
              kind: 'scenarioReward',
              scenarioLabel: `Percent chance: ${'y'.repeat(300)}`,
            },
          ],
        },
      ],
      accounts: {
        alice: {
          username: 'alice',
          balance: { microUnits: 1 },
          transactions: [{ id: 'tx-1', kind: 'scenarioReward', scenarioLabel: 'full copy' }],
        },
      },
    };

    const compact = compactLedgerForSeed(ledger);
    assert.ok(compact.blocks[0].scenarioLabel.length <= 120);
    assert.ok(compact.blocks[0].transactions[0].scenarioLabel.length <= 120);
    assert.deepEqual(compact.accounts.alice.transactions, []);
  });
});

describe('blockTipPayload', () => {
  it('ignores scenario narrative when building tip payload', () => {
    const full = blockTipPayload({
      index: 3,
      timestamp: '2026-07-05T12:00:00.000Z',
      treasuryEmitted: { microUnits: 1 },
      scenarioLabel: 'Percent chance: full scenario question here',
      transactions: [
        {
          id: 'tx-9',
          kind: 'scenarioReward',
          amount: { microUnits: 5 },
          timestamp: '2026-07-05T12:00:00.000Z',
          scenarioLabel: 'Percent chance: full scenario question here',
          memo: 'long memo text',
          percentChance: 42,
        },
      ],
    });
    const truncated = blockTipPayload({
      index: 3,
      timestamp: '2026-07-05T12:00:00.000Z',
      treasuryEmitted: { microUnits: 1 },
      scenarioLabel: 'Percent chance: truncated…',
      transactions: [
        {
          id: 'tx-9',
          kind: 'scenarioReward',
          amount: { microUnits: 5 },
          timestamp: '2026-07-05T12:00:00.000Z',
          scenarioLabel: 'Percent chance: truncated…',
          percentChance: 42,
        },
      ],
    });
    assert.deepEqual(full, truncated);
  });
});