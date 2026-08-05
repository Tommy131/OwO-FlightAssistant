import { useEffect, useState } from 'react';
import { useTranslate } from '../../../core/localization/use-translate';
import {
  IconButton,
  SegmentedControl,
  TextField,
} from '../../../core/widgets/common/controls';
import { showAdvancedConfirmDialog } from '../../../core/widgets/common/dialog';
import { MaterialIcon } from '../../../core/widgets/common/icon';
import { SnackBarHelper } from '../../../core/widgets/common/snack-bar';
import { EmptyState } from '../../../core/widgets/common/surfaces';
import { AppLogger, type LogEntry, type LogLevel } from '../../../core/utils/logger';
import { LogViewerLocalizationKeys as K } from '../localization/log-viewer-localization';
import styles from './log-viewer-page.module.css';

/**
 * 应用日志查看器
 *
 * 对应 Flutter 版 `modules/log_viewer/pages/log_viewer_page.dart`。
 *
 * ── Web 降级说明 ──
 * 桌面版读取 `<cacheRoot>/logs/{app,error}.log` 两个文件；
 * Web 版没有文件系统，读的是 AppLogger 的内存环形缓冲区。
 * 「全部 / 错误」两个视图对应桌面版的两个日志文件，导出为 .log 文本。
 */
type LogScope = 'all' | 'error';

const LEVEL_COLOR: Record<LogLevel, string> = {
  debug: 'var(--color-text-secondary)',
  info: '#2a78d6',
  warning: '#ec835a',
  error: '#d03b3b',
};

const LEVEL_ICON: Record<LogLevel, string> = {
  debug: 'bug_report',
  info: 'info',
  warning: 'warning',
  error: 'error',
};

export function LogViewerPage() {
  const t = useTranslate();
  const [scope, setScope] = useState<LogScope>('all');
  const [keyword, setKeyword] = useState('');
  const [entries, setEntries] = useState<LogEntry[]>([]);

  const reload = () => {
    setEntries(
      AppLogger.read({
        minLevel: scope === 'error' ? 'error' : undefined,
        keyword: keyword.trim().length > 0 ? keyword : undefined,
      }),
    );
  };

  // 首次载入 + 订阅新日志实时追加
  useEffect(() => {
    reload();
    const unsubscribe = AppLogger.subscribe(() => reload());
    return unsubscribe;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [scope, keyword]);

  const handleClear = async () => {
    const confirmed = await showAdvancedConfirmDialog({
      title: t(K.clearLogs),
      content: t(K.emptyLogs),
      icon: 'delete_sweep',
      confirmColor: 'var(--color-danger)',
      confirmText: t(K.clearLogs),
      cancelText: t(K.refresh),
    });
    if (confirmed !== true) return;
    AppLogger.clear();
    reload();
  };

  const handleExport = () => {
    const text = AppLogger.toPlainText(entries);
    const blob = new Blob([text], { type: 'text/plain;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement('a');
    anchor.href = url;
    anchor.download = scope === 'error' ? 'error.log' : 'app.log';
    anchor.click();
    URL.revokeObjectURL(url);
    SnackBarHelper.showSuccess(t(K.logFile));
  };

  return (
    <div className={styles.page}>
      <div className={styles.toolbar}>
        <SegmentedControl
          value={scope}
          options={[
            { value: 'all', label: t(K.allLogs), icon: 'notes' },
            { value: 'error', label: t(K.errorLogs), icon: 'error' },
          ]}
          onChange={setScope}
          size="sm"
        />

        <TextField
          value={keyword}
          onChange={setKeyword}
          placeholder={t(K.pageTitle)}
          icon="search"
          type="search"
          className={styles.search}
        />

        <span className={styles.countBadge}>{entries.length}</span>

        <IconButton icon="refresh" label={t(K.refresh)} onClick={reload} />
        <IconButton icon="download" label={t(K.logFile)} onClick={handleExport} />
        <IconButton icon="delete_sweep" label={t(K.clearLogs)} onClick={() => void handleClear()} />
      </div>

      {entries.length === 0 ? (
        <div className={styles.emptyWrap}>
          <EmptyState icon="notes" title={t(K.emptyLogs)} />
        </div>
      ) : (
        <div className={`${styles.list} scroll-area`}>
          {/* 倒序展示：最新的在最上面 */}
          {[...entries].reverse().map((entry, index) => (
            <div key={index} className={styles.row}>
              <MaterialIcon
                name={LEVEL_ICON[entry.level]}
                filled
                size={14}
                color={LEVEL_COLOR[entry.level]}
              />
              <span className={`${styles.time} text-mono`}>{formatTime(entry.timestamp)}</span>
              <span className={styles.level} style={{ color: LEVEL_COLOR[entry.level] }}>
                {entry.level.toUpperCase()}
              </span>
              <div className={styles.messageWrap}>
                <span className={styles.message}>{entry.message}</span>
                {entry.detail && (
                  <pre className={`${styles.detail} text-mono`}>{entry.detail}</pre>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function formatTime(date: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
}
