/**
 * 自更新的端到端流程，启动检查与设置页的「立刻更新」共用。
 *
 * 决策都在 `update-model.ts`（纯函数、有单测），本文件只负责编排：
 * 弹窗 → 记忽略 / 起安装 → 跟进度 → 收尾。
 */

import { AppLogger } from '../../../core/utils/logger';
import { translate } from '../../../core/services/localization-service';
import { UpdateLocalizationKeys as K } from '../localization/update-localization';
import { useUpdateStore } from '../providers/update-store';
import {
  showInstallFailedDialog,
  showInstallProgressDialog,
  showRestartingDialog,
  showUpdateAvailableDialog,
} from './update-dialog';
import {
  type UpdateCheckResult,
  downloadPercent,
  formatBytes,
  shouldPromptForUpdate,
} from './update-model';

/**
 * 启动时检查一次并在需要时弹窗。
 *
 * 只在**本次会话第一次**跑 —— 每切一次页面就弹一遍会让人想砸键盘。
 * 被忽略的版本不弹（判定见 shouldPromptForUpdate）。
 */
export async function runStartupUpdateCheck(): Promise<void> {
  const store = useUpdateStore.getState();
  if (store.startupChecked) return;
  store.markStartupChecked();

  const state = await store.check(false);
  if (!shouldPromptForUpdate(state) || !state?.result) return;
  await offerUpdate(state.result);
}

/**
 * 弹出更新提示并按用户的选择往下走。
 *
 * 三个出口：立刻更新 / 忽略此版本（记 tag）/ 稍后（什么都不记，下次照弹）。
 */
export async function offerUpdate(result: UpdateCheckResult): Promise<void> {
  const choice = await showUpdateAvailableDialog(result);
  const store = useUpdateStore.getState();

  if (choice === 'ignore') {
    AppLogger.info(`[Update] user ignored ${result.tag}`);
    await store.ignore(result.tag);
    return;
  }
  if (choice === 'later') return;

  await runInstall(result);
}

/** 起一次安装并跟着进度走，直到重启或失败。 */
export async function runInstall(result: UpdateCheckResult): Promise<void> {
  const store = useUpdateStore.getState();
  const progressDialog = showInstallProgressDialog();
  progressDialog.setText(translate(K.installDownloading).replace('{}', result.asset ?? ''));
  progressDialog.setPercent(undefined);

  const started = await store.install(result.tag);
  if (!started) {
    progressDialog.close();
    await showInstallFailedDialog('install_start_failed', result.htmlUrl);
    return;
  }

  // 跟着 store 里的进度更新弹窗，直到进入终态
  await new Promise<void>((resolve) => {
    const unsubscribe = useUpdateStore.subscribe((state) => {
      const progress = state.progress;
      if (!progress) return;

      switch (progress.phase) {
        case 'downloading': {
          const percent = downloadPercent(progress);
          const size =
            progress.totalBytes > 0
              ? ` (${formatBytes(progress.downloadedBytes)} / ${formatBytes(progress.totalBytes)})`
              : '';
          progressDialog.setText(
            translate(K.installDownloading).replace('{}', progress.asset ?? '') + size,
          );
          progressDialog.setPercent(percent);
          return;
        }
        case 'applying':
          progressDialog.setText(translate(K.installApplying));
          progressDialog.setPercent(100);
          return;
        case 'restarting':
          unsubscribe();
          progressDialog.close();
          void showRestartingDialog().then(resolve);
          return;
        case 'failed':
          unsubscribe();
          progressDialog.close();
          void showInstallFailedDialog(progress.error ?? 'unknown', result.htmlUrl).then(resolve);
          return;
        default:
          return;
      }
    });
  });
}
