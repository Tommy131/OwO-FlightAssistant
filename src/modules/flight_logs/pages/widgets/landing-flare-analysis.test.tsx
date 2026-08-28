// @vitest-environment jsdom

import { cleanup, fireEvent, render, screen } from '@testing-library/react';
import { afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';

import {
  registerModuleTranslations,
  useLocalizationStore,
} from '../../../../core/services/localization-service';
import { flightLogsTranslations } from '../../localization/flight-logs-localization';
import { makeFlightLog, makeFlightLogPoint } from '../../test/flight-log-fixtures';
import { LandingFlareAnalysis } from './landing-flare-analysis';

beforeAll(() => {
  registerModuleTranslations(flightLogsTranslations);
});

beforeEach(() => {
  useLocalizationStore.setState({ locale: 'en_US' });
});

afterEach(cleanup);

function landingLog() {
  const points = Array.from({ length: 11 }, (_, second) =>
    makeFlightLogPoint(second * 1_000, {
      verticalSpeed: -700 + second * 50,
      radioAltitude: 100 - second * 10,
      airspeed: 140 - second,
      onGround: second === 10,
    }),
  );
  const touchdown = points[10].timestamp;

  return makeFlightLog(points, {
    landingData: {
      latitude: 40,
      longitude: 116,
      gForce: 1.2,
      gForceSource: 'body',
      verticalSpeed: -180,
      airspeed: 130,
      groundSpeed: 128,
      pitch: 5,
      roll: 1,
      rating: 'good',
      timestamp: touchdown,
      touchdownSequence: [],
      touchdownGForces: [],
    },
  });
}

function chartWithViewport(width = 1_000) {
  render(<LandingFlareAnalysis log={landingLog()} />);

  const chart = document.querySelector('svg');
  if (!chart) throw new Error('Expected landing flare chart to render.');
  vi.spyOn(chart, 'getBoundingClientRect').mockReturnValue({
    bottom: 240,
    height: 240,
    left: 0,
    right: width,
    top: 0,
    width,
    x: 0,
    y: 0,
    toJSON: () => ({}),
  });

  return chart;
}

describe('LandingFlareAnalysis curve readout', () => {
  it('defaults to zero at the top and reverses the vertical axis from the shared switch', () => {
    const chart = chartWithViewport();
    const firstPoint = chart.querySelector('circle');
    const toggle = screen.getByRole('switch', {
      name: 'Place zero baseline at bottom',
    });

    expect(toggle).not.toBeChecked();
    expect(Number(firstPoint?.getAttribute('cy'))).toBeGreaterThan(100);

    fireEvent.click(toggle);

    expect(toggle).toBeChecked();
    expect(Number(firstPoint?.getAttribute('cy'))).toBeLessThan(100);
  });

  it('shows the nearest sample time and actual sink rate while the cursor moves over the plot', () => {
    const chart = chartWithViewport();

    fireEvent.pointerMove(chart, { clientX: 525, clientY: 120 });

    expect(screen.getByTestId('flare-cursor-readout')).toHaveTextContent('T-5s');
    expect(screen.getByTestId('flare-cursor-readout')).toHaveTextContent('-450 fpm');
  });

  it('shows the touchdown values when the touchdown point is clicked', () => {
    const chart = chartWithViewport();

    fireEvent.click(chart, { clientX: 978, clientY: 120 });

    expect(screen.getByTestId('flare-cursor-readout')).toHaveTextContent('TD');
    expect(screen.getByTestId('flare-cursor-readout')).toHaveTextContent('-180 fpm');
  });

  it('keeps the readout on the point under the cursor when a wide SVG adds horizontal letterboxing', () => {
    const chart = chartWithViewport(1_200);

    fireEvent.pointerMove(chart, { clientX: 262.6, clientY: 120 });

    expect(screen.getByTestId('flare-cursor-readout')).toHaveTextContent('T-9s');
    expect(screen.getByTestId('flare-cursor-readout')).toHaveTextContent('-650 fpm');
  });
});
