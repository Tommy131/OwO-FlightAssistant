import type { ModuleTranslations } from '../../../core/services/localization-service';

/**
 * LogViewer 模块国际化
 *
 * 对应 Flutter 版 `modules/log_viewer/localization/*.dart`（8 个 key）。
 * 由脚本机械转换，key 与文案逐条对齐。
 */
export const LogViewerLocalizationKeys = {
  navTitle: 'log_viewer_nav_title',
  pageTitle: 'log_viewer_page_title',
  refresh: 'log_viewer_refresh',
  clearLogs: 'log_viewer_clear_logs',
  allLogs: 'log_viewer_all_logs',
  errorLogs: 'log_viewer_error_logs',
  emptyLogs: 'log_viewer_empty_logs',
  logFile: 'log_viewer_log_file',
} as const;

const K = LogViewerLocalizationKeys;

export const logViewerTranslations: ModuleTranslations = {
  zh_CN: {
    [K.navTitle]: '日志查看',
    [K.pageTitle]: '应用日志',
    [K.refresh]: '刷新',
    [K.clearLogs]: '清空',
    [K.allLogs]: '全部日志',
    [K.errorLogs]: '错误日志',
    [K.emptyLogs]: '暂无日志记录',
    [K.logFile]: '日志文件',
  },
  en_US: {
    [K.navTitle]: 'Log Viewer',
    [K.pageTitle]: 'App Logs',
    [K.refresh]: 'Refresh',
    [K.clearLogs]: 'Clear',
    [K.allLogs]: 'All Logs',
    [K.errorLogs]: 'Error Logs',
    [K.emptyLogs]: 'No logs found',
    [K.logFile]: 'Log File',
  },
};
