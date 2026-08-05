import {
  allocateOverlayId,
  useOverlayStore,
  type ConfirmDialogStyle,
} from './overlay-store';

/**
 * 命令式对话框 API
 *
 * 对应 Flutter 版 `core/widgets/common/dialog.dart` 的
 * `showAdvancedConfirmDialog` 与 `showLoadingDialog`，参数与默认值保持一致。
 */

export type { ConfirmDialogStyle } from './overlay-store';

export interface ConfirmDialogOptions {
  title: string;
  content: string;
  style?: ConfirmDialogStyle;
  /** Material Symbols 图标名，默认 help */
  icon?: string;
  confirmColor?: string;
  confirmText?: string;
  /** 传空串则不显示取消按钮（桌面版用此方式做「仅确认」弹窗） */
  cancelText?: string;
  dialogWidth?: number;
  contentTextAlign?: 'left' | 'center' | 'right';
}

/**
 * 高级确认对话框
 * @returns 确认 → true；取消 → false；点遮罩/ESC 关闭 → null
 */
export function showAdvancedConfirmDialog(
  options: ConfirmDialogOptions,
): Promise<boolean | null> {
  const {
    title,
    content,
    style = 'material',
    icon = 'help',
    confirmColor = 'var(--color-primary)',
    confirmText = 'Yes',
    cancelText = 'Cancel',
    dialogWidth,
    contentTextAlign = 'center',
  } = options;

  return new Promise<boolean | null>((resolve) => {
    useOverlayStore.getState().pushDialog({
      id: allocateOverlayId(),
      kind: 'confirm',
      style,
      title,
      content,
      icon,
      confirmColor,
      confirmText,
      cancelText,
      dialogWidth,
      contentTextAlign,
      resolve,
    });
  });
}

/** 加载对话框句柄 */
export interface LoadingDialogHandle {
  close: () => void;
}

/**
 * 加载中对话框（无按钮，不可关闭）
 *
 * 桌面版是 `showLoadingDialog(...)` 后再 `Navigator.pop()`；
 * Web 版返回句柄，调用 `handle.close()` 关闭。
 */
export function showLoadingDialog(options: {
  title: string;
  content?: string;
  style?: ConfirmDialogStyle;
}): LoadingDialogHandle {
  const id = allocateOverlayId();
  useOverlayStore.getState().pushDialog({
    id,
    kind: 'loading',
    style: options.style ?? 'material',
    title: options.title,
    content: options.content ?? '',
  });
  return {
    close: () => useOverlayStore.getState().closeDialog(id),
  };
}
