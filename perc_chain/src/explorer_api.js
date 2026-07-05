import { maskEndpoint } from './endpoint_privacy.js';
import { genericBlockLabel } from './block_display_label.js';
import { blockHeight, tipHash } from './ledger_store.js';
import { seedBlockHeightFromLedger } from './seed_block.js';

const CHAIN_ID = 'evolve-chronoflux-principia-chain-1';
import { isPeerOnline, PEER_ONLINE_MS } from './peer_online.js';

export { isPeerOnline, PEER_ONLINE_MS };

export function peerOnlineTimeoutSeconds() {
  return Math.round(PEER_ONLINE_MS / 1000);
}

export function hiddenPeerUsernames() {
  const treasury = (process.env.PERC_TREASURY_USERNAME ?? 'evolve_treasury').trim();
  const hidden = new Set([treasury, 'rgsneddon']);
  const extra = (process.env.PERC_HIDDEN_PEERS ?? '').split(',').map((s) => s.trim()).filter(Boolean);
  for (const name of extra) hidden.add(name);
  return hidden;
}

export function isHiddenPeer(username) {
  if (!username) return true;
  return hiddenPeerUsernames().has(username);
}

/** Seed always visible; other wallets only while recently heartbeating. */
export function isNetworkNodeVisible(username, peerOrLastSeenMs, seedUsername, now = Date.now()) {
  if (username === seedUsername) return true;
  const updated =
    typeof peerOrLastSeenMs === 'number'
      ? peerOrLastSeenMs
      : peerOrLastSeenMs?.updatedAt ?? 0;
  return updated > 0 && now - updated <= PEER_ONLINE_MS;
}

export function formatPercAmount(amount) {
  if (!amount || typeof amount !== 'object') return '0';
  if (amount.microUnits != null) {
    const mu = Number(amount.microUnits);
    const whole = Math.floor(mu / 100_000_000);
    const fraction = mu % 100_000_000;
    if (!fraction) return String(whole);
    const frac = String(fraction).padStart(8, '0').replace(/0+$/, '');
    return frac ? `${whole}.${frac}` : String(whole);
  }
  const whole = amount.whole ?? 0;
  const fraction = amount.fraction ?? 0;
  if (!fraction) return String(whole);
  const frac = String(fraction).padStart(8, '0').replace(/0+$/, '');
  return frac ? `${whole}.${frac}` : String(whole);
}

export function buildPublicTreasuryEmission(ledger, treasuryUsername = 'evolve_treasury') {
  if (!ledger?.blockchainLaunched) return null;
  const treasury = ledger.accounts?.[treasuryUsername];
  const balanceMicro = treasury?.balance?.microUnits ?? 0;
  const regenThresholdMicro = Math.round(0.66 * 100_000_000);
  return {
    emissionPerMinute: '1',
    balance: formatPercAmount(treasury?.balance),
    cumulativeMinted: formatPercAmount(ledger.cumulativeTreasuryMinted),
    treasuryCycle: ledger.treasuryCycle ?? 1,
    manualSendsLocked: true,
    disclaimer: 'Manual sends from evolve_treasury are disabled; emission and faucet payouts continue.',
    regenerationThreshold: '0.66',
    needsRegeneration: balanceMicro < regenThresholdMicro,
  };
}

export function summarizeBlock(block, ledger) {
  if (!block) return null;
  const txs = block.transactions ?? [];
  return {
    index: block.index,
    timestamp: block.timestamp,
    txCount: txs.length,
    treasuryEmitted: formatPercAmount(block.treasuryEmitted),
    displayLabel: genericBlockLabel(block),
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

export function scenarioBlockFromLedger(ledger, username) {
  const acc = ledger?.accounts?.[username];
  return Number(acc?.scenarioBlockHeight ?? 0);
}

/** Collect every visible wallet and its block heights for the five-point chart. */
export function buildWalletBlockChart({
  peers,
  ledgers,
  store,
  seedUsername,
  chainId = CHAIN_ID,
  now = Date.now(),
}) {
  const rows = new Map();

  const upsert = (username, patch) => {
    const u = (username ?? '').trim();
    if (!u || isHiddenPeer(u)) return;
    const prev = rows.get(u) ?? {
      username: u,
      chainBlockHeight: 0,
      scenarioBlockHeight: 0,
      relayHeight: 0,
      online: false,
      lastSeen: null,
      endpoint: null,
    };
    rows.set(u, { ...prev, ...patch });
  };

  const seedLedger = store?.ledger ?? null;
  const seedAnchorBlock = seedBlockHeightFromLedger(seedLedger);

  upsert(seedUsername, {
    chainBlockHeight: seedAnchorBlock,
    scenarioBlockHeight: scenarioBlockFromLedger(seedLedger, seedUsername),
    relayHeight: blockHeight(seedLedger),
    online: true,
    lastSeen: new Date(now).toISOString(),
    endpoint: null,
  });

  for (const p of peers.values()) {
    if ((p.evolutionaryChainId ?? chainId) !== chainId) continue;
    const u = p.sessionUsername;
    if (!u) continue;
    const relayed = ledgers.get(u);
    const relayLedger = relayed?.ledger ?? null;
    const relayHeight = relayLedger ? blockHeight(relayLedger) : 0;
    upsert(u, {
      chainBlockHeight: p.blockHeight ?? 0,
      relayHeight,
      scenarioBlockHeight: Math.max(
        scenarioBlockFromLedger(relayLedger, u),
        rows.get(u)?.scenarioBlockHeight ?? 0,
      ),
      online: isPeerOnline(p, now),
      lastSeen: p.updatedAt ? new Date(p.updatedAt).toISOString() : null,
      endpoint: maskEndpoint(p.endpoint ?? null),
    });
  }

  for (const [relayUser, relayed] of ledgers) {
    const ledger = relayed?.ledger;
    if (!ledger?.accounts) continue;
    const relayHeight = blockHeight(ledger);
    for (const [accName, acc] of Object.entries(ledger.accounts)) {
      upsert(accName, {
        scenarioBlockHeight: Math.max(
          rows.get(accName)?.scenarioBlockHeight ?? 0,
          Number(acc.scenarioBlockHeight ?? 0),
        ),
        relayHeight: Math.max(rows.get(accName)?.relayHeight ?? 0, relayHeight),
        chainBlockHeight: Math.max(
          rows.get(accName)?.chainBlockHeight ?? 0,
          relayUser === accName ? relayHeight : 0,
        ),
      });
    }
  }

  const users = [...rows.values()]
    .map((row) => {
      const displayBlock = Math.max(
        row.chainBlockHeight,
        row.relayHeight,
        row.scenarioBlockHeight,
      );
      return { ...row, displayBlock };
    })
    .filter((row) => {
      if (row.username === seedUsername) return true;
      if (!row.lastSeen) return false;
      const seenMs = new Date(row.lastSeen).getTime();
      return isNetworkNodeVisible(row.username, seenMs, seedUsername, now);
    })
    .sort((a, b) => b.displayBlock - a.displayBlock || a.username.localeCompare(b.username));

  const maxBlock = Math.max(1, seedAnchorBlock, ...users.map((u) => u.displayBlock));
  const pentagonScale = [0, 0.25, 0.5, 0.75, 1].map((t) => Math.round(maxBlock * t));

  return {
    seedAnchorBlock,
    maxBlock,
    pentagonScale,
    visibleTimeoutSeconds: peerOnlineTimeoutSeconds(),
    users,
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
    .filter((p) => !isHiddenPeer(p.sessionUsername))
    .filter((p) => isNetworkNodeVisible(p.sessionUsername, p, seedUsername, now))
    .map((p) => {
      const username = p.sessionUsername ?? 'unknown';
      const relayed = ledgers.get(username);
      const relayHeight = relayed?.ledger ? blockHeight(relayed.ledger) : 0;
      return {
        username,
        endpoint: maskEndpoint(p.endpoint ?? null),
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
    endpoint: maskEndpoint(endpoint),
    blockHeight: seedBlockHeightFromLedger(ledger),
    tipHash: tipHash(ledger),
    revision: store.revision,
    networkGenesisRevision: store.getGenesisRevision(),
    ledgerReady: store.hasLedger(),
    peerOnlineTimeoutSeconds: peerOnlineTimeoutSeconds(),
    peers: {
      total: peerRows.length,
      online: onlineCount,
      offline: peerRows.length - onlineCount,
    },
    networkHeight: Math.max(height, maxPeerHeight),
    peerList: peerRows,
    blockchainLaunched: ledger?.blockchainLaunched ?? false,
    treasuryEmission: buildPublicTreasuryEmission(ledger),
    walletBlockChart: buildWalletBlockChart({
      peers,
      ledgers,
      store,
      seedUsername,
      chainId,
      now,
    }),
    updatedAt: new Date(now).toISOString(),
  };
}