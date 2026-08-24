import { describe, expect, it } from 'vitest';

import type { JsonMap } from '../../../core/utils/parse-utils';
import {
  deserializeLandingReport,
  serializeLandingReport,
  type LandingReport,
} from './landing-report-models';
import { makeFlightLogPoint } from '../test/flight-log-fixtures';

function fixtureLandingReport(overrides: Partial<LandingReport> = {}): LandingReport {
  const point = makeFlightLogPoint(0, { radioAltitude: 42, radioAltitudeSource: 'radio' });
  return {
    id: 'landing-report-1',
    simulator: 'MSFS',
    startedAt: 1_000,
    endedAt: 2_000,
    touchdownAt: 1_500,
    status: 'completed',
    endReason: 'stable_landing',
    points: [point],
    landing: {
      latitude: point.latitude,
      longitude: point.longitude,
      gForce: 1.2,
      gForceSource: 'body',
      verticalSpeed: -120,
      airspeed: 130,
      groundSpeed: 125,
      pitch: 2,
      roll: 1,
      rating: 'butter',
      timestamp: point.timestamp,
      touchdownSequence: [point],
      touchdownGForces: [1.2],
    },
    createdAt: 3_000,
    updatedAt: 4_000,
    ...overrides,
  };
}

describe('landing report codec', () => {
  it('round-trips an incomplete landing report', () => {
    const report = fixtureLandingReport({
      status: 'incomplete',
      endReason: 'simulator_disconnected',
    });

    expect(deserializeLandingReport(serializeLandingReport(report))).toEqual(report);
  });

  it('persists radio altitude source with the compact ras key', () => {
    const encoded = serializeLandingReport(fixtureLandingReport());

    expect(encoded.points).toEqual([expect.objectContaining({ ras: 'radio' })]);
    expect((encoded.landing as { seq: unknown[] }).seq).toEqual([
      expect.objectContaining({ ras: 'radio' }),
    ]);
  });

  it('omits radio altitude source when it is absent', () => {
    const encoded = serializeLandingReport(
      fixtureLandingReport({ points: [makeFlightLogPoint()] }),
    );

    const [point] = encoded.points as JsonMap[];

    expect(point).not.toHaveProperty('ras');
  });
});
