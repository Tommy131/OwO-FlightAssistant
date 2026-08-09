/**
 * 航路气象剖面图
 *
 * 横轴是沿航线的航路点，纵轴左侧风速、右侧温度，都取巡航高度上的插值。
 * 另画一条顺风分量：这是三条线里唯一能直接回答「这趟省不省油」的。
 *
 * 为什么只画巡航高度而不画整个二维剖面：真正影响航程的就是巡航那一层，
 * 把八层全铺开会得到一张谁也读不出结论的热力图。想看某点的完整廓线，
 * 鼠标悬上去 tooltip 会列出各层。
 */

import { useMemo } from 'react';
import type { EChartsOption } from 'echarts';
import { EChart } from '../../../../core/widgets/common/echart';
import { useTranslate } from '../../../../core/localization/use-translate';
import { BriefingLocalizationKeys as K } from '../../localization/briefing-localization';
import type { PlannedRoute } from '../../../common/models/planned-route-models';
import type { RouteProfileSample } from '../../models/route-profile-models';
import {
  interpolateAtAltitude,
  tailwindComponentKt,
} from '../../services/route-profile-parser';

/** 没给巡航高度时的兜底 —— 民航长航线的典型值 */
const DEFAULT_CRUISE_FT = 35000;

/**
 * 两点间的大圆初始航向（度）。
 *
 * 用来算顺风分量。不能用「经纬度差的 atan2」那种平面近似：
 * 高纬度上经度差会被严重放大，欧亚航线上能偏出几十度。
 */
function initialBearingDeg(
  from: { latitude: number; longitude: number },
  to: { latitude: number; longitude: number },
): number {
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const lat1 = toRad(from.latitude);
  const lat2 = toRad(to.latitude);
  const deltaLon = toRad(to.longitude - from.longitude);
  const y = Math.sin(deltaLon) * Math.cos(lat2);
  const x = Math.cos(lat1) * Math.sin(lat2) - Math.sin(lat1) * Math.cos(lat2) * Math.cos(deltaLon);
  return ((Math.atan2(y, x) * 180) / Math.PI + 360) % 360;
}

/** 采样点的横轴标签：优先用航路点名，取不到就用坐标 */
function sampleLabel(sample: RouteProfileSample, plan: PlannedRoute): string {
  // index 0 是起飞机场，最后一个是落地机场，中间对应 plan.points
  if (sample.index === 0) return plan.origin.code;
  const pointIndex = sample.index - 1;
  if (pointIndex >= 0 && pointIndex < plan.points.length) {
    const ident = plan.points[pointIndex].ident.trim();
    if (ident.length > 0) return ident;
  }
  if (sample.index === plan.points.length + 1) return plan.destination.code;
  return `${sample.latitude.toFixed(1)},${sample.longitude.toFixed(1)}`;
}

export function RouteProfileChart({
  samples,
  plan,
}: {
  samples: readonly RouteProfileSample[];
  plan: PlannedRoute;
}) {
  const t = useTranslate();
  const cruiseFt = plan.cruiseAltitudeFt ?? DEFAULT_CRUISE_FT;

  const data = useMemo(() => {
    const labels: string[] = [];
    const windSpeed: (number | null)[] = [];
    const temperature: (number | null)[] = [];
    const tailwind: (number | null)[] = [];
    const detail: string[] = [];

    samples.forEach((sample, i) => {
      labels.push(sampleLabel(sample, plan));
      const level = interpolateAtAltitude(sample, cruiseFt);
      if (!level) {
        // 缺数据留空洞，让折线自己断开 —— 补零会画出一条「无风」的假线
        windSpeed.push(null);
        temperature.push(null);
        tailwind.push(null);
        detail.push('');
        return;
      }
      windSpeed.push(Number(level.windSpeedKt.toFixed(1)));
      temperature.push(Number(level.temperatureC.toFixed(1)));

      // 航向取「到下一点」；最后一点没有下一点，就沿用前一段的航向
      const next = samples[i + 1] ?? samples[i - 1];
      if (next) {
        const track =
          samples[i + 1] !== undefined
            ? initialBearingDeg(sample, next)
            : initialBearingDeg(next, sample);
        tailwind.push(
          Number(
            tailwindComponentKt(level.windDirectionDeg, level.windSpeedKt, track).toFixed(1),
          ),
        );
      } else {
        tailwind.push(null);
      }

      detail.push(
        sample.levels
          .slice()
          .reverse()
          .map(
            (item) =>
              `FL${Math.round(item.altitudeFt / 100)}&nbsp;&nbsp;` +
              `${item.windDirectionDeg.toFixed(0).padStart(3, '0')}°/${item.windSpeedKt.toFixed(0)}kt&nbsp;&nbsp;` +
              `${item.temperatureC.toFixed(0)}°C`,
          )
          .join('<br/>'),
      );
    });

    return { labels, windSpeed, temperature, tailwind, detail };
  }, [samples, plan, cruiseFt]);

  const option = useMemo<EChartsOption>(
    () => ({
      grid: { left: 46, right: 46, top: 28, bottom: 46 },
      legend: {
        top: 0,
        textStyle: { fontSize: 10, color: 'var(--color-text-secondary)' },
        data: [t(K.profileWind), t(K.profileTailwind), t(K.profileTemperature)],
      },
      tooltip: {
        trigger: 'axis',
        // 悬停时列出该点的完整廓线：主图只画巡航那一层，其余层在这里看
        formatter: (params: unknown) => {
          const list = Array.isArray(params) ? params : [params];
          const first = list[0] as { dataIndex: number; axisValue: string } | undefined;
          if (!first) return '';
          const lines = list
            .map((item) => {
              const point = item as { seriesName: string; value: number | null };
              if (point.value === null || point.value === undefined) return '';
              return `${point.seriesName}: ${point.value}`;
            })
            .filter((line) => line.length > 0);
          const levels = data.detail[first.dataIndex];
          return (
            `<b>${first.axisValue}</b><br/>${lines.join('<br/>')}` +
            (levels ? `<br/><span style="opacity:.7">${levels}</span>` : '')
          );
        },
      },
      xAxis: {
        type: 'category',
        data: data.labels,
        axisLabel: { fontSize: 9, rotate: 45, interval: 0 },
      },
      yAxis: [
        {
          type: 'value',
          name: 'kt',
          nameTextStyle: { fontSize: 9 },
          axisLabel: { fontSize: 9 },
          splitLine: { lineStyle: { opacity: 0.12 } },
        },
        {
          type: 'value',
          name: '°C',
          nameTextStyle: { fontSize: 9 },
          axisLabel: { fontSize: 9 },
          splitLine: { show: false },
        },
      ],
      series: [
        {
          name: t(K.profileWind),
          type: 'line',
          smooth: true,
          symbolSize: 4,
          data: data.windSpeed,
          lineStyle: { width: 2 },
          itemStyle: { color: '#38bdf8' },
        },
        {
          name: t(K.profileTailwind),
          type: 'line',
          smooth: true,
          symbolSize: 4,
          data: data.tailwind,
          lineStyle: { width: 2 },
          itemStyle: { color: '#4ade80' },
          // 零线分开顺风与顶风：线在上面省油，在下面费油
          markLine: {
            silent: true,
            symbol: 'none',
            data: [{ yAxis: 0 }],
            lineStyle: { color: '#9aa4b2', type: 'dashed', opacity: 0.5 },
            label: { show: false },
          },
        },
        {
          name: t(K.profileTemperature),
          type: 'line',
          smooth: true,
          symbolSize: 4,
          yAxisIndex: 1,
          data: data.temperature,
          lineStyle: { width: 2, type: 'dotted' },
          itemStyle: { color: '#fbbf24' },
        },
      ],
    }),
    [data, t],
  );

  return <EChart option={option} height={260} />;
}
