/**
 * Chronoflux SSUCF social cohesion engine — faithful port of EvolveEngine
 * hydrodynamic core + refined continuum integration.
 *
 * Scores from social-discourse-observed construct fields (v/f/s + resistance)
 * and a posed question (SSUCF framing ending in "please").
 */

import { parseQuestionSemantics, fieldFingerprint } from './question_semantics.js';

const NEUTRAL = 50;
const DEFAULT_WEIGHTS = [0.2, 0.2, 0.2, 0.2, 0.2]; // continuum, flow, shear, resistance, vortex

function clamp(n, lo, hi) {
  return Math.min(hi, Math.max(lo, n));
}

function explicitScs(text) {
  const m = String(text || '').match(/scs[:\s=]*(\d{1,3})/i);
  if (!m) return null;
  return clamp(Number(m[1]), 0, 100);
}

function scsFromFieldContext(fieldText, questionOffset, clampMin, clampMax) {
  const t = (fieldText || '').trim();
  if (!t) return clamp(questionOffset, clampMin, clampMax);
  const ex = explicitScs(t);
  if (ex != null) return ex;
  const fp = fieldFingerprint(t);
  const words = t.split(/\s+/).filter(Boolean).length;
  const presence = (Math.min(24, Math.max(4, words)) - 4) * 0.15;
  const variableOffset = questionOffset + fp * 0.35 + presence;
  return clamp(questionOffset * 0.5 + variableOffset * 0.5, clampMin, clampMax);
}

function scsForVortex(fieldText, observed) {
  const ex = explicitScs(fieldText);
  if (ex != null) return ex;
  return clamp(observed, 38, 82);
}

function inferLean(input, sem) {
  const corpus = [
    input.posedQuestion,
    input.topic,
    input.vortexText,
    input.shearText,
    input.resistanceText,
    input.flowText,
    input.continuumText,
  ]
    .join(' ')
    .toLowerCase();
  if (sem.polarity === 'adverse') return 'REGRESSIVE';
  if (sem.polarity === 'favourable') return 'PROGRESSIVE';
  if (/\b(criminality|idiots|conceited|nonsense|done nothing|performative)\b/.test(corpus)) {
    return 'REGRESSIVE';
  }
  if (/\b(trust|cohesion|transparent|accountab|progressive)\b/.test(corpus)) {
    return 'PROGRESSIVE';
  }
  return 'REGRESSIVE';
}

/**
 * Weight construal from scenario context (simplified ChronofluxWeightConstrual).
 */
export function construeWeights(input, lean) {
  const w = [1, 1, 1, 1, 1]; // continuum, flow, shear, resistance, vortex
  if ((input.posedQuestion || '').trim()) w[4] += 2.5;
  if ((input.topic || '').trim()) w[0] += 1.0;
  w[4] += 0.8; // regional
  if ((input.vortexText || '').trim()) w[4] += 0.6;
  if ((input.shearText || '').trim()) w[2] += 0.6;
  if ((input.resistanceText || '').trim()) w[3] += 0.6;
  if ((input.flowText || '').trim()) w[1] += 0.6;

  if (lean === 'REGRESSIVE') {
    w[2] *= 1.38;
    w[3] *= 1.28;
    w[1] *= 0.86;
    w[4] *= 1.08;
  } else if (lean === 'PROGRESSIVE') {
    w[1] *= 1.38;
    w[4] *= 1.22;
    w[2] *= 0.86;
    w[3] *= 0.9;
  }

  const total = w.reduce((a, x) => a + x, 0);
  return w.map((x) => x / total);
}

function enrichConstructs(input) {
  const regionId = input.regionId || 'uk-ireland';
  const query = [input.posedQuestion, input.topic].filter(Boolean).join('\n');
  const sem = parseQuestionSemantics(query, { regionId });

  let vortexObs = sem.vortexOffset;
  if ((input.vortexText || '').trim()) {
    const rel = parseQuestionSemantics(input.vortexText, { regionId });
    vortexObs = vortexObs * 0.5 + rel.vortexOffset * 0.5;
  }

  const vortexScs = scsForVortex(input.vortexText, vortexObs);
  const shearScs = scsFromFieldContext(input.shearText, sem.shearOffset, 42, 78);
  const resistanceScs = scsFromFieldContext(
    input.resistanceText,
    sem.resistanceOffset,
    40,
    74,
  );
  const flowScs = scsFromFieldContext(input.flowText, sem.flowOffset, 32, 68);

  const lean = input.lean || inferLean(input, sem);
  const weights = construeWeights(input, lean);

  const constructs = {
    continuum: { scs: NEUTRAL, weight: weights[0] },
    flow: { scs: flowScs, weight: weights[1] },
    shear: { scs: shearScs, weight: weights[2] },
    resistance: { scs: resistanceScs, weight: weights[3] },
    vortex: { scs: vortexScs, weight: weights[4] },
  };

  // Continuum from weighted constructs if no continuum text
  const ordered = ['continuum', 'flow', 'shear', 'resistance', 'vortex'];
  let contSum = 0;
  for (let i = 0; i < 5; i++) {
    contSum += constructs[ordered[i]].scs * weights[i];
  }
  if ((input.continuumText || '').trim()) {
    constructs.continuum.scs = scsFromFieldContext(
      input.continuumText,
      contSum,
      30,
      80,
    );
  } else {
    constructs.continuum.scs = clamp(contSum, 30, 80);
  }

  return { constructs, sem, lean, weights };
}

function hydrodynamicCore(constructs) {
  const ordered = [
    constructs.continuum,
    constructs.flow,
    constructs.shear,
    constructs.resistance,
    constructs.vortex,
  ];
  const w = ordered.map((c) => c.weight);
  const wSum = w.reduce((a, x) => a + x, 0) || 1;
  const nw = w.map((x) => x / wSum);

  const eff = (i) => clamp(ordered[i].scs * nw[i] * 5, 0, 100);
  const e = {
    continuum: eff(0),
    flow: eff(1),
    shear: eff(2),
    resistance: eff(3),
    vortex: eff(4),
  };

  let weightedScs = 0;
  for (let i = 0; i < 5; i++) weightedScs += ordered[i].scs * nw[i];

  const positive = (e.flow + e.vortex + e.continuum * 0.75) / 2.75;
  const dissipative = (e.shear * 0.62 + e.resistance * 0.78) / 1.4;

  let scs = (positive - dissipative * 0.68) * 1.25;
  const lo = clamp(weightedScs - 14, 22, 62);
  const hi = clamp(weightedScs + 14, 48, 90);
  scs = clamp(scs, lo, hi);

  let progressiveRaw = positive * 0.82 * (1 - dissipative / 155);
  let regressiveRaw = dissipative * 0.95 * (1 + (e.resistance - 55) / 140);
  regressiveRaw = clamp(regressiveRaw, 28, 45);

  const total = progressiveRaw + regressiveRaw;
  const progressivePct = total > 1e-9 ? (progressiveRaw / total) * 100 : 50;
  const regressivePct = total > 1e-9 ? (regressiveRaw / total) * 100 : 50;
  const netMomentum = (progressiveRaw - regressiveRaw) / 100;

  return {
    weightedOverallScs: weightedScs,
    baselineScs: scs,
    positive,
    dissipative,
    progressivePct,
    regressivePct,
    netMomentum,
    lean: netMomentum >= 0 ? 'PROGRESSIVE' : 'REGRESSIVE',
    effective: e,
  };
}

function refinedCore(baseline, constructs, contextLean, hasQuestion) {
  const v = constructs.vortex.scs;
  const f = constructs.flow.scs;
  const s = constructs.shear.scs;
  const r = constructs.resistance.scs;

  const constructive = (v + f) / 2;
  const dissipativeChannel = (s + r) / 2;
  const refinedPositive = (constructive + baseline.positive) / 2;
  const refinedDissipative = (dissipativeChannel * 0.68 + baseline.dissipative) / 1.68;
  const eliteFactor = 1 + (s + r) / 300;
  const mechanicalBaseline = (v + s + r + f) / 4;

  let refinedScs =
    (refinedPositive - refinedDissipative * 0.68) * 1.25 * eliteFactor;
  refinedScs = clamp(refinedScs, mechanicalBaseline * 0.85, mechanicalBaseline * 1.15);

  if (hasQuestion) {
    refinedScs = clamp(refinedScs * 0.55 + v * 0.45, 20, 87);
  } else {
    refinedScs = clamp(refinedScs, 20, 87);
  }

  let progRaw = refinedPositive * 0.82 * (1 - refinedDissipative / 155);
  let regRaw = refinedDissipative * 0.95 * (1 + (r - 55) / 140);
  regRaw = clamp(regRaw, 28, 55);

  const total = progRaw + regRaw;
  let progPct = total > 1e-9 ? (progRaw / total) * 100 : 50;
  let regPct = total > 1e-9 ? (regRaw / total) * 100 : 50;

  if (contextLean === 'REGRESSIVE' && progPct >= regPct) {
    progPct -= 2;
    regPct += 2;
  } else if (contextLean === 'PROGRESSIVE' && regPct >= progPct) {
    progPct += 2;
    regPct -= 2;
  }

  const net = (progPct - regPct) / 100;

  return {
    overallScs: baseline.weightedOverallScs,
    baselineScs: baseline.baselineScs,
    refinedScs,
    progressivePct: progPct,
    regressivePct: regPct,
    netMomentum: net,
    lean: contextLean,
    continuumScs: constructs.continuum.scs,
    flowScs: f,
    shearScs: s,
    resistanceScs: r,
    vortexScs: v,
    omega: v,
    sigma: s,
    itau: r,
    jmu: f,
    positive: refinedPositive,
    dissipative: refinedDissipative,
  };
}

function partThreeLevers(input, core) {
  const without = core.refinedScs;
  const flowLift = core.flowScs / 100;
  const constructiveLift = (core.vortexScs + core.flowScs) / 100;
  const applyLevers = input.applyLevers !== false;

  // Lever band is relative to current refined SCS (always a raise when levers apply).
  // Do not use absolute BURNHAM-era floors (56–63) that can project a drop.
  let withMin = without;
  let withMax = without;
  if (applyLevers) {
    const minDelta = clamp(1.0 + flowLift * 2.5, 1.0, 4.0);
    const maxDelta = clamp(minDelta + 1.5 + constructiveLift * 2.0, minDelta + 1.0, 8.0);
    withMin = clamp(without + minDelta, without + 0.5, 100);
    withMax = clamp(without + maxDelta, withMin + 0.5, 100);
    // Cap room near ceiling while preserving raise semantics
    if (withMin <= without) withMin = clamp(without + 0.5, 0, 100);
    if (withMax <= withMin) withMax = clamp(withMin + 0.5, 0, 100);
  }

  const subject =
    input.topic ||
    'The SOCIAL COHESION SCORE OF ANDY BURNHAM, BEING PRIME MINISTER — UK & Ireland focus';

  return {
    interventions: [
      `Publish verified, differentiated data on ${subject}.`,
      'Cut σ/Iτ friction with transparent follow-through.',
      'Strengthen Jμ trust transport across groups.',
      `Target the highest-friction construct (σ or Iτ) with measurable de-escalation milestones on ${subject}.`,
      `Publish a PROGRESSIVE accountability review with published milestones tying lever use to SCS gains on ${subject}.`,
    ],
    withoutLeversScs: without,
    withLeversMin: withMin,
    withLeversMax: withMax,
    actions: [
      `minister: Issue an evidence-based response on ${subject}.`,
      `minister: Hold an open press Q&A on ${subject}.`,
      'minister: Commission a 30-day messaging review.',
      `minister: Reduce Iτ institutional drag on ${subject} — publish decision timelines. Work through stated Iτ resistance.`,
      `minister: Commit to a PROGRESSIVE accountability review with published milestones for ${subject}.`,
    ],
  };
}

/**
 * Run full Chronoflux social cohesion analysis.
 * @param {object} rawInput
 * @returns {object} structured result (SCS + constructs + BURNHAM-like parts)
 */
export function scoreSocialCohesion(rawInput = {}) {
  const input = {
    topic:
      rawInput.topic ||
      'The SOCIAL COHESION SCORE OF ANDY BURNHAM, BEING PRIME MINISTER — UK & Ireland focus',
    posedQuestion: rawInput.posedQuestion || rawInput.scenarioQuery || '',
    vortexText: rawInput.vortexText || rawInput.v || rawInput.omega || '',
    shearText: rawInput.shearText || rawInput.s || rawInput.sigma || '',
    resistanceText: rawInput.resistanceText || rawInput.r || rawInput.itau || '',
    flowText: rawInput.flowText || rawInput.f || rawInput.jmu || '',
    continuumText: rawInput.continuumText || '',
    regionId: rawInput.regionId || 'uk-ireland',
    applyLevers: rawInput.applyLevers !== false,
    lean: rawInput.lean,
    xHandle: rawInput.xHandle || '@AndyBurnham',
  };

  const { constructs, sem, lean, weights } = enrichConstructs(input);
  const baseline = hydrodynamicCore(constructs);
  const hasQuestion = Boolean((input.posedQuestion || '').trim());
  const core = refinedCore(baseline, constructs, lean, hasQuestion);
  const levers = partThreeLevers(input, core);

  const fieldNarratives = {
    vortex: (input.vortexText || '').trim() || `ω signal from ${sem.displaySubject}`,
    shear: (input.shearText || '').trim() || `σ polarisation on ${sem.displaySubject}`,
    resistance: (input.resistanceText || '').trim() || 'Iτ institutional drag',
    flow: (input.flowText || '').trim() || 'Jμ trust transport',
  };

  return {
    ok: true,
    timestamp: new Date().toISOString(),
    scenario: {
      xHandle: input.xHandle,
      topic: input.topic,
      posedQuestion: input.posedQuestion,
      regionId: input.regionId,
      fields: {
        v: input.vortexText,
        f: input.flowText,
        s: input.shearText,
        r: input.resistanceText,
      },
    },
    refinedScs: round1(core.refinedScs),
    baselineScs: round1(core.baselineScs),
    overallScs: round1(core.overallScs),
    progressivePct: round1(core.progressivePct),
    regressivePct: round1(core.regressivePct),
    lean: core.lean,
    netMomentum: Number(core.netMomentum.toFixed(3)),
    constructs: {
      omega: round1(core.vortexScs),
      sigma: round1(core.shearScs),
      itau: round1(core.resistanceScs),
      jmu: round1(core.flowScs),
      continuum: round1(core.continuumScs),
      vortex: round1(core.vortexScs),
      shear: round1(core.shearScs),
      resistance: round1(core.resistanceScs),
      flow: round1(core.flowScs),
    },
    weights: {
      continuum: round3(weights[0]),
      flow: round3(weights[1]),
      shear: round3(weights[2]),
      resistance: round3(weights[3]),
      vortex: round3(weights[4]),
    },
    semantics: {
      subject: sem.displaySubject,
      frame: sem.frame,
      polarity: sem.polarity,
      fingerprint: sem.fingerprint,
      hintSignals: sem.hintSignals,
    },
    partOne: {
      title: 'Part One: Baseline Parameter Mapping',
      vortex: fieldNarratives.vortex,
      shear: fieldNarratives.shear,
      resistance: fieldNarratives.resistance,
      flow: fieldNarratives.flow,
      baselineScs: round1(baseline.baselineScs),
      weightedOverallScs: round1(baseline.weightedOverallScs),
      progressivePct: round1(baseline.progressivePct),
      regressivePct: round1(baseline.regressivePct),
    },
    partTwo: {
      title: 'Part Two: Broader Political Continuum Integration',
      expandedVortex: `Unified institutional narrative on "${input.topic}" narrows public debate (ω ${round1(core.vortexScs)}/100). Continuum integration: ~${round1(core.regressivePct)}% regressive / ~${round1(core.progressivePct)}% progressive lean.`,
      shearRefinement: `Polarisation on "${sem.displaySubject}" — favours cohesion-repair paths (σ ${round1(core.shearScs)}/100).`,
      resistanceFlow: `Contested transport — net lean ${core.lean} (Iτ ${round1(core.resistanceScs)}/100, Jμ ${round1(core.flowScs)}/100). Scenario signal: ${sem.hintSignals[0] || 'institutional framing'}.`,
      refinedScs: round1(core.refinedScs),
      progressivePct: round1(core.progressivePct),
      regressivePct: round1(core.regressivePct),
      lean: core.lean,
    },
    partThree: {
      title: 'Part Three: Actionable Levers for Friction Reduction',
      ...levers,
      projectedWithout: `Without levers: Continued ~${round1(core.refinedScs)}/100 with recurrence risk.`,
      projectedWith: `With levers: rise from ~${round1(core.refinedScs)} toward ${round1(levers.withLeversMin)}–${round1(levers.withLeversMax)}/100 within 3 months.`,
    },
    historyPoint: {
      t: Date.now(),
      refinedScs: round1(core.refinedScs),
      progressivePct: round1(core.progressivePct),
      regressivePct: round1(core.regressivePct),
      omega: round1(core.vortexScs),
      sigma: round1(core.shearScs),
      itau: round1(core.resistanceScs),
      jmu: round1(core.flowScs),
    },
  };
}

function round1(n) {
  return Math.round(Number(n) * 10) / 10;
}
function round3(n) {
  return Math.round(Number(n) * 1000) / 1000;
}

export { DEFAULT_WEIGHTS, clamp };
