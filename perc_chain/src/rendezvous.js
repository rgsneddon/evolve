import http from 'http';
import {
  findAddressInLedgerCollection,
  indexLedgerAddresses,
} from './address_index.js';

const PORT = Number(process.env.PORT ?? process.env.PERC_RENDEZVOUS_PORT ?? 9478);
const CHAIN_ID = 'evolve-chronoflux-principia-chain-1';

/** @type {Map<string, object>} */
const peers = new Map();
/** @type {Map<string, object>} */
const ledgers = new Map();
/** @type {Map<string, string>} wallet address → sessionUsername */
const addresses = new Map();

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
    indexLedgerAddresses(data.ledger, addresses);
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

  if (req.method === 'GET' && url.pathname === '/perc/rendezvous/ledger') {
    const username = url.searchParams.get('username');
    if (!username || !ledgers.has(username)) {
      return json(res, 404, { error: 'ledger not found' });
    }
    return json(res, 200, ledgers.get(username));
  }

  if (req.method === 'GET' && url.pathname === '/health') {
    return json(res, 200, { ok: true, service: 'perc-rendezvous', peers: peers.size });
  }

  return json(res, 404, { error: 'not found' });
});

const bindHost = process.env.PERC_RENDEZVOUS_HOST ?? '0.0.0.0';
server.listen(PORT, bindHost, () => {
  console.log(`Perccent internet rendezvous listening on http://0.0.0.0:${PORT}`);
});