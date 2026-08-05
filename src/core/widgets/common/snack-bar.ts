import { allocateOverlayId, useOverlayStore, type SnackBarType } from './overlay-store';

/**
 * 全局提示条
 *
 * 对应 Flutter 版 `core/widgets/common/snack_bar.dart` 的 `SnackBarHelper`。
 * 桌面版需要 BuildContext，Web 版走全局 store，因此调用处不再传 context。
 */

const DEFAULT_DURATION_MS = 3200;
/** 错误提示停留更久，方便阅读 */
const ERROR_DURATION_MS = 5000;

function show(
  type: SnackBarType,
  message: string,
  options: { title?: string; durationMs?: number } = {},
): void {
  useOverlayStore.getState().pushSnackBar({
    id: allocateOverlayId(),
    type,
    title: options.title,
    message,
    durationMs:
      options.durationMs ?? (type === 'error' ? ERROR_DURATION_MS : DEFAULT_DURATION_MS),
  });
}

export const SnackBarHelper = {
  showSuccess(message: string, options?: { title?: string; durationMs?: number }): void {
    show('success', message, options);
  },
  showInfo(message: string, options?: { title?: string; durationMs?: number }): void {
    show('info', message, options);
  },
  showWarning(message: string, options?: { title?: string; durationMs?: number }): void {
    show('warning', message, options);
  },
  showError(message: string, options?: { title?: string; durationMs?: number }): void {
    show('error', message, options);
  },
};

export type { SnackBarType } from './overlay-store';
