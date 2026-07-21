/**
 * Grok construe for construct fields — fills ONLY blank fields.
 * Live Grok via XAI_API_KEY when available; heuristic fallback otherwise.
 */

/**
 * Heuristic construal from posed question / topic (blank-field-only).
 * Mirrors Evolve GrokHeuristicConstrual.pick behaviour.
 */
export function heuristicConstrue(input = {}) {
  const question = (input.posedQuestion || input.scenarioQuery || input.topic || '').trim();
  const topic =
    input.topic ||
    'The SOCIAL COHESION SCORE OF ANDY BURNHAM, BEING PRIME MINISTER — UK & Ireland focus';
  const handle = input.xHandle || '@AndyBurnham';

  const suggestions = {
    continuumText: `Continuum framing of ${handle} as PM under UK & Ireland institutional narrative — ${topic}.`,
    vortexText: `Authority circulation around ${handle} becoming prime minister; performative opening narrative and establishment briefings shape ω.`,
    shearText: `Public polarisation on whether ${handle} as PM delivers substance versus optics; street and media shear on early record.`,
    resistanceText: `Institutional and factional resistance to ${handle} premiership — procedural drag, personnel decisions, and opposition critique (Iτ).`,
    flowText: `Trust transport and messaging flow under ${handle} PM: who is rewarded, who is sidelined, and how narrative reaches the public (Jμ).`,
  };

  if (question) {
    suggestions.vortexText = `Core vortex from observed discourse on: ${question.slice(0, 160)} — authority lanes tilt toward institutional framing of ${handle}.`;
    suggestions.shearText = `Shear from discourse polarisation in: ${question.slice(0, 120)} — open-channel split on premiership legitimacy.`;
  }

  return {
    continuumText: pickBlank(input.continuumText, suggestions.continuumText),
    vortexText: pickBlank(input.vortexText || input.v, suggestions.vortexText),
    shearText: pickBlank(input.shearText || input.s, suggestions.shearText),
    resistanceText: pickBlank(input.resistanceText || input.r, suggestions.resistanceText),
    flowText: pickBlank(input.flowText || input.f, suggestions.flowText),
    provenance: 'grok-heuristic',
    filledFields: filledKeys(input, suggestions),
  };
}

function pickBlank(existing, suggestion) {
  if (existing != null && String(existing).trim() !== '') return String(existing).trim();
  return suggestion;
}

function filledKeys(input, suggestions) {
  const keys = ['continuumText', 'vortexText', 'shearText', 'resistanceText', 'flowText'];
  const map = {
    continuumText: input.continuumText,
    vortexText: input.vortexText || input.v,
    shearText: input.shearText || input.s,
    resistanceText: input.resistanceText || input.r,
    flowText: input.flowText || input.f,
  };
  return keys.filter((k) => !(map[k] != null && String(map[k]).trim() !== '') && suggestions[k]);
}

/**
 * Merge construal into input without overwriting non-blank user fields.
 */
export function applyConstrual(input, construal) {
  return {
    ...input,
    continuumText: pickBlank(input.continuumText, construal.continuumText),
    vortexText: pickBlank(input.vortexText || input.v, construal.vortexText),
    shearText: pickBlank(input.shearText || input.s, construal.shearText),
    resistanceText: pickBlank(input.resistanceText || input.r, construal.resistanceText),
    flowText: pickBlank(input.flowText || input.f, construal.flowText),
  };
}

/** True when XAI_API_KEY (or options.apiKey) is configured. */
export function isGrokConfigured(options = {}) {
  return Boolean((options.apiKey || process.env.XAI_API_KEY || '').trim());
}

/**
 * Decide whether to call live Grok.
 * Default: use live Grok when a key is present unless liveGrok === false.
 */
export function shouldUseLiveGrok(body = {}, options = {}) {
  if (body.liveGrok === false || body.liveGrok === 'false' || body.heuristicOnly) {
    return false;
  }
  if (body.liveGrok === true || body.liveGrok === 'true') return isGrokConfigured(options);
  // Default for construe paths: prefer live when configured
  return isGrokConfigured(options);
}

/**
 * Live Grok construal via xAI API when XAI_API_KEY is set.
 * On failure or missing key, falls back to heuristic.
 * Fills blank construct fields only (never overwrites user-supplied text).
 * When all fields are full, still pings Grok for a short discourse note if forceNote.
 */
export async function grokConstrue(input = {}, options = {}) {
  const apiKey = options.apiKey || process.env.XAI_API_KEY || '';
  if (!apiKey) {
    const h = heuristicConstrue(input);
    return { ...h, provenance: 'grok-heuristic', grokConfigured: false };
  }

  const blanks = [];
  if (!(input.vortexText || input.v || '').trim()) blanks.push('vortex');
  if (!(input.shearText || input.s || '').trim()) blanks.push('shear');
  if (!(input.resistanceText || input.r || '').trim()) blanks.push('resistance');
  if (!(input.flowText || input.f || '').trim()) blanks.push('flow');
  if (!(input.continuumText || '').trim()) blanks.push('continuum');

  // All fields supplied: still call Grok for a brief live discourse note (does not overwrite fields)
  const forceNote = options.forceNote !== false && blanks.length === 0;

  if (blanks.length === 0 && !forceNote) {
    return {
      continuumText: (input.continuumText || '').trim(),
      vortexText: (input.vortexText || input.v || '').trim(),
      shearText: (input.shearText || input.s || '').trim(),
      resistanceText: (input.resistanceText || input.r || '').trim(),
      flowText: (input.flowText || input.f || '').trim(),
      provenance: 'user-supplied',
      filledFields: [],
      grokConfigured: true,
    };
  }

  const handle = input.xHandle || '@AndyBurnham';
  const fieldList = blanks.length ? blanks.join(', ') : 'none (all filled — return discourseNote only)';
  const prompt = `You are Evolve Chronoflux construct construal. Scenario: ${handle} has become UK Prime Minister. Topic: ${input.topic || 'social cohesion of Andy Burnham as PM'}.
Posed question: ${input.posedQuestion || input.scenarioQuery || 'n/a'}
Existing fields (do not contradict unless blank):
vortex: ${(input.vortexText || input.v || '').slice(0, 200)}
shear: ${(input.shearText || input.s || '').slice(0, 200)}
resistance: ${(input.resistanceText || input.r || '').slice(0, 200)}
flow: ${(input.flowText || input.f || '').slice(0, 200)}
Blank fields to fill (JSON keys): ${fieldList}.
Return pure JSON only: {"vortex":"...","shear":"...","resistance":"...","flow":"...","continuum":"...","discourseNote":"one sentence live Grok read of social discourse"}.
Only populate blank construct keys; always include discourseNote. Do not invent numeric SCS.`;

  try {
    const res = await fetch('https://api.x.ai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: options.model || process.env.XAI_MODEL || 'grok-3-mini',
        messages: [
          { role: 'system', content: 'Return only valid JSON for Chronoflux construct fields.' },
          { role: 'user', content: prompt },
        ],
        temperature: 0.4,
      }),
      signal: AbortSignal.timeout(options.timeoutMs || 45000),
    });
    if (!res.ok) {
      const errBody = await res.text().catch(() => '');
      throw new Error(`Grok HTTP ${res.status}${errBody ? `: ${errBody.slice(0, 180)}` : ''}`);
    }
    const data = await res.json();
    const text = data.choices?.[0]?.message?.content || '';
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (!jsonMatch) throw new Error('No JSON in Grok response');
    const parsed = JSON.parse(jsonMatch[0]);
    const base = heuristicConstrue(input);
    return {
      continuumText: pickBlank(input.continuumText, parsed.continuum || base.continuumText),
      vortexText: pickBlank(input.vortexText || input.v, parsed.vortex || base.vortexText),
      shearText: pickBlank(input.shearText || input.s, parsed.shear || base.shearText),
      resistanceText: pickBlank(
        input.resistanceText || input.r,
        parsed.resistance || base.resistanceText,
      ),
      flowText: pickBlank(input.flowText || input.f, parsed.flow || base.flowText),
      discourseNote: (parsed.discourseNote || '').trim() || null,
      provenance: 'grok-live',
      filledFields: blanks,
      grokConfigured: true,
      model: options.model || process.env.XAI_MODEL || 'grok-3-mini',
    };
  } catch (err) {
    const h = heuristicConstrue(input);
    return {
      ...h,
      provenance: 'grok-heuristic-fallback',
      grokConfigured: true,
      grokError: String(err?.message || err).slice(0, 240),
    };
  }
}
