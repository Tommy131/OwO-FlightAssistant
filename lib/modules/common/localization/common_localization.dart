/// 公共模块通用本地化 Key（跨模块复用）
///
/// 包含以下分类：
///   - `backend.*`：后端连接状态（侧边栏徽章等）
///   - `mini.*`：侧边栏飞行状态迷你卡片
///   - `nav.*`：机场导航选择（目的地、出发、备降）
///   - `search.*`：机场搜索栏（被 home 模块复用）
class CommonLocalizationKeys {
  // ── 后端状态 ────────────────────────────────────────────────────────────

  /// 后端可达状态标签（徽章展开时显示）
  static const String backendAvailableLabel = 'common.backend.available_label';

  /// 后端不可达标题（徽章展开时显示）
  static const String backendUnavailableTitle =
      'common.backend.unavailable_title';

  /// 后端不可达详细说明（弹窗正文）
  static const String backendUnavailableContent =
      'common.backend.unavailable_content';

  /// 前往设置按钮文本
  static const String goToSettings = 'common.backend.go_to_settings';

  // ── 机场导航选择 ─────────────────────────────────────────────────────────

  /// 出发机场
  static const String navDeparture = 'common.nav.departure';

  /// 目的地机场
  static const String navDestination = 'common.nav.destination';

  /// 备降机场
  static const String navAlternate = 'common.nav.alternate';

  // ── 机场搜索栏 ───────────────────────────────────────────────────────────

  /// 搜索框占位文字
  static const String searchHint = 'common.search.hint';

  /// 搜索结果为空时提示
  static const String searchEmpty = 'common.search.empty';

  // ── 侧边栏迷你卡片：飞行阶段 ─────────────────────────────────────────────

  static const String miniStageGround = 'common.mini.stage.ground';
  static const String miniStageClimb = 'common.mini.stage.climb';
  static const String miniStageCruise = 'common.mini.stage.cruise';
  static const String miniStageDescent = 'common.mini.stage.descent';
  static const String miniStageApproach = 'common.mini.stage.approach';

  // ── 侧边栏迷你卡片：天气描述 ─────────────────────────────────────────────

  static const String miniWeatherUnknown = 'common.mini.weather.unknown';
  static const String miniWeatherThunderstorm =
      'common.mini.weather.thunderstorm';
  static const String miniWeatherHeavyRain = 'common.mini.weather.heavy_rain';
  static const String miniWeatherRain = 'common.mini.weather.rain';
  static const String miniWeatherSnow = 'common.mini.weather.snow';
  static const String miniWeatherLowVisibility =
      'common.mini.weather.low_visibility';
  static const String miniWeatherOvercast = 'common.mini.weather.overcast';
  static const String miniWeatherExcellent = 'common.mini.weather.excellent';
  static const String miniWeatherNormal = 'common.mini.weather.normal';

  // ── 侧边栏迷你卡片：标签与指示 ──────────────────────────────────────────

  static const String miniNearbyAirport = 'common.mini.nearby_airport';
  static const String miniLabelPhase = 'common.mini.label.phase';
  static const String miniLabelAirport = 'common.mini.label.airport';
  static const String miniLabelCurrentAirport =
      'common.mini.label.current_airport';
  static const String miniLabelNearbyAirport =
      'common.mini.label.nearby_airport';
  static const String miniLabelWeather = 'common.mini.label.weather';
  static const String miniLabelVisibility = 'common.mini.label.visibility';
  static const String miniLabelDistance = 'common.mini.label.distance';
  static const String miniLabelEta = 'common.mini.label.eta';
  static const String miniRecording = 'common.mini.recording';
}

/// 公共模块翻译内容
///
/// 包含侧边栏、后端状态、机场导航选择等通用文案。
/// 由 [CommonModule] 在注册时加载。
final Map<String, Map<String, String>> commonModuleTranslations = {
  'zh_CN': {
    CommonLocalizationKeys.backendAvailableLabel: '已连接后端服务',
    CommonLocalizationKeys.backendUnavailableTitle: '后端服务不可用',
    CommonLocalizationKeys.backendUnavailableContent:
        '当前无法与已配置的后端 HTTP 接口通信，请启动中间件服务，或检查网络代理与后端地址配置是否正确。',
    CommonLocalizationKeys.goToSettings: '前往设置',
    CommonLocalizationKeys.navDeparture: '起飞机场',
    CommonLocalizationKeys.navDestination: '目的地',
    CommonLocalizationKeys.navAlternate: '备降',
    CommonLocalizationKeys.searchHint: '输入 ICAO/IATA/名称/经纬度...',
    CommonLocalizationKeys.searchEmpty: '未找到相关机场',
    CommonLocalizationKeys.miniStageGround: '在地面',
    CommonLocalizationKeys.miniStageClimb: '爬升中',
    CommonLocalizationKeys.miniStageCruise: '巡航中',
    CommonLocalizationKeys.miniStageDescent: '下降中',
    CommonLocalizationKeys.miniStageApproach: '进近中',
    CommonLocalizationKeys.miniWeatherUnknown: '未知',
    CommonLocalizationKeys.miniWeatherThunderstorm: '雷暴',
    CommonLocalizationKeys.miniWeatherHeavyRain: '暴雨',
    CommonLocalizationKeys.miniWeatherRain: '阴雨',
    CommonLocalizationKeys.miniWeatherSnow: '降雪',
    CommonLocalizationKeys.miniWeatherLowVisibility: '低能见',
    CommonLocalizationKeys.miniWeatherOvercast: '阴天',
    CommonLocalizationKeys.miniWeatherExcellent: '天气极好',
    CommonLocalizationKeys.miniWeatherNormal: '天气一般',
    CommonLocalizationKeys.miniNearbyAirport: '附近机场',
    CommonLocalizationKeys.miniLabelPhase: '阶段',
    CommonLocalizationKeys.miniLabelAirport: '机场',
    CommonLocalizationKeys.miniLabelCurrentAirport: '当前机场',
    CommonLocalizationKeys.miniLabelNearbyAirport: '附近机场',
    CommonLocalizationKeys.miniLabelWeather: '天气',
    CommonLocalizationKeys.miniLabelVisibility: '能见度',
    CommonLocalizationKeys.miniLabelDistance: '距离',
    CommonLocalizationKeys.miniLabelEta: '预计到达',
    CommonLocalizationKeys.miniRecording: '录制中',
  },
  'en_US': {
    CommonLocalizationKeys.backendAvailableLabel: 'Backend Connected',
    CommonLocalizationKeys.backendUnavailableTitle:
        'Backend service unavailable',
    CommonLocalizationKeys.backendUnavailableContent:
        'Cannot communicate with the configured backend HTTP endpoint. Start the middleware service or verify proxy and endpoint settings.',
    CommonLocalizationKeys.goToSettings: 'Open Settings',
    CommonLocalizationKeys.navDeparture: 'Departure',
    CommonLocalizationKeys.navDestination: 'Destination',
    CommonLocalizationKeys.navAlternate: 'Alternate',
    CommonLocalizationKeys.searchHint: 'Enter ICAO/IATA/name/coordinates...',
    CommonLocalizationKeys.searchEmpty: 'No matching airports',
    CommonLocalizationKeys.miniStageGround: 'Ground',
    CommonLocalizationKeys.miniStageClimb: 'Climb',
    CommonLocalizationKeys.miniStageCruise: 'Cruise',
    CommonLocalizationKeys.miniStageDescent: 'Descent',
    CommonLocalizationKeys.miniStageApproach: 'Approach',
    CommonLocalizationKeys.miniWeatherUnknown: 'Unknown',
    CommonLocalizationKeys.miniWeatherThunderstorm: 'Thunderstorm',
    CommonLocalizationKeys.miniWeatherHeavyRain: 'Heavy Rain',
    CommonLocalizationKeys.miniWeatherRain: 'Rain',
    CommonLocalizationKeys.miniWeatherSnow: 'Snow',
    CommonLocalizationKeys.miniWeatherLowVisibility: 'Low Visibility',
    CommonLocalizationKeys.miniWeatherOvercast: 'Overcast',
    CommonLocalizationKeys.miniWeatherExcellent: 'Excellent',
    CommonLocalizationKeys.miniWeatherNormal: 'Normal',
    CommonLocalizationKeys.miniNearbyAirport: 'Nearby Airport',
    CommonLocalizationKeys.miniLabelPhase: 'Phase',
    CommonLocalizationKeys.miniLabelAirport: 'Airport',
    CommonLocalizationKeys.miniLabelCurrentAirport: 'Current Airport',
    CommonLocalizationKeys.miniLabelNearbyAirport: 'Nearby Airport',
    CommonLocalizationKeys.miniLabelWeather: 'Weather',
    CommonLocalizationKeys.miniLabelVisibility: 'Visibility',
    CommonLocalizationKeys.miniLabelDistance: 'Distance',
    CommonLocalizationKeys.miniLabelEta: 'ETA',
    CommonLocalizationKeys.miniRecording: 'REC',
  },
};
