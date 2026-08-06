/**
 * 数值工具
 *
 * `clamp` 此前在三处各写了一份（`core/theme/color-utils.ts`、
 * `map-canvas.tsx`、`map/services/holding-geometry.ts`），实现等价但各自独立。
 * 收到这里统一，避免哪天有人只改其中一处。
 */

/** 把值夹在 [min, max] 区间内；NaN 原样返回（调用方自己负责先校验） */
export function clamp(value: number, min: number, max: number): number {
  return value < min ? min : value > max ? max : value;
}
