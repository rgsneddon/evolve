import { blockHeight, tipHash } from './ledger_store.js';

const CHAIN_ID = 'evolve-chronoflux-principia-chain-1';
const PEER_ONLINE_MS = Number(process.env.PERC_PEER_ONLINE_MS ?? 15 * 60 * 1000);

export function isPeerOnline(peer, now = Date.now()) {
  const updated = peer?.updatedAt ?? 0;
  return updated > 0 && now - updated <= PEER_ONLINE_MS;
}

export function formatPercAmount(amount) {
  if (!amount || typeof amount !== 'object') return '0';
  const whole = amount.whole ?? 0;
  const fraction = amount.fraction ?? 0;
  if (!fraction) return String(whole);
  const frac = String(fraction).padStart(8, '0').replace(/0+$/, '');
  return frac ? `${whole}.${frac}` : String(whole);
}

export function summarizeBlock(block, ledger) {
  if (!block) return null;
  const txs = block.transactions ?? [];
  return {
    index: block.index,
    timestamp: block.timestamp,
    txCount: txs.length,
    treasuryEmitted: formatPercAmount(block.treasuryEmitted),
    scenarioLabel: block.scenarioLabel ?? null,
    triggerUsername: block.triggerUsername ?? null,
    treasuryCycle: block.treasuryCycle ?? 1,
    microblockSeal: block.microblockSeal ?? false,
    hash: blockHashAt(ledger, block.index),
  };
}

export function blockHashAt(ledger, index) {
  if (!ledger?.blocks?.length) return tipHash(ledger);
  const block = ledger.blocks[index];
  if (!block) return null;
  return tipHash({ ...ledger, blocks: [block] });
}

export function listBlocks(ledger, { offset = 0, limit = 50 } = {}) {
  const blocks = ledger?.blocks ?? [];
  const total = blocks.length;
  const start = Math.max(0, Math.min(offset, total));
  const end = Math.max(start, Math.min(start + limit, total));
  const slice = blocks.slice(start, end).reverse();
  return {
    total,
    offset: start,
    limit,
    blocks: slice.map((b) => summarizeBlock(b, ledger)),
  };
}

export function getBlockDetail(ledger, index) {
  const blocks = ledger?.blocks ?? [];
  const block = blocks[index];
  if (!block) return null;
  return {
    ...summarizeBlock(block, ledger),
    transactions: (block.transactions ?? []).map((tx) => ({
      id: tx.id,
      kind: tx.kind,
      from: tx.from ?? null,
      to: tx.to ?? null,
      amount: formatPercAmount(tx.amount),
      fee: tx.fee ? formatPercAmount(tx.fee) : null,
      memo: tx.memo ?? null,
      timestamp: tx.timestamp ?? block.timestamp,
    })),
  };
}

export function buildNetworkSnapshot({
  peers,
  ledgers,
  store,
  seedUsername,
  endpoint,
  chainId = CHAIN_ID,
}) {
  const now = Date.now();
  const ledger = store.ledger;
  const height = blockHeight(ledger);
  const peerRows = [...peers.values()]
    .filter((p) => (p.evolutionaryChainId ?? chainId) === chainId)
    .map((p) => {
      const username = p.sessionUsername ?? 'unknown';
      const relayed = ledgers.get(username);
      const relayHeight = relayed?.ledger ? blockHeight(relayed.ledger) : 0;
      return {
        username,
        endpoint: p.endpoint ?? null,
        blockHeight: p.blockHeight ?? 0,
        tipHash: p.tipHash ?? '',
        relayHeight,
        online: isPeerOnline(p, now),
        lastSeen: p.updatedAt ? new Date(p.updatedAt).toISOString() : null,
        ageSeconds: p.updatedAt ? Math.floor((now - p.updatedAt) / 1000) : null,
      };
    })
    .sort((a, b) => b.blockHeight - a.blockHeight);

  const onlineCount = peerRows.filter((p) => p.online).length;
  const maxPeerHeight = peerRows.reduce((m, p) => Math.max(m, p.blockHeight, p.relayHeight), 0);

  return {
    ok: true,
    service: 'perc-internet-node',
    nodeStatus: 'online',
    chainId,
    seedUsername,
    endpoint,
    blockHeight: height,
    tipHash: tipHash(ledger),
    revision: store.revision,
    ledgerReady: store.hasLedger(),
    peers: {
      total: peerRows.length,
      online: onlineCount,
      offline: peerRows.length - onlineCount,
    },
    networkHeight: Math.max(height, maxPeerHeight),
    peerList: peerRows,
    updatedAt: new Date(now).toISOString(),
  };
}