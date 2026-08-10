import { AppLogger } from '../../../core/utils/logger';
import type { MapRunwayGeometry } from '../../map/models/map-models';
import { parseAirportDetail } from '../../map/services/map-airport-parser';
import { findOccupiedRunway } from '../../map/services/runway-occupancy';
import { MiddlewareHttpService } from '../../http/services/middleware-http-service';

/**
 * 按坐标反查所在跑道
 *
 * 「剩余跑道」需要跑道几何（两端坐标 + 长度），而飞行日志只记采样点、
 * 不含任何机场结构。所以收尾时按起降场的 ICAO 去中间件拉一次机场布局，
 * 再用起飞/接地点落在哪条跑道上把它定位出来。
 *
 * 收尾路径上只跑一次，不是热路径 —— 拉不到就让「剩余跑道」保持不可用并
 * 在界面上说明原因，绝不编一个数出来。
 */

/** 起降点判定用的半宽（米）。比地图高亮那套放宽一些 —— 接地点常常偏离中线 */
const TOUCHDOWN_HALF_WIDTH_M = 45;

/**
 * 取某机场里包含给定坐标的那条跑道。
 *
 * 拿不到（机场码为空、接口失败、坐标不在任何跑道上）一律返回 undefined。
 */
export async function lookupRunwayAt(
  icao: string | undefined,
  position: { latitude: number; longitude: number },
): Promise<MapRunwayGeometry | undefined> {
  const code = (icao ?? '').trim().toUpperCase();
  if (code.length !== 4) return undefined;
  if (!Number.isFinite(position.latitude) || !Number.isFinite(position.longitude)) {
    return undefined;
  }

  try {
    await MiddlewareHttpService.init();
    const response = await MiddlewareHttpService.getAirportLayoutByIcao(code);
    const body = response.objectBody;
    if (!body) return undefined;
    const detail = parseAirportDetail(body, code);
    if (!detail || detail.runwayGeometries.length === 0) return undefined;

    // 复用地图那套「点是否压在跑道上」的判定：垂距 + 投影落在线段内
    const hit = findOccupiedRunway(detail.runwayGeometries, {
      position,
      // 起降点本来就在地面，跳过高度门槛
      onGround: true,
      halfWidthM: TOUCHDOWN_HALF_WIDTH_M,
    });
    if (!hit) return undefined;
    return detail.runwayGeometries.find((runway) => runway.ident === hit.ident);
  } catch (e) {
    AppLogger.info(`[FlightLogs] runway lookup failed for ${code}: ${String(e)}`);
    return undefined;
  }
}
