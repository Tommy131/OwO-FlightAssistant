/**
 * 公布程序图层（SID / STAR / 进近）
 *
 * 与「计划航路」的区别：那是这一趟要飞的航路（来自 SimBrief），
 * 这里画的是机场**公布的**标准程序，用来对照与预习。两者可能同屏，配色要拉开。
 *
 * ── 没有坐标的航段怎么办 ──
 * `CA`（飞到某高度）这类以条件结束的航段本就没有定位点。**不能跳过它直接把
 * 前后两点连起来** —— 那会画出一条根本不存在的直线。正确做法是就地断开：
 * 前一段画到此为止，下一个有坐标的点另起一段。
 */

import L from 'leaflet';
import { escapeHtml } from '../../../../core/utils/escape-html';
import type { MapProcedure, MapProcedureKind } from '../../models/map-models';
import { formatAltitudeConstraint } from '../../services/procedure-parser';
import { MARKER_Z } from './layer-style';

/** 航路点标签的最低缩放级别 */
export const PROCEDURE_LABEL_MIN_ZOOM = 8;

/**
 * 三类程序分色。
 *
 * 与计划航路（青 #38bdf8 / 紫 #c084fc）刻意错开：
 * 同屏时得一眼分清「公布的标准程序」与「这趟要飞的航路」。
 */
const PROCEDURE_STYLE: Record<MapProcedureKind, { color: string; dashArray?: string }> = {
  SID: { color: '#4ade80' },
  STAR: { color: '#fbbf24' },
  APPROACH: { color: '#f87171', dashArray: '6 4' },
};

/** 航路点标记 + 高度限制标注 */
function procedurePointHtml(
  ident: string,
  color: string,
  constraint: string | undefined,
  showLabel: boolean,
): string {
  const dot = `<span style="width:7px;height:7px;border-radius:50%;background:${color};
    border:1.5px solid rgba(255,255,255,.9);flex-shrink:0"></span>`;
  if (!showLabel) {
    return `<div style="position:absolute;left:0;top:0;transform:translate(-50%,-50%);
      display:flex;align-items:center">${dot}</div>`;
  }
  // 高度限制单独一行，按航图习惯压在标识下方
  const constraintLine = constraint
    ? `<div style="font-size:8px;font-weight:600;color:${color};line-height:1.1">
        ${escapeHtml(constraint)}</div>`
    : '';
  return `<div style="position:absolute;left:0;top:0;transform:translate(-50%,-50%);
    display:flex;align-items:center;gap:4px">
    ${dot}
    <div style="padding:1px 5px;border-radius:7px;background:rgba(12,18,28,.85);
      border:1px solid ${color};color:#eaf6ff;font-size:9px;font-weight:600;
      white-space:nowrap;text-align:left">
      <div style="line-height:1.15">${escapeHtml(ident)}</div>${constraintLine}
    </div>
  </div>`;
}

/**
 * 重画选中的程序。
 *
 * 一次只画一条：机场动辄上百条程序（ZBAA 实测 154 条），全画出来就是一团麻。
 */
export function renderProcedure(
  map: L.Map,
  group: L.LayerGroup | undefined,
  procedure: MapProcedure | null,
  visible: boolean,
): void {
  if (!group) return;
  group.clearLayers();
  if (!visible || !procedure) return;

  const style = PROCEDURE_STYLE[procedure.kind];
  const showLabel = map.getZoom() >= PROCEDURE_LABEL_MIN_ZOOM;

  /*
   * 按「有坐标的连续段」切分。
   *
   * 遇到没有坐标的航段（CA/VA…）就断开当前段 —— 直接跳过去连线会凭空画出
   * 一条不存在的航迹，看起来还挺像回事，正因如此才更容易骗过人。
   */
  let current: [number, number][] = [];
  const flush = () => {
    if (current.length >= 2) {
      L.polyline(current, {
        color: style.color,
        weight: 2.5,
        opacity: 0.9,
        dashArray: style.dashArray,
      }).addTo(group);
    }
    current = [];
  };

  for (const leg of procedure.legs) {
    if (!leg.hasPosition || !leg.position) {
      flush();
      continue;
    }
    current.push([leg.position.latitude, leg.position.longitude]);
  }
  flush();

  for (const leg of procedure.legs) {
    if (!leg.hasPosition || !leg.position) continue;
    const marker = L.marker([leg.position.latitude, leg.position.longitude], {
      icon: L.divIcon({
        className: 'owo-map-autolabel',
        html: procedurePointHtml(
          leg.fixIdent ?? '',
          style.color,
          formatAltitudeConstraint(leg),
          showLabel,
        ),
        iconSize: undefined,
      }),
      zIndexOffset: MARKER_Z.taxiwayRef,
      interactive: true,
    });

    const detail = [
      leg.legType,
      formatAltitudeConstraint(leg),
      leg.speedLimitKt !== undefined && leg.speedLimitKt > 0
        ? `${leg.speedLimitKt.toFixed(0)} kt`
        : undefined,
    ]
      .filter((part): part is string => part !== undefined && part.length > 0)
      .join(' · ');
    marker.bindTooltip(
      `${escapeHtml(leg.fixIdent ?? '')}${detail ? ` — ${escapeHtml(detail)}` : ''}`,
      { direction: 'top' },
    );
    marker.addTo(group);
  }
}

/** 程序的唯一键：同名程序会有多条转换（不同跑道），必须连转换一起区分 */
export function procedureKey(procedure: MapProcedure): string {
  return `${procedure.kind}|${procedure.name}|${procedure.transition ?? ''}`;
}
