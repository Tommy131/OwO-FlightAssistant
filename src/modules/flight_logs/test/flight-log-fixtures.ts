import type { FlightLog, FlightLogPoint } from '../models/flight-log-models';

export const FLIGHT_LOG_TEST_START = new Date('2026-08-11T10:00:00.000Z');

export function makeFlightLogPoint(
  offsetMs = 0,
  overrides: Partial<FlightLogPoint> = {},
): FlightLogPoint {
  return {
    latitude: 40,
    longitude: 116,
    altitude: 0,
    airspeed: 0,
    groundSpeed: 0,
    verticalSpeed: 0,
    heading: 0,
    pitch: 0,
    roll: 0,
    gForce: 1,
    gForceSource: 'body',
    fuelQuantity: 100,
    timestamp: new Date(FLIGHT_LOG_TEST_START.getTime() + offsetMs),
    anomalyAlerts: [],
    ...overrides,
  };
}

export function makeFlightLog(
  points: FlightLogPoint[],
  overrides: Partial<FlightLog> = {},
): FlightLog {
  return {
    id: 'test-flight-log',
    aircraftTitle: 'Test Aircraft',
    departureAirport: 'TEST',
    startTime: points[0]?.timestamp ?? FLIGHT_LOG_TEST_START,
    points,
    maxG: 1,
    minG: 1,
    maxAltitude: 0,
    maxAirspeed: 0,
    maxGroundSpeed: 0,
    wasOnGroundAtStart: true,
    wasOnGroundAtEnd: false,
    ...overrides,
  };
}