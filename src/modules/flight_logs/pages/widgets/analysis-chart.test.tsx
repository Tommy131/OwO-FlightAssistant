// @vitest-environment jsdom
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { fireEvent, render, screen } from '@testing-library/react';
import type { EChartsOption } from 'echarts';
import {
  registerModuleTranslations,
  useLocalizationStore,
} from '../../../../core/services/localization-service';
import {
  flightLogsTranslations,
} from '../../localization/flight-logs-localization';
import {
  makeFlightLog,
  makeFlightLogPoint,
} from '../../test/flight-log-fixtures';
import { AnalysisChart } from './analysis-chart';

vi.mock('../../../../core/widgets/common/echart', async (importOriginal) => {
  const actual =
    await importOriginal<
      typeof import('../../../../core/widgets/common/echart')
    >();

  return {
    ...actual,
    EChart: ({
      option,
      height,
    }: {
      option: EChartsOption;
      height?: number | string;
    }) => {
      const series = Array.isArray(option.series) ? option.series : [];
      const lineCount = series.filter((item) => item.type === 'line').length;
      const eventCount = series.filter((item) => item.type === 'scatter').length;
      return (
        <div
          data-testid={height === '100%' ? 'combined-echart' : 'metric-echart'}
          data-line-count={lineCount}
          data-event-count={eventCount}
        />
      );
    },
  };
});

class ResizeObserverMock {
  observe() {}
  unobserve() {}
  disconnect() {}
}

beforeAll(() => {
  vi.stubGlobal('ResizeObserver', ResizeObserverMock);
  registerModuleTranslations(flightLogsTranslations);
});

afterAll(() => {
  vi.unstubAllGlobals();
});

beforeEach(() => {
  useLocalizationStore.setState({ locale: 'en_US' });
});

function representativeLog() {
  return makeFlightLog([
    makeFlightLogPoint(0, {
      onGround: true,
      altitude: 500,
      groundSpeed: 90,
      verticalSpeed: 0,
      gForce: 1,
      pitch: 1,
      gearDown: true,
    }),
    makeFlightLogPoint(60_000, {
      onGround: false,
      altitude: 2500,
      groundSpeed: 170,
      verticalSpeed: 1200,
      gForce: 1.08,
      pitch: 8,
      gearDown: true,
    }),
  ]);
}

describe('AnalysisChart', () => {
  it('shows the combined chart and all default metric and event selections', () => {
    render(<AnalysisChart log={representativeLog()} />);

    expect(
      screen.getByRole('region', { name: 'Combined Chart' }),
    ).toBeVisible();
    expect(screen.getAllByRole('button', { pressed: true })).toHaveLength(13);
    expect(screen.getByRole('button', { name: 'Gear Up' })).toBeDisabled();
    expect(screen.getByTestId('combined-echart')).toHaveAttribute(
      'data-line-count',
      '4',
    );
    expect(screen.getAllByTestId('metric-echart')).toHaveLength(4);
  });

  it('hides only the combined chart and keeps individual charts visible', () => {
    render(<AnalysisChart log={representativeLog()} />);

    fireEvent.click(
      screen.getByRole('button', { name: 'Hide Combined Chart' }),
    );

    expect(
      screen.queryByRole('region', { name: 'Combined Chart' }),
    ).not.toBeInTheDocument();
    expect(screen.getAllByTestId('metric-echart')).toHaveLength(4);
    expect(
      screen.getByRole('button', { name: 'Show Combined Chart' }),
    ).toBeVisible();
  });

  it('uses a metric selection for both combined and individual charts', () => {
    render(<AnalysisChart log={representativeLog()} />);

    fireEvent.click(screen.getByRole('button', { name: /Pitch/ }));

    expect(screen.getByRole('button', { name: /Pitch/ })).toHaveAttribute(
      'aria-pressed',
      'true',
    );
    expect(screen.getByTestId('combined-echart')).toHaveAttribute(
      'data-line-count',
      '5',
    );
    expect(screen.getAllByTestId('metric-echart')).toHaveLength(5);
    expect(screen.getAllByText(/Pitch/).length).toBeGreaterThan(1);
  });

  it('filters available event markers without hiding the event control', () => {
    render(<AnalysisChart log={representativeLog()} />);

    expect(screen.getByTestId('combined-echart')).toHaveAttribute(
      'data-event-count',
      '1',
    );
    fireEvent.click(screen.getByRole('button', { name: 'Takeoff' }));

    expect(screen.getByRole('button', { name: 'Takeoff' })).toHaveAttribute(
      'aria-pressed',
      'false',
    );
    expect(screen.getByTestId('combined-echart')).toHaveAttribute(
      'data-event-count',
      '0',
    );
  });
});