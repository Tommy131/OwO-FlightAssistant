// @vitest-environment jsdom

import { cleanup, fireEvent, render, screen } from '@testing-library/react';
import { afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';

import {
  registerModuleTranslations,
  useLocalizationStore,
} from '../../../core/services/localization-service';
import { flightLogsTranslations } from '../localization/flight-logs-localization';
import { useFlightLogsStore } from '../providers/flight-logs-store';
import { useLandingReportsStore } from '../providers/landing-reports-store';
import { makeFlightLog, makeFlightLogPoint } from '../test/flight-log-fixtures';
import { FlightLogsPage } from './flight-logs-page';

beforeAll(() => {
  registerModuleTranslations(flightLogsTranslations);
});

beforeEach(() => {
  vi.stubGlobal(
    'ResizeObserver',
    class {
      observe() {}
      unobserve() {}
      disconnect() {}
    },
  );
  useLocalizationStore.setState({ locale: 'en_US' });
  useFlightLogsStore.setState({
    logs: [],
    isLoading: false,
    selectedLog: null,
    isRecording: false,
    isRecordingPaused: false,
    refreshLogs: vi.fn().mockResolvedValue(undefined),
  });
  useLandingReportsStore.setState({
    reports: [],
    selectedReport: undefined,
    initialize: vi.fn().mockResolvedValue(undefined),
  });
});

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

describe('FlightLogsPage log workspaces', () => {
  it('switches between Flight Logs and Landing Reports and scopes manual controls to Flight Logs', () => {
    render(<FlightLogsPage />);

    const flightTab = screen.getByRole('tab', { name: 'Flight Logs' });
    const landingTab = screen.getByRole('tab', { name: 'Landing Reports' });
    expect(flightTab).toHaveAttribute('aria-selected', 'true');
    expect(screen.getByRole('button', { name: 'Start Recording' })).toBeVisible();
    expect(screen.getByRole('button', { name: 'Import Log' })).toBeVisible();

    fireEvent.click(landingTab);

    expect(landingTab).toHaveAttribute('aria-selected', 'true');
    expect(screen.queryByRole('button', { name: 'Start Recording' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Import Log' })).not.toBeInTheDocument();
  });

  it('moves focus and selection between log tabs with the keyboard', () => {
    render(<FlightLogsPage />);
    const flightTab = screen.getByRole('tab', { name: 'Flight Logs' });
    const landingTab = screen.getByRole('tab', { name: 'Landing Reports' });
    flightTab.focus();

    fireEvent.keyDown(flightTab, { key: 'ArrowRight' });

    expect(landingTab).toHaveAttribute('aria-selected', 'true');
    expect(landingTab).toHaveFocus();
    expect(flightTab).toHaveAttribute('tabindex', '-1');

    fireEvent.keyDown(landingTab, { key: 'ArrowRight' });

    expect(flightTab).toHaveAttribute('aria-selected', 'true');
    expect(flightTab).toHaveFocus();
  });

  it('shows a structured incomplete status and exact end reason in the list and detail', () => {
    const log = makeFlightLog([makeFlightLogPoint(0, { onGround: true })], {
      departureAirport: 'EDDF',
      arrivalAirport: 'EGLL',
      wasOnGroundAtEnd: true,
      status: 'incomplete',
      endReason: 'user_stopped',
    });
    useFlightLogsStore.setState({ logs: [log] });

    render(<FlightLogsPage />);

    expect(screen.getByTitle('Incomplete')).toBeVisible();
    expect(screen.getByTitle('Stopped by user')).toBeVisible();

    fireEvent.click(screen.getByRole('button', { name: /EDDF.*EGLL/ }));

    expect(screen.getByLabelText('Incomplete: Stopped by user')).toBeVisible();
  });
});
