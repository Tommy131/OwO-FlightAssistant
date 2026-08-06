/**
 * 选中机场的详情图层：轮廓 / 跑道 / 停机位 / 进近波束 / 等待航线
 *
 * 波束几何按**真方位**绘制、标签按**磁航道**显示 —— 两者差一个磁差角，
 * 混用会让波束整体偏转（见 `docs/DESIGN.md` §5）。
 */

import L from 'leaflet';
import { clamp } from '../../../../core/utils/math-utils';
import { escapeHtml } from '../../../../core/utils/escape-html';
import { buildApproachBeam, type ApproachBeamKind } from '../../services/approach-beam';
import { buildHoldingGeometry } from '../../services/holding-geometry';
import { computeAirportOutline } from '../../services/airport-outline';
import { centeredBox, parkingSpotHtml } from '../../services/map-marker-html';
import type {
  MapCoordinate,
  MapHoldingPattern,
  MapRunwayNavaid,
  MapSelectedAirportDetail,
} from '../../models/map-models';
import { useMapStore } from '../../providers/map-store';
import {
  AEROWAY_COLORS,
  BEAM_STYLE,
  HOLDING_COLOR,
  ILS_CATEGORY_MAP_COLOR,
  MARKER_Z,
} from './layer-style';

/** 跑道端点标签、停机位的显示门槛（与桌面版一致） */
export const RUNWAY_LABEL_MIN_ZOOM = 14;

/** 进近设施信息板的门槛：比编号高一级，否则远看一屏全是信息块 */
export const RUNWAY_NAVAID_MIN_ZOOM = 15;

// ──────────────────────────────────────────────────────────────────────────
// 选中机场细节：轮廓 / 跑道 / 停机位
// ──────────────────────────────────────────────────────────────────────────



export const PARKING_MIN_ZOOM = 14;

// ──────────────────────────────────────────────────────────────────────────
// 视野内机场
// ──────────────────────────────────────────────────────────────────────────





export const PARKING_NAME_MIN_ZOOM = 16;

export function renderAirportDetail(map: L.Map, group: L.LayerGroup | undefined): void {
  if (!group) return;
  group.clearLayers();

  const state = useMapStore.getState();
  const detail = state.selectedAirport;
  if (!detail) return;

  const zoom = map.getZoom();
  // 以 zoom 15 为基准缩放线宽
  const scale = Math.min(Math.max(2 ** (zoom - 15), 0.5), 2.2);

  // ── 机场轮廓 ──
  const outline = computeAirportOutline(detail);
  if (outline && outline.length >= 3) {
    L.polygon(
      outline.map((point) => [point.latitude, point.longitude] as [number, number]),
      {
        color: '#fab219',
        weight: 2,
        opacity: 0.75,
        dashArray: '8 6',
        fillColor: '#fab219',
        fillOpacity: 0.07,
        interactive: false,
      },
    )
      .bindTooltip(escapeHtml(detail.marker.code), { sticky: true })
      .addTo(group);
  }

  if (state.showRunways) {
    // ── 跑道：深色沥青道面 + 白色虚线中线 ──
    //
    // 与滑行道图层里的画法同源（AEROWAY_COLORS），只是改由「跑道」开关控制：
    // 跑道标线按 ICAO Annex 14 是**白色**，道面画成沥青色才像铺装。
    // 原先那种蓝色光晕 + 白芯线只是发光条，既不写实也和滑行道那套对不上。
    for (const runway of detail.runwayGeometries) {
      const path: [number, number][] = [
        [runway.start.latitude, runway.start.longitude],
        [runway.end.latitude, runway.end.longitude],
      ];

      L.polyline(path, {
        color: AEROWAY_COLORS.runwaySurface,
        weight: clamp(14 * scale, 6, 26),
        opacity: 0.95,
        lineCap: 'butt',
        interactive: false,
      }).addTo(group);

      // 中线可点：点一下展开这条跑道两端的进近波束，再点收起
      L.polyline(path, {
        color: AEROWAY_COLORS.runwayCenterline,
        weight: clamp(1.4 * scale, 1, 3),
        opacity: 0.7,
        dashArray: '10 12',
      })
        .bindTooltip(
          [escapeHtml(runway.ident), runway.lengthM ? `${Math.round(runway.lengthM)}m` : null]
            .filter(Boolean)
            .join(' · '),
          { sticky: true },
        )
        .on('click', (event) => {
          // 别让点击穿透到地图（绘制模式下会误加滑行道节点）
          L.DomEvent.stopPropagation(event);
          useMapStore.getState().setBeamRunway(runway.ident);
        })
        .addTo(group);

      // 中线太细不好点，叠一条透明的宽线专门接点击
      L.polyline(path, {
        color: '#ffffff',
        opacity: 0,
        weight: clamp(18 * scale, 12, 34),
      })
        .on('click', (event) => {
          L.DomEvent.stopPropagation(event);
          useMapStore.getState().setBeamRunway(runway.ident);
        })
        .addTo(group);
    }

    // ── 跑道端点编号 / 进近设施 ──
    if (zoom >= RUNWAY_LABEL_MIN_ZOOM) {
      // 放大到一定程度就把 CAT 类别、航向台频率、下滑角一并画在入口旁，
      // 跟真实进近图一样，不用再回头去翻卡片
      const withNavaids = zoom >= RUNWAY_NAVAID_MIN_ZOOM && state.showRunwayNavaids;
      for (const runway of detail.runwayGeometries) {
        if (runway.leIdent) {
          addRunwayEndpointLabel(
            group,
            runway.start,
            runway.leIdent,
            withNavaids ? detail.runwayNavaids?.[runway.leIdent.toUpperCase()] : undefined,
            state.showGlideslope,
          );
        }
        if (runway.heIdent) {
          addRunwayEndpointLabel(
            group,
            runway.end,
            runway.heIdent,
            withNavaids ? detail.runwayNavaids?.[runway.heIdent.toUpperCase()] : undefined,
            state.showGlideslope,
          );
        }
      }
    }
  }

  // ── 停机位 ──
  if (state.showParkings && zoom >= PARKING_MIN_ZOOM) {
    const showName = zoom >= PARKING_NAME_MIN_ZOOM;
    for (const spot of detail.parkingSpots) {
      const named = showName && !!spot.name;
      L.marker([spot.position.latitude, spot.position.longitude], {
        icon: L.divIcon({
          // 带名称的标签宽度交给 CSS 按内容自适应（见 .owo-map-autolabel）：
          // 原来按 `name.length * 8` 估宽，短名字白留一截、宽字符又装不下。
          className: named ? 'owo-map-autolabel' : '',
          html: parkingSpotHtml(named ? spot.name : undefined, spot.headingDeg),
          // iconSize 传 undefined，Leaflet 就不会把宽高写死在 style 上
          iconSize: named ? undefined : [16, 16],
          iconAnchor: named ? undefined : [8, 8],
        }),
        title: spot.name,
        interactive: false,
      }).addTo(group);
    }
  }
}

/**
 * 跑道入口标牌
 *
 * 只有编号时是一枚小方牌；带进近设施时展开成一小块信息板，
 * 排布照真实进近图：跑道号 + 类别在上，航向台频率、下滑角在下。
 */
export function addRunwayEndpointLabel(
  group: L.LayerGroup,
  position: { latitude: number; longitude: number },
  label: string,
  navaid: MapRunwayNavaid | undefined,
  showGlideslope: boolean,
): void {
  const identChip = `<span style="display:inline-flex;align-items:center;justify-content:center;
    min-width:26px;padding:0 5px;border-radius:3px;
    background:rgba(10,10,10,.88);border:1px solid rgba(255,255,255,.55);
    color:#fff;font-size:10px;font-weight:800;letter-spacing:.04em">${escapeHtml(label)}</span>`;

  if (!navaid?.category) {
    L.marker([position.latitude, position.longitude], {
      icon: L.divIcon({ className: 'owo-map-autolabel', html: centeredBox(identChip) }),
      interactive: false,
      zIndexOffset: MARKER_Z.runwayEndpoint,
    }).addTo(group);
    return;
  }

  const categoryColor = ILS_CATEGORY_MAP_COLOR[navaid.category] ?? '#9aa4b2';
  const rows: string[] = [];

  if (navaid.locFrequency) {
    rows.push(
      `<span style="color:#d7dce4">${escapeHtml(navaid.locIdent ?? 'LOC')}</span>
       <span style="color:#fff;font-weight:700">${escapeHtml(navaid.locFrequency)}</span>` +
        (navaid.locCourse !== undefined
          ? `<span style="color:#98a2b3">${Math.round(navaid.locCourse)}°</span>`
          : ''),
    );
  }
  if (showGlideslope && navaid.glideslopeAngle !== undefined) {
    rows.push(
      `<span style="color:#7fd4ff;font-weight:700">GS ${navaid.glideslopeAngle.toFixed(2)}°</span>` +
        (navaid.hasDme ? `<span style="color:#98a2b3">DME</span>` : ''),
    );
  } else if (navaid.hasDme) {
    rows.push(`<span style="color:#98a2b3">DME</span>`);
  }

  const body = `<div style="display:flex;flex-direction:column;gap:2px;align-items:flex-start;
      padding:3px 5px;border-radius:4px;
      background:rgba(10,12,16,.9);border:1px solid rgba(255,255,255,.28);
      box-shadow:0 1px 4px rgba(0,0,0,.55);white-space:nowrap;font-size:9px;line-height:1.1">
      <div style="display:flex;align-items:center;gap:4px">
        ${identChip}
        <span style="padding:0 4px;border-radius:2px;font-size:8px;font-weight:800;
          color:${categoryColor};border:1px solid ${categoryColor}">${escapeHtml(navaid.category)}</span>
      </div>
      ${rows.map((row) => `<div style="display:flex;gap:4px">${row}</div>`).join('')}
    </div>`;

  L.marker([position.latitude, position.longitude], {
    icon: L.divIcon({ className: 'owo-map-autolabel', html: centeredBox(body) }),
    interactive: false,
    zIndexOffset: MARKER_Z.runwayEndpoint,
  }).addTo(group);
}

/**
 * 画选中跑道的进近波束
 *
 * 只画被点开的那条跑道 —— 一次把所有跑道的波束都铺出来会糊成一片。
 * 一条跑道两端各画一束，因为两端的航道、类别、频率都不一样。
 */
export function renderApproachBeams(group: L.LayerGroup, detail: MapSelectedAirportDetail, ident: string): void {
  const runway = detail.runwayGeometries.find((item) => item.ident === ident);
  if (!runway) return;

  const ends: { ident: string; threshold: MapCoordinate; far: MapCoordinate }[] = [];
  if (runway.leIdent) ends.push({ ident: runway.leIdent, threshold: runway.start, far: runway.end });
  if (runway.heIdent) ends.push({ ident: runway.heIdent, threshold: runway.end, far: runway.start });

  for (const end of ends) {
    const key = end.ident.toUpperCase();
    const navaid = detail.runwayNavaids?.[key];
    const published = detail.runwayApproaches?.[key] ?? [];

    // 公布了哪几类就画哪几类；都没有时按跑道走向给一条 RNAV 示意
    const kinds: ApproachBeamKind[] = [];
    if (published.includes('ILS') || navaid?.category) kinds.push('ILS');
    if (published.includes('GLS')) kinds.push('GLS');
    if (published.some((type) => type === 'RNAV' || type === 'RNP-AR' || type === 'GPS')) {
      kinds.push('RNAV');
    }
    if (kinds.length === 0) continue;

    // 宽的画在下面，窄的叠在上面，几束重叠时都能看见
    for (const kind of kinds.slice().reverse()) {
      const beam = buildApproachBeam(kind, end.ident, end.threshold, end.far, navaid);
      if (!beam) continue;
      const style = BEAM_STYLE[kind];

      L.polygon(
        beam.polygon.map((point) => [point.latitude, point.longitude] as [number, number]),
        {
          color: style.color,
          weight: 1,
          opacity: 0.55,
          dashArray: style.dash,
          fillColor: style.color,
          fillOpacity: 0.08,
          interactive: false,
        },
      ).addTo(group);

      L.polyline(
        beam.centerline.map((point) => [point.latitude, point.longitude] as [number, number]),
        {
          color: style.color,
          weight: 1.5,
          opacity: 0.85,
          dashArray: style.dash ?? '14 8',
          interactive: false,
        },
      ).addTo(group);

      // 波束末端挂一块标签，写明类型、航道、频率
      addBeamLabel(group, beam.centerline[1], kind, beam, style.color);
    }
  }
}

export function addBeamLabel(
  group: L.LayerGroup,
  position: MapCoordinate,
  kind: ApproachBeamKind,
  beam: ReturnType<typeof buildApproachBeam> & object,
  color: string,
): void {
  const navaid = beam.navaid;
  const rows = [
    `${kind} ${beam.runway}`,
    `${Math.round(beam.course)}°${navaid?.locFrequency ? ` · ${navaid.locFrequency}` : ''}`,
    navaid?.glideslopeAngle !== undefined ? `GS ${navaid.glideslopeAngle.toFixed(2)}°` : null,
  ].filter((row): row is string => row !== null);

  L.marker([position.latitude, position.longitude], {
    icon: L.divIcon({
      className: 'owo-map-autolabel',
      html: centeredBox(`<div style="display:flex;flex-direction:column;gap:1px;
        padding:3px 6px;border-radius:4px;
        background:rgba(10,12,16,.9);border:1px solid ${color};
        box-shadow:0 1px 4px rgba(0,0,0,.55);white-space:nowrap;
        font-size:9px;font-weight:700;line-height:1.2;color:${color}">
        ${rows.map((row) => `<div>${escapeHtml(row)}</div>`).join('')}
      </div>`),
    }),
    interactive: false,
    zIndexOffset: MARKER_Z.runwayEndpoint,
  }).addTo(group);
}

/**
 * 画等待航线
 *
 * 画的是**航线本身**（那个跑道形的环圈），不是等待保护区 ——
 * 保护区还要叠风修正和导航容差，比航线大一大圈。
 */
export function renderHoldings(group: L.LayerGroup, holdings: readonly MapHoldingPattern[]): void {
  for (const hold of holdings) {
    const geometry = buildHoldingGeometry(hold);
    if (!geometry) continue;

    L.polyline(
      geometry.path.map((point) => [point.latitude, point.longitude] as [number, number]),
      {
        color: HOLDING_COLOR,
        weight: 1.8,
        opacity: 0.9,
        interactive: false,
      },
    ).addTo(group);

    // 定位点画个小菱形，顺带标出入航道与转向
    const altitude =
      hold.minAltitudeFt > 0
        ? `${Math.round(hold.minAltitudeFt)}${hold.maxAltitudeFt > 0 ? `-${Math.round(hold.maxAltitudeFt)}` : '+'} ft`
        : '';
    L.marker([geometry.fixPosition.latitude, geometry.fixPosition.longitude], {
      icon: L.divIcon({
        className: 'owo-map-autolabel',
        html: centeredBox(`<div style="display:flex;align-items:center;gap:4px;
          padding:2px 6px;border-radius:4px;
          background:rgba(10,12,16,.88);border:1px solid ${HOLDING_COLOR};
          color:${HOLDING_COLOR};font-size:9px;font-weight:700;white-space:nowrap">
          <span>${escapeHtml(geometry.fix)}</span>
          <span style="opacity:.75">${Math.round(geometry.inboundCourse)}° ${geometry.turnDirection}</span>
          ${altitude ? `<span style="opacity:.6">${escapeHtml(altitude)}</span>` : ''}
        </div>`),
      }),
      interactive: false,
    }).addTo(group);
  }
}
