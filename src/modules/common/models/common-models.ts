/**
 * 公共飞行数据模型
 *
 * 对应 Flutter 版 `modules/common/models/common_models.dart`，字段逐一对齐。
 * 所有可空字段沿用「数据缺失即 undefined」的语义，UI 层统一渲染为 `--`。
 */

/** 模拟器类型 */
export type SimulatorType = 'none' | 'xplane' | 'msfs';

/** 机场基本信息 */
export interface AirportInfo {
  readonly icaoCode: string;
  readonly iataCode: string;
  readonly name: string;
  readonly nameChinese: string;
  readonly latitude: number;
  readonly longitude: number;
}

/** 优先返回中文名称，无中文名则返回英文名 */

/** METAR 气象报文数据 */
export interface LiveMetarData {
  readonly raw: string;
  readonly timestamp: Date;
  readonly displayWind: string;
  readonly displayVisibility: string;
  readonly displayTemperature: string;
  readonly displayAltimeter: string;
}

/** 当前检查单阶段信息（用于仪表盘展示） */
export interface FlightChecklistPhase {
  readonly labelKey: string;
  /** Material Symbols 图标名 */
  readonly icon: string;
}

/** 飞行警报条目 */
export interface FlightAlert {
  readonly id: string;
  readonly level: string;
  readonly message: string;
}

/** AI（周边）飞机状态 */
export interface AIAircraftState {
  readonly id: string;
  readonly type?: string;
  readonly latitude: number;
  readonly longitude: number;
  readonly altitude?: number;
  readonly heading?: number;
  readonly groundSpeed?: number;
  readonly onGround?: boolean;
}

/**
 * 实时飞行数据快照（来自模拟器）
 *
 * 与桌面版一致的 96 个字段，按功能分组排列。
 */
export interface FlightData {
  // ── 主飞行参数 ──
  airspeed?: number;
  machNumber?: number;
  altitude?: number;
  heading?: number;
  verticalSpeed?: number;
  groundSpeed?: number;
  trueAirspeed?: number;
  radioAltitude?: number;

  // ── 姿态与载荷 ──
  gForce?: number;
  touchdownGearG?: number;
  noseGearG?: number;
  leftGearG?: number;
  rightGearG?: number;
  pitch?: number;
  bank?: number;
  angleOfAttack?: number;
  stallWarning?: boolean;

  // ── 位置 ──
  latitude?: number;
  longitude?: number;
  departureAirport?: string;
  arrivalAirport?: string;

  // ── 通信与环境 ──
  com1Frequency?: number;
  outsideAirTemperature?: number;
  totalAirTemperature?: number;
  windSpeed?: number;
  windDirection?: number;
  windGust?: number;
  gustDelta?: number;
  gustFactorRate?: number;
  crosswindComponent?: number;
  baroPressure?: number;
  baroPressureUnit?: string;
  visibility?: number;

  // ── 发动机与燃油 ──
  numEngines?: number;
  fuelQuantity?: number;
  fuelFlow?: number;
  engine1N1?: number;
  engine2N1?: number;
  engine1N2?: number;
  engine2N2?: number;
  engine1EGT?: number;
  engine2EGT?: number;
  engine1Running?: boolean;
  engine2Running?: boolean;
  apuRunning?: boolean;

  // ── 操纵面与配平 ──
  aileronInput?: number;
  elevatorInput?: number;
  rudderInput?: number;
  aileronTrim?: number;
  elevatorTrim?: number;
  rudderTrim?: number;

  // ── 告警 ──
  masterWarning?: boolean;
  masterCaution?: boolean;
  fireWarningEngine1?: boolean;
  fireWarningEngine2?: boolean;
  fireWarningAPU?: boolean;

  // ── 灯光（9 组）──
  beacon?: boolean;
  strobes?: boolean;
  navLights?: boolean;
  logoLights?: boolean;
  wingLights?: boolean;
  landingLights?: boolean;
  taxiLights?: boolean;
  runwayTurnoffLights?: boolean;
  wheelWellLights?: boolean;

  // ── 地面与气动装置 ──
  onGround?: boolean;
  parkingBrake?: boolean;
  speedBrake?: boolean;
  speedBrakeLabel?: string;
  spoilersDeployed?: boolean;
  autoBrakeLabel?: string;
  flapsDeployed?: boolean;
  flapsLabel?: string;
  flapsAngle?: number;
  flapsDeployRatio?: number;
  gearDown?: boolean;
  noseGearDown?: number;
  leftGearDown?: number;
  rightGearDown?: number;

  // ── 自动驾驶 ──
  autopilotEngaged?: boolean;
  autothrottleEngaged?: boolean;
  autopilotHeadingTarget?: number;
  autopilotLateralMode?: string;
  autopilotVerticalMode?: string;

  // ── 机型识别 ──
  aircraftProfile?: string;
  aircraftId?: string;
  aircraftManufacturer?: string;
  aircraftFamily?: string;
  aircraftModel?: string;
  aircraftIcao?: string;
  aircraftDisplayName?: string;

  // ── 飞行阶段与告警集合 ──
  flightPhase?: string;
  flightAlertLevel?: string;
  flightAlerts: FlightAlert[];
  aiAircraft: AIAircraftState[];
}

/** 空飞行数据 */
export function emptyFlightData(): FlightData {
  return { flightAlerts: [], aiAircraft: [] };
}

/**
 * 应用级飞行数据快照
 * （连接状态、机场、METAR 等聚合信息）
 */
export interface FlightDataSnapshot {
  readonly isConnected: boolean;
  readonly isBackendReachable: boolean;
  /** 后端中断版本号，自增用于触发一次性提示 */
  readonly backendOutageVersion: number;
  readonly simulatorType: SimulatorType;
  readonly errorMessage?: string;
  readonly aircraftTitle?: string;
  readonly isPaused?: boolean;
  readonly transponderState?: string;
  readonly transponderCode?: string;
  readonly flightNumber?: string;
  readonly isFuelSufficient?: boolean;
  readonly checklistPhase?: FlightChecklistPhase;
  readonly checklistProgress?: number;
  readonly flightData: FlightData;
  readonly departureAirport?: AirportInfo;
  readonly destinationAirport?: AirportInfo;
  readonly alternateAirport?: AirportInfo;
  readonly nearestAirport?: AirportInfo;
  readonly suggestedAirports: AirportInfo[];
  readonly metarsByIcao: Record<string, LiveMetarData>;
  readonly metarErrorsByIcao: Record<string, string>;
  readonly metarRefreshingIcaos: Set<string>;
}

/** 构建空/未连接状态快照 */
export function emptyFlightDataSnapshot(): FlightDataSnapshot {
  return {
    isConnected: false,
    isBackendReachable: false,
    backendOutageVersion: 0,
    simulatorType: 'none',
    flightData: emptyFlightData(),
    suggestedAirports: [],
    metarsByIcao: {},
    metarErrorsByIcao: {},
    metarRefreshingIcaos: new Set<string>(),
  };
}
