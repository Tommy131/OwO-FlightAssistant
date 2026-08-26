import { describe, expect, it } from 'vitest';
import {
  mapReferenceOverlayUrl,
  mapTileAttribution,
  mapTileUrl,
} from './map-models';

describe('dark map basemap', () => {
  it('uses the keyless Esri dark canvas and its reference overlay', () => {
    expect(mapTileUrl('dark')).toBe(
      'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}',
    );
    expect(mapReferenceOverlayUrl('dark')).toBe(
      'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Reference/MapServer/tile/{z}/{y}/{x}',
    );
    expect(mapTileAttribution('dark')).toContain('Esri');
    expect(mapTileUrl('dark')).not.toContain('cartocdn');
  });
});
