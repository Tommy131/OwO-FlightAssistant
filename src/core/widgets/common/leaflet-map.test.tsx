// @vitest-environment jsdom

import { cleanup, render } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { LeafletMap } from './leaflet-map';

const leafletMocks = vi.hoisted(() => ({
  invalidateSize: vi.fn(),
  remove: vi.fn(),
  tileLayer: vi.fn((_url: string, _options: Record<string, unknown>) => ({ addTo: vi.fn() })),
}));

vi.mock('leaflet', () => ({
  default: {
    map: vi.fn(() => ({
      invalidateSize: leafletMocks.invalidateSize,
      remove: leafletMocks.remove,
    })),
    tileLayer: leafletMocks.tileLayer,
  },
}));

let resizeCallback: ResizeObserverCallback;

class ResizeObserverMock implements ResizeObserver {
  constructor(callback: ResizeObserverCallback) {
    resizeCallback = callback;
  }

  readonly observe = vi.fn();
  readonly unobserve = vi.fn();
  readonly disconnect = vi.fn();
}

describe('LeafletMap', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    globalThis.ResizeObserver = ResizeObserverMock;
  });

  afterEach(cleanup);

  it('fill 模式使用绝对定位填满有明确尺寸的宿主', () => {
    const { container } = render(
      <div style={{ position: 'relative', minHeight: 240 }}>
        <LeafletMap fill />
      </div>,
    );

    const canvas = container.firstElementChild?.firstElementChild as HTMLElement;
    expect(canvas.style.position).toBe('absolute');
    expect(canvas.style.inset).toBe('0px');
    expect(canvas.style.height).toBe('');
  });

  it('宿主尺寸变化时通知 Leaflet 重新计算瓦片尺寸', () => {
    render(<LeafletMap />);

    resizeCallback([], {} as ResizeObserver);

    expect(leafletMocks.invalidateSize).toHaveBeenCalledOnce();
  });

  it('默认深色底图无需 API key，并叠加独立注记层', () => {
    render(<LeafletMap />);

    const firstCall = leafletMocks.tileLayer.mock.calls[0];
    const secondCall = leafletMocks.tileLayer.mock.calls[1];
    expect(firstCall?.[0]).toBe(
      'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}',
    );
    expect(firstCall?.[1].attribution).toContain('Esri');
    expect(secondCall?.[0]).toBe(
      'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Reference/MapServer/tile/{z}/{y}/{x}',
    );
    expect(firstCall?.[0]).not.toContain('cartocdn');
  });

  it('浅色底图使用配对的 Esri 画布和注记层', () => {
    render(<LeafletMap tileLayer="esriLight" />);

    const firstCall = leafletMocks.tileLayer.mock.calls[0];
    const secondCall = leafletMocks.tileLayer.mock.calls[1];
    expect(firstCall?.[0]).toBe(
      'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}',
    );
    expect(firstCall?.[1].attribution).toContain('Esri');
    expect(secondCall?.[0]).toBe(
      'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Reference/MapServer/tile/{z}/{y}/{x}',
    );
    expect(firstCall?.[0]).not.toContain('cartocdn');
  });
});
