import http from 'http';
import path from 'path';
import { LedgerStore, blockHeight, tipHash } from './ledger_store.js';

const PORT = Number(process.env.PORT ?? process.env.PERC_RENDEZVOUS_PORT ?? 9478);
const CHAIN_ID = 'evolve-chronoflux-principia-chain-1';
const SEED_USERNAME = process.env.PERC_SEED_USERNAME ?? 'evolve_seed_node';
const DATA_DIR = process.env.PERC_DATA_DIR ?? path.join(process.cwd(), 'data');
const SYNC_INTERVAL_MS = Number(process.env.PERC_SYNC_INTERVAL_MS ?? 120_000);

/** @type {Map<string, object>} */
const peers = new Map();
/** @type {Map<string, object>} */
const ledgers = new Map();

const store = new LedgerStore(DATA_DIR);

function publicEndpoint() {
  const explicit = (process.env.PERC_PUBLIC_ENDPOINT ?? process.env.RENDER_EXTERNAL_URL ?? '').trim();
  if (explicit) return explicit.replace(/\/$/, '');
  return `http://127.0.0.1:${PORT}`;
}

function json(res, code, body) {
  res.writeHead(code, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  });
  res.end(JSON.stringify(body));
}

function readBody(req) {
  return new Promise((resolve) => {
    let body = '';
    req.on('data', (chunk) => (body += chunk));
    req.on('end', () => {
      try {
        resolve(body ? JSON.parse(body) : {});
      } catch {
        resolve({});
      }
    });
  });
}

async function registerSeed() {
  const endpoint = publicEndpoint();
  if (!endpoint || endpoint.includes('127.0.0.1') || endpoint.includes('localhost')) return;
  const status = store.status(SEED_USERNAME, endpoint);
  peers.set(SEED_USERNAME, {
    sessionUsername: SEED_USERNAME,
    endpoint,
    evolutionaryChainId: status.evolutionaryChainId,
    blockHeight: status.blockHeight,
    tipHash: status.tipHash,
    revision: status.revision,
    updatedAt: Date.now(),
  });
  if (store.hasLedger()) {
    ledgers.set(SEED_USERNAME, {
      username: SEED_USERNAME,
      ledger: store.ledger,
      updatedAt: Date.now(),
    });
  }
}

async function fetchJson(url, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(options.headers ?? {}),
    },
    signal: AbortSignal.timeout(8000),
  });
  if (!response.ok) return null;
  return response.json();
}

async function syncFromNetwork() {
  const base = publicEndpoint();
  if (!base || base.includes('127.0.0.1')) return;

  let peerList = [];
  try {
    peerList = await fetchJson(
      `${base}/perc/rendezvous/peers?chainId=${encodeURIComponent(CHAIN_ID)}`,
    );
  } catch {
    return;
  }
  if (!Array.isArray(peerList)) return;

  let best = null;
  let bestUsername = null;

  for (const peer of peerList) {
    const username = peer.sessionUsername;
    const endpoint = peer.endpoint;
    const height = peer.blockHeight ?? 0;
    if (!username || username === SEED_USERNAME) continue;
    if (height < blockHeight(best)) continue;

    let candidate = null;
    if (endpoint && !endpoint.includes('127.0.0.1') && !endpoint.includes('localhost')) {
      try {
        candidate = await fetchJson(`${endpoint.replace(/\/$/, '')}/perc/ledger`);
      } catch {
        candidate = null;
      }
    }
    if (!candidate || blockHeight(candidate) < height) {
      try {
        const relay = await fetchJson(
          `${base}/perc/rendezvous/ledger?username=${encodeURIComponent(username)}`,
        );
        candidate = relay?.ledger ?? null;
      } catch {
        candidate = null;
      }
    }
    if (candidate && blockHeight(candidate) >= blockHeight(best)) {
      best = candidate;
      bestUsername = username;
    }
  }

  if (best && store.importLedger(best)) {
    console.log(
      `Seed synced to height ${blockHeight(best)} from ${bestUsername ?? bestEndpoint ?? 'network'}`,
    );
    await registerSeed();
  }
}

const server = http.createServer(async (req, res) => {
  if (req.method === 'OPTIONS') {
    return json(res, 204, {});
  }

  const url = new URL(req.url, `http://127.0.0.1:${PORT}`);

  if (req.method === 'POST' && url.pathname === '/perc/rendezvous/register') {
    const data = await readBody(req);
    if (!data.sessionUsername || !data.endpoint) {
      return json(res, 400, { error: 'sessionUsername and endpoint required' });
    }
    peers.set(data.sessionUsername, {
      ...data,
      evolutionaryChainId: data.evolutionaryChainId ?? CHAIN_ID,
      updatedAt: Date.now(),
    });
    return json(res, 200, { ok: true });
  }

  if (req.method === 'POST' && url.pathname === '/perc/rendezvous/unregister') {
    const data = await readBody(req);
    if (data.username) {
      peers.delete(data.username);
      ledgers.delete(data.username);
    }
    return json(res, 200, { ok: true });
  }

  if (req.method === 'GET' && url.pathname === '/perc/rendezvous/peers') {
    const chainId = url.searchParams.get('chainId') ?? CHAIN_ID;
    const list = [...peers.values()].filter(
      (p) => (p.evolutionaryChainId ?? CHAIN_ID) === chainId,
    );
    return json(res, 200, list);
  }

  if (req.method === 'PUT' && url.pathname === '/perc/rendezvous/ledger') {
    const data = await readBody(req);
    if (!data.username || !data.ledger) {
      return json(res, 400, { error: 'username and ledger required' });
    }
    ledgers.set(data.username, {
      username: data.username,
      ledger: data.ledger,
      updatedAt: Date.now(),
    });
    if (data.username !== SEED_USERNAME) {
      store.importLedger(data.ledger);
    }
    return json(res, 200, { ok: true });
  }

  if (req.method === 'GET' && url.pathname === '/perc/rendezvous/ledger') {
    const username = url.searchParams.get('username');
    if (!username || !ledgers.has(username)) {
      return json(res, 404, { error: 'ledger not found' });
    }
    return json(res, 200, ledgers.get(username));
  }

  if (req.method === 'GET' && url.pathname === '/perc/status') {
    return json(res, 200, store.status(SEED_USERNAME, publicEndpoint()));
  }

  if (req.method === 'GET' && url.pathname === '/perc/ledger') {
    if (!store.hasLedger()) {
      return json(res, 503, { error: 'seed ledger not ready — sync pending' });
    }
    return json(res, 200, store.ledger);
  }

  if (req.method === 'POST' && url.pathname === '/perc/ledger') {
    const remote = await readBody(req);
    if (!remote || typeof remote !== 'object') {
      return json(res, 400, { error: 'ledger body required' });
    }
    store.importLedger(remote);
    await registerSeed();
    return json(res, 200, { ok: true });
  }

  if (req.method === 'GET' && url.pathname === '/health') {
    return json(res, 200, {
      ok: true,
      service: 'perc-internet-node',
      seedUsername: SEED_USERNAME,
      endpoint: publicEndpoint(),
      blockHeight: blockHeight(store.ledger),
      tipHash: tipHash(store.ledger),
      peers: peers.size,
    });
  }

  return json(res, 404, { error: 'not found' });
});

const bindHost = process.env.PERC_BIND_HOST ?? '0.0.0.0';
server.listen(PORT, bindHost, async () => {
  console.log(`Perccent internet node listening on http://${bindHost}:${PORT}`);
  console.log(`Public endpoint: ${publicEndpoint()}`);
  console.log(`Seed username: ${SEED_USERNAME}`);
  await registerSeed();
  await syncFromNetwork();
  setInterval(async () => {
    await syncFromNetwork();
    await registerSeed();
  }, SYNC_INTERVAL_MS);
});