// @vitest-environment jsdom
import { afterEach, describe, expect, it, vi } from 'vitest';

import { installRecordingUnloadGuard } from './recording-lifecycle';

const noSubscription = (): (() => void) => () => undefined;

describe('installRecordingUnloadGuard', () => {
  const cleanups: Array<() => void> = [];

  afterEach(() => {
    cleanups.splice(0).forEach((cleanup) => cleanup());
  });

  it.each([
    { flightActive: true, landingActive: false },
    { flightActive: false, landingActive: true },
  ])(
    'prompts and flushes when durable work is active: $flightActive/$landingActive',
    ({ flightActive, landingActive }) => {
      const flush = vi.fn().mockResolvedValue(undefined);
      cleanups.push(
        installRecordingUnloadGuard({
          flightActive: () => flightActive,
          landingActive: () => landingActive,
          subscribeFlightActive: noSubscription,
          subscribeLandingActive: noSubscription,
          flush,
        }),
      );
      const event = new Event('beforeunload', {
        cancelable: true,
      });
      let assignedReturnValue: unknown;
      Object.defineProperty(event, 'returnValue', {
        configurable: true,
        get: () => assignedReturnValue ?? true,
        set: (value: unknown) => {
          assignedReturnValue = value;
        },
      });

      window.dispatchEvent(event);

      expect(event.defaultPrevented).toBe(true);
      expect(assignedReturnValue).toBe('');
      expect(flush).toHaveBeenCalledTimes(1);
    },
  );

  it('does not prompt or flush when both recorders are idle', () => {
    const flush = vi.fn().mockResolvedValue(undefined);
    cleanups.push(
      installRecordingUnloadGuard({
        flightActive: () => false,
        landingActive: () => false,
        subscribeFlightActive: noSubscription,
        subscribeLandingActive: noSubscription,
        flush,
      }),
    );
    const event = new Event('beforeunload', {
      cancelable: true,
    });

    window.dispatchEvent(event);

    expect(event.defaultPrevented).toBe(false);
    expect(event.returnValue).toBe(true);
    expect(flush).not.toHaveBeenCalled();
  });

  it('installs the unload listener only while either recorder has active work', () => {
    let flightActive = false;
    let landingActive = false;
    let notifyFlight: () => void = () => undefined;
    let notifyLanding: () => void = () => undefined;
    const addListener = vi.spyOn(window, 'addEventListener');
    const removeListener = vi.spyOn(window, 'removeEventListener');

    cleanups.push(
      installRecordingUnloadGuard({
        flightActive: () => flightActive,
        landingActive: () => landingActive,
        subscribeFlightActive: (listener) => {
          notifyFlight = listener;
          return () => undefined;
        },
        subscribeLandingActive: (listener) => {
          notifyLanding = listener;
          return () => undefined;
        },
        flush: vi.fn().mockResolvedValue(undefined),
      }),
    );

    expect(addListener).not.toHaveBeenCalledWith('beforeunload', expect.any(Function));

    flightActive = true;
    notifyFlight();
    expect(addListener).toHaveBeenCalledWith('beforeunload', expect.any(Function));

    landingActive = true;
    notifyLanding();
    flightActive = false;
    notifyFlight();
    expect(removeListener).not.toHaveBeenCalledWith('beforeunload', expect.any(Function));

    landingActive = false;
    notifyLanding();
    expect(removeListener).toHaveBeenCalledWith('beforeunload', expect.any(Function));
  });

  it('stops guarding after cleanup', () => {
    const flush = vi.fn().mockResolvedValue(undefined);
    const cleanup = installRecordingUnloadGuard({
      flightActive: () => true,
      landingActive: () => false,
      subscribeFlightActive: noSubscription,
      subscribeLandingActive: noSubscription,
      flush,
    });
    cleanups.push(cleanup);
    cleanup();
    const event = new Event('beforeunload', {
      cancelable: true,
    });

    window.dispatchEvent(event);

    expect(event.defaultPrevented).toBe(false);
    expect(flush).not.toHaveBeenCalled();
  });
});
