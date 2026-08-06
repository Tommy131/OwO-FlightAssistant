/**
 * 地图标记的 HTML 构造（纯函数）
 *
 * Leaflet 的 `divIcon` 收字符串，内部是 `node.innerHTML = html` —— 所以这些
 * 函数的产物直接进 DOM，凡拼接外部文本处一律走 `escapeHtml`（NFR-6）。
 *
 * 原先散在 `map-canvas.tsx` 里（一个 1400 多行的组件），与 Leaflet 渲染逻辑
 * 混在一起。它们本身不依赖 Leaflet，抽出来即可单独调用与测试。
 */

import { escapeHtml } from '../../../core/utils/escape-html';
import { MAP_ALERT_LEVEL_COLOR, type MapAirportMarker } from '../models/map-models';

// ──────────────────────────────────────────────────────────────────────────
// 标记 HTML（divIcon 内容）
// ──────────────────────────────────────────────────────────────────────────

export function aircraftMarkerHtml(heading: number, alertLevel?: 'caution' | 'warning' | 'danger'): string {
  const color = alertLevel ? MAP_ALERT_LEVEL_COLOR[alertLevel] : '#ffffff';
  return `<div style="transform:rotate(${heading}deg);width:34px;height:34px;display:flex;align-items:center;justify-content:center">
    <svg width="30" height="30" viewBox="0 0 24 24" fill="${color}" stroke="#000" stroke-width="0.7">
      <path d="M12 2 L14.2 10.5 L22 13.2 L22 15 L14.2 13.6 L13.4 19.4 L16 21.2 L16 22.4 L12 21.4 L8 22.4 L8 21.2 L10.6 19.4 L9.8 13.6 L2 15 L2 13.2 L9.8 10.5 Z"/>
    </svg>
  </div>`;
}

export function aiAircraftMarkerHtml(heading: number, onGround: boolean): string {
  const color = onGround ? '#898781' : '#3987e5';
  return `<div style="transform:rotate(${heading}deg);width:20px;height:20px;display:flex;align-items:center;justify-content:center">
    <svg width="16" height="16" viewBox="0 0 24 24" fill="${color}" stroke="#000" stroke-width="0.8" opacity="0.9">
      <path d="M12 2 L14.2 10.5 L22 13.2 L22 15 L14.2 13.6 L13.4 19.4 L16 21.2 L16 22.4 L12 21.4 L8 22.4 L8 21.2 L10.6 19.4 L9.8 13.6 L2 15 L2 13.2 L9.8 10.5 Z"/>
    </svg>
  </div>`;
}

export function airportMarkerHtml(
  airport: MapAirportMarker,
  isHome: boolean,
  strokeColor: string,
): string {
  const size = airport.isPrimary ? 30 : 22;
  const fill = isHome ? '#fab219' : airport.isPrimary ? '#eb6834' : '#199e70';
  const dot = airport.isPrimary ? 9 : 6;
  return `<div style="width:${size}px;height:${size}px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:1px">
    <span style="width:${dot}px;height:${dot}px;border-radius:50%;background:${fill};border:2px solid ${strokeColor};box-shadow:0 1px 3px rgba(0,0,0,.5)"></span>
    ${
      airport.isPrimary
        ? `<span style="font-size:9px;font-weight:700;color:${strokeColor === '#ffffff' ? '#fff' : '#111'};text-shadow:0 1px 2px rgba(0,0,0,.7);white-space:nowrap">${escapeHtml(airport.code)}</span>`
        : ''
    }
  </div>`;
}

/** 视野内机场的 pin：一个圆点 + 始终显示的 ICAO */
export function nearbyAirportHtml(airport: MapAirportMarker, bright: boolean): string {
  const textColor = bright ? '#111' : '#fff';
  const haloColor = bright ? 'rgba(255,255,255,.85)' : 'rgba(0,0,0,.75)';
  return `<div style="position:absolute;left:0;top:0;transform:translate(-50%,-50%);
    display:flex;flex-direction:column;align-items:center;gap:1px;cursor:pointer;pointer-events:auto">
    <span style="width:8px;height:8px;border-radius:50%;background:#199e70;
      border:2px solid ${bright ? '#1a1a1a' : '#ffffff'};box-shadow:0 1px 3px rgba(0,0,0,.5)"></span>
    <span style="font-size:9px;font-weight:700;letter-spacing:.04em;white-space:nowrap;
      color:${textColor};text-shadow:0 0 3px ${haloColor},0 0 3px ${haloColor}">${escapeHtml(airport.code)}</span>
  </div>`;
}

export function parkingSpotHtml(name: string | undefined, headingDeg: number | undefined): string {
  // 无名称时只画一个朝向小三角，密集机坪下不至于糊成一片
  if (!name) {
    return `<div style="width:16px;height:16px;display:flex;align-items:center;justify-content:center;
      transform:rotate(${headingDeg ?? 0}deg)">
      <span style="width:0;height:0;border-left:5px solid transparent;border-right:5px solid transparent;
        border-bottom:9px solid rgba(26,158,112,.95);filter:drop-shadow(0 1px 2px rgba(0,0,0,.6))"></span>
    </div>`;
  }
  // 外层零尺寸、内层用 translate(-50%,-50%) 自己居中 ——
  // 这样宽度可以完全由文字决定，不必事先估算（见 .owo-map-autolabel）
  return `<div style="position:absolute;left:0;top:0;transform:translate(-50%,-50%);
    display:flex;align-items:center;gap:3px;padding:2px 6px;border-radius:9px;
    background:rgba(25,158,112,.9);border:1px solid rgba(255,255,255,.5);
    color:#fff;font-size:9px;font-weight:700;white-space:nowrap;
    box-shadow:0 1px 3px rgba(0,0,0,.5)">
    <span style="width:5px;height:5px;border-radius:50%;background:#fff;flex-shrink:0"></span>${escapeHtml(name)}
  </div>`;
}

export function taxiwayNodeHtml(index: number, draggable: boolean): string {
  return `<div style="width:20px;height:20px;display:flex;align-items:center;justify-content:center;
    border-radius:50%;background:${draggable ? '#eb6834' : 'rgba(235,104,52,.7)'};
    border:2px solid #fff;box-shadow:0 1px 3px rgba(0,0,0,.5);
    font-size:9px;font-weight:700;color:#fff;cursor:${draggable ? 'grab' : 'pointer'}">${index}</div>`;
}

/** 包一层零尺寸容器，内容自己居中到锚点（配合 .owo-map-autolabel） */
export function centeredBox(inner: string): string {
  return `<div style="position:absolute;left:0;top:0;transform:translate(-50%,-50%);
    display:flex;align-items:center;justify-content:center">${inner}</div>`;
}
