import { useEffect, useRef, useState } from 'react';
import { useTranslate } from '../../../core/localization/use-translate';
import { IconButton, TextField } from '../../../core/widgets/common/controls';
import { showAdvancedConfirmDialog } from '../../../core/widgets/common/dialog';
import { MaterialIcon } from '../../../core/widgets/common/icon';
import { SnackBarHelper } from '../../../core/widgets/common/snack-bar';
import { InfoChip } from '../../../core/widgets/common/surfaces';
import { toJsonMap, type JsonMap } from '../../../core/utils/parse-utils';
import { suggestionFromApi } from '../../airport_search/models/airport-search-models';
import { MiddlewareHttpService } from '../../http/services/middleware-http-service';
import { MapLocalizationKeys as K } from '../localization/map-localization';
import {
  MAP_ALERT_LEVEL_COLOR,
  MAP_LAYER_STYLES,
  type MapAirportMarker,
  type MapCoordinate,
  type MapLayerStyle,
  type MapRunwayNavaid,
} from '../models/map-models';
import { useMapStore } from '../providers/map-store';
import { parseAirportDetail } from '../services/map-airport-parser';
import { MapLegendStack } from '../widgets/map-legend';
import { PapiIndicator } from '../widgets/papi-indicator';
import { MarqueeText } from '../widgets/marquee-text';
import { MapCanvas } from './map-canvas';
import styles from './map-page.module.css';

/**
 * 地图页面
 *
 * 对应 Flutter 版 `modules/map/pages/map_page.dart`（4218 行）与 widgets/ 下 20+ 组件：
 * 顶部搜索与飞行状态条 / 左下 HUD / 右侧控制栏 / 图层选择器 /
 * 滑行道绘制工具条 / 选中机场底卡 / 告警浮层。
 */
/** 搜索联想候选项 */
interface AirportSuggestion {
  icao: string;
  label: string;
}

export function MapPage() {
  const t = useTranslate();
  const init = useMapStore((s) => s.init);
  const initialized = useRef(false);

  const [layerPickerOpen, setLayerPickerOpen] = useState(false);
  const [searchValue, setSearchValue] = useState('');

  useEffect(() => {
    if (initialized.current) return;
    initialized.current = true;
    void init();
  }, [init]);

  const selectAirportByIcao = async (icao: string) => {
    const code = icao.trim().toUpperCase();
    if (code.length === 0) return;
    try {
      await MiddlewareHttpService.init();
      const response = await MiddlewareHttpService.getAirportByIcao(code);
      const body = response.objectBody;
      if (!body) throw new Error('invalid response');
      const detail = parseAirportDetail(body, code);
      if (!detail) throw new Error('parse failed');
      useMapStore.getState().setSelectedAirport(detail);
    } catch {
      SnackBarHelper.showWarning(t(K.searchNoResult));
    }
  };

  const handleAirportClick = (airport: MapAirportMarker) => {
    void selectAirportByIcao(airport.code);
  };

  /** 联想建议：非四位精确 ICAO 时给候选列表（占位符承诺了名称/IATA 检索） */
  const fetchSuggestions = async (keyword: string): Promise<AirportSuggestion[]> => {
    const query = keyword.trim();
    if (query.length === 0) return [];
    try {
      await MiddlewareHttpService.init();
      const response = await MiddlewareHttpService.getAirportSuggestions(query);
      const body = response.objectBody;
      const raw = body?.suggestions;
      if (!Array.isArray(raw)) return [];
      return raw
        .map((item) => toJsonMap(item))
        .filter((item): item is JsonMap => item !== null)
        .map((item) => {
          const suggestion = suggestionFromApi(item);
          return {
            icao: suggestion.icao,
            label: [suggestion.name, suggestion.source].filter(Boolean).join(' · '),
          };
        })
        .filter((item) => item.icao.length > 0);
    } catch {
      return [];
    }
  };

  const handleMapClick = (point: MapCoordinate) => {
    // 绘制模式下点击地图 = 添加滑行道节点
    if (useMapStore.getState().isTaxiwayDrawingActive) {
      useMapStore.getState().addTaxiwayNode(point);
    }
  };

  return (
    <div className={styles.page}>
      <MapCanvas onAirportClick={handleAirportClick} onMapClick={handleMapClick} />

      <MapTopPanel
        searchValue={searchValue}
        onSearchChange={setSearchValue}
        onSearchSubmit={() => void selectAirportByIcao(searchValue)}
        onFetchSuggestions={fetchSuggestions}
        onSelectSuggestion={(icao) => {
          setSearchValue(icao);
          void selectAirportByIcao(icao);
        }}
      />

      <MapHud />
      <MapAlertOverlay />
      <MapLegendStack />
      {/* 只在满足进近条件时自己出现 */}
      <PapiIndicator />

      <MapRightControls onOpenLayerPicker={() => setLayerPickerOpen(true)} />

      <TaxiwayToolbar />

      {layerPickerOpen && <MapLayerPicker onClose={() => setLayerPickerOpen(false)} />}

      <SelectedAirportCard />
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 顶部面板：搜索 + 飞行状态
// ──────────────────────────────────────────────────────────────────────────

function MapTopPanel({
  searchValue,
  onSearchChange,
  onSearchSubmit,
  onFetchSuggestions,
  onSelectSuggestion,
}: {
  searchValue: string;
  onSearchChange: (value: string) => void;
  onSearchSubmit: () => void;
  onFetchSuggestions: (keyword: string) => Promise<AirportSuggestion[]>;
  onSelectSuggestion: (icao: string) => void;
}) {
  const t = useTranslate();
  const aircraft = useMapStore((s) => s.aircraft);
  const isConnected = useMapStore((s) => s.isConnected);
  const isPaused = useMapStore((s) => s.isPaused);
  const nearestIcao = useMapStore((s) => s.currentNearestAirportIcao);

  const [suggestions, setSuggestions] = useState<AirportSuggestion[]>([]);
  const [showSuggestions, setShowSuggestions] = useState(false);

  // 输入防抖 250ms，避免每敲一个字母打一次接口
  useEffect(() => {
    const query = searchValue.trim();
    if (query.length < 2) {
      setSuggestions([]);
      return;
    }
    let cancelled = false;
    const timer = setTimeout(() => {
      void onFetchSuggestions(query).then((result) => {
        if (!cancelled) setSuggestions(result);
      });
    }, 250);
    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [searchValue]);

  return (
    <div className={styles.topPanel}>
      <div className={styles.searchBar}>
        <TextField
          value={searchValue}
          onChange={(value) => {
            onSearchChange(value.toUpperCase());
            setShowSuggestions(true);
          }}
          placeholder={t(K.searchHint)}
          icon="search"
          monospace
          onSubmit={() => {
            setShowSuggestions(false);
            onSearchSubmit();
          }}
          onFocus={() => setShowSuggestions(true)}
          trailing={
            searchValue.length > 0 ? (
              <IconButton
                icon="close"
                label={t(K.clearSearch)}
                size={16}
                onClick={() => {
                  onSearchChange('');
                  setSuggestions([]);
                }}
              />
            ) : undefined
          }
        />

        {showSuggestions && suggestions.length > 0 && (
          <div className={styles.suggestionList}>
            {suggestions.map((suggestion) => (
              <button
                key={suggestion.icao}
                type="button"
                className={styles.suggestionItem}
                onClick={() => {
                  setShowSuggestions(false);
                  onSelectSuggestion(suggestion.icao);
                }}
              >
                <span className={`${styles.suggestionIcao} text-mono`}>{suggestion.icao}</span>
                <span className={styles.suggestionLabel}>{suggestion.label}</span>
              </button>
            ))}
          </div>
        )}
      </div>

      <div className={styles.statusChips}>
        {isPaused && <InfoChip icon="pause" label="PAUSED" color="var(--color-warning)" solid />}
        {nearestIcao && <InfoChip icon="local_airport" label={nearestIcao} />}
        {isConnected && aircraft && (
          <>
            <InfoChip icon="height" label={`${(aircraft.altitude ?? 0).toFixed(0)} ft`} />
            <InfoChip icon="speed" label={`${(aircraft.groundSpeed ?? 0).toFixed(0)} kt`} />
            <InfoChip icon="explore" label={`${(aircraft.heading ?? 0).toFixed(0)}°`} />
          </>
        )}
      </div>
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// HUD：计时器 + 航迹点数
// ──────────────────────────────────────────────────────────────────────────

function MapHud() {
  const t = useTranslate();
  const hudElapsedMs = useMapStore((s) => s.hudElapsedMs);
  const isRunning = useMapStore((s) => s.isHudTimerRunning);
  const routeCount = useMapStore((s) => s.route.length);
  const toggleHudTimer = useMapStore((s) => s.toggleHudTimer);
  const resetHudTimer = useMapStore((s) => s.resetHudTimer);
  const clearRoute = useMapStore((s) => s.clearRoute);

  const handleClearRoute = async () => {
    const confirmed = await showAdvancedConfirmDialog({
      title: t(K.clearRouteConfirmTitle),
      content: t(K.clearRouteConfirmContent),
      icon: 'delete_sweep',
      confirmColor: 'var(--color-danger)',
      confirmText: t(K.clearButton),
      cancelText: t(K.taxiwayAutoLoadSkip),
    });
    if (confirmed === true) clearRoute();
  };

  return (
    <div className={styles.hud}>
      <div className={styles.hudTimer}>
        <span className={`${styles.hudTime} text-mono`}>{formatElapsed(hudElapsedMs)}</span>
        <div className={styles.hudTimerActions}>
          <IconButton
            icon={isRunning ? 'pause' : 'play_arrow'}
            label={t(K.timerSectionTitle)}
            onClick={toggleHudTimer}
            active={isRunning}
          />
          <IconButton icon="restart_alt" label={t(K.clearButton)} onClick={resetHudTimer} />
        </div>
      </div>

      <div className={styles.hudRow}>
        <MaterialIcon name="timeline" size={14} color="var(--color-text-secondary)" />
        <span className={styles.hudLabel}>
          {routeCount} {t(K.routePoints)}
        </span>
        {routeCount > 0 && (
          <IconButton
            icon="delete_sweep"
            label={t(K.clearRoute)}
            size={16}
            onClick={() => void handleClearRoute()}
          />
        )}
      </div>
    </div>
  );
}

function formatElapsed(ms: number): string {
  const totalSeconds = Math.floor(ms / 1000);
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${pad(hours)}:${pad(minutes)}:${pad(seconds)}`;
}

// ──────────────────────────────────────────────────────────────────────────
// 告警浮层
// ──────────────────────────────────────────────────────────────────────────

function MapAlertOverlay() {
  const alerts = useMapStore((s) => s.activeAlerts);
  if (alerts.length === 0) return null;

  return (
    <div className={styles.alertOverlay}>
      {alerts.map((alert) => (
        <div
          key={alert.id}
          className={styles.alertBanner}
          style={{
            color: MAP_ALERT_LEVEL_COLOR[alert.level],
            borderColor: MAP_ALERT_LEVEL_COLOR[alert.level],
          }}
        >
          <MaterialIcon name="warning" filled size={18} />
          {alert.message}
        </div>
      ))}
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 右侧控制栏
// ──────────────────────────────────────────────────────────────────────────

interface ControlToggle {
  icon: string;
  label: string;
  active: boolean;
  onClick: () => void;
}

interface ControlGroup {
  id: string;
  icon: string;
  label: string;
  items: ControlToggle[];
}

/**
 * 右侧控制栏
 *
 * 十七八个开关平铺一列会占掉半个屏幕，所以按用途归成几组：
 * 平时只显示组图标，鼠标移上去自动展开该组，点一下则固定展开（不随移出收起）。
 * 组图标在任一子开关打开时高亮，收起状态下也能看出这组里有东西开着。
 */
function MapRightControls({ onOpenLayerPicker }: { onOpenLayerPicker: () => void }) {
  const t = useTranslate();
  const state = useMapStore();

  // 悬停展开的组；点击固定的组单独记，两者取并集显示
  const [hoveredGroup, setHoveredGroup] = useState<string | null>(null);
  const [pinnedGroup, setPinnedGroup] = useState<string | null>(null);

  const groups: ControlGroup[] = [
    {
      id: 'flight',
      icon: 'flight',
      label: t(K.controlGroupFlight),
      items: [
        {
          icon: 'my_location',
          label: t(K.tooltipFollow),
          active: state.followAircraft,
          onClick: state.toggleFollowAircraft,
        },
        {
          icon: 'timeline',
          label: t(K.toggleRoute),
          active: state.showRoute,
          onClick: state.toggleRoute,
        },
        {
          icon: 'explore',
          label: t(K.toggleCompass),
          active: state.showCompass,
          onClick: state.toggleCompass,
        },
      ],
    },
    {
      id: 'airport',
      icon: 'connecting_airports',
      label: t(K.controlGroupAirport),
      items: [
        {
          icon: 'local_airport',
          label: t(K.toggleAirports),
          active: state.showAirports,
          onClick: state.toggleAirports,
        },
        {
          icon: 'horizontal_rule',
          label: t(K.toggleRunways),
          active: state.showRunways,
          onClick: state.toggleRunways,
        },
        {
          icon: 'local_parking',
          label: t(K.toggleParkings),
          active: state.showParkings,
          onClick: state.toggleParkings,
        },
        {
          icon: 'alt_route',
          label: t(K.toggleAeroway),
          active: state.showAeroway,
          onClick: state.toggleAeroway,
        },
      ],
    },
    {
      id: 'procedure',
      icon: 'flight_land',
      label: t(K.controlGroupProcedure),
      items: [
        {
          icon: 'cell_tower',
          label: t(K.toggleRunwayNavaids),
          active: state.showRunwayNavaids,
          onClick: state.toggleRunwayNavaids,
        },
        {
          icon: 'loop',
          label: t(K.toggleHoldings),
          active: state.showHoldings,
          onClick: state.toggleHoldings,
        },
        {
          icon: 'trending_down',
          label: t(K.runwayGlideslope),
          active: state.showGlideslope,
          onClick: state.toggleGlideslope,
        },
      ],
    },
    {
      id: 'weather',
      icon: 'cloud',
      label: t(K.controlGroupWeather),
      items: [
        {
          icon: 'radar',
          label: t(K.toggleWeather),
          active: state.showWeather,
          onClick: state.toggleWeather,
        },
        {
          icon: 'water_drop',
          label: t(K.toggleWeatherRainfall),
          active: state.showWeatherRainfall,
          onClick: state.toggleWeatherRainfall,
        },
        {
          icon: 'air',
          label: t(K.toggleWeatherWind),
          active: state.showWeatherWind,
          onClick: state.toggleWeatherWind,
        },
        {
          icon: 'compress',
          label: t(K.toggleWeatherPressure),
          active: state.showWeatherPressure,
          onClick: state.toggleWeatherPressure,
        },
        {
          icon: 'thermostat',
          label: t(K.toggleWeatherTemperature),
          active: state.showWeatherTemperature,
          onClick: state.toggleWeatherTemperature,
        },
      ],
    },
    {
      id: 'hazard',
      icon: 'warning',
      label: t(K.controlGroupHazard),
      items: [
        {
          icon: 'block',
          label: t(K.toggleRestrictedAirspace),
          active: state.showRestrictedAirspace,
          onClick: state.toggleRestrictedAirspace,
        },
        {
          icon: 'terrain',
          label: t(K.toggleTerrainWarning),
          active: state.showTerrainWarning,
          onClick: state.toggleTerrainWarning,
        },
      ],
    },
    {
      id: 'taxiway',
      icon: 'edit_road',
      label: t(K.controlGroupTaxiway),
      items: [
        {
          icon: 'polyline',
          label: t(K.toggleCustomTaxiway),
          active: state.showCustomTaxiwayRoute,
          onClick: state.toggleCustomTaxiway,
        },
        {
          icon: 'draw',
          label: t(K.toggleTaxiwayDrawing),
          active: state.isTaxiwayDrawingActive,
          onClick: state.toggleTaxiwayDrawing,
        },
      ],
    },
  ];

  // 点击地图空白处收起固定展开的组
  useEffect(() => {
    if (!pinnedGroup) return;
    const close = (event: MouseEvent) => {
      // target 不一定是元素（可能是 document 本身），closest 只有 Element 才有
      const target = event.target;
      if (target instanceof Element && target.closest(`.${styles.rightControls}`)) {
        // 点在控制栏自己身上不算「点空白」
        return;
      }
      setPinnedGroup(null);
    };
    document.addEventListener('mousedown', close);
    return () => document.removeEventListener('mousedown', close);
  }, [pinnedGroup]);

  return (
    <div
      // 不能带 scroll-area：那个工具类会设 overflow，把向左弹出的子面板裁掉
      className={styles.rightControls}
      onMouseLeave={() => setHoveredGroup(null)}
    >
      <IconButton icon="layers" label={t(K.layerTitle)} onClick={onOpenLayerPicker} />
      <span className={styles.controlDivider} />

      {groups.map((group) => {
        const expanded = hoveredGroup === group.id || pinnedGroup === group.id;
        const anyActive = group.items.some((item) => item.active);
        return (
          <div
            key={group.id}
            className={styles.controlGroup}
            onMouseEnter={() => setHoveredGroup(group.id)}
          >
            <IconButton
              icon={group.icon}
              label={group.label}
              active={anyActive}
              onClick={() => setPinnedGroup((current) => (current === group.id ? null : group.id))}
            />
            {/* 常驻展开时给个小圆点，跟单纯悬停展开区分开 */}
            {pinnedGroup === group.id && <span className={styles.groupPinnedDot} />}

            {expanded && (
              <div className={styles.groupFlyout}>
                {group.items.map((item) => (
                  <IconButton
                    key={item.label}
                    icon={item.icon}
                    label={item.label}
                    active={item.active}
                    onClick={item.onClick}
                  />
                ))}
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 图层选择器
// ──────────────────────────────────────────────────────────────────────────

const LAYER_LABEL_KEY: Record<MapLayerStyle, string> = {
  dark: K.layerDark,
  satellite: K.layerSatellite,
  terrain: K.layerTerrain,
  taxiway: K.layerTaxiway,
};

const LAYER_ICON: Record<MapLayerStyle, string> = {
  dark: 'dark_mode',
  satellite: 'satellite_alt',
  terrain: 'terrain',
  taxiway: 'map',
};

function MapLayerPicker({ onClose }: { onClose: () => void }) {
  const t = useTranslate();
  const layerStyle = useMapStore((s) => s.layerStyle);
  const setLayerStyle = useMapStore((s) => s.setLayerStyle);

  return (
    <div className={styles.pickerScrim} onClick={onClose} role="presentation">
      <div className={styles.pickerCard} onClick={(event) => event.stopPropagation()}>
        <div className={styles.pickerHead}>
          <MaterialIcon name="layers" size={17} color="var(--color-primary)" />
          <span>{t(K.layerTitle)}</span>
        </div>
        <div className={styles.pickerGrid}>
          {MAP_LAYER_STYLES.map((style) => (
            <button
              key={style}
              type="button"
              className={`${styles.pickerItem}${style === layerStyle ? ` ${styles.pickerItemActive}` : ''}`}
              onClick={() => {
                void setLayerStyle(style);
                onClose();
              }}
            >
              <MaterialIcon name={LAYER_ICON[style]} size={22} filled={style === layerStyle} />
              {t(LAYER_LABEL_KEY[style])}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 滑行道绘制工具条
// ──────────────────────────────────────────────────────────────────────────

function TaxiwayToolbar() {
  const t = useTranslate();
  const isActive = useMapStore((s) => s.isTaxiwayDrawingActive);
  const nodeCount = useMapStore((s) => s.taxiwayNodes.length);
  const hasUnsaved = useMapStore((s) => s.hasUnsavedTaxiwayChanges);
  const undo = useMapStore((s) => s.undoTaxiwayRoute);
  const redo = useMapStore((s) => s.redoTaxiwayRoute);
  const canUndo = useMapStore((s) => s.canUndoTaxiwayRoute);
  const canRedo = useMapStore((s) => s.canRedoTaxiwayRoute);
  const clear = useMapStore((s) => s.clearTaxiwayRoute);
  const exportRoute = useMapStore((s) => s.exportTaxiwayRoute);
  const importRoute = useMapStore((s) => s.importTaxiwayRoute);
  const fileInputRef = useRef<HTMLInputElement>(null);

  if (!isActive) return null;

  const handleExport = () => {
    const result = exportRoute();
    if (result === 1) SnackBarHelper.showSuccess(t(K.taxiwayExportSuccess));
    else SnackBarHelper.showWarning(t(K.taxiwayNoRouteToSave));
  };

  const handleImport = async (file: File) => {
    const count = await importRoute(file);
    if (count > 0) SnackBarHelper.showSuccess(t(K.taxiwayImportSuccess, count));
    else SnackBarHelper.showError(t(K.taxiwayImportInvalid));
  };

  const handleClear = async () => {
    const confirmed = await showAdvancedConfirmDialog({
      title: t(K.tooltipTaxiwayClear),
      content: t(K.clearRouteConfirmContent),
      icon: 'ink_eraser',
      confirmColor: 'var(--color-danger)',
      confirmText: t(K.clearButton),
      cancelText: t(K.taxiwayAutoLoadSkip),
    });
    if (confirmed === true) clear();
  };

  return (
    <div className={styles.taxiwayToolbar}>
      <span className={styles.taxiwayHint}>
        <MaterialIcon name="touch_app" size={14} />
        {t(K.taxiwayNode)} · {nodeCount}
        {hasUnsaved && <span className={styles.unsavedDot} title={t(K.taxiwayEditUnsaved)} />}
      </span>

      <IconButton
        icon="undo"
        label={t(K.tooltipTaxiwayUndo)}
        disabled={!canUndo()}
        onClick={undo}
      />
      <IconButton
        icon="redo"
        label={t(K.tooltipTaxiwayRedo)}
        disabled={!canRedo()}
        onClick={redo}
      />
      {/* 用橡皮而不是 delete_sweep：那个已经是 HUD「清除航迹」的图标，
          这里清的是手绘的滑行道，是两件事 */}
      <IconButton
        icon="ink_eraser"
        label={t(K.tooltipTaxiwayClear)}
        disabled={nodeCount === 0}
        onClick={() => void handleClear()}
      />
      <span className={styles.controlDivider} />
      <IconButton
        icon="upload_file"
        label={t(K.tooltipTaxiwayImport)}
        onClick={() => fileInputRef.current?.click()}
      />
      <IconButton icon="download" label={t(K.tooltipTaxiwaySave)} onClick={handleExport} />

      <input
        ref={fileInputRef}
        type="file"
        accept=".json"
        className="sr-only"
        onChange={(event) => {
          const file = event.target.files?.[0];
          event.target.value = '';
          if (file) void handleImport(file);
        }}
      />
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 选中机场底卡
// ──────────────────────────────────────────────────────────────────────────

/** 飞行等级配色，与桌面版 ApproachRuleBadge 一致 */
const APPROACH_RULE_STYLE: Record<string, { color: string; icon: string }> = {
  VFR: { color: '#35d07f', icon: 'wb_sunny' },
  MVFR: { color: '#4db7ff', icon: 'cloud_queue' },
  IFR: { color: '#ffa63d', icon: 'grain' },
  LIFR: { color: '#ff5c6a', icon: 'thunderstorm' },
};

/**
 * ILS 类别配色
 *
 * 类别越高、可用的决断高度越低，对天气的容忍度越强，
 * 所以按「能力递增」上色：CAT I 常规蓝，CAT II 提升，CAT III 最高。
 * 只有航向台（LOC，没有下滑道）单独一档灰，避免被误当成精密进近。
 */
const ILS_CATEGORY_COLOR: Record<string, string> = {
  'CAT I': '#4db7ff',
  'CAT II': '#35d07f',
  'CAT III': '#a78bfa',
  ILS: '#4db7ff',
  LOC: '#9aa4b2',
};

/** 单个跑道端的进近设施徽标 */
function RunwayNavaidChips({
  end,
  navaid,
  showGlideslope,
}: {
  end: string;
  navaid?: MapRunwayNavaid;
  showGlideslope: boolean;
}) {
  const t = useTranslate();

  // 没有 ILS 的跑道端也要标出来，否则会被误以为是数据没加载出来
  if (!navaid?.category) {
    return (
      <span className={styles.runwayEnd}>
        <span className={`${styles.runwayEndIdent} text-mono`}>{end}</span>
        <span className={styles.navaidNone}>{t(K.runwayNoIls)}</span>
      </span>
    );
  }

  const color = ILS_CATEGORY_COLOR[navaid.category] ?? 'var(--color-text-secondary)';

  return (
    <span className={styles.runwayEnd}>
      <span className={`${styles.runwayEndIdent} text-mono`}>{end}</span>
      <span
        className={styles.navaidCategory}
        style={{
          color,
          borderColor: `color-mix(in srgb, ${color} 60%, transparent)`,
          background: `color-mix(in srgb, ${color} 14%, transparent)`,
        }}
      >
        {navaid.category}
      </span>
      {navaid.locFrequency && (
        <span className={`${styles.navaidChip} text-mono`} title={t(K.runwayLocHint)}>
          {navaid.locIdent ? `${navaid.locIdent} ` : ''}
          {navaid.locFrequency}
          {navaid.locCourse !== undefined && ` · ${Math.round(navaid.locCourse)}°`}
        </span>
      )}
      {showGlideslope && navaid.glideslopeAngle !== undefined && (
        <span className={styles.navaidGlideslope} title={t(K.runwayGlideslopeHint)}>
          <MaterialIcon name="airline_stops" size={10} />
          GS {navaid.glideslopeAngle.toFixed(2)}°
        </span>
      )}
      {navaid.hasDme && (
        <span className={styles.navaidChip} title={t(K.runwayDmeHint)}>
          DME
        </span>
      )}
    </span>
  );
}

function SelectedAirportCard() {
  const t = useTranslate();
  const detail = useMapStore((s) => s.selectedAirport);
  const homeAirport = useMapStore((s) => s.homeAirport);
  const setSelectedAirport = useMapStore((s) => s.setSelectedAirport);
  const setHomeAirport = useMapStore((s) => s.setHomeAirport);
  const clearHomeAirport = useMapStore((s) => s.clearHomeAirport);
  // 原文 / 解读切换；换机场时回到原文（与桌面版 didUpdateWidget 行为一致）
  const [showDecoded, setShowDecoded] = useState(false);
  // 下滑道开关放在 store 里：卡片和地图上的跑道标注共用同一个状态
  const showGlideslope = useMapStore((s) => s.showGlideslope);
  const toggleGlideslope = useMapStore((s) => s.toggleGlideslope);
  const shownCode = useRef<string | undefined>(undefined);

  const code = detail?.marker.code;
  useEffect(() => {
    if (shownCode.current === code) return;
    shownCode.current = code;
    setShowDecoded(false);
  }, [code]);

  if (!detail) return null;
  const isHome = homeAirport?.code === detail.marker.code;

  const rawMetar = (detail.rawMetar ?? detail.atis ?? '').trim();
  const decodedMetar = (detail.decodedMetar ?? '').trim();
  // 想看的那一种没有就退回另一种，两种都没有才显示「暂无数据」
  const weatherText = showDecoded
    ? decodedMetar || rawMetar || t(K.weatherNoData)
    : rawMetar || decodedMetar || t(K.weatherNoData);

  const rule = (detail.approachRule ?? 'UNK').toUpperCase();
  const ruleStyle = APPROACH_RULE_STYLE[rule];
  const { latitude, longitude } = detail.marker.position;

  return (
    <div className={styles.airportCard}>
      <div className={styles.airportHead}>
        <div className={styles.airportTitleWrap}>
          <span className={`${styles.airportCode} text-mono`}>{detail.marker.code}</span>
          {detail.marker.name && (
            // 机场全名经常放不下（"Muenchen Franz-Josef-Strauss"），滚动播完
            <MarqueeText text={detail.marker.name} className={styles.airportName} />
          )}
          {detail.source && (
            <span className={styles.airportSource}>{detail.source.toUpperCase()}</span>
          )}
        </div>

        <span className={styles.runwayCountBadge}>
          {detail.runwayGeometries.length} RWY
        </span>
        <span
          className={styles.approachBadge}
          style={{
            color: ruleStyle?.color ?? 'var(--color-text-secondary)',
            background: ruleStyle
              ? `color-mix(in srgb, ${ruleStyle.color} 14%, transparent)`
              : 'var(--color-on-surface-a04)',
            border: `1px solid ${
              ruleStyle
                ? `color-mix(in srgb, ${ruleStyle.color} 60%, transparent)`
                : 'var(--color-border)'
            }`,
          }}
          title={t(K.approachRuleHint)}
        >
          <MaterialIcon name={ruleStyle?.icon ?? 'help_outline'} size={12} />
          {rule}
        </span>

        <IconButton
          icon={isHome ? 'star' : 'star_border'}
          label={t(K.homeAirportSectionTitle)}
          filled={isHome}
          active={isHome}
          onClick={() => {
            if (isHome) void clearHomeAirport();
            else void setHomeAirport(detail.marker);
          }}
        />
        <IconButton
          icon="close"
          label={t(K.clearSearch)}
          onClick={() => setSelectedAirport(null)}
        />
      </div>

      <div className={`${styles.airportBody} scroll-area`}>
        <div className={styles.airportMetaRow}>
          <span className={styles.airportMetaItem}>
            <MaterialIcon name="straighten" size={12} />
            {detail.runwayGeometries.length} RWY
          </span>
          <span className={styles.airportMetaItem}>
            <MaterialIcon name="local_parking" size={12} />
            {detail.parkingSpots.length} SPOTS
          </span>
          <span className={styles.airportMetaItem}>
            <MaterialIcon name="location_on" size={12} />
            {latitude.toFixed(3)}, {longitude.toFixed(3)}
          </span>
        </div>

        {/* METAR：原文 / 中文解读切换 */}
        <div className={styles.metarBox}>
          <span className={`${styles.metarText} ${showDecoded ? '' : 'text-mono'}`}>
            {weatherText}
          </span>
          <span className={styles.metarToggleWrap}>
            <span className={styles.metarToggleLabel}>
              {t(showDecoded ? K.metarDecodedShort : K.metarRawShort)}
            </span>
            <button
              type="button"
              role="switch"
              aria-checked={showDecoded}
              aria-label={t(showDecoded ? K.metarDecodedShort : K.metarRawShort)}
              className={`${styles.metarToggle}${showDecoded ? ` ${styles.metarToggleOn}` : ''}`}
              onClick={() => setShowDecoded((value) => !value)}
            >
              <span className={styles.metarToggleKnob} />
            </button>
          </span>
        </div>

        {detail.runwayGeometries.length > 0 && (
          <div className={styles.airportSection}>
            <div className={styles.runwaySectionHead}>
              <span className={styles.airportSectionTitle}>{t(K.toggleRunways)}</span>
              {/* 下滑道信息单独开关：只关心航向台频率时可以收起来 */}
              <button
                type="button"
                className={`${styles.glideslopeToggle}${
                  showGlideslope ? ` ${styles.glideslopeToggleOn}` : ''
                }`}
                onClick={toggleGlideslope}
                title={t(K.runwayGlideslopeHint)}
              >
                <MaterialIcon name="airline_stops" size={11} />
                {t(K.runwayGlideslope)}
              </button>
            </div>

            {detail.runwayGeometries.map((runway) => (
              <div key={runway.ident} className={styles.runwayRow}>
                <span className={`${styles.runwayIdent} text-mono`}>{runway.ident}</span>
                {runway.lengthM !== undefined && (
                  <span className={styles.runwayLength}>
                    {Math.round(runway.lengthM)} m
                  </span>
                )}
                {runway.surface && (
                  <span className={styles.runwaySurface}>
                    {runway.surface.toUpperCase()}
                  </span>
                )}

                {/*
                  一条跑道有两端，进近设施各不相同（例如 ZBAA 36R 是 CAT III、
                  18L 只有 CAT I），所以按端分别列。
                */}
                <span className={styles.runwayEnds}>
                  {[runway.leIdent, runway.heIdent]
                    .filter((end): end is string => !!end)
                    .map((end) => (
                      <RunwayNavaidChips
                        key={end}
                        end={end}
                        navaid={detail.runwayNavaids?.[end.toUpperCase()]}
                        showGlideslope={showGlideslope}
                      />
                    ))}
                </span>
              </div>
            ))}
          </div>
        )}

        {detail.frequencyBadges.length > 0 && (
          <div className={styles.airportSection}>
            <span className={styles.airportSectionTitle}>COM</span>
            <div className={styles.airportChips}>
              {detail.frequencyBadges.map((badge) => (
                <InfoChip key={badge} icon="radio" label={badge} />
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
