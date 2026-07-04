import test from 'node:test';
import assert from 'node:assert/strict';
import { buildWalletBlockChart } from './explorer_api.js';

test('buildWalletBlockChart lists every peer with effective block height', () => {
  const peers = new Map([
    ['alice', {
      sessionUsername: 'alice',
      evolutionaryChainId: 'evolve-chronoflux-principia-chain-1',
      blockHeight: 4,
      endpoint: 'https://alice.example/perc',
      updatedAt: Date.now(),
    }],
    ['bob', {
      sessionUsername: 'bob',
      evolutionaryChainId: 'evolve-chronoflux-principia-chain-1',
      blockHeight: 2,
      endpoint: 'https://bob.example/perc',
      updatedAt: Date.now() - 60_000,
    }],
  ]);

  const ledgers = new Map([
    ['alice', {
      username: 'alice',
      ledger: {
        blocks: [{}, {}, {}, {}],
        accounts: {
          alice: { scenarioBlockHeight: 12 },
        },
      },
    }],
    ['bob', {
      username: 'bob',
      ledger: {
        blocks: [{}, {}],
        accounts: {
          bob: { scenarioBlockHeight: 7 },
        },
      },
    }],
  ]);

  const chart = buildWalletBlockChart({
    peers,
    ledgers,
    store: {
      ledger: {
        cumulativeTreasuryMinted: { microUnits: 0 },
        accounts: { evolve_seed_node: { scenarioBlockHeight: 1 } },
        blocks: [],
      },
    },
    seedUsername: 'evolve_seed_node',
  });

  assert.equal(chart.pentagonScale.length, 5);
  assert.equal(chart.users.length, 3);
  const alice = chart.users.find((u) => u.username === 'alice');
  assert.equal(alice.displayBlock, 12);
  assert.equal(alice.scenarioBlockHeight, 12);
  const bob = chart.users.find((u) => u.username === 'bob');
  assert.equal(bob.displayBlock, 7);
  assert.ok(chart.maxBlock >= 12);
});