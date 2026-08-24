import type { FlightLogPoint } from '../models/flight-log-models';
import type { LandingReport } from '../models/landing-report-models';
import type { RecordingEndReason } from '../models/recording-status';
import {
  buildLandingDataFromTouchdowns,
  hasElapsedAtLeast,
  hasElapsedMoreThan,
  isTouchdownTransition,
} from './takeoff-landing-metrics';

type RecorderState =
  | 'idle'
  | 'buffering'
  | 'armed'
  | 'touchdown_candidate'
  | 'post_touchdown';

export interface LandingRecorderEvent {
  type: 'finalize';
  report: LandingReport;
}

export interface LandingReportRecorder {
  push(point: FlightLogPoint): LandingRecorderEvent[];
  pause(): void;
  resume(): void;
  disconnect(): LandingRecorderEvent[];
  stop(): LandingRecorderEvent[];
  hasActiveWork(): boolean;
}

export interface LandingReportRecorderOptions {
  now: () => number;
  createId?: () => string;
  simulator?: string;
}

export const PRE_TOUCHDOWN_MS = 60_000;
export const POST_STABLE_MS = 15_000;
export const TOUCH_AND_GO_MS = 10_000;
export const ARM_HEIGHT_FT = 2_500;

export function createLandingReportRecorder(
  options: LandingReportRecorderOptions,
): LandingReportRecorder {
  let state: RecorderState = 'idle';
  let points: FlightLogPoint[] = [];
  let touchdownIndexes: number[] = [];
  let lastOnGround: boolean | undefined;
  let finalTouchdownAt: number | undefined;
  let airborneSince: number | undefined;
  let airborneStartIndex: number | undefined;
  let pausedAt: number | undefined;

  function reset(): void {
    state = 'idle';
    points = [];
    touchdownIndexes = [];
    lastOnGround = undefined;
    finalTouchdownAt = undefined;
    airborneSince = undefined;
    airborneStartIndex = undefined;
    pausedAt = undefined;
  }

  function trimRollingBuffer(referenceTime: number): void {
    const cutoff = referenceTime - PRE_TOUCHDOWN_MS;
    let firstKept = 0;
    while (
      firstKept < points.length &&
      points[firstKept].timestamp.getTime() < cutoff
    ) {
      firstKept += 1;
    }
    if (firstKept > 0) points.splice(0, firstKept);
  }

  function canArm(point: FlightLogPoint): boolean {
    const height = point.radioAltitude;
    const lowEnough =
      height !== undefined &&
      Number.isFinite(height) &&
      height >= 0 &&
      height <= ARM_HEIGHT_FT;
    return point.onGround === false && (lowEnough || point.gearDown === true);
  }

  function finalize(
    status: LandingReport['status'],
    endReason: RecordingEndReason,
    endAt: 'last_point' | 'now' = 'last_point',
  ): LandingRecorderEvent[] {
    if (points.length === 0) {
      reset();
      return [];
    }

    const createdAt = options.now();
    const landing = buildLandingDataFromTouchdowns(points, touchdownIndexes);
    const report: LandingReport = {
      id: options.createId?.() ?? crypto.randomUUID(),
      simulator: options.simulator ?? 'Unknown',
      startedAt: points[0].timestamp.getTime(),
      endedAt:
        endAt === 'now' ? createdAt : points[points.length - 1].timestamp.getTime(),
      touchdownAt: landing?.timestamp.getTime(),
      status,
      endReason,
      points: [...points],
      landing,
      createdAt,
      updatedAt: createdAt,
    };
    reset();
    return [{ type: 'finalize', report }];
  }

  function restartAfterTouchAndGo(nextPoints: FlightLogPoint[]): void {
    points = nextPoints;
    touchdownIndexes = [];
    lastOnGround = false;
    finalTouchdownAt = undefined;
    airborneSince = undefined;
    airborneStartIndex = undefined;
    const latest = points[points.length - 1];
    trimRollingBuffer(latest.timestamp.getTime());
    state = points.some(canArm) ? 'armed' : 'buffering';
  }

  function push(point: FlightLogPoint): LandingRecorderEvent[] {
    if (pausedAt !== undefined) return [];
    const timestamp = point.timestamp.getTime();

    if (state === 'idle') {
      if (point.onGround !== false) return [];
      points = [point];
      lastOnGround = false;
      state = canArm(point) ? 'armed' : 'buffering';
      trimRollingBuffer(timestamp);
      return [];
    }

    points.push(point);
    const previousOnGround = lastOnGround;
    if (point.onGround !== undefined) lastOnGround = point.onGround;

    if (touchdownIndexes.length === 0) trimRollingBuffer(timestamp);
    else trimRollingBuffer(points[touchdownIndexes[0]].timestamp.getTime());

    if (state === 'buffering') {
      if (point.onGround === true) {
        reset();
        return [];
      }
      if (canArm(point)) state = 'armed';
      return [];
    }

    if (state === 'armed') {
      if (isTouchdownTransition(previousOnGround, point.onGround)) {
        touchdownIndexes.push(points.length - 1);
        finalTouchdownAt = timestamp;
        airborneSince = undefined;
        state = 'touchdown_candidate';
      }
      return [];
    }

    if (
      point.onGround === true &&
      hasElapsedMoreThan(airborneSince, timestamp, TOUCH_AND_GO_MS)
    ) {
      const nextPoints = points.slice(airborneStartIndex ?? points.length - 1, -1);
      points.pop();
      const events = finalize('completed', 'touch_and_go', 'now');
      restartAfterTouchAndGo(nextPoints);
      return [...events, ...push(point)];
    }

    if (point.onGround === false) {
      if (airborneSince === undefined) {
        airborneSince = timestamp;
        airborneStartIndex = points.length - 1;
      }
      state = 'touchdown_candidate';
      if (hasElapsedMoreThan(airborneSince, timestamp, TOUCH_AND_GO_MS)) {
        const nextPoints = points.slice(airborneStartIndex ?? points.length - 1);
        const events = finalize('completed', 'touch_and_go');
        restartAfterTouchAndGo(nextPoints);
        return events;
      }
      return [];
    }

    if (isTouchdownTransition(previousOnGround, point.onGround)) {
      touchdownIndexes.push(points.length - 1);
      finalTouchdownAt = timestamp;
      airborneSince = undefined;
      airborneStartIndex = undefined;
    }

    if (point.onGround === true) {
      state = 'post_touchdown';
      if (
        hasElapsedAtLeast(finalTouchdownAt, timestamp, POST_STABLE_MS)
      ) {
        return finalize('completed', 'stable_landing');
      }
    }
    return [];
  }

  function pause(): void {
    if (pausedAt === undefined) pausedAt = options.now();
  }

  function resume(): void {
    if (pausedAt === undefined) return;
    const pausedDuration = Math.max(0, options.now() - pausedAt);
    if (finalTouchdownAt !== undefined) finalTouchdownAt += pausedDuration;
    if (airborneSince !== undefined) airborneSince += pausedDuration;
    pausedAt = undefined;
  }

  function interrupt(endReason: Extract<RecordingEndReason, 'simulator_disconnected' | 'user_stopped'>) {
    if (state === 'idle' || state === 'buffering') {
      reset();
      return [];
    }
    return finalize('incomplete', endReason, 'now');
  }

  return {
    push,
    pause,
    resume,
    disconnect: () => interrupt('simulator_disconnected'),
    stop: () => interrupt('user_stopped'),
    hasActiveWork: () =>
      state === 'armed' || state === 'touchdown_candidate' || state === 'post_touchdown',
  };
}
