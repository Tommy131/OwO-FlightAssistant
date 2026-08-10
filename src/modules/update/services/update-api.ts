/**
 * 自更新接口的取数适配器
 *
 * IO 在这里，判定与渲染在 `update-model.ts`（纯函数、有单测）。
 */

import { AppLogger } from '../../../core/utils/logger';
import { pickDouble, pickString } from '../../../core/utils/parse-utils';
import type { JsonMap } from '../../../core/utils/parse-utils';
import { MiddlewareHttpService } from '../../http/services/middleware-http-service';
import type { UpdateCheckResult, UpdateProgress, UpdateState } from './update-model';

/** 查询是否有可用更新。force 为真时让中间件跳过缓存重新问 GitHub。 */
export async function fetchUpdateState(force: boolean): Promise<UpdateState> {
  try {
    await MiddlewareHttpService.init();
    const response = await MiddlewareHttpService.getUpdateCheck(force);
    const body = response.objectBody;
    if (!body) return failedState('empty_response');
    return parseUpdateState(body);
  } catch (e) {
    AppLogger.info(`[Update] check failed: ${String(e)}`);
    return failedState(String(e));
  }
}

/** 记下被忽略的版本；tag 传空表示取消忽略。 */
export async function ignoreUpdate(tag: string): Promise<boolean> {
  try {
    await MiddlewareHttpService.init();
    const response = await MiddlewareHttpService.postUpdateIgnore(tag);
    return response.objectBody !== undefined;
  } catch (e) {
    AppLogger.warning(`[Update] ignore failed: ${String(e)}`);
    return false;
  }
}

/** 让中间件开始下载并替换自身。 */
export async function startUpdateInstall(tag: string): Promise<boolean> {
  try {
    await MiddlewareHttpService.init();
    const response = await MiddlewareHttpService.postUpdateInstall(tag);
    return response.objectBody !== undefined;
  } catch (e) {
    AppLogger.warning(`[Update] install failed to start: ${String(e)}`);
    return false;
  }
}

/**
 * 查自更新进度。
 *
 * 中间件替换完自己会重启，这期间请求必然失败 —— 那不是错误，
 * 是预期之内的，所以拿不到就返回 undefined 由调用方按「重启中」处理。
 */
export async function fetchUpdateProgress(): Promise<UpdateProgress | undefined> {
  try {
    await MiddlewareHttpService.init();
    const response = await MiddlewareHttpService.getUpdateStatus();
    const body = response.objectBody;
    if (!body) return undefined;
    const raw = body['progress'];
    if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return undefined;
    return parseProgress(raw as JsonMap);
  } catch {
    return undefined;
  }
}

function failedState(detail: string): UpdateState {
  return { ignoredTag: '', ignored: false, checkFailed: true, errorDetail: detail };
}

/** 解析 `/update/check` 的响应 */
export function parseUpdateState(body: JsonMap): UpdateState {
  const ignoredTag = (pickString(body, ['ignored_tag']) ?? '').trim();
  const checkFailed = body['check_failed'] === true;
  const raw = body['result_data'];
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    return {
      ignoredTag,
      ignored: body['ignored'] === true,
      checkFailed: true,
      errorDetail: pickString(body, ['error_detail']),
    };
  }
  return {
    result: parseCheckResult(raw as JsonMap),
    ignoredTag,
    ignored: body['ignored'] === true,
    checkFailed,
    errorDetail: pickString(body, ['error_detail']),
  };
}

function parseCheckResult(map: JsonMap): UpdateCheckResult {
  return {
    available: map['available'] === true,
    current: pickString(map, ['current']) ?? '',
    latest: pickString(map, ['latest']) ?? '',
    tag: pickString(map, ['tag']) ?? '',
    releaseName: pickString(map, ['release_name']) ?? '',
    notes: pickString(map, ['notes']) ?? '',
    htmlUrl: pickString(map, ['html_url']) ?? '',
    isPrerelease: map['is_prerelease'] === true,
    publishedAt: pickString(map, ['published_at']),
    asset: pickString(map, ['asset']),
    assetSize: pickDouble(map, ['asset_size']),
    canSelfInstall: map['can_self_install'] === true,
    selfInstallBlockedReason: pickString(map, ['self_install_blocked_reason']),
  };
}

function parseProgress(map: JsonMap): UpdateProgress {
  const phase = (pickString(map, ['phase']) ?? 'idle').trim();
  return {
    phase:
      phase === 'downloading' || phase === 'applying' || phase === 'restarting' || phase === 'failed'
        ? phase
        : 'idle',
    tag: pickString(map, ['tag']),
    asset: pickString(map, ['asset']),
    downloadedBytes: pickDouble(map, ['downloaded_bytes']) ?? 0,
    totalBytes: pickDouble(map, ['total_bytes']) ?? 0,
    error: pickString(map, ['error']),
  };
}
