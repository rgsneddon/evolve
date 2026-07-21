/**
 * Pure JSON → view-model helpers for the Evolve Chronoflux real-time stats UI.
 *
 * Consumes the same seed/public API shapes as v4.1.8:
 *   GET /health, GET /perc/status, GET /api/network, GET /api/blocks
 *
 * No network I/O — unit-testable with representative payloads.
 */

export const CHAIN_ID = 'evolve-chronoflux-principia-chain-1';
export const DEFAULT_SEED_BASE = 'https://evolve-perc-internet.onrender.com';
export const REFRESH_INTERVAL_SEC = 30;

/** Contract paths relative to a seed base URL (no trailing slash). */
export const API_PATHS = Object.freeze({
  health: '/health',
  status: '/perc/status',
  network: '/api/network',
  blocks: '/api/blocks',
});

/**
 * Resolve absolute API URLs for a seed base.
 * Empty / relative base keeps same-origin relative paths (seed-hosted explorer).
 */
export function apiUrls(seedBase = '') {
  const base = String(seedBase || '').replace(/\/$/, '');
  const join = (p) => (base ? `${base}${p}` : p);
  return {
    health: join(API_PATHS.health),
    status: join(API_PATHS.status),
    network: join(API_PATHS.network),
    blocks: join(`${API_PATHS.blocks}?limit=40`),
  };
}

function num(v, fallback = 0) {
  const n = Number(v);
  return Number.isFinite(n) ? n : fallback;
}

/**
 * Map `/api/network` snapshot → primary stats cards model.
 */
export function mapNetworkToStats(network = {}) {
  const peers = network.peers && typeof network.peers === 'object' ? network.peers : {};
  return {
    nodeOnline: network.nodeStatus === 'online' || network.ok === true,
    seedHeight: num(network.blockHeight),
    networkHeight: num(network.networkHeight, num(network.blockHeight)),
    peersOnline: num(peers.online ?? network.peersOnline),
    peersTotal: num(peers.total ?? network.peers),
    ledgerReady: Boolean(network.ledgerReady),
    chainId: String(network.chainId || CHAIN_ID),
    endpoint: String(network.endpoint || ''),
    tipHash: network.tipHash ? String(network.tipHash) : '',
    service: network.service ? String(network.service) : 'perc-internet-node',
    source: 'network',
  };
}

/**
 * Map `/health` → partial stats (seed-aligned heights / peers).
 */
export function mapHealthToStats(health = {}) {
  return {
    nodeOnline: health.ok === true,
    seedHeight: num(health.blockHeight),
    networkHeight: num(health.networkHeight, num(health.blockHeight)),
    peersOnline: num(health.peersOnline),
    peersTotal: num(health.peers),
    ledgerReady: Boolean(health.ledgerReady),
    chainId: CHAIN_ID,
    endpoint: String(health.endpoint || ''),
    tipHash: health.tipHash ? String(health.tipHash) : '',
    service: health.service ? String(health.service) : '',
    source: 'health',
  };
}

/**
 * Map `/perc/status` → partial stats (chain id + tip height).
 */
export function mapStatusToStats(status = {}) {
  return {
    nodeOnline: true,
    seedHeight: num(status.blockHeight),
    networkHeight: num(status.blockHeight),
    peersOnline: 0,
    peersTotal: 0,
    ledgerReady: true,
    chainId: String(status.evolutionaryChainId || status.chainId || CHAIN_ID),
    endpoint: String(status.endpoint || ''),
    tipHash: status.tipHash ? String(status.tipHash) : '',
    service: '',
    source: 'status',
  };
}

/**
 * Prefer `/api/network` when present; fill gaps from health + perc/status.
 */
export function mergeLiveSources({ health = null, status = null, network = null } = {}) {
  const fromNet = network ? mapNetworkToStats(network) : null;
  const fromHealth = health ? mapHealthToStats(health) : null;
  const fromStatus = status ? mapStatusToStats(status) : null;

  if (!fromNet && !fromHealth && !fromStatus) {
    return {
      nodeOnline: false,
      seedHeight: 0,
      networkHeight: 0,
      peersOnline: 0,
      peersTotal: 0,
      ledgerReady: false,
      chainId: CHAIN_ID,
      endpoint: '',
      tipHash: '',
      service: '',
      source: 'none',
    };
  }

  const base = fromNet || fromHealth || fromStatus;
  return {
    nodeOnline: fromNet
      ? fromNet.nodeOnline
      : Boolean(fromHealth?.nodeOnline || fromStatus),
    seedHeight: fromNet?.seedHeight ?? fromHealth?.seedHeight ?? fromStatus?.seedHeight ?? 0,
    networkHeight:
      fromNet?.networkHeight ?? fromHealth?.networkHeight ?? fromStatus?.networkHeight ?? 0,
    peersOnline: fromNet?.peersOnline ?? fromHealth?.peersOnline ?? 0,
    peersTotal: fromNet?.peersTotal ?? fromHealth?.peersTotal ?? 0,
    ledgerReady: fromNet?.ledgerReady ?? fromHealth?.ledgerReady ?? Boolean(fromStatus),
    chainId: fromStatus?.chainId || fromNet?.chainId || fromHealth?.chainId || CHAIN_ID,
    endpoint: fromNet?.endpoint || fromStatus?.endpoint || fromHealth?.endpoint || '',
    tipHash: fromNet?.tipHash || fromStatus?.tipHash || fromHealth?.tipHash || '',
    service: fromNet?.service || fromHealth?.service || '',
    source: [fromNet && 'network', fromHealth && 'health', fromStatus && 'status']
      .filter(Boolean)
      .join('+'),
  };
}

/**
 * Map `/api/blocks` list payload → table rows.
 */
export function mapBlocksToRows(payload = {}) {
  const blocks = Array.isArray(payload.blocks) ? payload.blocks : [];
  return {
    total: num(payload.total, blocks.length),
    offset: num(payload.offset),
    limit: num(payload.limit, blocks.length),
    rows: blocks.map((b) => ({
      index: num(b?.index),
      timestamp: b?.timestamp ? String(b.timestamp) : '',
      txCount: num(b?.txCount),
      treasuryEmitted: b?.treasuryEmitted != null ? String(b.treasuryEmitted) : '0',
      displayLabel: b?.displayLabel ? String(b.displayLabel) : '—',
      hash: b?.hash ? String(b.hash) : '',
    })),
  };
}

/** Presentation: online/offline pill class + label. */
export function onlinePresentation(online) {
  return {
    online: Boolean(online),
    className: online ? 'online' : 'offline',
    label: online ? 'Online' : 'Offline',
  };
}

/** Ledger readiness label. */
export function ledgerPresentation(ready) {
  return ready ? 'Synced' : 'Pending';
}

/**
 * Card descriptors for the primary stats grid (label + display value).
 * Used by both the seed explorer and standalone stats page.
 */
export function statsCardDescriptors(stats) {
  const online = onlinePresentation(stats.nodeOnline);
  return [
    { id: 'node', label: 'Node', value: online.label, online: online.online },
    { id: 'seedHeight', label: 'Seed height', value: String(stats.seedHeight) },
    { id: 'networkHeight', label: 'Network height', value: String(stats.networkHeight) },
    {
      id: 'peers',
      label: 'Peers online',
      value: `${stats.peersOnline} / ${stats.peersTotal}`,
    },
    { id: 'ledger', label: 'Ledger', value: ledgerPresentation(stats.ledgerReady) },
    { id: 'chainId', label: 'Chain', value: stats.chainId, mono: true },
  ];
}

/**
 * Assert chain identity matches the product Chronoflux Principia chain.
 */
export function isProductChainId(chainId) {
  return String(chainId || '') === CHAIN_ID;
}
