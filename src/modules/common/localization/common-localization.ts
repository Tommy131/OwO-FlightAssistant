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

  // ── 模拟器意外断连 ──
  simLostTitle: 'common.sim.lost_title',
  simLostAck: 'common.sim.lost_ack',
  simLostReasonUnknown: 'common.sim.lost_reason.unknown',
  simLostReasonSessionExpired: 'common.sim.lost_reason.session_expired',
  simLostReasonInvalidToken: 'common.sim.lost_reason.invalid_token',
  simLostReasonServiceStopped: 'common.sim.lost_reason.service_stopped',
  simLostReasonNoPackets: 'common.sim.lost_reason.no_packets',
  simLostReasonNoPacketsEver: 'common.sim.lost_reason.no_packets_ever',
  simLostReasonSimulatorQuit: 'common.sim.lost_reason.simulator_quit',
  simLostReasonSimconnectLost: 'common.sim.lost_reason.simconnect_lost',
  simLostReasonSimconnectError: 'common.sim.lost_reason.simconnect_error',
  simLostReasonLinkTimeout: 'common.sim.lost_reason.link_timeout',
  simLostReasonWsClosed: 'common.sim.lost_reason.ws_closed',
  simLostDetailSuffix: 'common.sim.lost_detail_suffix',

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

  // ── 训练模式 / 复盘模式 ──
  appModeLive: 'common.app_mode.live',
  appModeReview: 'common.app_mode.review',
  appModeTooltip: 'common.app_mode.tooltip',
  appModeLiveHint: 'common.app_mode.live_hint',
  appModeReviewHint: 'common.app_mode.review_hint',
  appModeReviewBanner: 'common.app_mode.review_banner',

  // ── 跨模块任务流 ──
  workflowTooltip: 'common.workflow.tooltip',
  workflowStageBriefing: 'common.workflow.stage.briefing',
  workflowStageMap: 'common.workflow.stage.map',
  workflowStageChecklist: 'common.workflow.stage.checklist',
  workflowStageFlightLogs: 'common.workflow.stage.flight_logs',
  workflowSkipStage: 'common.workflow.skip_stage',
} as const;

const K = CommonLocalizationKeys;

export const commonModuleTranslations: ModuleTranslations = {
  zh_CN: {
    [K.backendAvailableLabel]: '已连接后端服务',
    [K.backendUnavailableTitle]: '后端服务不可用',
    [K.backendUnavailableContent]:
      '当前无法与已配置的后端 HTTP 接口通信，请启动中间件服务，或检查网络代理与后端地址配置是否正确。',
    [K.goToSettings]: '前往设置',
    [K.simLostTitle]: '模拟器连接已断开',
    [K.simLostAck]: '知道了',
    [K.simLostReasonUnknown]: '模拟器连接意外中断，原因未知。请确认模拟器仍在运行后重新连接。',
    [K.simLostReasonSessionExpired]:
      '会话已过期（长时间无活动）。中间件已清理访问令牌，请重新连接模拟器。',
    [K.simLostReasonInvalidToken]: '访问令牌已失效，请重新连接模拟器。',
    [K.simLostReasonServiceStopped]: '中间件已停止模拟器数据服务，请重新连接。',
    [K.simLostReasonNoPackets]:
      '长时间未收到 X-Plane 遥测数据包。请确认 X-Plane 仍在飞行场景中，且网络/UDP 端口未被占用。',
    [K.simLostReasonNoPacketsEver]:
      '未收到任何模拟器数据包。请确认模拟器已进入飞行，且中间件地址/端口配置正确。',
    [K.simLostReasonSimulatorQuit]: '检测到模拟器已退出或离开飞行场景。',
    [K.simLostReasonSimconnectLost]:
      '与 MSFS 的 SimConnect 链路中断。请确认 MSFS 仍在运行并处于飞行中，然后重新连接。',
    [K.simLostReasonSimconnectError]: 'SimConnect 报错后链路未能恢复，请重新连接模拟器。',
    [K.simLostReasonLinkTimeout]:
      '模拟器链路在宽限期内未能恢复。可能是模拟器卡顿、切场景或后台被挂起。',
    [K.simLostReasonWsClosed]: '实时数据通道关闭且未能自动恢复，请重新连接。',
    [K.simLostDetailSuffix]: '技术细节：{detail}',
    [K.appModeLive]: '训练模式',
    [K.appModeReview]: '复盘模式',
    [K.appModeTooltip]: '当前：{mode}',
    [K.appModeLiveHint]: '实时辅助：检查单自动跟随遥测，气象自动刷新',
    [K.appModeReviewHint]: '事后分析：暂停一切实时联动，界面停在你选定的那一刻',
    [K.appModeReviewBanner]: '复盘模式已开启，实时联动已暂停',
    [K.workflowTooltip]: '飞行任务流 {}/{}',
    [K.workflowStageBriefing]: '简报：定起降与航路',
    [K.workflowStageMap]: '地图：核对航路与地形',
    [K.workflowStageChecklist]: '检查单：逐项确认',
    [K.workflowStageFlightLogs]: '飞行日志：开始录制',
    [K.workflowSkipStage]: '跳过当前步骤',
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
    [K.simLostTitle]: 'Simulator connection lost',
    [K.simLostAck]: 'OK',
    [K.simLostReasonUnknown]:
      'The simulator link dropped unexpectedly for an unknown reason. Confirm the sim is still running, then reconnect.',
    [K.simLostReasonSessionExpired]:
      'The session expired after a long idle period. The middleware cleared the access token — reconnect the simulator.',
    [K.simLostReasonInvalidToken]: 'The access token is no longer valid. Reconnect the simulator.',
    [K.simLostReasonServiceStopped]:
      'The middleware stopped the simulator data service. Reconnect to resume.',
    [K.simLostReasonNoPackets]:
      'No X-Plane telemetry packets for a long time. Confirm X-Plane is in a flight session and the UDP port is free.',
    [K.simLostReasonNoPacketsEver]:
      'No simulator packets were received. Confirm the sim is in flight and the middleware address/port are correct.',
    [K.simLostReasonSimulatorQuit]: 'The simulator quit or left the flight session.',
    [K.simLostReasonSimconnectLost]:
      'The MSFS SimConnect link was lost. Confirm MSFS is running in flight, then reconnect.',
    [K.simLostReasonSimconnectError]:
      'SimConnect reported an error and the link did not recover. Reconnect the simulator.',
    [K.simLostReasonLinkTimeout]:
      'The simulator link did not recover within the grace period. The sim may be stalled, loading, or suspended.',
    [K.simLostReasonWsClosed]:
      'The live data channel closed and could not be restored automatically. Reconnect.',
    [K.simLostDetailSuffix]: 'Technical detail: {detail}',
    [K.appModeLive]: 'Training mode',
    [K.appModeReview]: 'Review mode',
    [K.appModeTooltip]: 'Current: {mode}',
    [K.appModeLiveHint]: 'Live assist: checklist follows telemetry, weather auto-refreshes',
    [K.appModeReviewHint]: 'Post-flight analysis: all live linkage paused, the view stays where you put it',
    [K.appModeReviewBanner]: 'Review mode is on — live linkage is paused',
    [K.workflowTooltip]: 'Flight workflow {}/{}',
    [K.workflowStageBriefing]: 'Briefing: set route and airports',
    [K.workflowStageMap]: 'Map: verify route and terrain',
    [K.workflowStageChecklist]: 'Checklist: confirm each item',
    [K.workflowStageFlightLogs]: 'Flight logs: start recording',
    [K.workflowSkipStage]: 'Skip current step',
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
