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
  /** Variable SSUCF / Chronoflux analysis snapshot (refined SCS + % chance). */
  ssucfAnalysis: '/ssucf_analysis.json',
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
    // Seed listBlocks pages from the tip (offset=0 = newest `limit` blocks).
    blocks: join(`${API_PATHS.blocks}?limit=40&offset=0`),
    ssucfAnalysis: join(API_PATHS.ssucfAnalysis),
  };
}

/**
 * Assert a recent-blocks listing is tip-adjacent for a known chain height.
 * Used by unit tests and live probes (max row index near tip, min in window).
 */
export function isTipAdjacentBlockList(rows, { tipHeight, limit = 40 } = {}) {
  const tip = Number(tipHeight);
  const lim = Math.max(1, Number(limit) || 40);
  if (!Number.isFinite(tip) || tip < 0) return false;
  const indices = (rows ?? []).map((r) => Number(r?.index)).filter((n) => Number.isFinite(n));
  if (!indices.length) return tip === 0;
  const maxIdx = Math.max(...indices);
  const minIdx = Math.min(...indices);
  // Tip block index is tipHeight-1 when height counts blocks; or tipHeight when
  // height is last index+1. Accept either: max must be within 1 of tip.
  const nearTip = maxIdx >= tip - 1 && maxIdx <= tip;
  const windowOk = maxIdx - minIdx + 1 <= lim + 1;
  const newestFirst = indices.length < 2 || indices[0] >= indices[indices.length - 1];
  return nearTip && windowOk && newestFirst;
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

function pickNum(...candidates) {
  for (const c of candidates) {
    if (c == null || c === '') continue;
    const n = Number(c);
    if (Number.isFinite(n)) return n;
  }
  return NaN;
}

/**
 * Format refined/weighted SCS as Chronoflux display (~NN/100).
 */
export function formatScsScore(score) {
  const n = Number(score);
  if (!Number.isFinite(n)) return '—';
  const rounded = Math.abs(n - Math.round(n)) < 0.05 ? Math.round(n) : Math.round(n * 10) / 10;
  return `~${rounded}/100`;
}

/**
 * Format calibrated percent-chance headline (not continuum regressive share).
 */
export function formatPercentChance(pct) {
  const n = Number(pct);
  if (!Number.isFinite(n)) return '—';
  return `${Math.round(n)}%`;
}

/**
 * Format THE CONTINUUM regressive / progressive split.
 */
export function formatContinuumSplit(regressivePct, progressivePct) {
  const r = Number(regressivePct);
  const p = Number(progressivePct);
  if (!Number.isFinite(r) || !Number.isFinite(p)) return '—';
  return `~${Math.round(r)}% / ~${Math.round(p)}%`;
}

/**
 * Map SSUCF / Chronoflux analysis-shaped JSON → view model for variable SCS + % chance.
 *
 * Accepts flat fields or nested partTwo / forecast / continuum shapes used by
 * Evolve Chronoflux cohesion reports. Headline % chance is the *calibrated*
 * percentChance (app display rule) — never the raw regressive continuum share.
 *
 * @param {object} input
 * @returns {object} view model with numeric fields + display strings
 */
export function mapSsucfAnalysisToView(input = {}) {
  const src = input && typeof input === 'object' ? input : {};
  const partTwo = src.partTwo && typeof src.partTwo === 'object' ? src.partTwo : {};
  const forecast = src.forecast && typeof src.forecast === 'object' ? src.forecast : {};
  const continuum = src.continuum && typeof src.continuum === 'object' ? src.continuum : {};
  const conclusion = src.conclusion && typeof src.conclusion === 'object' ? src.conclusion : {};
  const core = src.core && typeof src.core === 'object' ? src.core : {};

  const refinedScs = pickNum(
    src.refinedScs,
    src.refinedCohesionScore,
    partTwo.refinedScs,
    src.socialCohesionOutcome?.refinedScs,
  );
  const weightedScs = pickNum(
    src.weightedScs,
    src.weightedOverallScs,
    conclusion.weightedScs,
    partTwo.weightedScs,
    refinedScs,
  );
  const baselineScs = pickNum(src.baselineScs, src.baselineCohesionScore, partTwo.baselineScs);

  // Calibrated headline % chance (must not default to regressive continuum %)
  const percentChance = pickNum(
    src.percentChance,
    src.calibratedPercentChance,
    src.headlinePercentChance,
    forecast.percentChance,
    forecast.calibratedPercent,
    forecast.heuristicPercent,
  );

  let regressivePct = pickNum(
    src.regressivePct,
    partTwo.regressivePct,
    continuum.regressivePct,
    core.regressivePct,
    src.continuumRegressivePct,
  );
  let progressivePct = pickNum(
    src.progressivePct,
    partTwo.progressivePct,
    continuum.progressivePct,
    core.progressivePct,
    src.continuumProgressivePct,
  );
  if (!Number.isFinite(progressivePct) && Number.isFinite(regressivePct)) {
    progressivePct = Math.max(0, 100 - regressivePct);
  }
  if (!Number.isFinite(regressivePct) && Number.isFinite(progressivePct)) {
    regressivePct = Math.max(0, 100 - progressivePct);
  }

  const leanRaw = String(
    src.lean || partTwo.lean || continuum.lean || core.lean || '',
  ).toUpperCase();
  let lean = leanRaw.includes('PROG')
    ? 'PROGRESSIVE'
    : leanRaw.includes('REG')
      ? 'REGRESSIVE'
      : '';
  if (!lean && Number.isFinite(regressivePct) && Number.isFinite(progressivePct)) {
    lean = regressivePct >= progressivePct ? 'REGRESSIVE' : 'PROGRESSIVE';
  }

  const topic = String(
    src.topic || src.posedQuestion || src.question || partTwo.topic || '',
  ).trim();

  const hasAnalysis =
    Number.isFinite(refinedScs) ||
    Number.isFinite(percentChance) ||
    Number.isFinite(weightedScs);

  return {
    topic,
    refinedScs: Number.isFinite(refinedScs) ? refinedScs : null,
    weightedScs: Number.isFinite(weightedScs) ? weightedScs : null,
    baselineScs: Number.isFinite(baselineScs) ? baselineScs : null,
    percentChance: Number.isFinite(percentChance) ? percentChance : null,
    regressivePct: Number.isFinite(regressivePct) ? regressivePct : null,
    progressivePct: Number.isFinite(progressivePct) ? progressivePct : null,
    lean,
    hasAnalysis,
    displayRefinedScs: formatScsScore(refinedScs),
    displayWeightedScs: formatScsScore(weightedScs),
    displayPercentChance: formatPercentChance(percentChance),
    displayContinuum: formatContinuumSplit(regressivePct, progressivePct),
    source: src.source ? String(src.source) : 'ssucf',
  };
}

/**
 * Card descriptors for SSUCF analysis (SCS + % chance + continuum).
 * Distinct ids from network stats cards.
 */
export function ssucfAnalysisCardDescriptors(analysis) {
  const a = analysis && typeof analysis === 'object' ? analysis : mapSsucfAnalysisToView({});
  const leanLabel = a.lean ? a.lean : '—';
  return [
    {
      id: 'refinedScs',
      label: 'Refined SCS',
      value: a.displayRefinedScs,
      numeric: a.refinedScs,
    },
    {
      id: 'percentChance',
      label: '% chance',
      value: a.displayPercentChance,
      numeric: a.percentChance,
    },
    {
      id: 'continuum',
      label: 'Regressive / Progressive',
      value: a.displayContinuum,
      numeric: a.regressivePct,
    },
    {
      id: 'weightedScs',
      label: 'Weighted SCS',
      value: a.displayWeightedScs,
      numeric: a.weightedScs,
    },
    {
      id: 'lean',
      label: 'Continuum lean',
      value: leanLabel,
      numeric: null,
    },
  ];
}

/**
 * Merge network stats with optional SSUCF analysis for combined page refresh.
 * Analysis cards stay separate; this only attaches the view model.
 */
export function attachSsucfAnalysis(networkStats, ssucfInput) {
  const analysis = mapSsucfAnalysisToView(ssucfInput || {});
  return {
    ...(networkStats || {}),
    analysis,
  };
}
