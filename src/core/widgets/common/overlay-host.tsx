import { useEffect } from 'react';
import { useTranslate } from '../../localization/use-translate';
import { LocalizationKeys } from '../../localization/localization-keys';
import { Button } from './controls';
import { MaterialIcon } from './icon';
import {
  useOverlayStore,
  type ConfirmDialogSpec,
  type LoadingDialogSpec,
  type SnackBarSpec,
  type SnackBarType,
} from './overlay-store';
import styles from './overlay-host.module.css';

/**
 * 浮层宿主
 *
 * 挂在应用最外层，负责渲染 `showAdvancedConfirmDialog` / `SnackBarHelper`
 * 推入 store 的对话框与提示条。四种对话框风格与桌面版逐一对应：
 * material / cupertino / glass（毛玻璃）/ darkNeon（暗色霓虹）。
 */
export function OverlayHost() {
  const dialogs = useOverlayStore((state) => state.dialogs);
  const snackBars = useOverlayStore((state) => state.snackBars);

  return (
    <>
      {dialogs.map((dialog) =>
        dialog.kind === 'confirm' ? (
          <ConfirmDialog key={dialog.id} spec={dialog} />
        ) : (
          <LoadingDialog key={dialog.id} spec={dialog} />
        ),
      )}
      {snackBars.length > 0 && (
        <div className={styles.snackStack} role="status" aria-live="polite">
          {snackBars.map((snackBar) => (
            <SnackBarItem key={snackBar.id} spec={snackBar} />
          ))}
        </div>
      )}
    </>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 确认对话框
// ──────────────────────────────────────────────────────────────────────────

function ConfirmDialog({ spec }: { spec: ConfirmDialogSpec }) {
  const closeDialog = useOverlayStore((state) => state.closeDialog);

  const settle = (value: boolean | null) => {
    closeDialog(spec.id);
    spec.resolve(value);
  };

  // ESC 关闭，等价于 Flutter 的 barrierDismissible
  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') settle(null);
      if (event.key === 'Enter') settle(true);
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [spec.id]);

  const hasCancel = spec.cancelText.trim().length > 0;

  return (
    <div
      className={`${styles.scrim} ${styles[`scrim_${spec.style}`]}`}
      onClick={() => settle(null)}
      role="presentation"
    >
      <div
        role="alertdialog"
        aria-modal="true"
        aria-label={spec.title}
        className={`${styles.dialog} ${styles[`dialog_${spec.style}`]}`}
        style={spec.dialogWidth ? { width: spec.dialogWidth } : undefined}
        onClick={(event) => event.stopPropagation()}
      >
        {spec.style !== 'cupertino' && (
          <div
            className={styles.dialogIcon}
            style={{
              color: spec.confirmColor,
              background: 'color-mix(in srgb, currentColor 14%, transparent)',
            }}
          >
            <MaterialIcon name={spec.icon} size={26} color={spec.confirmColor} />
          </div>
        )}

        <h2 className={styles.dialogTitle}>{spec.title}</h2>
        {spec.content.length > 0 && (
          <p className={styles.dialogContent} style={{ textAlign: spec.contentTextAlign }}>
            {spec.content}
          </p>
        )}

        <div className={styles.dialogActions}>
          {hasCancel && (
            <Button variant="text" onClick={() => settle(false)}>
              {spec.cancelText}
            </Button>
          )}
          <Button
            variant="elevated"
            onClick={() => settle(true)}
            style={{ background: spec.confirmColor }}
          >
            {spec.confirmText}
          </Button>
        </div>
      </div>
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 加载对话框
// ──────────────────────────────────────────────────────────────────────────

function LoadingDialog({ spec }: { spec: LoadingDialogSpec }) {
  return (
    <div className={`${styles.scrim} ${styles[`scrim_${spec.style}`]}`} role="presentation">
      <div
        role="alertdialog"
        aria-modal="true"
        aria-busy="true"
        aria-label={spec.title}
        className={`${styles.dialog} ${styles[`dialog_${spec.style}`]} ${styles.dialogLoading}`}
      >
        {/* motion-essential：加载弹窗的转圈同理，见 global.css 的说明 */}
        <div className={`${styles.loadingRing} motion-essential`} aria-hidden />
        <h2 className={styles.dialogTitle}>{spec.title}</h2>
        {spec.content.length > 0 && <p className={styles.dialogContent}>{spec.content}</p>}
      </div>
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────
// 提示条
// ──────────────────────────────────────────────────────────────────────────

const SNACK_STYLE: Record<SnackBarType, { color: string; icon: string; titleKey: string }> = {
  success: { color: '#00B894', icon: 'check_circle', titleKey: LocalizationKeys.success },
  info: { color: 'var(--color-primary)', icon: 'info', titleKey: LocalizationKeys.loading },
  warning: { color: '#F1C40F', icon: 'warning', titleKey: LocalizationKeys.dangerZone },
  error: { color: '#E74C30', icon: 'error', titleKey: LocalizationKeys.updateCheckFailed },
};

/** 各类型的默认标题（桌面版硬编码中文，这里改为随语言切换） */
const SNACK_DEFAULT_TITLE: Record<SnackBarType, Record<string, string>> = {
  success: { zh: '成功', en: 'Success', de: 'Erfolg' },
  info: { zh: '提示', en: 'Info', de: 'Hinweis' },
  warning: { zh: '警告', en: 'Warning', de: 'Warnung' },
  error: { zh: '错误', en: 'Error', de: 'Fehler' },
};

function SnackBarItem({ spec }: { spec: SnackBarSpec }) {
  const dismiss = useOverlayStore((state) => state.dismissSnackBar);
  const t = useTranslate();
  const style = SNACK_STYLE[spec.type];

  useEffect(() => {
    const timer = setTimeout(() => dismiss(spec.id), spec.durationMs);
    return () => clearTimeout(timer);
  }, [spec.id, spec.durationMs, dismiss]);

  // 依据当前界面语言取默认标题
  const langPrefix = document.documentElement.lang.slice(0, 2);
  const defaultTitle =
    SNACK_DEFAULT_TITLE[spec.type][langPrefix] ?? SNACK_DEFAULT_TITLE[spec.type].en;

  return (
    <div className={styles.snackBar} style={{ borderLeftColor: style.color }}>
      <MaterialIcon name={style.icon} size={20} color={style.color} filled />
      <div className={styles.snackBody}>
        <span className={styles.snackTitle} style={{ color: style.color }}>
          {spec.title ?? defaultTitle}
        </span>
        <span className={styles.snackMessage}>{spec.message}</span>
      </div>
      <button
        type="button"
        className={styles.snackClose}
        onClick={() => dismiss(spec.id)}
        aria-label={t(LocalizationKeys.close)}
      >
        <MaterialIcon name="close" size={16} />
      </button>
    </div>
  );
}
