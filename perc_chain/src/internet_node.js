import fs from 'fs';
import http from 'http';
import path from 'path';
import { fileURLToPath } from 'url';
import {
  buildNetworkSnapshot,
  getBlockDetail,
  isHiddenPeer,
  listBlocks,
} from './explorer_api.js';
import { LedgerStore, blockHeight, tipHash } from './ledger_store.js';
import { TreasuryAdmin } from './treasury_admin.js';
import { buildTreasuryWalletView } from './treasury_api.js';
import { launchBlockchainFromTreasuryLogin } from './blockchain_launch.js';
import { regenerateTreasuryIfLow } from './treasury_regeneration.js';
import { maskEndpoint, sanitizeForPublicExplorer } from './endpoint_privacy.js';
import {
  findAddressInLedgerCollection,
  indexLedgerAddresses,
} from './address_index.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PUBLIC_DIR = path.join(__dirname, '..', 'public');

const PORT = Number(process.env.PORT ?? process.env.PERC_RENDEZVOUS_PORT ?? 9478);
const CHAIN_ID = 'evolve-chronoflux-principia-chain-1';
const SEED_USERNAME = process.env.PERC_SEED_USERNAME ?? 'evolve_seed_node';
const TREASURY_USERNAME = process.env.PERC_TREASURY_USERNAME ?? 'evolve_treasury';
const DATA_DIR = process.env.PERC_DATA_DIR ?? path.join(process.cwd(), 'data');
const SYNC_INTERVAL_MS = Number(process.env.PERC_SYNC_INTERVAL_MS ?? 120_000);
const TREASURY_REGEN_INTERVAL_MS = Number(process.env.PERC_TREASURY_REGEN_INTERVAL_MS ?? 30_000);
const CHAIN_GENESIS_REVISION = Number(process.env.PERC_CHAIN_GENESIS_REVISION ?? 2);

/** @type {Map<string, object>} */
const peers = new Map();
/** @type {Map<string, object>} */
const ledgers = new Map();
/** @type {Map<string, string>} wallet address → sessionUsername */
const addresses = new Map();

const store = new LedgerStore(DATA_DIR);
const treasuryAdmin = new TreasuryAdmin(DATA_DIR);

function requireTreasuryAuth(req) {
  return treasuryAdmin.sessionFromAuthHeader(req.headers.authorization ?? '');
}

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
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  });
  res.end(JSON.stringify(body));
}

function html(res, code, body) {
  res.writeHead(code, {
    'Content-Type': 'text/html; charset=utf-8',
    'Cache-Control': 'no-cache',
  });
  res.end(body);
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

function servePublic(relPath, res) {
  const safe = path.normalize(relPath).replace(/^(\.\.[/\\])+/, '');
  const filePath = path.join(PUBLIC_DIR, safe);
  if (!filePath.startsWith(PUBLIC_DIR)) {
    return false;
  }
  if (!fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
    return false;
  }
  const ext = path.extname(filePath).toLowerCase();
  const types = {
    '.html': 'text/html; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
    '.js': 'application/javascript; charset=utf-8',
    '.svg': 'image/svg+xml',
    '.png': 'image/png',
    '.ico': 'image/x-icon',
  };
  res.writeHead(200, {
    'Content-Type': types[ext] ?? 'application/octet-stream',
    'Cache-Control': ext === '.html' ? 'no-cache' : 'public, max-age=3600',
  });
  res.end(fs.readFileSync(filePath));
  return true;
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
    indexLedgerAddresses(store.ledger, addresses);
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
    if (!username || username === SEED_USERNAME || isHiddenPeer(username)) continue;
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
      `Seed synced to height ${blockHeight(best)} from ${bestUsername ?? 'network'}`,
    );
    await registerSeed();
  }
}

const server = http.createServer(async (req, res) => {
  if (req.method === 'OPTIONS') {
    return json(res, 204, {});
  }

  const url = new URL(req.url, `http://127.0.0.1:${PORT}`);

  if (req.method === 'GET' && url.pathname === '/api/treasury/auth/setup-needed') {
    return json(res, 200, {
      needsPasswordSetup: treasuryAdmin.needsPasswordSetup(),
      blockchainLaunched:
        treasuryAdmin.isBlockchainLaunched() || (store.ledger?.blockchainLaunched ?? false),
    });
  }

  if (req.method === 'POST' && url.pathname === '/api/treasury/auth/login') {
    const data = await readBody(req);
    const result = treasuryAdmin.login({
      username: data.username,
      password: data.password,
      confirmPassword: data.confirmPassword,
    });
    if (!result.ok) {
      return json(res, result.needsSetup ? 400 : 401, result);
    }

    let launch = null;
    if (!treasuryAdmin.isBlockchainLaunched()) {
      launch = launchBlockchainFromTreasuryLogin(store, {
        adminPassword: data.password,
        launchedBy: result.username,
      });
      if (launch.ok && launch.launched) {
        treasuryAdmin.markBlockchainLaunched();
        await registerSeed();
      } else if (!launch.ok) {
        return json(res, 500, { ...result, launchError: launch.error });
      }
    }

    return json(res, 200, {
      ...result,
      blockchainLaunched: treasuryAdmin.isBlockchainLaunched(),
      launch,
    });
  }

  if (req.method === 'POST' && url.pathname === '/api/treasury/auth/logout') {
    const session = requireTreasuryAuth(req);
    const data = await readBody(req);
    treasuryAdmin.logout(data.token ?? (req.headers.authorization ?? '').replace('Bearer ', ''));
    return json(res, 200, { ok: true, username: session?.username ?? null });
  }

  if (req.method === 'GET' && url.pathname === '/api/treasury/auth/status') {
    const session = requireTreasuryAuth(req);
    if (!session) return json(res, 401, { ok: false, authenticated: false });
    return json(res, 200, {
      ok: true,
      authenticated: true,
      username: session.username,
      needsPasswordSetup: treasuryAdmin.needsPasswordSetup(),
    });
  }

  if (req.method === 'GET' && url.pathname === '/api/treasury/wallet') {
    const session = requireTreasuryAuth(req);
    if (!session) return json(res, 401, { ok: false, error: 'Treasury login required' });
    return json(res, 200, buildTreasuryWalletView(store));
  }

  if (req.method === 'GET' && url.pathname === '/api/network') {
    return json(
      res,
      200,
      sanitizeForPublicExplorer(
        buildNetworkSnapshot({
          peers,
          ledgers,
          store,
          seedUsername: SEED_USERNAME,
          endpoint: publicEndpoint(),
          chainId: CHAIN_ID,
        }),
      ),
    );
  }

  const blockMatch = url.pathname.match(/^\/api\/blocks\/(\d+)$/);
  if (req.method === 'GET' && blockMatch) {
    const index = Number(blockMatch[1]);
    if (!store.hasLedger()) {
      return json(res, 503, { error: 'ledger not ready' });
    }
    const detail = getBlockDetail(store.ledger, index);
    if (!detail) return json(res, 404, { error: 'block not found' });
    return json(res, 200, sanitizeForPublicExplorer(detail));
  }

  if (req.method === 'GET' && url.pathname === '/api/blocks') {
    if (!store.hasLedger()) {
      return json(res, 200, { total: 0, offset: 0, limit: 50, blocks: [] });
    }
    const offset = Number(url.searchParams.get('offset') ?? 0);
    const limit = Math.min(Number(url.searchParams.get('limit') ?? 50), 200);
    return json(res, 200, sanitizeForPublicExplorer(listBlocks(store.ledger, { offset, limit })));
  }

  if (req.method === 'GET' && (url.pathname === '/' || url.pathname === '/explorer')) {
    if (servePublic('index.html', res)) return;
    return json(res, 503, { error: 'explorer UI missing' });
  }

  if (req.method === 'GET' && url.pathname.startsWith('/public/')) {
    if (servePublic(url.pathname.slice('/public/'.length), res)) return;
    return json(res, 404, { error: 'not found' });
  }

  if (req.method === 'POST' && url.pathname === '/perc/rendezvous/register') {
    const data = await readBody(req);
    if (!data.sessionUsername || !data.endpoint) {
      return json(res, 400, { error: 'sessionUsername and endpoint required' });
    }
    if (isHiddenPeer(data.sessionUsername)) {
      return json(res, 200, { ok: true, hidden: true });
    }
    peers.set(data.sessionUsername, {
      ...data,
      evolutionaryChainId: data.evolutionaryChainId ?? CHAIN_ID,
      updatedAt: Date.now(),
    });
    if (data.walletAddress) {
      addresses.set(data.walletAddress, data.sessionUsername);
    }
    const relayed = ledgers.get(data.sessionUsername);
    if (relayed?.ledger) {
      indexLedgerAddresses(relayed.ledger, addresses);
    }
    return json(res, 200, { ok: true });
  }

  if (req.method === 'POST' && url.pathname === '/perc/rendezvous/unregister') {
    const data = await readBody(req);
    if (data.username) {
      peers.delete(data.username);
      // Keep address + ledger entries so offline wallets stay discoverable for sends.
    }
    return json(res, 200, { ok: true });
  }

  if (req.method === 'GET' && url.pathname === '/perc/rendezvous/address') {
    const address = url.searchParams.get('address')?.trim();
    if (!address) {
      return json(res, 404, { error: 'address not found' });
    }
    let username = addresses.get(address);
    if (!username) {
      const found = findAddressInLedgerCollection(address, [
        store.ledger,
        ...[...ledgers.values()].map((entry) => entry.ledger),
      ]);
      if (found) {
        username = found.username;
        addresses.set(found.address, found.username);
      }
    }
    if (!username) {
      return json(res, 404, { error: 'address not found' });
    }
    return json(res, 200, {
      username,
      address,
    });
  }

  if (req.method === 'GET' && url.pathname === '/perc/rendezvous/peers') {
    const chainId = url.searchParams.get('chainId') ?? CHAIN_ID;
    const list = [...peers.values()]
      .filter((p) => (p.evolutionaryChainId ?? CHAIN_ID) === chainId)
      .filter((p) => !isHiddenPeer(p.sessionUsername));
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
    indexLedgerAddresses(data.ledger, addresses);
    if (data.username !== SEED_USERNAME) {
      store.importLedger(data.ledger);
      indexLedgerAddresses(store.ledger, addresses);
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
      store.resetToGenesis(CHAIN_GENESIS_REVISION);
    }
    return json(res, 200, store.ledger);
  }

  if (req.method === 'POST' && url.pathname === '/perc/ledger') {
    const remote = await readBody(req);
    if (!remote || typeof remote !== 'object') {
      return json(res, 400, { error: 'ledger body required' });
    }
    store.importLedger(remote);
    indexLedgerAddresses(store.ledger, addresses);
    await registerSeed();
    return json(res, 200, { ok: true });
  }

  if (req.method === 'GET' && url.pathname === '/health') {
    const snapshot = buildNetworkSnapshot({
      peers,
      ledgers,
      store,
      seedUsername: SEED_USERNAME,
      endpoint: publicEndpoint(),
      chainId: CHAIN_ID,
    });
    return json(res, 200, {
      ok: true,
      service: 'perc-internet-node',
      explorer: maskEndpoint(`${publicEndpoint()}/`),
      seedUsername: SEED_USERNAME,
      endpoint: snapshot.endpoint,
      blockHeight: snapshot.blockHeight,
      networkHeight: snapshot.networkHeight,
      tipHash: snapshot.tipHash,
      peers: snapshot.peers.total,
      peersOnline: snapshot.peers.online,
      ledgerReady: snapshot.ledgerReady,
    });
  }

  return json(res, 404, { error: 'not found' });
});

const bindHost = process.env.PERC_BIND_HOST ?? '0.0.0.0';
server.listen(PORT, bindHost, async () => {
  console.log(`Perccent internet node listening on http://${bindHost}:${PORT}`);
  console.log(`Public endpoint: ${publicEndpoint()}`);
  console.log(`Explorer UI: ${publicEndpoint()}/`);
  console.log(`Seed username: ${SEED_USERNAME}`);
  console.log(`Treasury username: ${TREASURY_USERNAME} (hidden from public peers)`);
  console.log(`Chain genesis revision: ${CHAIN_GENESIS_REVISION}`);
  if (store.ensureGenesisRevision(CHAIN_GENESIS_REVISION)) {
    peers.clear();
    ledgers.clear();
    if (treasuryAdmin.record) {
      treasuryAdmin.record.blockchainLaunched = false;
      treasuryAdmin.save();
    }
    console.log('Chain reset to block 0 with new treasury wallet');
  }
  await registerSeed();
  await syncFromNetwork();
  if (regenerateTreasuryIfLow(store, TREASURY_USERNAME)) {
    await registerSeed();
  }
  setInterval(async () => {
    await syncFromNetwork();
    if (regenerateTreasuryIfLow(store, TREASURY_USERNAME)) {
      await registerSeed();
    }
    await registerSeed();
  }, SYNC_INTERVAL_MS);
  setInterval(() => {
    if (regenerateTreasuryIfLow(store, TREASURY_USERNAME)) {
      registerSeed().catch((err) => console.warn('Treasury regen register failed:', err));
    }
  }, TREASURY_REGEN_INTERVAL_MS);
});