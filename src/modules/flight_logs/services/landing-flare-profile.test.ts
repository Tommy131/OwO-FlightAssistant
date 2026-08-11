import { describe, expect, it } from 'vitest';

import type { FlightLogPoint, LandingData } from '../models/flight-log-models';
import { buildLandingFlareProfile } from './landing-flare-profile';

const START_MS = new Date('2026-08-11T10:00:00Z').getTime();

function point(second: number, verticalSpeed: number): FlightLogPoint {
  return {
    latitude: 40,
    longitude: 116,
    altitude: 1000 + (10 - second) * 10,
    airspeed: 140 - second,
    groundSpeed: 138 - second,
    verticalSpeed,
    heading: 180,
    pitch: second / 2,
    roll: second / 10,
    gForce: 1,
    gForceSource: 'body',
    fuelQuantity: 8000,
    radioAltitude: 100 - second * 10,
    onGround: second >= 10,
    timestamp: new Date(START_MS + second * 1000),
    anomalyAlerts: [],
  };
}

function landing(overrides: Partial<LandingData> = {}): LandingData {
  return {
    latitude: 40,
    longitude: 116,
    gForce: 1.2,
    gForceSource: 'body',
    verticalSpeed: -180,
    airspeed: 130,
    groundSpeed: 128,
    pitch: 5,
    roll: 1,
    rating: 'good',
    timestamp: new Date(START_MS + 10_000),
    touchdownSequence: [],
    touchdownGForces: [],
    ...overrides,
  };
}

describe('landing flare profile', () => {
  it('resamples the ten seconds before touchdown into eleven one-second rows', () => {
    const points = [0, 2, 4, 6, 8, 10].map((second) =>
      point(second, -700 + second * 50),
    );

    const profile = buildLandingFlareProfile({ points, landingData: landing() });

    expect(profile.map((sample) => sample.secondsBeforeTouchdown)).toEqual([
      10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0,
    ]);
    expect(profile[5].verticalSpeed).toBe(-450);
    expect(profile[5].radioAltitude).toBe(50);
    expect(profile[5].pitch).toBe(2.5);
  });

  it('uses the captured pre-contact sink rate for the touchdown row', () => {
    const profile = buildLandingFlareProfile({
      points: [point(9, -260), point(10, -20)],
      landingData: landing({ verticalSpeed: -180 }),
    });

    expect(profile.at(-1)).toMatchObject({
      secondsBeforeTouchdown: 0,
      verticalSpeed: -180,
      airspeed: 130,
      pitch: 5,
    });
  });

  it('preserves the recorder telemetry fields for each resampled row', () => {
    const profile = buildLandingFlareProfile({
      points: [
        {
          ...point(4, -500),
          heading: 359,
          gForce: 1.04,
          engine1N1: 52,
          engine2N1: 53,
          onGround: false,
        },
        {
          ...point(6, -400),
          heading: 1,
          gForce: 1.16,
          engine1N1: 60,
          engine2N1: 61,
          onGround: false,
        },
        {
          ...point(10, -100),
          heading: 3,
          gForce: 1.1,
          engine1N1: 65,
          engine2N1: 66,
          onGround: true,
        },
      ],
      landingData: landing({ gForce: 1.2 }),
    });

    expect(profile.find((sample) => sample.secondsBeforeTouchdown === 5)).toMatchObject({
      heading: 0,
      gForce: 1.1,
      engine1N1: 56,
      engine2N1: 57,
      onGround: false,
    });
    expect(profile.at(-1)).toMatchObject({ gForce: 1.2, onGround: true });
  });

  it('does not invent values across a telemetry gap', () => {
    const profile = buildLandingFlareProfile({
      points: [point(0, -700), point(10, -20)],
      landingData: landing(),
    });

    const missing = profile.find((sample) => sample.secondsBeforeTouchdown === 5);
    expect(missing?.verticalSpeed).toBeUndefined();
    expect(missing?.radioAltitude).toBeUndefined();
  });

  it('returns no profile when the recording contains no landing', () => {
    expect(buildLandingFlareProfile({ points: [point(0, -700)] })).toEqual([]);
  });
});
