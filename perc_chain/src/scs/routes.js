/**
 * Flokkinet / Render internet-node hooks for social cohesion scoring.
 * Mounted from internet_node.js — same Chronoflux engine as primeminster.
 */

import path from 'path';
import { fileURLToPath } from 'url';
import { scoreSocialCohesion } from './scs_engine.js';
import {
  grokConstrue,
  applyConstrual,
  heuristicConstrue,
  shouldUseLiveGrok,
  isGrokConfigured,
} from './construe.js';
import { burnhamScenario } from './scenario_burnham.js';
import { toBurnhamMarkdown } from './report.js';
import { HistoryStore } from './history_store.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DATA_DIR = process.env.SCS_DATA_DIR || process.env.PERC_DATA_DIR || path.join(__dirname, '..', '..', 'data');
const history = new HistoryStore(path.join(DATA_DIR, 'scs_history.json'));

const seed = scoreSocialCohesion(burnhamScenario());
seed.construeProvenance = 'seed';
history.push(seed);

async function runScore(body = {}, { construe = false } = {}) {
  let input = {
    ...burnhamScenario(),
    ...body,
    vortexText: body.vortexText ?? body.v ?? body.omega,
    shearText: body.shearText ?? body.s ?? body.sigma,
    resistanceText: body.resistanceText ?? body.r ?? body.itau,
    flowText: body.flowText ?? body.f ?? body.jmu,
    posedQuestion: body.posedQuestion ?? body.scenarioQuery,
  };
  for (const k of Object.keys(input)) {
    if (input[k] === undefined) delete input[k];
  }
  input = { ...burnhamScenario(), ...input };

  let provenance = null;
  let construeMeta = null;
  if (construe || body.construe) {
    const useLive = shouldUseLiveGrok(body);
    const c = useLive
      ? await grokConstrue(input)
      : { ...heuristicConstrue(input), provenance: 'grok-heuristic', grokConfigured: isGrokConfigured() };
    input = applyConstrual(input, c);
    provenance = c.provenance;
    construeMeta = {
      provenance: c.provenance,
      grokConfigured: Boolean(c.grokConfigured ?? isGrokConfigured()),
      filledFields: c.filledFields || [],
      discourseNote: c.discourseNote || null,
      grokError: c.grokError || null,
      model: c.model || null,
      liveAttempted: useLive,
    };
  }

  const result = scoreSocialCohesion(input);
  result.construeProvenance = provenance;
  result.construe = construeMeta;
  result.grokConfigured = isGrokConfigured();
  result.markdown = toBurnhamMarkdown(result);
  history.push(result);
  return result;
}

/**
 * @param {import('http').IncomingMessage} req
 * @param {import('http').ServerResponse} res
 * @param {URL} url
 * @param {{ json: Function, readBody: Function, servePublic: Function }} helpers
 * @returns {Promise<boolean>} true if handled
 */
export async function handleScsRoutes(req, res, url, helpers) {
  const { json, readBody, servePublic } = helpers;

  if (req.method === 'GET' && (url.pathname === '/burnham' || url.pathname === '/burnham/')) {
    if (servePublic('burnham/index.html', res)) return true;
    return false;
  }

  if (req.method === 'GET' && url.pathname.startsWith('/burnham/')) {
    const rel = url.pathname.slice(1);
    if (servePublic(rel, res)) return true;
  }

  if (req.method === 'GET' && url.pathname === '/scs/latest') {
    const snap = history.snapshot();
    json(res, 200, { ok: true, latest: snap.latest, history: snap.history, count: snap.count });
    return true;
  }

  if (req.method === 'GET' && url.pathname === '/scs/report') {
    const latest = history.latest || scoreSocialCohesion(burnhamScenario());
    const md = latest.markdown || toBurnhamMarkdown(latest);
    res.writeHead(200, {
      'Content-Type': 'text/markdown; charset=utf-8',
      'Access-Control-Allow-Origin': '*',
    });
    res.end(md);
    return true;
  }

  if (req.method === 'GET' && url.pathname === '/scs/scenario') {
    json(res, 200, { ok: true, scenario: burnhamScenario() });
    return true;
  }

  if (req.method === 'GET' && url.pathname === '/scs/health') {
    json(res, 200, {
      ok: true,
      service: 'flokkinet-scs',
      node: 'perc-internet-node',
      render: process.env.RENDER_EXTERNAL_URL || null,
      grokConfigured: isGrokConfigured(),
    });
    return true;
  }

  if (req.method === 'GET' && url.pathname === '/scs/grok-status') {
    json(res, 200, {
      ok: true,
      grokConfigured: isGrokConfigured(),
      model: process.env.XAI_MODEL || 'grok-3-mini',
      hint: isGrokConfigured()
        ? 'XAI_API_KEY present — construe uses live Grok when requested'
        : 'Set XAI_API_KEY on the host (Render env) for live Grok; heuristic runs until then',
    });
    return true;
  }

  if (req.method === 'POST' && url.pathname === '/scs/score') {
    const body = await readBody(req);
    try {
      const result = await runScore(body, { construe: Boolean(body.construe) });
      json(res, 200, result);
    } catch (e) {
      json(res, 500, { ok: false, error: e.message });
    }
    return true;
  }

  if (req.method === 'POST' && url.pathname === '/scs/construe') {
    const body = await readBody(req);
    const input = {
      ...burnhamScenario(),
      ...body,
      vortexText: body.vortexText ?? body.v,
      shearText: body.shearText ?? body.s,
      resistanceText: body.resistanceText ?? body.r,
      flowText: body.flowText ?? body.f,
    };
    try {
      const useLive = shouldUseLiveGrok(body);
      const c = useLive
        ? await grokConstrue(input)
        : { ...heuristicConstrue(input), provenance: 'grok-heuristic', grokConfigured: isGrokConfigured() };
      json(res, 200, {
        ok: true,
        ...c,
        liveAttempted: useLive,
        grokConfigured: isGrokConfigured(),
      });
    } catch (e) {
      json(res, 500, { ok: false, error: e.message });
    }
    return true;
  }

  if (req.method === 'POST' && url.pathname === '/scs/cycle') {
    const body = await readBody(req);
    try {
      const result = await runScore(
        { ...body, construe: true, liveGrok: body.liveGrok !== false },
        { construe: true },
      );
      json(res, 200, { ok: true, result, historyCount: history.history.length });
    } catch (e) {
      json(res, 500, { ok: false, error: e.message });
    }
    return true;
  }

  return false;
}

export { history, runScore, scoreSocialCohesion, burnhamScenario };
