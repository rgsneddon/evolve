/**
 * Burnham-PM scenario: social-discourse-observed field inputs for v, f, s (+ resistance)
 * with SSUCF posed question ending in "please". Seeded from BURNHAM.md structure
 * without freezing its numeric SCS as the only allowed result.
 */

export const BURNHAM_PM_SCENARIO = {
  xHandle: '@AndyBurnham',
  /** Typo alias from objective */
  xHandleAliases: ['@AndyBunrham', '@AndyBurnham'],
  regionId: 'uk-ireland',
  topic:
    'The SOCIAL COHESION SCORE OF ANDY BURNHAM, BEING PRIME MINISTER — UK & Ireland focus',
  /**
   * Evolve-style cohesion query framing (observed social discourse … please).
   */
  posedQuestion:
    'Using observed social discourse on X user @AndyBurnham who has recently become prime minister, what is the social cohesion score under Chronoflux covariant continuity for UK & Ireland please',
  /** v — Vortex (ω) */
  vortexText:
    'Performative nonsense perpetuating Mr Burnham, to think conceited that he started well.',
  /** s — Shear (σ) */
  shearText: 'When in fact, he had done nothing',
  /** resistance — Iτ */
  resistanceText: 'Shipped out a few idiots. well done.',
  /** f — Flow (Jμ) */
  flowText: 'REWARDED CRIMINALITY: ANGELA RAYNER',
  continuumText: 'FACT-BASED ANALYSIS — institutional narrative on Burnham as PM',
  applyLevers: true,
};

export function burnhamScenario(overrides = {}) {
  return { ...BURNHAM_PM_SCENARIO, ...overrides };
}

/** Discourse-only fields for tests that assert v/f/s drive scoring. */
export function discourseFieldsFromScenario(scenario = BURNHAM_PM_SCENARIO) {
  return {
    v: scenario.vortexText,
    f: scenario.flowText,
    s: scenario.shearText,
    r: scenario.resistanceText,
    posedQuestion: scenario.posedQuestion,
    topic: scenario.topic,
    xHandle: scenario.xHandle,
    regionId: scenario.regionId,
  };
}
