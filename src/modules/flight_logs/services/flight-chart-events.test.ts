import { describe, expect, it } from 'vitest';
import type { FlightLog, FlightLogPoint } from '../models/flight-log-models';
import { makeFlightLog, makeFlightLogPoint } from '../test/flight-log-fixtures';
import {
  detectFlightChartEvents,
  type FlightChartEvent,
} from './flight-chart-events';

function contactAt(offsetMs: number, gForce: number): FlightLogPoint {
  return makeFlightLogPoint(offsetMs, {
    gForce,
    touchdownGearG: gForce,
    onGround: true,
  });
}

function landingLogWithContacts(
  contacts: FlightLogPoint[],
  overrides: Partial<FlightLog> = {},
): FlightLog {
  const points = overrides.points ?? contacts;
  const finalContact = contacts.at(-1) ?? makeFlightLogPoint();
  return makeFlightLog(points, {
    ...overrides,
    landingData: {
      latitude: finalContact.latitude,
      longitude: finalContact.longitude,
      gForce: finalContact.touchdownGearG ?? finalContact.gForce,
      gForceSource: finalContact.gForceSource,
      verticalSpeed: finalContact.verticalSpeed,
      airspeed: finalContact.airspeed,
      groundSpeed: finalContact.groundSpeed,
      pitch: finalContact.pitch,
      roll: finalContact.roll,
      rating: 'good',
      timestamp: finalContact.timestamp,
      touchdownSequence: contacts,
      touchdownGForces: contacts.map(
        (point) => point.touchdownGearG ?? point.gForce,
      ),
    },
  });
}

function isTouchdown(event: FlightChartEvent): boolean {
  return event.type === 'touchdown' || event.type === 'finalTouchdown';
}

describe('detectFlightChartEvents', () => {
  it('detects takeoff, flap direction, AP mode changes and gear transitions', () => {
    const events = detectFlightChartEvents(makeFlightLog([
      makeFlightLogPoint(0, {
        onGround: true,
        flapsPosition: 0,
        gearDown: true,
      }),
      makeFlightLogPoint(1_000, {
        onGround: false,
        flapsPosition: 5,
        gearDown: true,
        autopilotLateralMode: 'LNAV',
        autopilotVerticalMode: 'VNAV',
      }),
      makeFlightLogPoint(2_000, {
        onGround: false,
        flapsPosition: 0,
        gearDown: false,
        autopilotLateralMode: 'HDG',
        autopilotVerticalMode: 'ALT',
      }),
      makeFlightLogPoint(3_000, {
        onGround: false,
        flapsPosition: 0,
        gearDown: true,
        autopilotLateralMode: 'HDG',
        autopilotVerticalMode: 'ALT',
      }),
    ]));

    expect(events.map((event) => event.type)).toEqual([
      'takeoff',
      'flapsDeploy',
      'autopilotLateral',
      'autopilotVertical',
      'flapsRetract',
      'autopilotLateral',
      'autopilotVertical',
      'gearUp',
      'gearDown',
    ]);
  });

  it('emits only finalTouchdown for a single landing contact', () => {
    const log = landingLogWithContacts([contactAt(5_000, 1.12)]);

    expect(
      detectFlightChartEvents(log).filter(isTouchdown).map((event) => event.type),
    ).toEqual(['finalTouchdown']);
  });

  it('emits each contact and a final marker for multiple contacts', () => {
    const log = landingLogWithContacts([
      contactAt(5_000, 1.34),
      contactAt(7_000, 1.08),
    ]);

    expect(
      detectFlightChartEvents(log).filter(isTouchdown).map((event) => event.type),
    ).toEqual(['touchdown', 'touchdown', 'finalTouchdown']);
  });

  it('parses flap labels and ignores inactive AP tokens', () => {
    const events = detectFlightChartEvents(makeFlightLog([
      makeFlightLogPoint(0, {
        flapsLabel: 'UP',
        autopilotLateralMode: '--',
      }),
      makeFlightLogPoint(1_000, {
        flapsLabel: '5\u00b0',
        autopilotLateralMode: ' lnav ',
      }),
      makeFlightLogPoint(2_000, {
        flapsLabel: '0',
        autopilotLateralMode: 'N/A',
      }),
      makeFlightLogPoint(3_000, {
        flapsLabel: '0',
        autopilotLateralMode: 'OFF',
      }),
    ]));

    expect(
      events
        .filter((event) => event.type.startsWith('flaps'))
        .map((event) => [event.type, event.detail]),
    ).toEqual([
      ['flapsDeploy', '5\u00b0'],
      ['flapsRetract', '0\u00b0'],
    ]);
    expect(
      events
        .filter((event) => event.type === 'autopilotLateral')
        .map((event) => event.detail),
    ).toEqual(['LNAV']);
  });

  it('matches landing timestamps to the nearest point and sorts simultaneous types', () => {
    const log = landingLogWithContacts(
      [contactAt(1_450, 1.31), contactAt(2_450, 1.07)],
      {
        points: [
          makeFlightLogPoint(0),
          makeFlightLogPoint(1_000),
          makeFlightLogPoint(2_000),
          makeFlightLogPoint(3_000),
        ],
      },
    );

    const events = detectFlightChartEvents(log).filter(isTouchdown);

    expect(events.map((event) => event.pointIndex)).toEqual([1, 2, 2]);
    expect(events.map((event) => event.type)).toEqual([
      'touchdown',
      'touchdown',
      'finalTouchdown',
    ]);
  });

  it('uses the first point as the event time origin', () => {
    const events = detectFlightChartEvents(makeFlightLog([
      makeFlightLogPoint(60_000, { onGround: true }),
      makeFlightLogPoint(180_000, { onGround: false }),
    ]));

    expect(events.find((event) => event.type === 'takeoff')?.timeMinutes).toBe(2);
  });

  it('returns no events for a log without points or landing contacts', () => {
    expect(detectFlightChartEvents(makeFlightLog([]))).toEqual([]);
  });
});