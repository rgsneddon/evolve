/**
 * BURNHAM.md-style Markdown report from SCS engine output.
 */

function round1(n) {
  return Math.round(Number(n) * 10) / 10;
}

export function toBurnhamMarkdown(result) {
  const c = result.constructs;
  const p1 = result.partOne;
  const p2 = result.partTwo;
  const p3 = result.partThree;
  const sc = result.scenario || {};

  return `# SSUCF Analysis: FACT-BASED ANALYSIS

Social Cohesion Analysis under Chronoflux-derived Covariant Continuity
Topic: ${sc.topic || result.semantics?.subject || 'Burnham PM cohesion'}
X handle: ${sc.xHandle || '@AndyBurnham'}

## Social Cohesion Outcome

Refined cohesion score: **~${result.refinedScs}/100**
Regressive: ~${result.regressivePct}% | Progressive: ~${result.progressivePct}%
Lean: **${result.lean}** · Net momentum: ${result.netMomentum}

## Part One: Baseline Parameter Mapping

### Vortex (Initial Conditions)
* Core input: ${p1.vortex}
* ω signal: Authority circulation at SCS ${c.omega}/100.
### Shear (Social Forces)
* ${p1.shear}
* σ: ${c.sigma}/100
### Resistance
* ${p1.resistance}
* Iτ: ${c.itau}/100
### Flow
* ${p1.flow}
* Jμ: ${c.jmu}/100
Baseline Cohesion Score: ~${p1.baselineScs}/100
Weighted Overall SCS: ~${p1.weightedOverallScs}/100
Regressive: ~${p1.regressivePct}% | Progressive: ~${p1.progressivePct}%

## Part Two: Broader Political Continuum Integration

### Expanded Vortex
* ${p2.expandedVortex}
### Shear Refinement
* ${p2.shearRefinement}
### Resistance & Flow
* ${p2.resistanceFlow}
Refined Cohesion Score: ~${p2.refinedScs}/100
Regressive: ~${p2.regressivePct}% | Progressive: ~${p2.progressivePct}%

## Part Three: Actionable Levers for Friction Reduction

### Targeted Interventions
${p3.interventions.map((line, i) => `${i + 1}. ${line}`).join('\n')}

### Projected Outcomes
${p3.projectedWithout}
${p3.projectedWith}

## Conclusion

Weighted Overall SCS: ~${result.overallScs}/100
Refined SCS: ~${result.refinedScs}/100 (${result.lean})

Final Summary: Move from narrative compression on "${sc.topic}" to differentiated, data-driven responses to rebuild covariant continuity and reduce social friction.

## Agent-Specific Recommended Actions

PART THREE — Five actions to raise SCS & PROGRESSIVE (minister)

${p3.actions.map((line, i) => `${i + 1}. ${line}`).join('\n')}

Expected: SCS rises from ~${result.refinedScs} toward ${round1(p3.withLeversMin)}–${round1(p3.withLeversMax)} on THE CONTINUUM.

🌀 SSUCF Cycle Complete. Analysis by Evolve Chronoflux from posed scenario and construct parameters.

---
Created: ${result.timestamp || new Date().toISOString()}
Region focus (ω): UK & Ireland
Analysis mode: Social cohesion
Construct scores: ω=${c.omega} σ=${c.sigma} Iτ=${c.itau} Jμ=${c.jmu} continuum=${c.continuum}
Posed question: ${sc.posedQuestion || ''}
Exported from PrimeMinster Chronoflux bridge — BURNHAM.md structural family.
`;
}
