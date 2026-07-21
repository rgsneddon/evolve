/**
 * Open-ended question semantics — port of Evolve QuestionSemantics (fingerprint + offsets).
 * Used to turn social-discourse field text into construct SCS offsets.
 */

function fingerprint(text) {
  if (!text) return 0;
  let hash = 0;
  for (let i = 0; i < text.length; i++) {
    hash = (hash * 31 + text.charCodeAt(i)) & 0x7fffffff;
  }
  return (hash % 17) - 8;
}

function detectFrame(lower) {
  if (/\b(chance|probability|likelihood|how likely|odds)\b/.test(lower)) return 'probability';
  if (/\b(how much|how many|what (percent|percentage|share|proportion|level))\b/.test(lower)) {
    return 'magnitude';
  }
  if (/^(will|would|could|can|should|is it likely|are we going to)\b/.test(lower)) return 'predictive';
  if (lower.includes('?')) return 'probability';
  return 'descriptive';
}

function isInterrogative(lower) {
  return (
    lower.includes('?') ||
    /^(what|who|when|where|why|how|will|would|could|can|should|is|are|do|does|did)\b/.test(lower)
  );
}

function detectPolarity(lower) {
  const adverseRx =
    /\b(unrest|riot|violence|war|conflict|invasion|attack|disorder|collapse|crisis|recession|fail|threat|risk|danger|harm|lose|decline|fall|drop|worse|condemn|backlash|resign|scandal|fraud|strike|shutdown|shortage|exceed|above|surge|criminality|idiots|conceited|nonsense)\b/g;
  const favourableRx =
    /\b(trust|cohesion|unity|peace|stable|stability|succeed|win|growth|improve|rise|recover|hold|accept|believe|support|approve|calm|resolve|agree|well done|rewarded)\b/g;
  const adverse = (lower.match(adverseRx) || []).length;
  const favourable = (lower.match(favourableRx) || []).length;
  if (adverse > favourable + 1) return 'adverse';
  if (favourable > adverse + 1) return 'favourable';
  return 'open';
}

function extractSubject(raw, lower) {
  let s = lower;
  const patterns = [
    /^(?:what is|what's|whats|calculate|estimate|compute|give me|tell me|please)?\s*(?:the\s+)?(?:percent(?:age)?\s+)?(?:chance|probability|likelihood)\s+(?:of|that)\s+/i,
    /^what (?:percent(?:age)?|proportion|share) (?:of )?(?:people |the population )?/i,
    /^how likely is (?:it )?(?:that )?/i,
    /^(?:will|would|could|can|should|is it likely that|are we going to)\s+/i,
    /^(?:what|how much|how many)\s+(?:is|are|was|were)\s+(?:the\s+)?/i,
    /^(?:do you think|please)\s+/i,
  ];
  for (const p of patterns) s = s.replace(p, '');
  s = s.replace(/\?\s*$/, '');
  s = s.replace(/\b(?:please|near[- ]term|short[- ]term|long[- ]term)\b\.?$/i, '');
  s = s.trim();
  if (s.length < 3) s = lower.replace(/\?/g, '').trim();
  return s || raw.replace(/\?\s*$/, '').trim();
}

function hintSignals(lower) {
  const hints = [];
  const push = (label, v, s, r, f) => hints.push({ label, vortex: v, shear: s, resistance: r, flow: f });
  if (/\b(prime minister|pm|minister|government|cabinet)\b/.test(lower)) {
    push('institutional framing', 2, 1, 1.5, 0.5);
  }
  if (/\b(protest|unrest|riot|disorder)\b/.test(lower)) {
    push('collective-disorder circulation', 3, 4, 1, -1);
  }
  if (/\b(election|vote|ballot|campaign)\b/.test(lower)) {
    push('electoral vortex', 3, 2, 0.5, 1);
  }
  if (/\b(economy|inflation|recession|cost of living)\b/.test(lower)) {
    push('macro-economic pressure', 1, 2, 2, -0.5);
  }
  if (/\b(trust|narrative|lens|selective|sceptic|skeptic)\b/.test(lower)) {
    push('narrative-lens compression', 1.5, 1.5, 0.5, -1);
  }
  if (/\b(cohesion|social cohesion|scs)\b/.test(lower)) {
    push('cohesion-score framing', 1, 1, 0.5, 1);
  }
  if (/\b(burnham|andy burnham)\b/.test(lower)) {
    push('burnham-pm scenario', 2, 1.5, 1, 0.5);
  }
  return hints;
}

/**
 * @param {string} raw
 * @param {{ regionId?: string, regionLabel?: string }} [opts]
 */
export function parseQuestionSemantics(raw, opts = {}) {
  const trimmed = (raw || '').trim();
  const lower = trimmed.toLowerCase();
  const regionId = opts.regionId || 'uk-ireland';
  const fp = fingerprint(lower);
  const frame = detectFrame(lower);
  const interrogative = isInterrogative(lower);
  const subject = extractSubject(trimmed, lower);
  const polarity = detectPolarity(lower);
  const hints = hintSignals(lower);

  const wordCount = subject.split(/\s+/).filter(Boolean).length;
  const complexity = (Math.min(24, Math.max(2, wordCount)) - 4) * 0.35;

  let vortex = 52 + complexity;
  let shear = 52 + complexity * 0.6;
  let resistance = 50 + complexity * 0.4;
  let flow = 54 + complexity * 0.3;

  if (interrogative) vortex += 4;
  if (frame === 'probability') {
    vortex += 3;
    flow += 4;
  }
  if (frame === 'predictive') vortex += 2;
  if (frame === 'magnitude') flow += 5;

  for (const h of hints) {
    vortex += h.vortex;
    shear += h.shear;
    resistance += h.resistance;
    flow += h.flow;
  }

  // Regional UK & Ireland bias (matches Evolve region construct bias style)
  if (regionId !== 'global') {
    vortex += 1.2;
    shear += 0.8;
    resistance += 0.6;
    flow += 0.4;
  }

  vortex += fp * 0.5;
  shear += fp * 0.35;
  resistance += fp * 0.3;
  flow += fp * 0.25;

  if (polarity === 'adverse') {
    shear += 3;
    flow -= 2;
  } else if (polarity === 'favourable') {
    flow += 2;
    resistance -= 1;
  }

  return {
    raw: trimmed,
    subject,
    displaySubject: subject.length > 88 ? `${subject.slice(0, 85)}…` : subject,
    frame,
    polarity,
    isInterrogative: interrogative,
    fingerprint: fp,
    vortexOffset: vortex,
    shearOffset: shear,
    resistanceOffset: resistance,
    flowOffset: flow,
    hintSignals: hints.map((h) => h.label),
    regionId,
  };
}

export function fieldFingerprint(text) {
  return fingerprint((text || '').toLowerCase());
}
