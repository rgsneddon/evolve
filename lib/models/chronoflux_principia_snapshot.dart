/// Live Chronoflux Principia fields on a scenario, hop, or capacity node.
///
/// Tweet core (status 2088642714531168636):
///   J^μ = ρ_t u^μ
///   T_t^{μν} = (ρ_t + p_t) u^μ u^ν + p_t g^{μν} + Σ^{μν}
///   ∇_μ T_t^{μν} = 0  (discrete residual)
///   G_{μν} = k_t T^t_{μν}
class ChronofluxPrincipiaSnapshot {
  const ChronofluxPrincipiaSnapshot({
    required this.rhoT,
    required this.pressureT,
    required this.fourVelocity,
    required this.metricDiag,
    required this.sigma,
    required this.current,
    required this.stress,
    required this.einstein,
    required this.temporalCoupling,
    required this.continuityResidual,
    required this.stressDivergence,
    required this.conserved,
    required this.sigmaScale,
  });

  /// Temporal density ρ_t.
  final double rhoT;

  /// Temporal pressure p_t.
  final double pressureT;

  /// Flow four-velocity u^μ (length 4).
  final List<double> fourVelocity;

  /// Minkowski diagonal g^{μν} = diag(-1, 1, 1, 1).
  final List<double> metricDiag;

  /// Anisotropic stress Σ^{μν} (4×4).
  final List<List<double>> sigma;

  /// Transport current J^μ.
  final List<double> current;

  /// Transport stress T_t^{μν}.
  final List<List<double>> stress;

  /// Geometric closure G_{μν} = k_t T_{μν}.
  final List<List<double>> einstein;

  /// Temporal coupling k_t (analog of 8πG/c^4).
  final double temporalCoupling;

  /// Discrete continuity residual ∇_μ J^μ.
  final double continuityResidual;

  /// Discrete stress divergence ∇_μ T^{μν} (length 4).
  final List<double> stressDivergence;

  /// True when max |∇_μ T^{μν}| and |∇_μ J^μ| are below atol.
  final bool conserved;

  /// Scalar shear scale used by the % chance contraction (Σ^{11}).
  final double sigmaScale;

  Map<String, dynamic> toJson() => {
        'rho_t': rhoT,
        'p_t': pressureT,
        'u': List<double>.from(fourVelocity),
        'g': List<double>.from(metricDiag),
        'sigma': [
          for (final row in sigma) List<double>.from(row),
        ],
        'J': List<double>.from(current),
        'T': [
          for (final row in stress) List<double>.from(row),
        ],
        'G': [
          for (final row in einstein) List<double>.from(row),
        ],
        'k_t': temporalCoupling,
        'continuity_residual': continuityResidual,
        'stress_divergence': List<double>.from(stressDivergence),
        'conserved': conserved,
        'sigma_scale': sigmaScale,
      };
}
