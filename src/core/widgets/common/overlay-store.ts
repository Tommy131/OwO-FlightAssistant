import { create } from 'zustand';

/**
 * 全局浮层（对话框 / 提示条）状态
 *
 * Flutter 用 `showDialog(context: ...)` 这种命令式 API；React 没有等价物，
 * 因此这里用一个全局 store + 顶层 `<OverlayHost />` 复刻同样的调用体验：
 *
 * ```ts
 * const ok = await showAdvancedConfirmDialog({ title, content });
 * SnackBarHelper.showSuccess(message);
 * ```
 */

/** 对话框风格，对应 Flutter 的 ConfirmDialogStyle */
export type ConfirmDialogStyle = 'material' | 'cupertino' | 'glass' | 'darkNeon';

export interface ConfirmDialogSpec {
  id: number;
  kind: 'confirm';
  style: ConfirmDialogStyle;
  title: string;
  content: string;
  /** Material Symbols 图标名 */
  icon: string;
  confirmColor: string;
  confirmText: string;
  /** 空串表示不显示取消按钮（与桌面版一致） */
  cancelText: string;
  dialogWidth?: number;
  contentTextAlign: 'left' | 'center' | 'right';
  resolve: (value: boolean | null) => void;
}

export interface LoadingDialogSpec {
  id: number;
  kind: 'loading';
  style: ConfirmDialogStyle;
  title: string;
  content: string;
}

export type DialogSpec = ConfirmDialogSpec | LoadingDialogSpec;

export type SnackBarType = 'info' | 'success' | 'warning' | 'error';

export interface SnackBarSpec {
  id: number;
  type: SnackBarType;
  title?: string;
  message: string;
  durationMs: number;
}

interface OverlayState {
  dialogs: DialogSpec[];
  snackBars: SnackBarSpec[];
  pushDialog: (dialog: DialogSpec) => void;
  closeDialog: (id: number) => void;
  pushSnackBar: (snackBar: SnackBarSpec) => void;
  dismissSnackBar: (id: number) => void;
}

export const useOverlayStore = create<OverlayState>((set) => ({
  dialogs: [],
  snackBars: [],

  pushDialog: (dialog) => set((state) => ({ dialogs: [...state.dialogs, dialog] })),

  closeDialog: (id) =>
    set((state) => ({ dialogs: state.dialogs.filter((dialog) => dialog.id !== id) })),

  pushSnackBar: (snackBar) =>
    // 最多同时展示 4 条，超出丢弃最旧的
    set((state) => ({ snackBars: [...state.snackBars, snackBar].slice(-4) })),

  dismissSnackBar: (id) =>
    set((state) => ({ snackBars: state.snackBars.filter((item) => item.id !== id) })),
}));

let nextOverlayId = 1;
export function allocateOverlayId(): number {
  return nextOverlayId++;
}
