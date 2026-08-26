import { describe, expect, it, vi } from 'vitest';
import { installMapBasemap } from './map-basemap-layer';

const leafletMocks = vi.hoisted(() => ({
  tileLayer: vi.fn(),
}));

vi.mock('leaflet', () => ({
  default: { tileLayer: leafletMocks.tileLayer },
}));

describe('installMapBasemap', () => {
  it('为主地图挂载深色底图和独立注记层', () => {
    const map = {};
    const base = { addTo: vi.fn(), setZIndex: vi.fn() };
    const reference = { addTo: vi.fn(), setZIndex: vi.fn() };
    base.addTo.mockReturnValue(base);
    reference.addTo.mockReturnValue(reference);
    leafletMocks.tileLayer.mockReturnValueOnce(base).mockReturnValueOnce(reference);

    const result = installMapBasemap(map as never, 'dark', 19);

    expect(leafletMocks.tileLayer).toHaveBeenNthCalledWith(
      1,
      'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}',
      expect.objectContaining({
        attribution: '© Esri, HERE, Garmin, OpenStreetMap contributors, GIS user community',
        maxZoom: 19,
      }),
    );
    expect(leafletMocks.tileLayer).toHaveBeenNthCalledWith(
      2,
      'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Reference/MapServer/tile/{z}/{y}/{x}',
      { maxZoom: 19 },
    );
    expect(base.addTo).toHaveBeenCalledWith(map);
    expect(reference.addTo).toHaveBeenCalledWith(map);
    expect(base.setZIndex).toHaveBeenCalledWith(1);
    expect(reference.setZIndex).toHaveBeenCalledWith(2);
    expect(result).toEqual({ base, reference });
  });
});
