import type { ModuleTranslations } from '../../../core/services/localization-service';

/**
 * 公共模块通用本地化 Key（跨模块复用）
 *
 * 对应 Flutter 版 `modules/common/localization/common_localization.dart`。
 * 分类：
 *   - `backend.*`：后端连接状态（侧边栏徽章等）
 *   - `mini.*`：侧边栏飞行状态迷你卡片
 *   - `nav.*`：机场导航选择（目的地、出发、备降）
 *   - `search.*`：机场搜索栏（被 home 模块复用）
 */
export const CommonLocalizationKeys = {
  // ── 后端状态 ──
  backendAvailableLabel: 'common.backend.available_label',
  backendUnavailableTitle: 'common.backend.unavailable_title',
  backendUnavailableContent: 'common.backend.unavailable_content',
  goToSettings: 'common.backend.go_to_settings',

  // ── 机场导航选择 ──
  navDeparture: 'common.nav.departure',
  navDestination: 'common.nav.destination',
  navAlternate: 'common.nav.alternate',

  // ── 机场搜索栏 ──
  searchHint: 'common.search.hint',
  searchEmpty: 'common.search.empty',

  // ── 迷你卡片：飞行阶段 ──
  miniStageGround: 'common.mini.stage.ground',
  miniStageClimb: 'common.mini.stage.climb',
  miniStageCruise: 'common.mini.stage.cruise',
  miniStageDescent: 'common.mini.stage.descent',
  miniStageApproach: 'common.mini.stage.approach',

  // ── 迷你卡片：天气描述 ──
  miniWeatherUnknown: 'common.mini.weather.unknown',
  miniWeatherThunderstorm: 'common.mini.weather.thunderstorm',
  miniWeatherHeavyRain: 'common.mini.weather.heavy_rain',
  miniWeatherRain: 'common.mini.weather.rain',
  miniWeatherSnow: 'common.mini.weather.snow',
  miniWeatherLowVisibility: 'common.mini.weather.low_visibility',
  miniWeatherOvercast: 'common.mini.weather.overcast',
  miniWeatherExcellent: 'common.mini.weather.excellent',
  miniWeatherNormal: 'common.mini.weather.normal',

  // ── 迷你卡片：标签与指示 ──
  miniNearbyAirport: 'common.mini.nearby_airport',
  miniLabelPhase: 'common.mini.label.phase',
  miniLabelAirport: 'common.mini.label.airport',
  miniLabelCurrentAirport: 'common.mini.label.current_airport',
  miniLabelNearbyAirport: 'common.mini.label.nearby_airport',
  miniLabelWeather: 'common.mini.label.weather',
  miniLabelVisibility: 'common.mini.label.visibility',
  miniLabelDistance: 'common.mini.label.distance',
  miniLabelEta: 'common.mini.label.eta',
  miniRecording: 'common.mini.recording',
} as const;

const K = CommonLocalizationKeys;

export const commonModuleTranslations: ModuleTranslations = {
  zh_CN: {
    [K.backendAvailableLabel]: '已连接后端服务',
    [K.backendUnavailableTitle]: '后端服务不可用',
    [K.backendUnavailableContent]:
      '当前无法与已配置的后端 HTTP 接口通信，请启动中间件服务，或检查网络代理与后端地址配置是否正确。',
    [K.goToSettings]: '前往设置',
    [K.navDeparture]: '起飞机场',
    [K.navDestination]: '目的地',
    [K.navAlternate]: '备降',
    [K.searchHint]: '输入 ICAO/IATA/名称/经纬度...',
    [K.searchEmpty]: '未找到相关机场',
    [K.miniStageGround]: '在地面',
    [K.miniStageClimb]: '爬升中',
    [K.miniStageCruise]: '巡航中',
    [K.miniStageDescent]: '下降中',
    [K.miniStageApproach]: '进近中',
    [K.miniWeatherUnknown]: '未知',
    [K.miniWeatherThunderstorm]: '雷暴',
    [K.miniWeatherHeavyRain]: '暴雨',
    [K.miniWeatherRain]: '阴雨',
    [K.miniWeatherSnow]: '降雪',
    [K.miniWeatherLowVisibility]: '低能见',
    [K.miniWeatherOvercast]: '阴天',
    [K.miniWeatherExcellent]: '天气极好',
    [K.miniWeatherNormal]: '天气一般',
    [K.miniNearbyAirport]: '附近机场',
    [K.miniLabelPhase]: '阶段',
    [K.miniLabelAirport]: '机场',
    [K.miniLabelCurrentAirport]: '当前机场',
    [K.miniLabelNearbyAirport]: '附近机场',
    [K.miniLabelWeather]: '天气',
    [K.miniLabelVisibility]: '能见度',
    [K.miniLabelDistance]: '距离',
    [K.miniLabelEta]: '预计到达',
    [K.miniRecording]: '录制中',
  },
  en_US: {
    [K.backendAvailableLabel]: 'Backend Connected',
    [K.backendUnavailableTitle]: 'Backend service unavailable',
    [K.backendUnavailableContent]:
      'Cannot communicate with the configured backend HTTP endpoint. Start the middleware service or verify proxy and endpoint settings.',
    [K.goToSettings]: 'Open Settings',
    [K.navDeparture]: 'Departure',
    [K.navDestination]: 'Destination',
    [K.navAlternate]: 'Alternate',
    [K.searchHint]: 'Enter ICAO/IATA/name/coordinates...',
    [K.searchEmpty]: 'No matching airports',
    [K.miniStageGround]: 'Ground',
    [K.miniStageClimb]: 'Climb',
    [K.miniStageCruise]: 'Cruise',
    [K.miniStageDescent]: 'Descent',
    [K.miniStageApproach]: 'Approach',
    [K.miniWeatherUnknown]: 'Unknown',
    [K.miniWeatherThunderstorm]: 'Thunderstorm',
    [K.miniWeatherHeavyRain]: 'Heavy Rain',
    [K.miniWeatherRain]: 'Rain',
    [K.miniWeatherSnow]: 'Snow',
    [K.miniWeatherLowVisibility]: 'Low Visibility',
    [K.miniWeatherOvercast]: 'Overcast',
    [K.miniWeatherExcellent]: 'Excellent',
    [K.miniWeatherNormal]: 'Normal',
    [K.miniNearbyAirport]: 'Nearby Airport',
    [K.miniLabelPhase]: 'Phase',
    [K.miniLabelAirport]: 'Airport',
    [K.miniLabelCurrentAirport]: 'Current Airport',
    [K.miniLabelNearbyAirport]: 'Nearby Airport',
    [K.miniLabelWeather]: 'Weather',
    [K.miniLabelVisibility]: 'Visibility',
    [K.miniLabelDistance]: 'Distance',
    [K.miniLabelEta]: 'ETA',
    [K.miniRecording]: 'REC',
  },
};

// ──────────────────────────────────────────────────────────────────────────
// 导航分组
// ──────────────────────────────────────────────────────────────────────────

export const NavigationLocalizationKeys = {
  navGroupGeneral: 'navigation.group.general',
  navGroupFlight: 'navigation.group.flight',
  navGroupTools: 'navigation.group.tools',
  navGroupOthers: 'navigation.group.others',
} as const;

const N = NavigationLocalizationKeys;

export const navigationModuleTranslations: ModuleTranslations = {
  zh_CN: {
    [N.navGroupGeneral]: '概览',
    [N.navGroupFlight]: '飞行',
    [N.navGroupTools]: '工具',
    [N.navGroupOthers]: '其他',
  },
  en_US: {
    [N.navGroupGeneral]: 'GENERAL',
    [N.navGroupFlight]: 'FLIGHT',
    [N.navGroupTools]: 'TOOLS',
    [N.navGroupOthers]: 'OTHERS',
  },
};
