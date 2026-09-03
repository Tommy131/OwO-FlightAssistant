import type { FlightLog, FlightLogPoint } from '../models/flight-log-models';

const PROFILE_SECONDS = 10;
const MAX_INTERPOLATION_GAP_MS = 2_500;

export interface LandingFlareSample {
  secondsBeforeTouchdown: number;
  timestamp: Date;
  verticalSpeed?: number;
  radioAltitude?: number;
  pitch?: number;
  roll?: number;
  airspeed?: number;
  groundSpeed?: number;
  heading?: number;
  gForce?: number;
  engine1N1?: number;
  engine2N1?: number;
  onGround?: boolean;
}

type FlareProfileLog = Pick<FlightLog, 'points' | 'landingData'>;

export function buildLandingFlareProfile(log: FlareProfileLog): LandingFlareSample[] {
  const landing = log.landingData;
  if (!landing) return [];

  const touchdownMs = landing.timestamp.getTime();
  const points = log.points
    .filter((point) => {
      const timestamp = point.timestamp.getTime();
      return Number.isFinite(timestamp) && timestamp <= touchdownMs;
    })
    .sort((a, b) => a.timestamp.getTime() - b.timestamp.getTime());

  return Array.from({ length: PROFILE_SECONDS + 1 }, (_, index) => {
    const secondsBeforeTouchdown = PROFILE_SECONDS - index;
    const targetMs = touchdownMs - secondsBeforeTouchdown * 1000;
    const interpolated = interpolatePoint(points, targetMs);
    const sample: LandingFlareSample = {
      secondsBeforeTouchdown,
      timestamp: new Date(targetMs),
      ...interpolated,
    };

    if (secondsBeforeTouchdown === 0) {
      sample.verticalSpeed = finiteOrUndefined(landing.verticalSpeed);
      sample.airspeed = finiteOrUndefined(landing.airspeed);
      sample.groundSpeed = finiteOrUndefined(landing.groundSpeed);
      sample.pitch = finiteOrUndefined(landing.pitch);
      sample.roll = finiteOrUndefined(landing.roll);
      sample.gForce = finiteOrUndefined(landing.gForce);
      sample.onGround = true;
      // The landing event proves surface contact. Historical reports may still
      // contain a small aircraft-specific radio-altimeter installation offset.
      sample.radioAltitude = 0;
    }

    return sample;
  });
}

function interpolatePoint(
  points: readonly FlightLogPoint[],
  targetMs: number,
): Omit<LandingFlareSample, 'secondsBeforeTouchdown' | 'timestamp'> {
  let before: FlightLogPoint | undefined;
  let after: FlightLogPoint | undefined;

  for (const point of points) {
    const pointMs = point.timestamp.getTime();
    if (pointMs === targetMs) return valuesFromPoint(point);
    if (pointMs < targetMs) before = point;
    if (pointMs > targetMs) {
      after = point;
      break;
    }
  }

  if (!before || !after) return {};
  const beforeMs = before.timestamp.getTime();
  const afterMs = after.timestamp.getTime();
  const gapMs = afterMs - beforeMs;
  if (gapMs <= 0 || gapMs > MAX_INTERPOLATION_GAP_MS) return {};

  const ratio = (targetMs - beforeMs) / gapMs;
  return {
    verticalSpeed: interpolate(before.verticalSpeed, after.verticalSpeed, ratio),
    radioAltitude: interpolate(before.radioAltitude, after.radioAltitude, ratio),
    pitch: interpolate(before.pitch, after.pitch, ratio),
    roll: interpolate(before.roll, after.roll, ratio),
    airspeed: interpolate(before.airspeed, after.airspeed, ratio),
    groundSpeed: interpolate(before.groundSpeed, after.groundSpeed, ratio),
    heading: interpolateHeading(before.heading, after.heading, ratio),
    gForce: interpolate(before.gForce, after.gForce, ratio),
    engine1N1: interpolate(before.engine1N1, after.engine1N1, ratio),
    engine2N1: interpolate(before.engine2N1, after.engine2N1, ratio),
    onGround: nearestOnGround(before, after, ratio),
  };
}

function valuesFromPoint(
  point: FlightLogPoint,
): Omit<LandingFlareSample, 'secondsBeforeTouchdown' | 'timestamp'> {
  return {
    verticalSpeed: finiteOrUndefined(point.verticalSpeed),
    radioAltitude: finiteOrUndefined(point.radioAltitude),
    pitch: finiteOrUndefined(point.pitch),
    roll: finiteOrUndefined(point.roll),
    airspeed: finiteOrUndefined(point.airspeed),
    groundSpeed: finiteOrUndefined(point.groundSpeed),
    heading: finiteOrUndefined(point.heading),
    gForce: finiteOrUndefined(point.gForce),
    engine1N1: finiteOrUndefined(point.engine1N1),
    engine2N1: finiteOrUndefined(point.engine2N1),
    onGround: point.onGround,
  };
}

function interpolate(
  from: number | undefined,
  to: number | undefined,
  ratio: number,
): number | undefined {
  if (from === undefined || to === undefined) return undefined;
  if (!Number.isFinite(from) || !Number.isFinite(to)) return undefined;
  return from + (to - from) * ratio;
}

function interpolateHeading(
  from: number | undefined,
  to: number | undefined,
  ratio: number,
): number | undefined {
  if (from === undefined || to === undefined) return undefined;
  if (!Number.isFinite(from) || !Number.isFinite(to)) return undefined;

  const start = normalizeHeading(from);
  const turn = ((normalizeHeading(to) - start + 540) % 360) - 180;
  return normalizeHeading(start + turn * ratio);
}

function nearestOnGround(
  before: FlightLogPoint,
  after: FlightLogPoint,
  ratio: number,
): boolean | undefined {
  const closest = ratio < 0.5 ? before : after;
  const other = ratio < 0.5 ? after : before;
  return closest.onGround ?? other.onGround;
}

function normalizeHeading(heading: number): number {
  return ((heading % 360) + 360) % 360;
}

function finiteOrUndefined(value: number | undefined): number | undefined {
  return value !== undefined && Number.isFinite(value) ? value : undefined;
}
