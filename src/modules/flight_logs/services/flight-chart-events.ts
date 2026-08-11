import type { FlightLog, FlightLogPoint } from '../models/flight-log-models';

export const FLIGHT_CHART_EVENT_TYPES = [
  'takeoff',
  'flapsDeploy',
  'flapsRetract',
  'autopilotLateral',
  'autopilotVertical',
  'gearDown',
  'gearUp',
  'touchdown',
  'finalTouchdown',
] as const;

export type FlightChartEventType =
  (typeof FLIGHT_CHART_EVENT_TYPES)[number];

export interface FlightChartEvent {
  type: FlightChartEventType;
  timestamp: Date;
  pointIndex: number;
  timeMinutes: number;
  detail?: string;
  sequence?: number;
  gForce?: number;
}

const EVENT_ORDER = new Map<FlightChartEventType, number>(
  FLIGHT_CHART_EVENT_TYPES.map((type, index) => [type, index]),
);

const INACTIVE_AUTOPILOT_MODES = new Set(['', 'OFF', '--', 'N/A']);

export function detectFlightChartEvents(log: FlightLog): FlightChartEvent[] {
  if (log.points.length === 0) return [];

  const events: FlightChartEvent[] = [];
  const originMs = (log.points[0]?.timestamp ?? log.startTime).getTime();
  let takeoffCaptured = false;
  let previousFlapsToken = '';
  let previousFlapsLevel: number | undefined;
  let flapsInitialized = false;
  let previousLateralMode = '';
  let previousVerticalMode = '';
  let lateralInitialized = false;
  let verticalInitialized = false;
  let previousGearDown: boolean | undefined;
  let gearInitialized = false;

  const addPointEvent = (
    type: FlightChartEventType,
    point: FlightLogPoint,
    pointIndex: number,
    detail?: string,
  ) => {
    events.push({
      type,
      timestamp: point.timestamp,
      pointIndex,
      timeMinutes: (point.timestamp.getTime() - originMs) / 60_000,
      detail,
    });
  };

  for (const [pointIndex, point] of log.points.entries()) {
    const isRecordedTakeoff =
      log.takeoffData?.timestamp.getTime() === point.timestamp.getTime();
    const isAirborne = (point.onGround ?? log.wasOnGroundAtStart) === false;
    if (!takeoffCaptured && (isRecordedTakeoff || isAirborne)) {
      addPointEvent('takeoff', point, pointIndex);
      takeoffCaptured = true;
    }

    const currentFlapsLevel = flapLevel(point);
    const currentFlapsToken = flapToken(point);
    if (!flapsInitialized) {
      previousFlapsLevel = currentFlapsLevel;
      previousFlapsToken = currentFlapsToken;
      flapsInitialized = true;
    } else if (
      currentFlapsLevel !== undefined &&
      currentFlapsToken.length > 0 &&
      currentFlapsToken !== previousFlapsToken
    ) {
      const type =
        previousFlapsLevel === undefined ||
        currentFlapsLevel > previousFlapsLevel
          ? 'flapsDeploy'
          : 'flapsRetract';
      addPointEvent(type, point, pointIndex, flapLabel(point));
    }

    const currentLateralMode = normalizeAutopilotMode(
      point.autopilotLateralMode,
    );
    if (!lateralInitialized) {
      lateralInitialized = true;
      if (currentLateralMode) {
        addPointEvent(
          'autopilotLateral',
          point,
          pointIndex,
          currentLateralMode,
        );
      }
    } else if (
      currentLateralMode &&
      currentLateralMode !== previousLateralMode
    ) {
      addPointEvent(
        'autopilotLateral',
        point,
        pointIndex,
        currentLateralMode,
      );
    }

    const currentVerticalMode = normalizeAutopilotMode(
      point.autopilotVerticalMode,
    );
    if (!verticalInitialized) {
      verticalInitialized = true;
      if (currentVerticalMode) {
        addPointEvent(
          'autopilotVertical',
          point,
          pointIndex,
          currentVerticalMode,
        );
      }
    } else if (
      currentVerticalMode &&
      currentVerticalMode !== previousVerticalMode
    ) {
      addPointEvent(
        'autopilotVertical',
        point,
        pointIndex,
        currentVerticalMode,
      );
    }

    const currentGearDown = point.gearDown;
    if (!gearInitialized) {
      previousGearDown = currentGearDown;
      gearInitialized = true;
    } else if (
      currentGearDown !== undefined &&
      previousGearDown !== undefined &&
      currentGearDown !== previousGearDown
    ) {
      addPointEvent(
        currentGearDown ? 'gearDown' : 'gearUp',
        point,
        pointIndex,
      );
    }

    previousFlapsLevel = currentFlapsLevel ?? previousFlapsLevel;
    previousFlapsToken = currentFlapsToken;
    previousLateralMode = currentLateralMode;
    previousVerticalMode = currentVerticalMode;
    previousGearDown = currentGearDown ?? previousGearDown;
  }

  addTouchdownEvents(log, events, originMs);

  return events.sort((left, right) => {
    const timestampDifference =
      left.timestamp.getTime() - right.timestamp.getTime();
    if (timestampDifference !== 0) return timestampDifference;
    const typeDifference =
      (EVENT_ORDER.get(left.type) ?? 0) - (EVENT_ORDER.get(right.type) ?? 0);
    if (typeDifference !== 0) return typeDifference;
    return (left.sequence ?? 0) - (right.sequence ?? 0);
  });
}

function addTouchdownEvents(
  log: FlightLog,
  events: FlightChartEvent[],
  originMs: number,
): void {
  const landing = log.landingData;
  if (!landing || landing.touchdownSequence.length === 0) return;

  const touchdownEvents: FlightChartEvent[] = [];
  for (const [index, contact] of landing.touchdownSequence.entries()) {
    const nearest = nearestPoint(log.points, contact.timestamp);
    if (!nearest) continue;
    touchdownEvents.push({
      type: 'touchdown',
      timestamp: nearest.point.timestamp,
      pointIndex: nearest.index,
      timeMinutes:
        (nearest.point.timestamp.getTime() - originMs) / 60_000,
      sequence: index + 1,
      gForce:
        landing.touchdownGForces[index] ??
        contact.touchdownGearG ??
        contact.gForce,
    });
  }

  if (touchdownEvents.length === 1) {
    const onlyContact = touchdownEvents[0];
    events.push({
      ...onlyContact,
      type: 'finalTouchdown',
      gForce: landing.gForce ?? onlyContact.gForce,
    });
    return;
  }

  if (touchdownEvents.length > 1) {
    events.push(...touchdownEvents);
    const finalTimestampMs = landing.timestamp.getTime();
    let finalContact = touchdownEvents[touchdownEvents.length - 1];
    for (const event of touchdownEvents) {
      if (event.timestamp.getTime() === finalTimestampMs) {
        finalContact = event;
      }
    }
    events.push({
      ...finalContact,
      type: 'finalTouchdown',
      sequence: touchdownEvents.length,
      gForce: landing.gForce ?? finalContact.gForce,
    });
  }
}

function nearestPoint(
  points: FlightLogPoint[],
  timestamp: Date,
): { point: FlightLogPoint; index: number } | undefined {
  if (points.length === 0) return undefined;

  let nearestIndex = 0;
  let minimumDifference = Math.abs(
    points[0].timestamp.getTime() - timestamp.getTime(),
  );
  for (let index = 1; index < points.length; index += 1) {
    const difference = Math.abs(
      points[index].timestamp.getTime() - timestamp.getTime(),
    );
    if (difference < minimumDifference) {
      minimumDifference = difference;
      nearestIndex = index;
    }
  }
  return { point: points[nearestIndex], index: nearestIndex };
}

function flapToken(point: FlightLogPoint): string {
  if (point.flapsPosition !== undefined) {
    return String(point.flapsPosition);
  }
  return point.flapsLabel?.trim() ?? '';
}

function flapLabel(point: FlightLogPoint): string {
  const level = flapLevel(point);
  if (level !== undefined) {
    const formatted = Number.isInteger(level)
      ? level.toFixed(0)
      : level.toFixed(1);
    return formatted + '\u00b0';
  }
  const label = point.flapsLabel?.trim();
  return label || '0\u00b0';
}

function flapLevel(point: FlightLogPoint): number | undefined {
  if (point.flapsPosition !== undefined) {
    return point.flapsPosition;
  }

  const label = point.flapsLabel?.trim();
  if (!label) return undefined;
  const normalized = label.toLowerCase();
  if (normalized === 'up' || normalized === '0') return 0;
  const match = /-?\d+(\.\d+)?/.exec(label);
  if (!match) return undefined;
  const value = Number.parseFloat(match[0]);
  return Number.isFinite(value) ? value : undefined;
}

function normalizeAutopilotMode(raw: string | undefined): string {
  const normalized = raw?.trim().toUpperCase() ?? '';
  return INACTIVE_AUTOPILOT_MODES.has(normalized) ? '' : normalized;
}