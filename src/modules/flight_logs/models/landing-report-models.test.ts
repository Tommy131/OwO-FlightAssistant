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
    aircraftTitle: 'Airbus A320neo',
    aircraftType: 'A20N',
    airport: 'EDDF',
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

  it('round-trips aircraft and touchdown-airport identity', () => {
    const decoded = deserializeLandingReport(serializeLandingReport(fixtureLandingReport()));

    expect(decoded).toMatchObject({
      aircraftTitle: 'Airbus A320neo',
      aircraftType: 'A20N',
      airport: 'EDDF',
    });
  });

  it('persists radio altitude source with the compact ras key', () => {
    const encoded = serializeLandingReport(fixtureLandingReport());

    expect(encoded.points).toEqual([expect.objectContaining({ ras: 'radio' })]);
    expect((encoded.landing as { seq: unknown[] }).seq).toEqual([
      expect.objectContaining({ ras: 'radio' }),
    ]);
  });

  it('round-trips the simulator autobrake label used by touchdown configuration', () => {
    const base = fixtureLandingReport();
    const point = { ...base.points[0], autoBrakeLabel: 'MED' };
    const decoded = deserializeLandingReport(serializeLandingReport({
      ...base,
      points: [point],
      landing: base.landing ? { ...base.landing, touchdownSequence: [point] } : undefined,
    }));

    expect(decoded.points[0]).toMatchObject({ autoBrakeLabel: 'MED' });
    expect(decoded.landing?.touchdownSequence[0]).toMatchObject({
      autoBrakeLabel: 'MED',
    });
  });

  it('omits radio altitude source when it is absent', () => {
    const encoded = serializeLandingReport(
      fixtureLandingReport({ points: [makeFlightLogPoint()] }),
    );

    const [point] = encoded.points as JsonMap[];

    expect(point).not.toHaveProperty('ras');
  });

  it.each([
    { caseName: 'missing', rawReason: undefined },
    { caseName: 'malformed', rawReason: { future: true } },
    { caseName: 'forward-version', rawReason: 'automatic_go_around' },
  ])('preserves an unavailable reason when end_reason is $caseName', ({ rawReason }) => {
    const encoded = serializeLandingReport(fixtureLandingReport());
    if (rawReason === undefined) delete encoded.end_reason;
    else encoded.end_reason = rawReason;

    const decoded = deserializeLandingReport(encoded);
    expect(decoded.endReason).toBeUndefined();
    expect(serializeLandingReport(decoded).end_reason).toBeNull();
  });
});
