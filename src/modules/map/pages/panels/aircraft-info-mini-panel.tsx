/**
 * 航空器信息迷你面板
 *
 * 移植自桌面版 `map_markers/aircraft_info_mini_panel.dart`：
 * 点飞机弹出，显示航班号/注册号、高度、地速、应答机；面板可拖，
 * 与飞机之间有一条引线。
 *
 * 定位与引线接点的算法在 `services/aircraft-info-panel-layout.ts`（纯函数、有单测），
 * 本组件只负责拖拽交互与渲染。
 */

import { useCallback, useEffect, useRef, useState } from 'react';

import { useTranslate } from '../../../../core/localization/use-translate';
import { MapLocalizationKeys as K } from '../../localization/map-localization';
import { useFlightDataStore } from '../../../common/providers/flight-data-store';
import { isBrightMapBackground } from '../../models/map-models';
import { useMapStore } from '../../providers/map-store';
import {
  PANEL_DEFAULT_OFFSET,
  layoutAircraftInfoPanel,
  resolveAircraftLabel,
  type ScreenPoint,
} from '../../services/aircraft-info-panel-layout';
import { formatClock } from '../../services/local-clock';
import { useClockTick } from '../../widgets/use-clock-tick';
import styles from '../map-page.module.css';

export interface AircraftInfoMiniPanelProps {
  /** 飞机在地图容器里的屏幕坐标 */
  aircraftScreenPoint: ScreenPoint;
  /** 地图容器尺寸 */
  viewport: { width: number; height: number };
  onClose: () => void;
}

export function AircraftInfoMiniPanel({
  aircraftScreenPoint,
  viewport,
  onClose,
}: AircraftInfoMiniPanelProps) {
  const t = useTranslate();
  const aircraft = useMapStore((s) => s.aircraft);
  const layerStyle = useMapStore((s) => s.layerStyle);
  // 航班号/应答机/注册号是应用级信息，在飞行数据快照里，不在地图 store
  const flightNumber = useFlightDataStore((s) => s.snapshot.flightNumber);
  const transponderCode = useFlightDataStore((s) => s.snapshot.transponderCode);
  const transponderState = useFlightDataStore((s) => s.snapshot.transponderState);
  const registration = useFlightDataStore((s) => s.snapshot.flightData.aircraftRegistration);
  // 本机所在位置的当地时间：时区从中间件查一次（按 0.1° 格点缓存），
  // 之后本地每秒自己走时 —— 显示一个跳秒的钟不该每秒去问一次后端
  const aircraftZone = useMapStore((s) => s.aircraftZone);
  const ensureAircraftZone = useMapStore((s) => s.ensureAircraftZone);
  const now = useClockTick();

  const [offset, setOffset] = useState<ScreenPoint>({ ...PANEL_DEFAULT_OFFSET });
  const dragRef = useRef<{ pointerId: number; startX: number; startY: number; base: ScreenPoint } | null>(
    null,
  );

  const handlePointerDown = useCallback(
    (event: React.PointerEvent<HTMLDivElement>) => {
      // 只接管左键/主指针，右键留给地图自己的上下文菜单
      if (event.button !== 0) return;
      event.stopPropagation();
      event.currentTarget.setPointerCapture(event.pointerId);
      dragRef.current = {
        pointerId: event.pointerId,
        startX: event.clientX,
        startY: event.clientY,
        base: offset,
      };
    },
    [offset],
  );

  const handlePointerMove = useCallback((event: React.PointerEvent<HTMLDivElement>) => {
    const drag = dragRef.current;
    if (!drag || drag.pointerId !== event.pointerId) return;
    setOffset({
      x: drag.base.x + (event.clientX - drag.startX),
      y: drag.base.y + (event.clientY - drag.startY),
    });
  }, []);

  const handlePointerUp = useCallback((event: React.PointerEvent<HTMLDivElement>) => {
    if (dragRef.current?.pointerId !== event.pointerId) return;
    dragRef.current = null;
    if (event.currentTarget.hasPointerCapture(event.pointerId)) {
      event.currentTarget.releasePointerCapture(event.pointerId);
    }
  }, []);

  // 飞机没了就自动收起，别留一个指向空处的面板
  useEffect(() => {
    if (!aircraft) onClose();
  }, [aircraft, onClose]);

  /*
   * 时区只在面板开着时查，且飞出 0.1° 格点才重查（判断在 store 里）。
   * 依赖里挂经纬度而不是整个 aircraft：后者每帧都是新对象，会让这个 effect 每帧都跑。
   */
  const latitude = aircraft?.position.latitude;
  const longitude = aircraft?.position.longitude;
  useEffect(() => {
    if (latitude === undefined || longitude === undefined) return;
    void ensureAircraftZone();
  }, [latitude, longitude, ensureAircraftZone]);

  if (!aircraft) return null;

  const layout = layoutAircraftInfoPanel({
    aircraft: aircraftScreenPoint,
    viewport,
    offset,
  });
  const bright = isBrightMapBackground(layerStyle);
  const label = resolveAircraftLabel(flightNumber, registration);

  const altitudeText =
    aircraft.altitude === undefined ? '--' : `${Math.round(aircraft.altitude)} ft`;
  const speedText =
    aircraft.groundSpeed === undefined ? '--' : `${Math.round(aircraft.groundSpeed)} kts`;
  const xpdr = `${(transponderCode ?? '----').trim() || '----'} ${
    (transponderState ?? '--').trim() || '--'
  }`;
  // 时区还没查到就显示占位，不要拿 UTC 冒充当地时间 —— 那会给出一个
  // 看着很正常的错时间，比明摆着说「还不知道」危险得多
  const localTimeText = aircraftZone ? formatClock(now, aircraftZone.timezone) : '--:--:--';

  return (
    <>
      {/*
        引线单独一层 SVG 铺满容器：画在面板里的话，面板一旦被 clamp 到边缘，
        线就会跟着被裁掉。pointer-events 关掉，免得挡住地图拖动。
      */}
      <svg
        className={styles.aircraftInfoConnector}
        width={viewport.width}
        height={viewport.height}
        aria-hidden="true"
      >
        <line
          x1={layout.lineStart.x}
          y1={layout.lineStart.y}
          x2={layout.lineEnd.x}
          y2={layout.lineEnd.y}
          stroke={bright ? 'rgba(0,0,0,0.34)' : 'rgba(255,255,255,0.38)'}
          strokeWidth={1.3}
        />
      </svg>

      <div
        className={`${styles.aircraftInfoPanel}${bright ? ` ${styles.aircraftInfoPanelBright}` : ''}`}
        style={{ left: layout.left, top: layout.top, width: layout.width, height: layout.height }}
        onPointerDown={handlePointerDown}
        onPointerMove={handlePointerMove}
        onPointerUp={handlePointerUp}
        onPointerCancel={handlePointerUp}
        role="dialog"
        aria-label={t(K.aircraftInfoPanelTitle)}
      >
        <div className={styles.aircraftInfoHead}>
          <span className={styles.aircraftInfoLabel}>{label}</span>
          <button
            type="button"
            className={styles.aircraftInfoClose}
            aria-label={t(K.clearSearch)}
            // 关闭按钮不能触发拖拽
            onPointerDown={(event) => event.stopPropagation()}
            onClick={onClose}
          >
            ×
          </button>
        </div>
        <div className={styles.aircraftInfoCells}>
          <InfoCell label="ALT" value={altitudeText} accent />
          <InfoCell label="SPD" value={speedText} />
          <InfoCell label="XPDR" value={xpdr} />
          {/* LT = local time，与 ALT/SPD/XPDR 一样用航空缩写，完整说明放在 title 上 */}
          <InfoCell
            label="LT"
            value={localTimeText}
            title={
              aircraftZone
                ? `${t(K.aircraftLocalTime)} · ${aircraftZone.timezone}`
                : t(K.aircraftLocalTime)
            }
          />
        </div>
      </div>
    </>
  );
}

function InfoCell({
  label,
  value,
  accent = false,
  title,
}: {
  label: string;
  value: string;
  accent?: boolean;
  title?: string;
}) {
  return (
    <span className={styles.aircraftInfoCell} title={title}>
      <span className={styles.aircraftInfoCellLabel}>{label}</span>
      <span
        className={`${styles.aircraftInfoCellValue}${
          accent ? ` ${styles.aircraftInfoCellAccent}` : ''
        } text-mono`}
      >
        {value}
      </span>
    </span>
  );
}
