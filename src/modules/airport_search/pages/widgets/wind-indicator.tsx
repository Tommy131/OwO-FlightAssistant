import {
  formatWindDirection,
  formatWindSpeedKt,
  type MetarWind,
} from '../../services/metar-wind';
import styles from './wind-indicator.module.css';

/**
 * 风向风速指示器
 *
 * 还原桌面版机场查询卡左侧那只罗盘：一个带 N/E/S/W 的圆盘 + 一支指针，
 * 下方写风向与风速。
 *
 * ── 指针指哪边 ──
 * 航空报文里的风向是**风从哪来**（`10003MPS` = 风来自 100°），
 * 而这支箭头画的是**风往哪去**，也就是 `风向 + 180°`。
 * 两种画法都有人用，混淆的代价是判断侧风方向时正好反 180° ——
 * 所以圆盘下面的数字一律标注 FROM 的那个值（和管制员报的一致），
 * 箭头只用来给一个直观的「往哪吹」。
 */

/** 圆盘尺寸（SVG 视口，实际显示大小由 CSS 控制） */
const SIZE = 100;
const CENTER = SIZE / 2;
const RADIUS = 42;

/** 四个方位标签的位置半径：比刻度再往里一点，避免压着圆环 */
const LABEL_RADIUS = 31;

const CARDINALS: readonly { label: string; deg: number }[] = [
  { label: 'N', deg: 0 },
  { label: 'E', deg: 90 },
  { label: 'S', deg: 180 },
  { label: 'W', deg: 270 },
];

/** 极坐标转直角坐标；0° 在正上方，顺时针为正 */
function polar(deg: number, radius: number): { x: number; y: number } {
  const rad = ((deg - 90) * Math.PI) / 180;
  return { x: CENTER + radius * Math.cos(rad), y: CENTER + radius * Math.sin(rad) };
}

export function WindIndicator({ wind }: { wind: MetarWind | null }) {
  const hasDirection = wind !== null && !wind.calm && !wind.variable && wind.directionDeg !== undefined;
  // 箭头指向「风往哪去」，即来向 + 180°
  const arrowDeg = hasDirection ? (wind.directionDeg! + 180) % 360 : 0;

  const directionText = formatWindDirection(wind);
  const speedText = formatWindSpeedKt(wind?.speedKt);

  return (
    <div className={styles.wrap}>
      <svg
        className={styles.dial}
        viewBox={`0 0 ${SIZE} ${SIZE}`}
        role="img"
        aria-label={`${directionText} ${speedText}`}
      >
        <circle className={styles.ring} cx={CENTER} cy={CENTER} r={RADIUS} />

        {/* 每 30° 一根刻度，正方位的加长加亮 */}
        {Array.from({ length: 12 }, (_, index) => index * 30).map((deg) => {
          const isCardinal = deg % 90 === 0;
          const outer = polar(deg, RADIUS);
          const inner = polar(deg, RADIUS - (isCardinal ? 7 : 4));
          return (
            <line
              key={deg}
              className={isCardinal ? styles.tickMajor : styles.tickMinor}
              x1={outer.x}
              y1={outer.y}
              x2={inner.x}
              y2={inner.y}
            />
          );
        })}

        {CARDINALS.map(({ label, deg }) => {
          const point = polar(deg, LABEL_RADIUS);
          return (
            <text
              key={label}
              className={label === 'N' ? styles.labelNorth : styles.label}
              x={point.x}
              y={point.y}
              textAnchor="middle"
              dominantBaseline="central"
            >
              {label}
            </text>
          );
        })}

        {hasDirection ? (
          <g transform={`rotate(${arrowDeg} ${CENTER} ${CENTER})`}>
            {/* 箭头本体：从圆心朝上，再整体旋转到风的去向 */}
            <line
              className={styles.needle}
              x1={CENTER}
              y1={CENTER + 13}
              x2={CENTER}
              y2={CENTER - 17}
            />
            <polygon
              className={styles.needleHead}
              points={`${CENTER},${CENTER - 24} ${CENTER - 6},${CENTER - 13} ${CENTER + 6},${CENTER - 13}`}
            />
          </g>
        ) : (
          // 静风/不定风没有确定方向，画个空心点表示「有数据但指不出方向」
          <circle className={styles.calmDot} cx={CENTER} cy={CENTER} r={6} />
        )}

        <circle className={styles.hub} cx={CENTER} cy={CENTER} r={2.5} />
      </svg>

      <span className={`${styles.readout} text-mono`}>
        {directionText} / {speedText}
      </span>
      {wind?.gustKt !== undefined && (
        <span className={styles.gust}>G {formatWindSpeedKt(wind.gustKt)}</span>
      )}
    </div>
  );
}
