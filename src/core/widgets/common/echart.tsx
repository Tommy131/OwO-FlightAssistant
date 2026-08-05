import { useEffect, useRef } from 'react';
import * as echarts from 'echarts/core';
import { LineChart, ScatterChart } from 'echarts/charts';
import {
  DatasetComponent,
  GridComponent,
  LegendComponent,
  MarkLineComponent,
  TooltipComponent,
} from 'echarts/components';
import { CanvasRenderer } from 'echarts/renderers';
import type { EChartsOption } from 'echarts';
import { useThemeStore } from '../../theme/theme-store';

/**
 * ECharts 封装
 *
 * 桌面版用 fl_chart 绘制监控与飞行日志图表；Web 版统一走 ECharts。
 * 只按需注册用到的图表与组件，避免整包引入（完整包 >1MB）。
 */
echarts.use([
  LineChart,
  ScatterChart,
  GridComponent,
  TooltipComponent,
  LegendComponent,
  DatasetComponent,
  MarkLineComponent,
  CanvasRenderer,
]);

export interface EChartProps {
  option: EChartsOption;
  height?: number | string;
  className?: string;
  /**
   * 数据高频刷新时置 true：复用实例并跳过动画，
   * 否则监控页每帧重建动画会明显掉帧。
   */
  streaming?: boolean;
}

export function EChart({ option, height = 200, className, streaming = false }: EChartProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const chartRef = useRef<echarts.ECharts | null>(null);
  // 主题切换后需要重建实例才能刷新坐标轴等静态样式
  const themeMode = useThemeStore((s) => s.themeMode);
  const currentTheme = useThemeStore((s) => s.currentTheme);
  const systemPrefersDark = useThemeStore((s) => s.systemPrefersDark);

  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;

    const chart = echarts.init(container, undefined, { renderer: 'canvas' });
    chartRef.current = chart;

    const observer = new ResizeObserver(() => chart.resize());
    observer.observe(container);

    return () => {
      observer.disconnect();
      chart.dispose();
      chartRef.current = null;
    };
    // 主题变化时重建，保证轴线/网格颜色跟随
  }, [themeMode, currentTheme, systemPrefersDark]);

  useEffect(() => {
    const chart = chartRef.current;
    if (!chart) return;
    chart.setOption(option, {
      // 流式刷新用 notMerge:false + 静默模式，避免每帧重放入场动画
      notMerge: !streaming,
      lazyUpdate: streaming,
    });
  }, [option, streaming]);

  return (
    <div
      ref={containerRef}
      className={className}
      style={{ width: '100%', height, minHeight: 0 }}
    />
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 图表配色与通用样式
// ──────────────────────────────────────────────────────────────────────────

/**
 * 图表系列配色
 *
 * 经 dataviz 校验器验证（浅色底 #FFFFFF / 深色底 #16213E 均通过
 * 亮度带、彩度下限、CVD 分离、正常视觉分离与 3:1 对比度）。
 *
 * ⚠️ 桌面版监控图表用的是 `Colors.orangeAccent` (#FFAB40, 1.88:1) 与
 * `Colors.cyanAccent` (#18FFFF, 1.25:1) —— 这两个是 Material *Accent* 色，
 * 只为深色底设计，在本应用的浅色主题下对比度不合格、曲线近乎不可见。
 * 这里换成同色系但通过校验的步进值。
 */
export const CHART_SERIES_COLORS = {
  /** 序列 1：蓝（飞行日志高度） */
  blue: { light: '#2a78d6', dark: '#3987e5' },
  /** 序列 2：橙（G 值、飞行日志速度） */
  orange: { light: '#eb6834', dark: '#d95926' },
  /** 序列 3：青绿（气压） */
  aqua: { light: '#199e70', dark: '#1baf7a' },
} as const;

export type ChartColorName = keyof typeof CHART_SERIES_COLORS;

/** 取当前亮度下的系列色 */
export function chartColor(name: ChartColorName, isDark: boolean): string {
  return CHART_SERIES_COLORS[name][isDark ? 'dark' : 'light'];
}

/** 图表通用底座：内边距、坐标轴、网格、tooltip 全部走主题令牌 */
export function baseChartOption(options: {
  isDark: boolean;
  /** 是否显示 X 轴刻度标签 */
  showXAxisLabel?: boolean;
  /** 是否显示 Y 轴刻度标签 */
  showYAxisLabel?: boolean;
  /** 网格留白 */
  grid?: { top?: number; right?: number; bottom?: number; left?: number };
}): EChartsOption {
  const { isDark, showXAxisLabel = false, showYAxisLabel = false, grid } = options;

  // 轴线与网格保持退让，不与数据争夺注意力
  const axisLine = isDark ? '#383835' : '#c3c2b7';
  const gridLine = isDark ? '#2c2c2a' : '#e1e0d9';
  const mutedInk = '#898781';
  const surface = isDark ? '#16213E' : '#FFFFFF';

  return {
    animation: false,
    grid: {
      top: grid?.top ?? 8,
      right: grid?.right ?? 8,
      bottom: grid?.bottom ?? (showXAxisLabel ? 24 : 6),
      left: grid?.left ?? (showYAxisLabel ? 46 : 6),
      containLabel: false,
    },
    xAxis: {
      type: 'value',
      axisLine: { show: false },
      axisTick: { show: false },
      splitLine: { show: false },
      axisLabel: {
        show: showXAxisLabel,
        color: mutedInk,
        fontSize: 10,
        fontFamily: 'inherit',
      },
    },
    yAxis: {
      type: 'value',
      axisLine: { show: false },
      axisTick: { show: false },
      splitLine: { show: true, lineStyle: { color: gridLine, width: 1 } },
      axisLabel: {
        show: showYAxisLabel,
        color: mutedInk,
        fontSize: 10,
        fontFamily: 'inherit',
      },
    },
    tooltip: {
      trigger: 'axis',
      backgroundColor: surface,
      borderColor: axisLine,
      borderWidth: 1,
      padding: [6, 9],
      textStyle: {
        // 文字用文本墨色，不用系列色
        color: isDark ? '#DFE6E9' : '#2D3436',
        fontSize: 12,
        fontFamily: 'inherit',
      },
      axisPointer: {
        type: 'line',
        lineStyle: { color: mutedInk, width: 1, type: 'dashed' },
      },
    },
  };
}

/** 单系列折线（带淡填充），2px 线宽、无数据点标记 */
export function lineSeries(options: {
  name: string;
  data: readonly (readonly [number, number])[];
  color: string;
  /** 是否绘制面积填充 */
  area?: boolean;
}): NonNullable<EChartsOption['series']> {
  const { name, data, color, area = true } = options;
  return [
    {
      name,
      type: 'line',
      data: data as [number, number][],
      showSymbol: false,
      smooth: 0.2,
      lineStyle: { width: 2, color },
      itemStyle: { color },
      ...(area
        ? {
            areaStyle: {
              color: {
                type: 'linear' as const,
                x: 0,
                y: 0,
                x2: 0,
                y2: 1,
                colorStops: [
                  { offset: 0, color: `${color}2e` },
                  { offset: 1, color: `${color}00` },
                ],
              },
            },
          }
        : {}),
    },
  ];
}
