/**
 * Unit tests for public Chronoflux stats page mapping helpers.
 * Feeds representative live-API-shaped payloads (health / status / network / blocks).
 */
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import {
  API_PATHS,
  CHAIN_ID,
  DEFAULT_SEED_BASE,
  apiUrls,
  formatPercentChance,
  formatScsScore,
  isProductChainId,
  isTipAdjacentBlockList,
  ledgerPresentation,
  mapBlocksToRows,
  mapHealthToStats,
  mapNetworkToStats,
  mapStatusToStats,
  mapSsucfAnalysisToView,
  mergeLiveSources,
  onlinePresentation,
  statsCardDescriptors,
  ssucfAnalysisCardDescriptors,
} from '../public/stats_page_model.js';
import { listBlocks } from './explorer_api.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const FIXTURE_PATH = path.join(__dirname, '../public/ssucf_analysis.json');

/** Representative /api/network body (field names match live seed). */
const SAMPLE_NETWORK = {
  ok: true,
  service: 'perc-internet-node',
  nodeStatus: 'online',
  chainId: 'evolve-chronoflux-principia-chain-1',
  publicAlias: 'd4q4e',
  endpoint: 'https://evolve-perc-internet.onrender.com',
  blockHeight: 96,
  tipHash: 'bacc545bf2932bc3e0aa6484221494f095b64eb2aa047610ed2eca6681cb3017',
  revision: 111,
  ledgerReady: true,
  peers: { total: 4, online: 3, offline: 1 },
  networkHeight: 96,
};

/** Representative /health body. */
const SAMPLE_HEALTH = {
  ok: true,
  service: 'perc-internet-node',
  explorer: 'https://evolve-perc-internet.onrender.com/',
  endpoint: 'https://evolve-perc-internet.onrender.com',
  blockHeight: 96,
  networkHeight: 96,
  tipHash: 'bacc545bf2932bc3e0aa6484221494f095b64eb2aa047610ed2eca6681cb3017',
  peers: 4,
  peersOnline: 3,
  ledgerReady: true,
};

/** Representative /perc/status body. */
const SAMPLE_STATUS = {
  evolutionaryChainId: 'evolve-chronoflux-principia-chain-1',
  blockHeight: 96,
  tipHash: 'bacc545bf2932bc3e0aa6484221494f095b64eb2aa047610ed2eca6681cb3017',
  revision: 111,
  endpoint: 'https://evolve-perc-internet.onrender.com',
  publicAlias: 'd4q4e',
};

const SAMPLE_BLOCKS = {
  total: 96,
  offset: 0,
  limit: 3,
  blocks: [
    {
      index: 2,
      timestamp: '2026-07-04T20:59:08.812133Z',
      txCount: 3,
      treasuryEmitted: '6582',
      displayLabel: 'SCS input',
      hash: '9ec69f90',
    },
    {
      index: 1,
      timestamp: '2026-07-04T19:09:26.585856Z',
      txCount: 2,
      treasuryEmitted: '16692',
      displayLabel: '% chance input',
      hash: '5420ad5b',
    },
  ],
};

describe('stats_page_model API contract', () => {
  it('exposes live seed paths used by v4.1.8 explorer', () => {
    assert.equal(API_PATHS.health, '/health');
    assert.equal(API_PATHS.status, '/perc/status');
    assert.equal(API_PATHS.network, '/api/network');
    assert.equal(API_PATHS.blocks, '/api/blocks');
    assert.equal(CHAIN_ID, 'evolve-chronoflux-principia-chain-1');
    assert.ok(DEFAULT_SEED_BASE.includes('evolve-perc-internet'));
  });

  it('builds absolute and same-origin API URLs', () => {
    const abs = apiUrls(DEFAULT_SEED_BASE);
    assert.equal(abs.health, `${DEFAULT_SEED_BASE}/health`);
    assert.equal(abs.status, `${DEFAULT_SEED_BASE}/perc/status`);
    assert.equal(abs.network, `${DEFAULT_SEED_BASE}/api/network`);
    assert.ok(abs.blocks.startsWith(`${DEFAULT_SEED_BASE}/api/blocks`));

    const rel = apiUrls('');
    assert.equal(rel.health, '/health');
    assert.equal(rel.network, '/api/network');
  });
});

describe('mapNetworkToStats', () => {
  it('maps heights, peers, online state, ledger, chain id from /api/network', () => {
    const s = mapNetworkToStats(SAMPLE_NETWORK);
    assert.equal(s.nodeOnline, true);
    assert.equal(s.seedHeight, 96);
    assert.equal(s.networkHeight, 96);
    assert.equal(s.peersOnline, 3);
    assert.equal(s.peersTotal, 4);
    assert.equal(s.ledgerReady, true);
    assert.equal(s.chainId, CHAIN_ID);
    assert.ok(isProductChainId(s.chainId));
    assert.equal(s.endpoint, SAMPLE_NETWORK.endpoint);
  });

  it('treats offline nodeStatus as offline', () => {
    const s = mapNetworkToStats({ ...SAMPLE_NETWORK, nodeStatus: 'offline', ok: false });
    assert.equal(s.nodeOnline, false);
    assert.equal(onlinePresentation(s.nodeOnline).label, 'Offline');
    assert.equal(onlinePresentation(s.nodeOnline).className, 'offline');
  });
});

describe('mapHealthToStats + mapStatusToStats', () => {
  it('maps /health peer counters and heights', () => {
    const s = mapHealthToStats(SAMPLE_HEALTH);
    assert.equal(s.nodeOnline, true);
    assert.equal(s.seedHeight, 96);
    assert.equal(s.networkHeight, 96);
    assert.equal(s.peersOnline, 3);
    assert.equal(s.peersTotal, 4);
    assert.equal(s.ledgerReady, true);
  });

  it('maps /perc/status chain id and height', () => {
    const s = mapStatusToStats(SAMPLE_STATUS);
    assert.equal(s.chainId, CHAIN_ID);
    assert.equal(s.seedHeight, 96);
    assert.ok(isProductChainId(s.chainId));
  });
});

describe('mergeLiveSources', () => {
  it('prefers network snapshot and fills chain id from status', () => {
    const merged = mergeLiveSources({
      health: SAMPLE_HEALTH,
      status: SAMPLE_STATUS,
      network: SAMPLE_NETWORK,
    });
    assert.equal(merged.seedHeight, 96);
    assert.equal(merged.networkHeight, 96);
    assert.equal(merged.peersOnline, 3);
    assert.equal(merged.peersTotal, 4);
    assert.equal(merged.nodeOnline, true);
    assert.equal(merged.ledgerReady, true);
    assert.equal(merged.chainId, CHAIN_ID);
    assert.match(merged.source, /network/);
  });

  it('falls back to health when network is missing', () => {
    const merged = mergeLiveSources({ health: SAMPLE_HEALTH, status: SAMPLE_STATUS });
    assert.equal(merged.seedHeight, 96);
    assert.equal(merged.peersOnline, 3);
    assert.equal(merged.peersTotal, 4);
    assert.equal(merged.chainId, CHAIN_ID);
    assert.equal(merged.nodeOnline, true);
  });
});

describe('mapBlocksToRows', () => {
  it('maps recent blocks list for the explorer table', () => {
    const { total, rows } = mapBlocksToRows(SAMPLE_BLOCKS);
    assert.equal(total, 96);
    assert.equal(rows.length, 2);
    assert.equal(rows[0].index, 2);
    assert.equal(rows[0].txCount, 3);
    assert.equal(rows[0].displayLabel, 'SCS input');
    assert.equal(rows[1].index, 1);
    assert.equal(rows[1].displayLabel, '% chance input');
  });
});

describe('listBlocks tip-adjacent recent window', () => {
  it('offset=0 limit=N returns newest N indices near tip, not genesis', () => {
    const blocks = Array.from({ length: 96 }, (_, i) => ({
      index: i,
      timestamp: `2026-07-01T00:00:${String(i).padStart(2, '0')}.000Z`,
      transactions: [],
      treasuryEmitted: { microUnits: 0 },
    }));
    const ledger = { blocks };
    const listing = listBlocks(ledger, { offset: 0, limit: 40 });
    assert.equal(listing.total, 96);
    assert.equal(listing.blocks.length, 40);
    const indices = listing.blocks.map((b) => b.index);
    assert.equal(indices[0], 95, 'first row must be tip index');
    assert.equal(indices[indices.length - 1], 56, 'window ends 40 below tip');
    assert.ok(
      isTipAdjacentBlockList(listing.blocks, { tipHeight: 96, limit: 40 }),
      'max row index must be near tip height',
    );
    // Must not be the old bug (oldest window max index 39)
    assert.ok(Math.max(...indices) > 39);
  });

  it('mapBlocksToRows + isTipAdjacentBlockList accept tip-window payload', () => {
    const tipPayload = {
      total: 96,
      offset: 0,
      limit: 5,
      blocks: [95, 94, 93, 92, 91].map((index) => ({
        index,
        timestamp: '2026-07-04T00:00:00.000Z',
        txCount: 1,
        treasuryEmitted: '0',
        displayLabel: 'test',
      })),
    };
    const { rows } = mapBlocksToRows(tipPayload);
    assert.ok(isTipAdjacentBlockList(rows, { tipHeight: 96, limit: 5 }));
    assert.equal(Math.max(...rows.map((r) => r.index)), 95);
  });
});

describe('presentation helpers', () => {
  it('builds card descriptors with heights peers chain id', () => {
    const stats = mapNetworkToStats(SAMPLE_NETWORK);
    const cards = statsCardDescriptors(stats);
    const byId = Object.fromEntries(cards.map((c) => [c.id, c]));
    assert.equal(byId.node.value, 'Online');
    assert.equal(byId.seedHeight.value, '96');
    assert.equal(byId.networkHeight.value, '96');
    assert.equal(byId.peers.value, '3 / 4');
    assert.equal(byId.ledger.value, ledgerPresentation(true));
    assert.equal(byId.chainId.value, CHAIN_ID);
  });

  it('shows Pending ledger when not ready', () => {
    assert.equal(ledgerPresentation(false), 'Pending');
    const cards = statsCardDescriptors(mapNetworkToStats({ ...SAMPLE_NETWORK, ledgerReady: false }));
    assert.equal(cards.find((c) => c.id === 'ledger').value, 'Pending');
  });
});

/** Objective-shaped SSUCF: Andy Burnham GE 2029 analysis. */
const BURNHAM_SSUCF = {
  topic: 'What is the percent chance of Andy Burnham winning the general election in 2029?',
  refinedScs: 59,
  weightedScs: 61.7,
  baselineScs: 48,
  percentChance: 44,
  calibratedPercentChance: 44,
  regressivePct: 64,
  progressivePct: 36,
  lean: 'REGRESSIVE',
  partTwo: { refinedScs: 59, regressivePct: 64, progressivePct: 36 },
  forecast: { percentChance: 44, calibratedPercent: 44 },
};

describe('mapSsucfAnalysisToView (variable SCS + % chance)', () => {
  it('maps Burnham 2029 objective-shaped refined SCS and calibrated % chance', () => {
    const view = mapSsucfAnalysisToView(BURNHAM_SSUCF);
    assert.equal(view.refinedScs, 59);
    assert.equal(view.weightedScs, 61.7);
    assert.equal(view.percentChance, 44);
    assert.equal(view.regressivePct, 64);
    assert.equal(view.progressivePct, 36);
    assert.equal(view.lean, 'REGRESSIVE');
    assert.equal(view.displayRefinedScs, formatScsScore(59));
    assert.equal(view.displayPercentChance, formatPercentChance(44));
    assert.equal(view.displayRefinedScs, '~59/100');
    assert.equal(view.displayPercentChance, '44%');
    assert.equal(view.displayContinuum, '~64% / ~36%');
    assert.equal(view.displayWeightedScs, '~61.7/100');
    // Headline % must not equal raw regressive continuum share
    assert.notEqual(Math.round(view.percentChance), Math.round(view.regressivePct));
    assert.match(view.topic, /Andy Burnham/i);
  });

  it('reads nested partTwo / forecast shapes without flat fields', () => {
    const view = mapSsucfAnalysisToView({
      topic: 'nested only',
      partTwo: { refinedScs: 59, regressivePct: 64, progressivePct: 36, lean: 'REGRESSIVE' },
      forecast: { percentChance: 44 },
      conclusion: { weightedScs: 61.7 },
    });
    assert.equal(view.refinedScs, 59);
    assert.equal(view.percentChance, 44);
    assert.equal(view.weightedScs, 61.7);
    assert.equal(view.displayPercentChance, '44%');
  });

  it('builds analysis card descriptors with SCS and % chance ids', () => {
    const view = mapSsucfAnalysisToView(BURNHAM_SSUCF);
    const cards = ssucfAnalysisCardDescriptors(view);
    const byId = Object.fromEntries(cards.map((c) => [c.id, c]));
    assert.equal(byId.refinedScs.value, '~59/100');
    assert.equal(byId.percentChance.value, '44%');
    assert.equal(byId.continuum.value, '~64% / ~36%');
    assert.equal(byId.weightedScs.value, '~61.7/100');
    assert.equal(byId.lean.value, 'REGRESSIVE');
    assert.equal(byId.percentChance.numeric, 44);
    assert.equal(byId.refinedScs.numeric, 59);
  });

  it('maps shipped ssucf_analysis.json fixture (real file path)', () => {
    const raw = JSON.parse(readFileSync(FIXTURE_PATH, 'utf8'));
    const view = mapSsucfAnalysisToView(raw);
    assert.equal(view.refinedScs, 59);
    assert.equal(view.percentChance, 44);
    assert.equal(view.regressivePct, 64);
    assert.equal(view.progressivePct, 36);
    assert.ok(view.hasAnalysis);
    assert.equal(API_PATHS.ssucfAnalysis, '/ssucf_analysis.json');
    assert.ok(apiUrls(DEFAULT_SEED_BASE).ssucfAnalysis.endsWith('/ssucf_analysis.json'));
  });

  it('updates displayed values when input payload changes (variable path)', () => {
    const a = mapSsucfAnalysisToView({ refinedScs: 59, percentChance: 44, regressivePct: 64, progressivePct: 36 });
    const b = mapSsucfAnalysisToView({ refinedScs: 72, percentChance: 51, regressivePct: 40, progressivePct: 60 });
    assert.equal(a.displayRefinedScs, '~59/100');
    assert.equal(b.displayRefinedScs, '~72/100');
    assert.equal(a.displayPercentChance, '44%');
    assert.equal(b.displayPercentChance, '51%');
    assert.notEqual(a.displayRefinedScs, b.displayRefinedScs);
  });
});
