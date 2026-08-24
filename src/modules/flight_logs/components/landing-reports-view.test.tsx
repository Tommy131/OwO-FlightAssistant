// @vitest-environment jsdom

import { cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { useState } from 'react';
import { afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';

import {
  registerModuleTranslations,
  useLocalizationStore,
} from '../../../core/services/localization-service';
import { showAdvancedConfirmDialog } from '../../../core/widgets/common/dialog';
import { flightLogsTranslations } from '../localization/flight-logs-localization';
import type { LandingReport } from '../models/landing-report-models';
import type { RecordingEndReason } from '../models/recording-status';
import { makeFlightLogPoint } from '../test/flight-log-fixtures';
import { LandingReportsView } from './landing-reports-view';

vi.mock('../../../core/widgets/common/dialog', () => ({
  showAdvancedConfirmDialog: vi.fn(),
}));

vi.mock('../pages/widgets/analysis-chart', () => ({
  AnalysisChart: ({ log }: { log: { points: unknown[] } }) => (
    <section aria-label="Landing chart fields">{log.points.length} chart samples</section>
  ),
}));

vi.mock('../pages/widgets/landing-flare-analysis', () => ({
  LandingFlareAnalysis: ({ log }: { log: { landingData?: unknown } }) => (
    <section aria-label="Landing flare chart">
      {log.landingData ? 'Landing data ready' : 'No landing data'}
    </section>
  ),
}));

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
  vi.mocked(showAdvancedConfirmDialog).mockReset();
});

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

describe('LandingReportsView', () => {
  it('opens landing detail inline and returns to the landing list', () => {
    render(<LandingReportsHarness reports={[makeLandingReport()]} />);

    const reportButton = screen.getByRole('button', { name: 'Landing report lr-1' });
    reportButton.focus();
    fireEvent.click(reportButton);

    expect(screen.queryByRole('list', { name: 'Landing Reports' })).not.toBeInTheDocument();
    expect(screen.getByRole('heading', { level: 2 })).toHaveFocus();
    const overview = screen.getByRole('region', { name: 'Landing report overview' });
    expect(within(overview).getByTitle('Simulator disconnected')).toBeVisible();
    expect(within(overview).getByTitle('MSFS')).toBeVisible();
    expect(within(overview).getByTitle('Incomplete')).toBeVisible();
    expect(within(overview).getByTitle('Touchdown time')).toBeVisible();
    expect(within(overview).getByTitle('Radio altimeter')).toBeVisible();
    expect(screen.getAllByTitle('1.23')[0]).toBeVisible();
    expect(screen.getByTitle('-180')).toBeVisible();
    expect(screen.getByRole('region', { name: 'Landing flare chart' })).toHaveTextContent(
      'Landing data ready',
    );
    expect(screen.getByRole('region', { name: 'Landing chart fields' })).toHaveTextContent(
      '11 chart samples',
    );

    fireEvent.click(screen.getByRole('button', { name: 'Back' }));

    expect(screen.getByRole('list', { name: 'Landing Reports' })).toBeVisible();
    expect(screen.getByRole('button', { name: 'Landing report lr-1' })).toHaveFocus();
  });

  it('does not invent touchdown data for a report interrupted before touchdown', () => {
    const report = makeLandingReport({ touchdownAt: undefined, landing: undefined });
    render(<LandingReportsHarness reports={[report]} />);

    expect(screen.getByText('No touchdown recorded')).toBeVisible();
    fireEvent.click(screen.getByRole('button', { name: 'Landing report lr-1' }));

    expect(screen.getByRole('heading', { level: 2, name: 'No touchdown recorded' })).toBeVisible();
    const overview = screen.getByRole('region', { name: 'Landing report overview' });
    expect(within(overview).getByTitle('No touchdown recorded')).toBeVisible();
    const bounceLabel = screen.getByTitle('Bounce Count');
    const bounceCard = bounceLabel.parentElement?.parentElement;
    expect(bounceCard).not.toBeNull();
    expect(within(bounceCard as HTMLElement).getByTitle('--')).toBeVisible();
  });

  it('uses established landing metric notes for unavailable values', () => {
    const base = makeLandingReport();
    const report = makeLandingReport({
      landing: {
        ...base.landing!,
        runway: '27',
        approachStabilityScore: undefined,
        remainingRunwayFt: undefined,
        metricNotes: {
          approachStabilityScore: 'insufficient_samples',
          remainingRunwayFt: 'no_runway_geometry',
        },
      },
    });
    render(<LandingReportsHarness reports={[report]} />);

    fireEvent.click(screen.getByRole('button', { name: 'Landing report lr-1' }));

    expect(screen.getByTitle('27')).toBeVisible();
    expect(screen.getByText('Too few samples to score')).toBeVisible();
    expect(screen.getByText('Runway could not be identified')).toBeVisible();
  });

  it('renders every recording end reason in English and Chinese', () => {
    const reasons: RecordingEndReason[] = [
      'stable_landing',
      'touch_and_go',
      'user_stopped',
      'simulator_disconnected',
      'page_closed',
      'interrupted',
    ];
    const reports = reasons.map((reason, index) =>
      makeLandingReport({ id: `lr-${index + 1}`, endReason: reason }),
    );
    const { rerender } = render(
      <LandingReportsView
        reports={reports}
        selectedReport={undefined}
        selectReport={vi.fn()}
        deleteReport={vi.fn().mockResolvedValue(undefined)}
      />,
    );

    for (const label of [
      'Stable landing',
      'Touch-and-go',
      'Stopped by user',
      'Simulator disconnected',
      'Page closed',
      'Recording interrupted',
    ]) {
      expect(screen.getByText(label)).toBeVisible();
    }

    useLocalizationStore.setState({ locale: 'zh_CN' });
    rerender(
      <LandingReportsView
        reports={reports}
        selectedReport={undefined}
        selectReport={vi.fn()}
        deleteReport={vi.fn().mockResolvedValue(undefined)}
      />,
    );

    for (const label of ['稳定落地', '连续起降', '用户停止', '模拟器连接中断', '页面关闭', '录制中断']) {
      expect(screen.getByText(label)).toBeVisible();
    }
  });

  it('shows the established loading and empty states', () => {
    const { rerender } = render(
      <LandingReportsView
        reports={[]}
        selectedReport={undefined}
        selectReport={vi.fn()}
        deleteReport={vi.fn().mockResolvedValue(undefined)}
        isLoading
      />,
    );
    expect(screen.getByRole('status', { name: 'Loading landing reports' })).toBeVisible();

    rerender(
      <LandingReportsView
        reports={[]}
        selectedReport={undefined}
        selectReport={vi.fn()}
        deleteReport={vi.fn().mockResolvedValue(undefined)}
      />,
    );
    expect(screen.getByText('No landing reports yet')).toBeVisible();
  });

  it('shows a load error with a retry action', () => {
    const retry = vi.fn();
    render(
      <LandingReportsView
        reports={[]}
        selectedReport={undefined}
        selectReport={vi.fn()}
        deleteReport={vi.fn().mockResolvedValue(undefined)}
        loadError="Could not load landing reports"
        retryLoad={retry}
      />,
    );

    expect(screen.getByRole('alert')).toHaveTextContent('Could not load landing reports');
    fireEvent.click(screen.getByRole('button', { name: 'Retry' }));
    expect(retry).toHaveBeenCalledOnce();
  });

  it('confirms and deletes a report without opening it', async () => {
    const selectReport = vi.fn();
    const deleteReport = vi.fn().mockResolvedValue(undefined);
    vi.mocked(showAdvancedConfirmDialog).mockResolvedValue(true);
    render(
      <LandingReportsView
        reports={[makeLandingReport()]}
        selectedReport={undefined}
        selectReport={selectReport}
        deleteReport={deleteReport}
      />,
    );

    fireEvent.click(screen.getByRole('button', { name: 'Delete landing report lr-1' }));

    await waitFor(() => expect(deleteReport).toHaveBeenCalledWith('lr-1'));
    expect(selectReport).not.toHaveBeenCalled();
  });

  it('guards a report against duplicate deletion while confirmation is pending', async () => {
    let resolveConfirmation: (confirmed: boolean) => void = () => undefined;
    const confirmation = new Promise<boolean>((resolve) => {
      resolveConfirmation = resolve;
    });
    vi.mocked(showAdvancedConfirmDialog).mockReturnValue(confirmation);
    render(
      <LandingReportsView
        reports={[makeLandingReport()]}
        selectedReport={undefined}
        selectReport={vi.fn()}
        deleteReport={vi.fn().mockResolvedValue(undefined)}
      />,
    );

    const deleteButton = screen.getByRole('button', { name: 'Delete landing report lr-1' });
    fireEvent.click(deleteButton);

    expect(deleteButton).toBeDisabled();
    fireEvent.click(deleteButton);
    expect(showAdvancedConfirmDialog).toHaveBeenCalledOnce();

    resolveConfirmation(false);
    await waitFor(() => expect(deleteButton).toBeEnabled());
  });

  it('keeps the report available and explains a delete failure', async () => {
    vi.mocked(showAdvancedConfirmDialog).mockResolvedValue(true);
    const deleteReport = vi.fn().mockRejectedValue(new Error('storage unavailable'));
    render(
      <LandingReportsView
        reports={[makeLandingReport()]}
        selectedReport={undefined}
        selectReport={vi.fn()}
        deleteReport={deleteReport}
      />,
    );

    fireEvent.click(screen.getByRole('button', { name: 'Delete landing report lr-1' }));

    expect(await screen.findByRole('alert')).toHaveTextContent(
      'Landing report could not be deleted. Try again.',
    );
    expect(screen.getByRole('button', { name: 'Landing report lr-1' })).toBeVisible();
  });
});

function LandingReportsHarness({ reports }: { reports: LandingReport[] }) {
  const [selectedId, setSelectedId] = useState<string>();
  return (
    <LandingReportsView
      reports={reports}
      selectedReport={reports.find((report) => report.id === selectedId)}
      selectReport={setSelectedId}
      deleteReport={vi.fn().mockResolvedValue(undefined)}
    />
  );
}

function makeLandingReport(overrides: Partial<LandingReport> = {}): LandingReport {
  const startedAt = new Date('2026-08-11T10:00:00.000Z').getTime();
  const points = Array.from({ length: 11 }, (_, second) =>
    makeFlightLogPoint(second * 1_000, {
      altitude: 100 - second * 10,
      airspeed: 140 - second,
      groundSpeed: 136 - second,
      verticalSpeed: -700 + second * 52,
      pitch: 2 + second * 0.3,
      roll: 1,
      gForce: second === 10 ? 1.23 : 1,
      radioAltitude: 100 - second * 10,
      radioAltitudeSource: 'radio',
      onGround: second === 10,
    }),
  );
  const touchdownAt = startedAt + 10_000;
  return {
    id: 'lr-1',
    simulator: 'MSFS',
    startedAt,
    endedAt: touchdownAt + 2_000,
    touchdownAt,
    status: 'incomplete',
    endReason: 'simulator_disconnected',
    points,
    landing: {
      latitude: 40,
      longitude: 116,
      gForce: 1.23,
      gForceSource: 'gear',
      verticalSpeed: -180,
      airspeed: 130,
      groundSpeed: 126,
      pitch: 5,
      roll: 1,
      rating: 'good',
      timestamp: new Date(touchdownAt),
      touchdownSequence: [points[10]],
      touchdownGForces: [1.23],
      approachStabilityScore: 91,
      flareHeightFt: 28,
      sinkRateAt50FtFpm: -520,
      crosswindAtTouchdownKt: 7,
      bounceCount: 0,
    },
    createdAt: touchdownAt + 2_000,
    updatedAt: touchdownAt + 2_000,
    ...overrides,
  };
}
