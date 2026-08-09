/**
 * 监控模块数据模型
 * 对应 Flutter 版 `modules/monitor/models/{monitor_data,monitor_chart_data}.dart`
 */

/** 图表数据点 [时间轴序号, 值] */
export type ChartPoint = readonly [number, number];

/** 图表缓冲区快照 */
export interface MonitorChartData {
  gForceSpots: ChartPoint[];
  altitudeSpots: ChartPoint[];
  pressureSpots: ChartPoint[];
  currentTime: number;
}

export function emptyMonitorChartData(): MonitorChartData {
  return { gForceSpots: [], altitudeSpots: [], pressureSpots: [], currentTime: 0 };
}

/** 监控页面完整数据快照 */
export interface MonitorData {
  isConnected: boolean;
  isPaused?: boolean;
  masterWarning?: boolean;
  masterCaution?: boolean;
  heading?: number;
  parkingBrake?: boolean;
  transponderState?: string;
  transponderCode?: string;
  flapsLabel?: string;
  flapsDeployRatio?: number;
  speedBrakeLabel?: string;
  speedBrake?: boolean;
  fireWarningEngine1?: boolean;
  fireWarningEngine2?: boolean;
  fireWarningAPU?: boolean;
  /** 机型信息，用来判断起落架构型（可收放 / 轮组排布） */
  aircraftIcao?: string;
  aircraftTitle?: string;
  noseGearDown?: number;
  leftGearDown?: number;
  rightGearDown?: number;
  gForce?: number;
  altitude?: number;
  baroPressure?: number;
  chartData: MonitorChartData;
}

export function emptyMonitorData(): MonitorData {
  return { isConnected: false, chartData: emptyMonitorChartData() };
}

/**
 * 图表环形缓冲区
 *
 * 对应 Flutter 版 `monitor_chart_buffer.dart`：保留最近 60 个采样点，
 * 时间轴用递增序号而非真实时间戳（与桌面版一致）。
 */
export class MonitorChartBuffer {
  static readonly maxPoints = 60;

  private chartTime = 0;
  private gForceSpots: ChartPoint[] = [];
  private altitudeSpots: ChartPoint[] = [];
  private pressureSpots: ChartPoint[] = [];

  append(values: { gForce: number; altitude: number; pressure: number }): void {
    this.chartTime += 1;
    this.gForceSpots = appendSpot(this.gForceSpots, [this.chartTime, values.gForce]);
    this.altitudeSpots = appendSpot(this.altitudeSpots, [this.chartTime, values.altitude]);
    this.pressureSpots = appendSpot(this.pressureSpots, [this.chartTime, values.pressure]);
  }

  buildSnapshot(): MonitorChartData {
    return {
      gForceSpots: this.gForceSpots,
      altitudeSpots: this.altitudeSpots,
      pressureSpots: this.pressureSpots,
      currentTime: this.chartTime,
    };
  }

  reset(): void {
    this.chartTime = 0;
    this.gForceSpots = [];
    this.altitudeSpots = [];
    this.pressureSpots = [];
  }
}

function appendSpot(source: ChartPoint[], spot: ChartPoint): ChartPoint[] {
  const next = [...source, spot];
  if (next.length <= MonitorChartBuffer.maxPoints) return next;
  return next.slice(next.length - MonitorChartBuffer.maxPoints);
}
