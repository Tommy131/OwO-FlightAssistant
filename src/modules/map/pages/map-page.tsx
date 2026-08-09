import { useEffect, useRef, useState } from 'react';
import { useTranslate } from '../../../core/localization/use-translate';
import { SnackBarHelper } from '../../../core/widgets/common/snack-bar';
import { toJsonMap, type JsonMap } from '../../../core/utils/parse-utils';
import { suggestionFromApi } from '../../airport_search/models/airport-search-models';
import { MiddlewareHttpService } from '../../http/services/middleware-http-service';
import { MapLocalizationKeys as K } from '../localization/map-localization';
import {
  type MapAirportMarker,
  type MapCoordinate,
} from '../models/map-models';
import { useMapStore } from '../providers/map-store';
import { parseAirportDetail } from '../services/map-airport-parser';
import { MapLegendStack } from '../widgets/map-legend';
import { PapiIndicator } from '../widgets/papi-indicator';
import { MapCanvas } from './map-canvas';
import { MapTopPanel, type AirportSuggestion } from './panels/map-top-panel';
import { MapHud } from './panels/map-hud';
import { MapAlertOverlay } from './panels/map-alert-overlay';
import { MapRightControls } from './panels/map-right-controls';
import { MapLayerPicker } from './panels/map-layer-picker';
import { TaxiwayToolbar } from './panels/taxiway-toolbar';
import { SelectedAirportCard } from './panels/selected-airport-card';
import { ProcedurePanel } from './panels/procedure-panel';
import { TaxiGuidancePanel } from './panels/taxi-guidance-panel';
import styles from './map-page.module.css';

/**
 * 地图页面
 *
 * 对应 Flutter 版 `modules/map/pages/map_page.dart`（4218 行）与 widgets/ 下 20+ 组件：
 * 顶部搜索与飞行状态条 / 左下 HUD / 右侧控制栏 / 图层选择器 /
 * 滑行道绘制工具条 / 选中机场底卡 / 告警浮层。
 */

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
      {/* 自己判断显隐：开关在右侧控制栏的「进近程序」组里 */}
      <ProcedurePanel />
      <TaxiGuidancePanel />
    </div>
  );
}












