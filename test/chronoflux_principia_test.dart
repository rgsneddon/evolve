import 'package:flutter_test/flutter_test.dart';
import 'package:evolve/models/scenario_input.dart';
import 'package:evolve/services/chronoflux_principia.dart';
import 'package:evolve/services/evolve_engine.dart';

void main() {
  test('transport current is rho_t times four-velocity', () {
    const rho = 0.4;
    const u = [1.2, 0.1, -0.2, 0.05];
    final j = ChronofluxPrincipia.transportCurrent(rho, u);
    for (var i = 0; i < 4; i++) {
      expect(j[i], closeTo(rho * u[i], 1e-12));
    }
  });

  test('stress tensor matches perfect-fluid-plus-sigma identity', () {
    const rho = 0.35;
    const p = 0.15;
    const u = [1.05, 0.2, 0.0, 0.0];
    final sigma = ChronofluxPrincipia.zeros44();
    sigma[1][1] = 0.22;
    final t = ChronofluxPrincipia.transportStressTensor(
      rhoT: rho,
      pressureT: p,
      fourVelocity: u,
      sigma: sigma,
    );
    const g = ChronofluxPrincipia.minkowskiDiag;
    for (var mu = 0; mu < 4; mu++) {
      for (var nu = 0; nu < 4; nu++) {
        final gMuNu = mu == nu ? g[mu] : 0.0;
        final expected =
            (rho + p) * u[mu] * u[nu] + p * gMuNu + sigma[mu][nu];
        expect(t[mu][nu], closeTo(expected, 1e-12));
      }
    }
  });

  test('geometric closure is k_t times stress', () {
    const rho = 0.5;
    const p = 0.1;
    const u = [1.0, 0.0, 0.0, 0.0];
    final t = ChronofluxPrincipia.transportStressTensor(
      rhoT: rho,
      pressureT: p,
      fourVelocity: u,
    );
    final g = ChronofluxPrincipia.geometricClosure(t);
    for (var mu = 0; mu < 4; mu++) {
      for (var nu = 0; nu < 4; nu++) {
        expect(
          g[mu][nu],
          closeTo(ChronofluxPrincipia.temporalCoupling * t[mu][nu], 1e-12),
        );
      }
    }
  });

  test('conserved neighbor faces have vanishing residuals', () {
    final snap = ChronofluxPrincipia.fromScenarioObservables(
      regressivePct: 42,
      refinedScs: 61,
      shearScs: 55,
      flowScs: 48,
    );
    expect(snap.conserved, isTrue);
    expect(snap.continuityResidual.abs(), lessThan(ChronofluxPrincipia.atol));
    for (final c in snap.stressDivergence) {
      expect(c.abs(), lessThan(ChronofluxPrincipia.atol));
    }
  });

  test('non-conserved neighbor faces are flagged', () {
    final base = ChronofluxPrincipia.fromScenarioObservables(
      regressivePct: 42,
      refinedScs: 61,
      shearScs: 55,
    );
    final neighborT = [
      for (final row in base.stress) [for (final v in row) v + 0.4],
    ];
    final neighborJ = [for (final v in base.current) v + 0.3];
    final flagged = ChronofluxPrincipia.fromScenarioObservables(
      regressivePct: 42,
      refinedScs: 61,
      shearScs: 55,
      neighborStress: neighborT,
      neighborCurrent: neighborJ,
    );
    expect(flagged.conserved, isFalse);
    expect(flagged.continuityResidual.abs(), greaterThan(ChronofluxPrincipia.atol));
  });

  test('percent chance calculator drives shipped Principia identities', () {
    const engine = EvolveEngine();
    const input = ScenarioInput(
      posedQuestion: 'What is the chance of sporadic civil unrest in Glasgow?',
      vortexText: 'Polarised coverage of ward protests.',
      shearText: 'High σ between establishment and grassroots frames.',
      resistanceText: 'Institutional Iτ drag after delayed follow-through.',
      flowText: 'Uneven Jμ trust transport across wards.',
    );
    final result = engine.analyze(input);
    expect(result.principia, isNotNull);
    final snap = result.principia!;
    for (var i = 0; i < 4; i++) {
      expect(snap.current[i], closeTo(snap.rhoT * snap.fourVelocity[i], 1e-12));
    }
    expect(
      result.forecast.heuristicPercent,
      closeTo(ChronofluxPrincipia.percentChanceFromSnapshot(snap), 1e-9),
    );
    expect(result.percentChance, inInclusiveRange(8, 92));

    final continuum = engine.continuumSnapshot(input);
    expect(continuum.principia, isNotNull);
    expect(
      continuum.continuumPercent,
      closeTo(
        ChronofluxPrincipia.percentChanceFromSnapshot(continuum.principia!),
        1e-9,
      ),
    );
  });
}
