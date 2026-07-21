/**
 * Tests for flokkinet SCS integration — drives shipped scs modules.
 */

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { scoreSocialCohesion } from './scs/scs_engine.js';
import { burnhamScenario } from './scs/scenario_burnham.js';
import { runScore } from './scs/routes.js';

describe('flokkinet scs engine (shipped)', () => {
  it('scores Burnham scenario via perc_chain copy', () => {
    const r = scoreSocialCohesion(burnhamScenario());
    assert.ok(r.refinedScs >= 0 && r.refinedScs <= 100);
    assert.ok(r.constructs.omega != null);
    assert.ok(r.partOne && r.partTwo && r.partThree);
  });

  it('runScore with construe fills blanks only', async () => {
    const r = await runScore(
      {
        vortexText: 'LOCKED V',
        shearText: '',
        flowText: '',
        resistanceText: 'LOCKED R',
        construe: true,
      },
      { construe: true },
    );
    assert.equal(r.scenario.fields.v, 'LOCKED V');
    assert.equal(r.scenario.fields.r, 'LOCKED R');
    assert.ok(r.scenario.fields.s.trim().length > 0);
    assert.ok(r.refinedScs >= 0 && r.refinedScs <= 100);
  });
});
