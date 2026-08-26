// @vitest-environment jsdom

import { render, screen, waitFor } from '@testing-library/react';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { MapSelectedAirportDetail } from '../models/map-models';
import { PapiIndicator } from './papi-indicator';

const mocks = vi.hoisted(() => ({
  fetchPapiAirportDetail: vi.fn(),
  state: {
    aircraft: {
      position: { latitude: 39.9334, longitude: 116 },
      radioAltitude: 1274,
      onGround: false,
    },
    selectedAirport: null as MapSelectedAirportDetail | null,
    currentNearestAirportIcao: null as string | null,
  },
}));

vi.mock('../../../core/localization/use-translate', () => ({
  useTranslate: () => (key: string) => key,
}));

vi.mock('../providers/map-store', () => ({
  useMapStore: (selector: (state: typeof mocks.state) => unknown) => selector(mocks.state),
}));

vi.mock('../services/papi-airport-detail', () => ({
  fetchPapiAirportDetail: mocks.fetchPapiAirportDetail,
}));

const DETAIL: MapSelectedAirportDetail = {
  marker: {
    code: 'TEST',
    position: { latitude: 40, longitude: 116 },
    isPrimary: true,
  },
  runways: ['36/18'],
  runwayGeometries: [
    {
      ident: '36/18',
      leIdent: '36',
      heIdent: '18',
      start: { latitude: 40, longitude: 116 },
      end: { latitude: 40.05, longitude: 116 },
    },
  ],
  parkingSpots: [],
  frequencies: [],
};

describe('PapiIndicator', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.state.selectedAirport = null;
    mocks.state.currentNearestAirportIcao = 'TEST';
  });

  it('MSFS 进近时未手动选机场也会用最近机场跑道显示 PAPI', async () => {
    mocks.fetchPapiAirportDetail.mockResolvedValue(DETAIL);

    render(<PapiIndicator />);

    await waitFor(() => expect(mocks.fetchPapiAirportDetail).toHaveBeenCalledWith('TEST'));
    expect(await screen.findByRole('status')).toHaveTextContent('PAPI');
  });

  it('旧的手动机场不匹配当前进近时回退到最近机场', async () => {
    mocks.state.selectedAirport = {
      ...DETAIL,
      marker: { ...DETAIL.marker, code: 'OLD', position: { latitude: 30, longitude: 110 } },
      runwayGeometries: [],
    };
    mocks.fetchPapiAirportDetail.mockResolvedValue(DETAIL);

    render(<PapiIndicator />);

    expect(await screen.findByRole('status')).toHaveTextContent('PAPI');
  });
});
