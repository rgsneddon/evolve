/// Canonical Evolve / Chronoflux equations from the article
/// (`chronoflux_restore_sim.py` hydrodynamic core).
///
/// Constructs (array order): [Continuum ρt, Flow Jμ, Shear σ, Resistance Iτ, Vortex ω]
class FrameworkSpec {
  const FrameworkSpec._();

  static const constructs = [
    'Continuum (ρt)',
    'Flow (Jμ)',
    'Shear (σ)',
    'Resistance (Iτ)',
    'Vortex (ω)',
  ];

  static const rules = [
    'Numeric SCS scores form the Continuum — no polls or betting odds.',
    'PART TWO + PART THREE are zero-sum on THE CONTINUUM (progressive + regressive = 100%).',
    'Blank σ / Iτ / Jμ → Grok observational inference relative to the ω question.',
    'Flow obeys covariant continuity: ∇μJμ ≈ 0 (conserved trust transport).',
  ];

  static const partOneEquations = [
    'Weighted SCS = Σ(scsᵢ × wᵢ), weights normalised to 1',
    'effᵢ = clip(scsᵢ × wᵢ × 5, 0, 100)',
    'positive = (Jμ + ω + ρt × 0.75) / 2.75',
    'sentience_% = scenario σ-awareness (polarisation, unrest, adverse signals)',
    'salience_% = scenario Iτ-attention (institutional drag, horizon, policy)',
    'σ_eff = σ_eff × (0.45 + 0.55 × sentience_% / 100) — sentience reacts as shear',
    'Iτ_eff = Iτ_eff × (0.45 + 0.55 × salience_% / 100) — salience reacts as resistance',
    'dissipative = (σ_eff × 0.62 + Iτ_eff × 0.78) / 1.4',
    'baseline_scs = clip((positive − dissipative × 0.68) × 1.25, 68, 87)',
    'progressive_raw = (positive × 0.82) × (1 − dissipative / 155)',
    'regressive_raw = clip(dissipative × 0.95 × (1 + (Iτ − 55) / 140), 28, 45)',
    'progressive_% = progressive_raw / (progressive_raw + regressive_raw) × 100',
    'regressive_% = regressive_raw / (progressive_raw + regressive_raw) × 100',
    'net_momentum = (progressive_raw − regressive_raw) / 100',
  ];

  static const partTwoEquations = [
    'constructive_channel = (ω_scs + Jμ_scs) / 2',
    'dissipative_channel = (σ_reacted + Iτ_reacted) / 2',
    'refined_positive = (constructive_channel + positive) / 2',
    'refined_dissipative = (dissipative_channel × 0.68 + dissipative) / 1.68',
    'elite_factor = 1 + (σ_scs + Iτ_scs) / 300',
    'refined_scs = clip(((refined_positive − refined_dissipative × 0.68) × 1.25 × elite_factor), …)',
    'Recompute progressive_% / regressive_% on refined channels',
  ];

  static const continuumEquations = [
    'percent_chance = clip(regressive_% × 0.55 + σ_reacted × 0.25 + (100 − refined_scs) × 0.2, 8, 92)',
    'CONCLUSION - THE CONTINUUM: direct answer to the ω question',
  ];

  static const partThreeEquations = [
    'without_levers_scs = refined_scs from PART TWO',
    'with_levers_scs ≈ clip(mechanical_baseline × 0.72 + Jμ_lift × 14, 56, 63)',
    'mechanical_baseline = (ω + σ + Iτ + Jμ) / 4',
  ];

  static String fullReference() => [
    'Evolve Chronoflux Framework — Equation Reference',
    '',
    'Rules:',
    ...rules.map((r) => '• $r'),
    '',
    'PART ONE — Baseline hydrodynamic core:',
    ...partOneEquations.map((e) => '• $e'),
    '',
    'PART TWO — Continuum integration:',
    ...partTwoEquations.map((e) => '• $e'),
    '',
    'THE CONTINUUM — Percent chance:',
    ...continuumEquations.map((e) => '• $e'),
    '',
    'PART THREE — Actionable levers:',
    ...partThreeEquations.map((e) => '• $e'),
  ].join('\n');
}