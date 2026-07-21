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

export { round1, easeInOut };
