/**
 * 坐标校验
 *
 * 原先在 `map/services/map-response-parsers.ts` 与 `map/services/map-airport-parser.ts`
 * 里各有一份逐字符相同的实现。收到 core 之后，`common/` 的解析器也能用 ——
 * 否则它得反过来 import `map/`，而全库的约定是共享代码往内收、不往模块里借。
 */

/**
 * 判断一对经纬度是否可用。
 *
 * 除了范围检查，还**显式排除 (0,0)** —— 那个点在几内亚湾外海，
 * 现实中不会是机场或航路点；实际出现时几乎总是「字段缺失被当成 0」。
 * 不排除的话，缺数据的要素会全部堆到地图左下角那一点上。
 */
export function isValidCoordinate(lat: number, lon: number): boolean {
  return (
    Number.isFinite(lat) &&
    Number.isFinite(lon) &&
    lat >= -90 &&
    lat <= 90 &&
    lon >= -180 &&
    lon <= 180 &&
    !(lat === 0 && lon === 0)
  );
}
