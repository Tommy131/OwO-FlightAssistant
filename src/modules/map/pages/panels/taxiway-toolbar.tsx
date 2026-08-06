/**
 * 自定义滑行道绘制工具条：撤销/重做/清空/导入导出
 */

import { useRef } from 'react';
import { useTranslate } from '../../../../core/localization/use-translate';
import { IconButton } from '../../../../core/widgets/common/controls';
import { showAdvancedConfirmDialog } from '../../../../core/widgets/common/dialog';
import { MaterialIcon } from '../../../../core/widgets/common/icon';
import { SnackBarHelper } from '../../../../core/widgets/common/snack-bar';
import { MapLocalizationKeys as K } from '../../localization/map-localization';
import { useMapStore } from '../../providers/map-store';
import styles from '../map-page.module.css';

// ──────────────────────────────────────────────────────────────────────────
// 滑行道绘制工具条
// ──────────────────────────────────────────────────────────────────────────

export function TaxiwayToolbar() {
  const t = useTranslate();
  const isActive = useMapStore((s) => s.isTaxiwayDrawingActive);
  const nodeCount = useMapStore((s) => s.taxiwayNodes.length);
  const hasUnsaved = useMapStore((s) => s.hasUnsavedTaxiwayChanges);
  const undo = useMapStore((s) => s.undoTaxiwayRoute);
  const redo = useMapStore((s) => s.redoTaxiwayRoute);
  const canUndo = useMapStore((s) => s.canUndoTaxiwayRoute);
  const canRedo = useMapStore((s) => s.canRedoTaxiwayRoute);
  const clear = useMapStore((s) => s.clearTaxiwayRoute);
  const exportRoute = useMapStore((s) => s.exportTaxiwayRoute);
  const importRoute = useMapStore((s) => s.importTaxiwayRoute);
  const fileInputRef = useRef<HTMLInputElement>(null);

  if (!isActive) return null;

  const handleExport = () => {
    const result = exportRoute();
    if (result === 1) SnackBarHelper.showSuccess(t(K.taxiwayExportSuccess));
    else SnackBarHelper.showWarning(t(K.taxiwayNoRouteToSave));
  };

  const handleImport = async (file: File) => {
    const count = await importRoute(file);
    if (count > 0) SnackBarHelper.showSuccess(t(K.taxiwayImportSuccess, count));
    else SnackBarHelper.showError(t(K.taxiwayImportInvalid));
  };

  const handleClear = async () => {
    const confirmed = await showAdvancedConfirmDialog({
      title: t(K.tooltipTaxiwayClear),
      content: t(K.clearRouteConfirmContent),
      icon: 'ink_eraser',
      confirmColor: 'var(--color-danger)',
      confirmText: t(K.clearButton),
      cancelText: t(K.taxiwayAutoLoadSkip),
    });
    if (confirmed === true) clear();
  };

  return (
    <div className={styles.taxiwayToolbar}>
      <span className={styles.taxiwayHint}>
        <MaterialIcon name="touch_app" size={14} />
        {t(K.taxiwayNode)} · {nodeCount}
        {hasUnsaved && <span className={styles.unsavedDot} title={t(K.taxiwayEditUnsaved)} />}
      </span>

      <IconButton
        icon="undo"
        label={t(K.tooltipTaxiwayUndo)}
        disabled={!canUndo()}
        onClick={undo}
      />
      <IconButton
        icon="redo"
        label={t(K.tooltipTaxiwayRedo)}
        disabled={!canRedo()}
        onClick={redo}
      />
      {/* 用橡皮而不是 delete_sweep：那个已经是 HUD「清除航迹」的图标，
          这里清的是手绘的滑行道，是两件事 */}
      <IconButton
        icon="ink_eraser"
        label={t(K.tooltipTaxiwayClear)}
        disabled={nodeCount === 0}
        onClick={() => void handleClear()}
      />
      <span className={styles.controlDivider} />
      <IconButton
        icon="upload_file"
        label={t(K.tooltipTaxiwayImport)}
        onClick={() => fileInputRef.current?.click()}
      />
      <IconButton icon="download" label={t(K.tooltipTaxiwaySave)} onClick={handleExport} />

      <input
        ref={fileInputRef}
        type="file"
        accept=".json"
        className="sr-only"
        onChange={(event) => {
          const file = event.target.files?.[0];
          event.target.value = '';
          if (file) void handleImport(file);
        }}
      />
    </div>
  );
}
