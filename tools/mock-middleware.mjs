// 最小 mock 中间件，仅用于本地验证 Web 端数据层与导航可用性门控
import { createServer } from 'node:http';

const json = (res, body, status = 200) => {
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(body));
};

const AIRPORTS = {
  ZBAA: {
    icao: 'ZBAA',
    iata: 'PEK',
    name: 'Beijing Capital International Airport',
    city: 'Beijing',
    country: 'China',
    latitude: 40.0801,
    longitude: 116.5846,
    elevation: 116,
  },
  EDDF: {
    icao: 'EDDF',
    iata: 'FRA',
    name: 'Frankfurt am Main Airport',
    city: 'Frankfurt',
    country: 'Germany',
    latitude: 50.0333,
    longitude: 8.5706,
    elevation: 364,
  },
};

createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost');
  const path = url.pathname;

  if (path === '/health') return json(res, { status: 'ok' });
  if (path === '/api/v1/version') return json(res, { version: '0.0.0-mock' });

  if (path.startsWith('/api/v1/airport/')) {
    const icao = path.split('/').pop().toUpperCase();
    const airport = AIRPORTS[icao];
    if (!airport) return json(res, { error: 'not_found' }, 404);
    return json(res, {
      data: {
        airport_detail: {
          airport,
          runways: [
            { ident: '18L/36R', le_ident: '18L', he_ident: '36R', length_m: 3800, surface: 'ASPH' },
            { ident: '18R/36L', le_ident: '18R', he_ident: '36L', length_m: 3200, surface: 'CONC' },
          ],
          frequencies: [
            { type: 'TWR', frequency: '118.500' },
            { type: 'GND', frequency: '121.750' },
            { type: 'ATIS', frequency: '127.100' },
          ],
          parkings: [{ name: 'A01', lat: airport.latitude, lon: airport.longitude, heading_deg: 90 }],
        },
        database_source: 'mock-db',
        airac: '2508',
      },
    });
  }

  if (path.startsWith('/api/v1/metar/')) {
    const icao = path.split('/').pop().toUpperCase();
    return json(res, {
      raw_metar: `${icao} 301200Z 03012KT 9999 SCT030 BKN080 18/09 Q1013 NOSIG`,
      translated_metar: '风 030 度 12 节，能见度 10 公里以上，疏云 3000 尺，多云 8000 尺',
      display_wind: '030°/12kt',
      display_visibility: '>10km',
      display_temperature: '18/09°C',
      display_altimeter: 'Q1013',
      metar_timestamp_unix: Math.floor(Date.now() / 1000),
    });
  }

  if (path === '/api/v1/airport-suggest') {
    const q = (url.searchParams.get('q') ?? '').toUpperCase();
    const suggestions = Object.values(AIRPORTS)
      .filter((a) => a.icao.startsWith(q))
      .map((a) => ({ icao: a.icao, name: a.name, source: 'mock' }));
    return json(res, { suggestions });
  }

  if (path === '/api/v1/performance/aircraft-profiles') {
    return json(res, {
      profiles: [
        {
          id: 'a320',
          manufacturer: 'Airbus',
          family: 'A320',
          model: 'A320-200',
          reference_weight: 66000,
          min_weight: 45000,
          max_weight: 78000,
        },
      ],
    });
  }

  if (path === '/api/v1/performance/calculate') {
    return json(res, {
      v1: 142, vr: 146, v2: 152,
      takeoff_required: 1980, landing_required: 1520,
      takeoff_margin: 1220, landing_margin: 1680,
      flex_recommended: true, flex_temperature: 52,
      runway_level_code: 'high',
    });
  }

  json(res, { error: 'not_implemented' }, 404);
}).listen(18080, '127.0.0.1', () => console.log('mock middleware on 18080'));
