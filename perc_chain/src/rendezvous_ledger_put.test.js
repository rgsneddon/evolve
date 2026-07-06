import { describe, it, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'fs';
import http from 'http';
import os from 'os';
import path from 'path';
import { LedgerStore } from './ledger_store.js';
import { createGenesisLedger } from './genesis.js';
import { applyRelayLedgerPut } from './rendezvous_ledger_put.js';
import { getBlockDetail } from './explorer_api.js';

const CHAIN_ID = 'evolve-chronoflux-principia-chain-1';
const SEED_USERNAME = 'evolve_seed_node';
const MICROBLOCKS_PER_BLOCK = 100_000_000;

function launchLedger(base) {
  return {
    ...base,
    blockchainLaunched: true,
    blocks: [
      ...(base.blocks ?? []),
      {
        index: base.blocks?.length ?? 0,
        timestamp: '2026-07-06T10:00:00.000Z',
        scenarioLabel: 'Blockchain launch',
        transactions: [],
      },
    ],
    microblocksPerBlock: MICROBLOCKS_PER_BLOCK,
  };
}

function scenarioBlock(previous, index, label) {
  return {
    ...previous,
    blocks: [
      ...previous.blocks,
      {
        index,
        timestamp: `2026-07-06T11:${String(index).padStart(2, '0')}:00.000Z`,
        scenarioLabel: label,
        triggerUsername: 'GLAL7',
        transactions: [
          {
            id: `tx-scenario-${index}`,
            kind: 'scenarioReward',
            toUsername: 'GLAL7',
            amount: { microUnits: 100 },
          },
        ],
      },
    ],
  };
}

function senderRelayWithTransfer(base) {
  const index = base.blocks.length;
  return {
    ...base,
    blocks: [
      ...base.blocks,
      {
        index,
        timestamp: '2026-07-06T12:00:00.000Z',
        triggerUsername: 'android_user',
        transactions: [
          {
            id: 'tx-relay-transfer-1',
            kind: 'transfer',
            fromUsername: 'android_user',
            toUsername: 'windows_user',
            amount: { microUnits: 10 },
            memo: 'Relayed send',
            timestamp: '2026-07-06T12:00:00.000Z',
          },
          {
            id: 'tx-relay-fee-1',
            kind: 'feeBurn',
            fromUsername: 'android_user',
            amount: { microUnits: 1 },
          },
        ],
      },
    ],
  };
}

function createPutHandler(ctx) {
  return async (req, res) => {
    if (req.method === 'PUT' && req.url === '/perc/rendezvous/ledger') {
      let body = '';
      req.on('data', (chunk) => {
        body += chunk;
      });
      req.on('end', () => {
        const data = body ? JSON.parse(body) : {};
        const result = applyRelayLedgerPut({
          store: ctx.store,
          ledgers: ctx.ledgers,
          addresses: ctx.addresses,
          username: data.username,
          ledger: data.ledger,
          seedUsername: SEED_USERNAME,
        });
        res.writeHead(result.ok ? 200 : 400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(result.ok ? { ok: true, imported: result.imported } : result));
      });
      return;
    }
    res.writeHead(404);
    res.end();
  };
}

describe('rendezvous PUT relay path promotes transfer blocks into seed store', () => {
  let tmpDir;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'perc-rendezvous-put-'));
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  it('applyRelayLedgerPut merges transfer from shorter sender relay over taller seed', () => {
    const store = new LedgerStore(tmpDir);
    let tall = launchLedger(createGenesisLedger({ genesisRevision: 2, chainId: CHAIN_ID }));
    tall = scenarioBlock(tall, tall.blocks.length, 'Scenario A');
    tall = scenarioBlock(tall, tall.blocks.length, 'Scenario B');
    store.forceReplaceLedger(tall);

    const senderBase = launchLedger(createGenesisLedger({ genesisRevision: 2, chainId: CHAIN_ID }));
    const senderRelay = senderRelayWithTransfer(senderBase);
    assert.ok(senderRelay.blocks.length < tall.blocks.length);

    const ledgers = new Map();
    const addresses = new Map();
    const result = applyRelayLedgerPut({
      store,
      ledgers,
      addresses,
      username: 'android_user',
      ledger: senderRelay,
      seedUsername: SEED_USERNAME,
    });

    assert.equal(result.ok, true);
    assert.equal(result.imported, true);
    assert.equal(store.ledger.blocks.length, tall.blocks.length + 1);

    const transferIndex = store.ledger.blocks.length - 1;
    const detail = getBlockDetail(store.ledger, transferIndex);
    assert.ok(detail);
    assert.equal(detail.displayLabel, 'Manual tx');
    const transfer = detail.transactions.find((tx) => tx.kind === 'transfer');
    assert.ok(transfer);
    assert.equal(transfer.from, 'android_user');
    assert.equal(transfer.to, 'windows_user');
    assert.equal(transfer.amount, '0.0000001');
    assert.equal(store.ledger.microblocksPerBlock, MICROBLOCKS_PER_BLOCK);
  });

  it('HTTP PUT /perc/rendezvous/ledger imports transfer block detail with kind transfer', async () => {
    const store = new LedgerStore(tmpDir);
    let tall = launchLedger(createGenesisLedger({ genesisRevision: 2, chainId: CHAIN_ID }));
    tall = scenarioBlock(tall, tall.blocks.length, 'Seed activity');
    store.forceReplaceLedger(tall);

    const senderRelay = senderRelayWithTransfer(
      launchLedger(createGenesisLedger({ genesisRevision: 2, chainId: CHAIN_ID })),
    );

    const ctx = { store, ledgers: new Map(), addresses: new Map() };
    const server = http.createServer(createPutHandler(ctx));

    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    const { port } = server.address();

    try {
      const response = await fetch(`http://127.0.0.1:${port}/perc/rendezvous/ledger`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username: 'android_user', ledger: senderRelay }),
      });
      assert.equal(response.status, 200);
      const payload = await response.json();
      assert.equal(payload.ok, true);
      assert.equal(payload.imported, true);

      const detail = getBlockDetail(store.ledger, store.ledger.blocks.length - 1);
      assert.equal(detail.displayLabel, 'Manual tx');
      assert.ok(detail.transactions.some((tx) => tx.kind === 'transfer'));
    } finally {
      await new Promise((resolve) => server.close(resolve));
    }
  });
});