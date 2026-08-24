import { describe, expect, it } from 'vitest';

import type { FlightLogPoint } from '../models/flight-log-models';
import { FLIGHT_LOG_TEST_START, makeFlightLogPoint } from '../test/flight-log-fixtures';
import {
  createLandingReportRecorder,
  type LandingReportCaptureContext,
  type LandingRecorderEvent,
  type LandingReportRecorder,
} from './landing-report-recorder';

const BASE_TIME = FLIGHT_LOG_TEST_START.getTime();

function point(offsetMs: number, overrides: Partial<FlightLogPoint> = {}): FlightLogPoint {
  return makeFlightLogPoint(offsetMs, {
    onGround: false,
    radioAltitude: 3_000,
    radioAltitudeSource: 'radio',
    gearDown: false,
    airspeed: 130,
    groundSpeed: 125,
    verticalSpeed: -500,
    ...overrides,
  });
}

function harness(): {
  recorder: LandingReportRecorder;
  push: (
    offsetMs: number,
    overrides?: Partial<FlightLogPoint>,
    context?: LandingReportCaptureContext,
  ) => LandingRecorderEvent[];
  advanceTo: (offsetMs: number) => void;
} {
  let now = BASE_TIME;
  const recorder = createLandingReportRecorder({
    now: () => now,
    createId: () => 'landing-report-test',
    simulator: 'MSFS 2024',
  });
  return {
    recorder,
    push(offsetMs, overrides, context) {
      now = BASE_TIME + offsetMs;
      return recorder.push(point(offsetMs, overrides), context);
    },
    advanceTo(offsetMs) {
      now = BASE_TIME + offsetMs;
    },
  };
}

function onlyFinalizedReport(events: LandingRecorderEvent[]) {
  expect(events).toHaveLength(1);
  expect(events[0]?.type).toBe('finalize');
  return events[0].report;
}

describe('automatic landing report recorder', () => {
  it('does not create a cruise disconnect report before approach arming', () => {
    const { recorder, push } = harness();

    push(0, { onGround: false, radioAltitude: 12_000 });

    expect(recorder.hasActiveWork()).toBe(false);
    expect(recorder.disconnect()).toEqual([]);
  });

  it('waits for an airborne observation instead of treating startup-on-ground as a landing', () => {
    const { recorder, push } = harness();

    push(0, { onGround: true, radioAltitude: 0, gearDown: true });
    push(15_000, { onGround: true, radioAltitude: 0, gearDown: true });

    expect(recorder.hasActiveWork()).toBe(false);
    expect(recorder.disconnect()).toEqual([]);
  });

  it.each([
    ['resolved height', { radioAltitude: 2_500, gearDown: false }],
    ['landing gear', { radioAltitude: 8_000, gearDown: true }],
  ] as const)('arms while airborne using %s', (_case, armingPoint) => {
    const { recorder, push } = harness();

    push(0, { onGround: false, ...armingPoint });

    expect(recorder.hasActiveWork()).toBe(true);
  });

  it('does not arm from invalid resolved height alone', () => {
    const { recorder, push } = harness();

    push(0, { onGround: false, radioAltitude: Number.NaN, gearDown: false });

    expect(recorder.hasActiveWork()).toBe(false);
    expect(recorder.stop()).toEqual([]);
  });

  it('exposes no recoverable report for buffering discarded by a ground reset', () => {
    const { recorder, push } = harness();

    push(0, { onGround: false, radioAltitude: 12_000 });
    expect(recorder.getRecoverableReport()).toBeUndefined();
    push(1_000, { onGround: true, radioAltitude: 0 });

    expect(recorder.getRecoverableReport()).toBeUndefined();
  });

  it('exposes the exact trimmed recoverable points with the final report identity', () => {
    const { recorder, push } = harness();

    push(0, { radioAltitude: 12_000 });
    push(10_000, { radioAltitude: 8_000 });
    push(70_000, { radioAltitude: 2_500 });

    const active = recorder.getRecoverableReport();
    expect(active?.id).toBe('landing-report-test');
    expect(active?.points.map((item) => item.timestamp.getTime())).toEqual([
      BASE_TIME + 10_000,
      BASE_TIME + 70_000,
    ]);

    const finalized = onlyFinalizedReport(recorder.stop());
    expect(finalized.id).toBe(active?.id);
    expect(finalized.createdAt).toBe(active?.createdAt);
  });

  it('keeps exactly the rolling minute before touchdown and fifteen seconds after touchdown', () => {
    const { push } = harness();

    push(0, { radioAltitude: 4_000 });
    push(29_999, { radioAltitude: 3_000 });
    push(30_000, { radioAltitude: 2_500 });
    push(60_000, { radioAltitude: 1_000 });
    push(89_000, { radioAltitude: 20 });
    push(90_000, { onGround: true, radioAltitude: 0, verticalSpeed: -50 });
    expect(push(104_999, { onGround: true, radioAltitude: 0, verticalSpeed: 0 })).toEqual([]);

    const report = onlyFinalizedReport(
      push(105_000, { onGround: true, radioAltitude: 0, verticalSpeed: 0 }),
    );

    expect(report.points[0].timestamp.getTime()).toBe(BASE_TIME + 30_000);
    expect(report.touchdownAt).toBe(BASE_TIME + 90_000);
    expect(report.endedAt).toBe(BASE_TIME + 105_000);
    expect(report.status).toBe('completed');
    expect(report.endReason).toBe('stable_landing');
  });

  it('merges a short bounce into one completed landing report', () => {
    const { push } = harness();

    push(0, { radioAltitude: 500 });
    push(1_000, { onGround: true, radioAltitude: 0, gForce: 1.2 });
    push(2_000, { onGround: false, radioAltitude: 5 });
    push(6_000, { onGround: true, radioAltitude: 0, gForce: 1.4 });

    const report = onlyFinalizedReport(push(21_000, { onGround: true, radioAltitude: 0 }));

    expect(report.endReason).toBe('stable_landing');
    expect(report.landing?.touchdownSequence).toHaveLength(2);
    expect(report.landing?.bounceCount).toBe(1);
  });

  it('finalizes a touch-and-go only after more than ten airborne seconds', () => {
    const { push } = harness();

    push(0, { radioAltitude: 500 });
    push(1_000, { onGround: true, radioAltitude: 0 });
    push(2_000, { onGround: false, radioAltitude: 10 });
    expect(push(12_000, { onGround: false, radioAltitude: 1_000 })).toEqual([]);

    const report = onlyFinalizedReport(
      push(12_001, { onGround: false, radioAltitude: 1_001 }),
    );

    expect(report.endReason).toBe('touch_and_go');
    expect(report.status).toBe('completed');
  });

  it('preserves the airborne suffix as history for the landing after a touch-and-go', () => {
    const { push } = harness();

    push(0, { radioAltitude: 500 });
    push(1_000, { onGround: true, radioAltitude: 0 });
    push(2_000, { onGround: false, radioAltitude: 10 });
    push(7_000, { onGround: false, radioAltitude: 500 });
    onlyFinalizedReport(push(12_001, { onGround: false, radioAltitude: 1_000 }));
    push(13_000, { onGround: true, radioAltitude: 0 });

    const nextReport = onlyFinalizedReport(
      push(28_000, { onGround: true, radioAltitude: 0 }),
    );

    expect(nextReport.startedAt).toBe(BASE_TIME + 2_000);
  });

  it('preserves capture identity on an airborne touch-and-go rollover before another sample', () => {
    const { recorder, push } = harness();
    const context = {
      aircraftTitle: 'Airbus A320neo',
      aircraftType: 'A20N',
      airport: 'EDDF',
    };

    push(0, { radioAltitude: 500 }, context);
    push(1_000, { onGround: true, radioAltitude: 0 }, context);
    push(2_000, { onGround: false, radioAltitude: 10 }, context);
    onlyFinalizedReport(
      push(12_001, { onGround: false, radioAltitude: 1_000 }, context),
    );

    expect(recorder.getRecoverableReport()).toMatchObject(context);
  });

  it('separates a new touchdown first observed just beyond the airborne cutoff', () => {
    const { push } = harness();

    push(0, { radioAltitude: 500 });
    push(1_000, { onGround: true, radioAltitude: 0 });
    push(2_000, { onGround: false, radioAltitude: 10 });
    expect(push(12_000, { onGround: false, radioAltitude: 1_000 })).toEqual([]);

    const touchAndGo = onlyFinalizedReport(
      push(12_001, { onGround: true, radioAltitude: 0 }),
    );
    const nextLanding = onlyFinalizedReport(
      push(27_001, { onGround: true, radioAltitude: 0 }),
    );

    expect(touchAndGo.endReason).toBe('touch_and_go');
    expect(nextLanding.touchdownAt).toBe(BASE_TIME + 12_001);
    expect(nextLanding.landing?.touchdownSequence).toHaveLength(1);
  });

  it('retains the last known ground state when a sample omits onGround', () => {
    const { push } = harness();

    push(0, { onGround: false, radioAltitude: 500 });
    push(500, { onGround: undefined, radioAltitude: 50 });
    push(1_000, { onGround: true, radioAltitude: 0 });

    const report = onlyFinalizedReport(push(16_000, { onGround: true, radioAltitude: 0 }));

    expect(report.touchdownAt).toBe(BASE_TIME + 1_000);
  });

  it('does not advance stable-ground time while paused', () => {
    const { recorder, push, advanceTo } = harness();

    push(0, { radioAltitude: 500 });
    push(1_000, { onGround: true, radioAltitude: 0 });
    advanceTo(2_000);
    recorder.pause();
    advanceTo(22_000);
    expect(push(22_000, { onGround: true, radioAltitude: 0 })).toEqual([]);
    recorder.resume();
    expect(push(35_999, { onGround: true, radioAltitude: 0 })).toEqual([]);

    onlyFinalizedReport(push(36_000, { onGround: true, radioAltitude: 0 }));
  });

  it('does not advance airborne touch-and-go time while paused', () => {
    const { recorder, push, advanceTo } = harness();

    push(0, { radioAltitude: 500 });
    push(1_000, { onGround: true, radioAltitude: 0 });
    push(2_000, { onGround: false, radioAltitude: 10 });
    advanceTo(3_000);
    recorder.pause();
    advanceTo(23_000);
    recorder.resume();
    expect(push(32_000, { onGround: false, radioAltitude: 1_000 })).toEqual([]);

    const report = onlyFinalizedReport(
      push(32_001, { onGround: false, radioAltitude: 1_001 }),
    );
    expect(report.endReason).toBe('touch_and_go');
  });

  it.each([
    ['disconnect', 'simulator_disconnected'],
    ['stop', 'user_stopped'],
  ] as const)('preserves armed samples on %s', (method, reason) => {
    const { recorder, push } = harness();
    push(0, { radioAltitude: 2_500 });
    push(1_000, { radioAltitude: 2_000 });

    const report = onlyFinalizedReport(recorder[method]());

    expect(report.status).toBe('incomplete');
    expect(report.endReason).toBe(reason);
    expect(report.points).toHaveLength(2);
    expect(recorder.hasActiveWork()).toBe(false);
  });

  it('ends an interrupted report at the injected interruption time', () => {
    const { recorder, push, advanceTo } = harness();
    push(0, { radioAltitude: 2_500 });
    advanceTo(5_000);

    const report = onlyFinalizedReport(recorder.disconnect());

    expect(report.endedAt).toBe(BASE_TIME + 5_000);
  });

  it.each(['touchdown_candidate', 'post_touchdown'] as const)(
    'preserves and idempotently finalizes the %s state on disconnect',
    (activeState) => {
      const { recorder, push } = harness();
      push(0, { radioAltitude: 500 });
      push(1_000, { onGround: true, radioAltitude: 0 });
      if (activeState === 'touchdown_candidate') {
        push(2_000, { onGround: false, radioAltitude: 5 });
      } else {
        push(2_000, { onGround: true, radioAltitude: 0 });
      }

      const report = onlyFinalizedReport(recorder.disconnect());

      expect(report.status).toBe('incomplete');
      expect(report.endReason).toBe('simulator_disconnected');
      expect(report.landing).toBeDefined();
      expect(recorder.disconnect()).toEqual([]);
      expect(recorder.stop()).toEqual([]);
    },
  );
});
