import { describe, expect, it } from 'vitest';

import {
  flightLogFromJson,
  flightLogIsCompleted,
  flightLogToJson,
} from './flight-log-models';
import { makeFlightLog, makeFlightLogPoint } from '../test/flight-log-fixtures';

describe('flight log recording status codec', () => {
  it('uses the legacy arrival-and-ground heuristic only when structured status is absent', () => {
    const legacyFlightLogJson = {
      id: 'legacy-flight-log',
      aircraft: 'A320',
      departure: 'EDDF',
      start: '2026-08-24T10:00:00.000Z',
      max_g: 1,
      min_g: 1,
      max_alt: 0,
      max_spd: 0,
      max_gs: 0,
      ground_start: true,
      ground_end: true,
      points: [],
    };

    const log = flightLogFromJson(legacyFlightLogJson);

    expect(log.status).toBeUndefined();
    expect(log.endReason).toBeUndefined();
    expect(flightLogIsCompleted(log)).toBe(false);
  });

  it('preserves an absent structured status when an incomplete legacy log is round-tripped', () => {
    const legacyIncomplete = flightLogFromJson({
      id: 'legacy-incomplete',
      aircraft: 'A320',
      departure: 'EDDF',
      start: '2026-08-24T10:00:00.000Z',
      max_g: 1,
      min_g: 1,
      max_alt: 1_000,
      max_spd: 180,
      max_gs: 170,
      ground_start: true,
      ground_end: false,
      points: [],
    });

    const roundTripped = flightLogFromJson(flightLogToJson(legacyIncomplete));

    expect(roundTripped.status).toBeUndefined();
    expect(flightLogIsCompleted(roundTripped)).toBe(false);
  });

  it('treats structured incomplete status as authoritative even when the legacy heuristic completes', () => {
    const log = makeFlightLog([makeFlightLogPoint(0, { onGround: true })], {
      arrivalAirport: 'EGLL',
      wasOnGroundAtEnd: true,
      status: 'incomplete',
      endReason: 'user_stopped',
    });

    expect(flightLogIsCompleted(log)).toBe(false);
  });

  it('round-trips recording status and end reason', () => {
    const log = makeFlightLog([makeFlightLogPoint()], {
      status: 'incomplete',
      endReason: 'page_closed',
    });

    expect(flightLogFromJson(flightLogToJson(log))).toMatchObject({
      status: 'incomplete',
      endReason: 'page_closed',
    });
  });
});
