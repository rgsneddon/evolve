/**
 * Browser copy of src/view_model.js — keep in sync (same API).
 * Moving score tween + per-conclusion diagram series.
 */

function round1(n) {
  return Math.round(Number(n) * 10) / 10;
}

function easeInOut(t) {
  const x = Math.min(1, Math.max(0, t));
  return x < 0.5 ? 2 * x * x : 1 - Math.pow(-2 * x + 2, 2) / 2;
}

export function interpolateScore(from, to, t) {
  const a = Number(from) || 0;
  const b = Number(to) || 0;
  return a + (b - a) * easeInOut(t);
}

export function tweenSteps(from, to, steps = 12) {
  const n = Math.max(2, Math.floor(steps));
  const out = [];
  for (let i = 0; i <= n; i++) {
    out.push(round1(interpolateScore(from, to, i / n)));
  }
  return out;
}

export function partOneDiagram(result) {
  const p1 = result?.partOne || {};
  const c = result?.constructs || {};
  return {
    part: 'one',
    title: 'Part One: Baseline Parameter Mapping',
    labels: ['ω Vortex', 'σ Shear', 'Iτ Resistance', 'Jμ Flow', 'Baseline SCS', 'Weighted SCS'],
    values: [
      num(c.omega ?? c.vortex),
      num(c.sigma ?? c.shear),
      num(c.itau ?? c.resistance),
      num(c.jmu ?? c.flow),
      num(p1.baselineScs ?? result?.baselineScs),
      num(p1.weightedOverallScs ?? result?.overallScs),
    ],
    colors: ['#7c6cff', '#ff6b9d', '#f59e0b', '#00d4aa', '#4b5568', '#6c63ff'],
  };
}

export function partTwoDiagram(result) {
  const p2 = result?.partTwo || {};
  const reg = num(p2.regressivePct ?? result?.regressivePct);
  const prog = num(p2.progressivePct ?? result?.progressivePct);
  const refined = num(p2.refinedScs ?? result?.refinedScs);
  return {
    part: 'two',
    title: 'Part Two: Broader Political Continuum Integration',
    labels: ['Regressive %', 'Progressive %', 'Refined SCS'],
    values: [reg, prog, refined],
    colors: ['#f59e0b', '#00d4aa', '#6c63ff'],
    split: { regressive: reg, progressive: prog },
  };
}

export function partThreeDiagram(result) {
  const p3 = result?.partThree || {};
  const without = num(p3.withoutLeversScs ?? result?.refinedScs);
  const min = num(p3.withLeversMin ?? without);
  const max = num(p3.withLeversMax ?? min);
  return {
    part: 'three',
    title: 'Part Three: Actionable Levers',
    labels: ['Without levers', 'Levers min', 'Levers max'],
    values: [without, min, max],
    colors: ['#4b5568', '#00d4aa', '#34d399'],
  };
}

export function conclusionDiagrams(result) {
  return {
    partOne: partOneDiagram(result),
    partTwo: partTwoDiagram(result),
    partThree: partThreeDiagram(result),
  };
}

function num(v) {
  const n = Number(v);
  return Number.isFinite(n) ? n : 0;
}

export function loadingPresentation(currentlyVisible, event) {
  switch (event) {
    case 'start':
      return { visible: true, label: 'LOADING…', reason: 'fetch-start' };
    case 'success':
      return { visible: false, label: 'LOADING…', reason: 'fetch-success' };
    case 'error':
      return { visible: false, label: 'LOADING…', reason: 'fetch-error' };
    case 'idle':
    default:
      return {
        visible: Boolean(currentlyVisible),
        label: 'LOADING…',
        reason: 'idle',
      };
  }
}

export function initialLoadingState() {
  return loadingPresentation(false, 'start');
}

export function chartConfig() {
  return {
    engine: 'svg-bars',
    maxSurfaces: 4,
    animations: false,
    cdn: false,
    historyCap: 12,
    fetchTimeoutMs: 15000,
  };
}

export function buildBarChartSvg(labels, values, colors = [], opts = {}) {
  const max = opts.max ?? 100;
  const width = opts.width ?? 420;
  const rowH = opts.rowH ?? 26;
  const left = 110;
  const barW = width - left - 48;
  const n = Math.min(labels.length, values.length);
  const height = Math.max(rowH * n + 8, 40);
  let rows = '';
  for (let i = 0; i < n; i++) {
    const v = Math.max(0, Math.min(max, Number(values[i]) || 0));
    const w = (v / max) * barW;
    const y = 8 + i * rowH;
    const fill = colors[i] || '#6c63ff';
    const lab = String(labels[i] ?? '').replace(/[<>&]/g, (c) =>
      ({ '<': '&lt;', '>': '&gt;', '&': '&amp;' }[c]),
    );
    rows += `<text x="0" y="${y + 14}" fill="#9aa3b8" font-size="11">${lab}</text>`;
    rows += `<rect x="${left}" y="${y}" width="${barW}" height="16" rx="3" fill="#1e2436"/>`;
    rows += `<rect x="${left}" y="${y}" width="${Math.max(2, w)}" height="16" rx="3" fill="${fill}"/>`;
    rows += `<text x="${left + barW + 6}" y="${y + 13}" fill="#e8ecf4" font-size="11">${round1(v)}</text>`;
  }
  return `<svg class="light-chart" data-chart-engine="svg-bars" viewBox="0 0 ${width} ${height}" width="100%" height="${height}" role="img" aria-label="bar chart">${rows}</svg>`;
}

export function capHistory(history, cap = 12) {
  const arr = Array.isArray(history) ? history : [];
  if (arr.length <= cap) return arr.slice();
  return arr.slice(arr.length - cap);
}

export { round1, easeInOut };
