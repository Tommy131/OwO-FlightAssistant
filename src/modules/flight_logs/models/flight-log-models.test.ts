import { describe, expect, it } from 'vitest';

import { flightLogFromJson, flightLogToJson } from './flight-log-models';
import { makeFlightLog, makeFlightLogPoint } from '../test/flight-log-fixtures';

describe('flight log recording status codec', () => {
  it('loads legacy flight logs as completed', () => {
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

    expect(log.status).toBe('completed');
    expect(log.endReason).toBeUndefined();
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
