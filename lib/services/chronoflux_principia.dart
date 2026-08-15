import 'dart:math' as math;

import '../models/chronoflux_principia_snapshot.dart';

/// Tweet-core Chronoflux Principia identities (discrete Minkowski form).
///
/// Pure functions of node / scenario observables. No I/O.
class ChronofluxPrincipia {
  const ChronofluxPrincipia();

  /// k_t — temporal coupling, analog of 8πG/c^4 in G=c=1 units.
  static const double temporalCoupling = 8 * math.pi;

  static const double atol = 1e-9;

  /// Mostly-plus Minkowski diagonal g^{μν} = diag(-1, 1, 1, 1).
  static const List<double> minkowskiDiag = <double>[-1, 1, 1, 1];

  static List<double> zeros4() => List<double>.filled(4, 0);

  static List<List<double>> zeros44() =>
      List<List<double>>.generate(4, (_) => List<double>.filled(4, 0));

  /// J^μ = ρ_t u^μ
  static List<double> transportCurrent(double rhoT, List<double> fourVelocity) {
    final u = _vec4(fourVelocity);
    return [for (var i = 0; i < 4; i++) rhoT * u[i]];
  }

  /// T_t^{μν} = (ρ_t + p_t) u^μ u^ν + p_t g^{μν} + Σ^{μν}
  static List<List<double>> transportStressTensor({
    required double rhoT,
    required double pressureT,
    required List<double> fourVelocity,
    List<double>? metricDiag,
    List<List<double>>? sigma,
  }) {
    final u = _vec4(fourVelocity);
    final g = metricDiag ?? minkowskiDiag;
    final s = sigma ?? zeros44();
    final t = zeros44();
    final enthalpy = rhoT + pressureT;
    for (var mu = 0; mu < 4; mu++) {
      for (var nu = 0; nu < 4; nu++) {
        final gMuNu = mu == nu ? g[mu] : 0.0;
        t[mu][nu] =
            enthalpy * u[mu] * u[nu] + pressureT * gMuNu + s[mu][nu];
      }
    }
    return t;
  }

  /// G_{μν} = k_t T^t_{μν}
  static List<List<double>> geometricClosure(
    List<List<double>> stress, {
    double? coupling,
  }) {
    final k = coupling ?? temporalCoupling;
    return [
      for (var mu = 0; mu < 4; mu++)
        [for (var nu = 0; nu < 4; nu++) k * stress[mu][nu]],
    ];
  }

  /// Discrete ∇_μ J^μ from opposite faces (plus − minus) / dx^μ.
  static double continuityResidual(
    List<double> currentMinus,
    List<double> currentPlus, {
    List<double>? dx,
  }) {
    final a = _vec4(currentMinus);
    final b = _vec4(currentPlus);
    final step = dx ?? const <double>[1, 1, 1, 1];
    var acc = 0.0;
    for (var mu = 0; mu < 4; mu++) {
      acc += (b[mu] - a[mu]) / step[mu];
    }
    return acc;
  }

  /// Discrete ∇_μ T^{μν} (length-4 residual).
  static List<double> stressDivergenceResidual(
    List<List<double>> stressMinus,
    List<List<double>> stressPlus, {
    List<double>? dx,
  }) {
    final step = dx ?? const <double>[1, 1, 1, 1];
    final out = zeros4();
    for (var nu = 0; nu < 4; nu++) {
      var acc = 0.0;
      for (var mu = 0; mu < 4; mu++) {
        acc += (stressPlus[mu][nu] - stressMinus[mu][nu]) / step[mu];
      }
      out[nu] = acc;
    }
    return out;
  }

  static bool isConserved({
    required double continuity,
    required List<double> stressDivergence,
    double tolerance = atol,
  }) {
    if (continuity.abs() > tolerance) return false;
    for (final component in stressDivergence) {
      if (component.abs() > tolerance) return false;
    }
    return true;
  }

  /// Rest-frame or boosted four-velocity from a spatial 3-velocity (|v|<1).
  static List<double> fourVelocityFromSpatial(List<double> spatial) {
    var v1 = spatial.isNotEmpty ? spatial[0] : 0.0;
    var v2 = spatial.length > 1 ? spatial[1] : 0.0;
    var v3 = spatial.length > 2 ? spatial[2] : 0.0;
    var v2sum = v1 * v1 + v2 * v2 + v3 * v3;
    if (v2sum >= 0.99) {
      final scale = math.sqrt(0.98 / v2sum);
      v1 *= scale;
      v2 *= scale;
      v3 *= scale;
      v2sum = v1 * v1 + v2 * v2 + v3 * v3;
    }
    final u0 = 1.0 / math.sqrt(1.0 - v2sum);
    return [u0, u0 * v1, u0 * v2, u0 * v3];
  }

  /// Scenario / % chance observables → live Principia snapshot.
  ///
  /// ρ_t from the regressive continuum share; p_t from refined-SCS strain;
  /// Σ^{11} from shear; u^μ from flow / shear / resistance spatial boost.
  static ChronofluxPrincipiaSnapshot fromScenarioObservables({
    required double regressivePct,
    required double refinedScs,
    required double shearScs,
    double continuumScs = 50,
    double flowScs = 50,
    double resistanceScs = 50,
    double vortexScs = 50,
    List<List<double>>? neighborStress,
    List<double>? neighborCurrent,
  }) {
    final rhoT = (regressivePct / 100.0).clamp(0.0, 1.5);
    final pressureT = ((100.0 - refinedScs) / 100.0).clamp(0.0, 1.5);
    final sigmaScale = (shearScs / 100.0).clamp(0.0, 1.5);
    final u = fourVelocityFromSpatial([
      ((flowScs - 50.0) / 200.0).clamp(-0.8, 0.8),
      ((shearScs - 50.0) / 250.0).clamp(-0.8, 0.8),
      ((resistanceScs - 50.0) / 250.0).clamp(-0.8, 0.8),
    ]);
    final sigma = zeros44();
    sigma[1][1] = sigmaScale;
    // Unused construct scores still shape later elaborations via u^0 tilt.
    final tilt = ((continuumScs - vortexScs) / 400.0).clamp(-0.2, 0.2);
    if (tilt.abs() > 0) {
      // Trace-free temporal–spatial correction kept off the headline Σ^{11}.
      sigma[0][1] = tilt;
      sigma[1][0] = tilt;
    }
    return assemble(
      rhoT: rhoT,
      pressureT: pressureT,
      fourVelocity: u,
      sigma: sigma,
      sigmaScale: sigmaScale,
      neighborStress: neighborStress,
      neighborCurrent: neighborCurrent,
    );
  }

  /// Residual-node / perc hop-density observables → live snapshot.
  static ChronofluxPrincipiaSnapshot fromHopDensity({
    required double density,
    required double pressure,
    double flow = 0,
    double anisotropy = 0,
    int hops = 1,
    List<List<double>>? neighborStress,
    List<double>? neighborCurrent,
  }) {
    final rhoT = density.clamp(0.0, 1.5);
    final pressureT = pressure.clamp(0.0, 1.5);
    final hopBoost = (hops.clamp(0, 8)) / 20.0;
    final u = fourVelocityFromSpatial([
      flow.clamp(-0.8, 0.8),
      (anisotropy * 0.5).clamp(-0.8, 0.8),
      hopBoost.clamp(0.0, 0.4),
    ]);
    final sigma = zeros44();
    final sigmaScale = anisotropy.abs().clamp(0.0, 1.5);
    sigma[1][1] = sigmaScale;
    return assemble(
      rhoT: rhoT,
      pressureT: pressureT,
      fourVelocity: u,
      sigma: sigma,
      sigmaScale: sigmaScale,
      neighborStress: neighborStress,
      neighborCurrent: neighborCurrent,
    );
  }

  static ChronofluxPrincipiaSnapshot assemble({
    required double rhoT,
    required double pressureT,
    required List<double> fourVelocity,
    required List<List<double>> sigma,
    required double sigmaScale,
    List<List<double>>? neighborStress,
    List<double>? neighborCurrent,
    List<double>? metricDiag,
    double? coupling,
  }) {
    final g = metricDiag ?? minkowskiDiag;
    final k = coupling ?? temporalCoupling;
    final j = transportCurrent(rhoT, fourVelocity);
    final t = transportStressTensor(
      rhoT: rhoT,
      pressureT: pressureT,
      fourVelocity: fourVelocity,
      metricDiag: g,
      sigma: sigma,
    );
    final einstein = geometricClosure(t, coupling: k);
    final jFace = neighborCurrent ?? j;
    final tFace = neighborStress ?? t;
    final cont = continuityResidual(jFace, j);
    final divT = stressDivergenceResidual(tFace, t);
    return ChronofluxPrincipiaSnapshot(
      rhoT: rhoT,
      pressureT: pressureT,
      fourVelocity: fourVelocity,
      metricDiag: g,
      sigma: sigma,
      current: j,
      stress: t,
      einstein: einstein,
      temporalCoupling: k,
      continuityResidual: cont,
      stressDivergence: divT,
      conserved: isConserved(continuity: cont, stressDivergence: divT),
      sigmaScale: sigmaScale,
    );
  }

  /// Headline % chance as a contraction of live Principia fields.
  ///
  /// J^μ = ρ_t u^μ  ⇒  ρ_t = J^0 / u^0.
  /// percent = 55 ρ_t + 25 Σ^{11} + 20 p_t   (clamped 8..92)
  /// which is the shipped heuristic expressed on the tweet identities.
  static double percentChanceFromSnapshot(ChronofluxPrincipiaSnapshot snap) {
    final u0 = snap.fourVelocity[0];
    final rhoT = u0.abs() < 1e-12 ? snap.rhoT : snap.current[0] / u0;
    final raw = 55.0 * rhoT + 25.0 * snap.sigmaScale + 20.0 * snap.pressureT;
    return raw.clamp(8.0, 92.0);
  }

  static double percentChanceFromObservables({
    required double regressivePct,
    required double refinedScs,
    required double shearScs,
    double continuumScs = 50,
    double flowScs = 50,
    double resistanceScs = 50,
    double vortexScs = 50,
  }) {
    final snap = fromScenarioObservables(
      regressivePct: regressivePct,
      refinedScs: refinedScs,
      shearScs: shearScs,
      continuumScs: continuumScs,
      flowScs: flowScs,
      resistanceScs: resistanceScs,
      vortexScs: vortexScs,
    );
    return percentChanceFromSnapshot(snap);
  }
}

List<double> _vec4(List<double> raw) {
  final out = List<double>.filled(4, 0);
  for (var i = 0; i < 4 && i < raw.length; i++) {
    out[i] = raw[i];
  }
  return out;
}
