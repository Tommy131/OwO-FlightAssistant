import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { MiddlewareHttpService } from '../../http/services/middleware-http-service';
import { MiddlewareFlightDataAdapter } from './middleware-flight-data-adapter';

type AdapterPrivate = {
  token: string | null;
  isConnected: boolean;
  simulatorType: string;
  intentionalDisconnect: boolean;
  applySimulatorResponseBody: (body: Record<string, unknown>) => void;
  noteSimulatorLinkLost: (reason: string, detail?: string | null) => void;
  finalizeUnexpectedDisconnect: (reason: string, detail?: string | null) => Promise<void>;
};

function asPrivate(adapter: MiddlewareFlightDataAdapter): AdapterPrivate {
  return adapter as unknown as AdapterPrivate;
}

function jsonResponse(body: Record<string, unknown>) {
  return {
    statusCode: 200,
    objectBody: body,
    decodedBody: body,
    isSuccess: true,
    uri: 'test',
  };
}

describe('simulator link grace period', () => {
  let adapter: MiddlewareFlightDataAdapter;

  beforeEach(() => {
    vi.useFakeTimers();
    adapter = new MiddlewareFlightDataAdapter();
    vi.spyOn(MiddlewareHttpService, 'disconnectSimulator').mockResolvedValue(
      jsonResponse({ disconnected: true }) as never,
    );

    const priv = asPrivate(adapter);
    priv.token = 'tok-live';
    priv.isConnected = true;
    priv.simulatorType = 'msfs';
    priv.intentionalDisconnect = false;
  });

  afterEach(() => {
    adapter.dispose();
    vi.useRealTimers();
  });

  it('keeps session during soft disconnect and recovers when link returns', () => {
    let latest = { isConnected: false, simulatorOutageVersion: 0, errorMessage: undefined as string | undefined };
    adapter.subscribe((s) => {
      latest = {
        isConnected: s.isConnected,
        simulatorOutageVersion: s.simulatorOutageVersion,
        errorMessage: s.errorMessage,
      };
    });

    asPrivate(adapter).applySimulatorResponseBody({
      connected: false,
      disconnect_reason: 'simconnect_lost',
      client_dataset: { connected: false },
    });

    expect(latest.isConnected).toBe(true);
    expect(latest.simulatorOutageVersion).toBe(0);
    expect(latest.errorMessage).toBe('simconnect_lost');

    asPrivate(adapter).applySimulatorResponseBody({
      connected: true,
      client_dataset: { connected: true, altitude_ft: 1200 },
    });

    expect(latest.isConnected).toBe(true);
    expect(latest.simulatorOutageVersion).toBe(0);
    expect(latest.errorMessage).toBeUndefined();
  });

  it('finalizes with outage version after grace timeout', async () => {
    let latest = {
      isConnected: true,
      simulatorOutageVersion: 0,
      disconnectReason: undefined as string | undefined,
    };
    adapter.subscribe((s) => {
      latest = {
        isConnected: s.isConnected,
        simulatorOutageVersion: s.simulatorOutageVersion,
        disconnectReason: s.disconnectReason,
      };
    });

    asPrivate(adapter).noteSimulatorLinkLost('simconnect_lost', 'dispatch failed');

    expect(latest.isConnected).toBe(true);
    expect(latest.simulatorOutageVersion).toBe(0);

    await vi.advanceTimersByTimeAsync(45_000);
    await Promise.resolve();
    await Promise.resolve();

    expect(latest.isConnected).toBe(false);
    expect(latest.simulatorOutageVersion).toBe(1);
    expect(latest.disconnectReason).toBe('simconnect_lost');
  });
});
