import type { ModuleTranslations } from '../../../core/services/localization-service';

/** 自更新模块的 i18n 键 */
export const UpdateLocalizationKeys = {
  settingsTitle: 'update.settings.title',
  settingsDescription: 'update.settings.description',

  statusUnknown: 'update.status.unknown',
  statusChecking: 'update.status.checking',
  statusAvailable: 'update.status.available',
  statusIgnored: 'update.status.ignored',
  statusUpToDate: 'update.status.up_to_date',
  statusFailed: 'update.status.failed',

  currentVersion: 'update.current_version',
  latestVersion: 'update.latest_version',
  prereleaseBadge: 'update.prerelease_badge',
  checkButton: 'update.check_button',
  checkingButton: 'update.checking_button',
  installButton: 'update.install_button',
  ignoreButton: 'update.ignore_button',
  unignoreButton: 'update.unignore_button',
  laterButton: 'update.later_button',
  openReleaseButton: 'update.open_release_button',

  dialogTitle: 'update.dialog.title',
  dialogPrereleaseWarning: 'update.dialog.prerelease_warning',
  dialogNotesTitle: 'update.dialog.notes_title',
  dialogNoNotes: 'update.dialog.no_notes',
  dialogDownloadSize: 'update.dialog.download_size',
  downloadSize: 'update.download_size',

  installTitle: 'update.install.title',
  installDownloading: 'update.install.downloading',
  installApplying: 'update.install.applying',
  installRestarting: 'update.install.restarting',
  installRestartHint: 'update.install.restart_hint',
  installFailed: 'update.install.failed',

  blockedUnsupportedPlatform: 'update.blocked.unsupported_platform',
  blockedNoAsset: 'update.blocked.no_asset',
  blockedNotWritable: 'update.blocked.not_writable',
  blockedUnknown: 'update.blocked.unknown',
  blockedHint: 'update.blocked.hint',
} as const;

const K = UpdateLocalizationKeys;

export const updateTranslations: ModuleTranslations = {
  zh_CN: {
    [K.settingsTitle]: '软件更新',
    [K.settingsDescription]: '检查中间件是否有新版本，可自动下载并替换',

    [K.statusUnknown]: '尚未检查',
    [K.statusChecking]: '正在检查更新…',
    [K.statusAvailable]: '有可用更新',
    [K.statusIgnored]: '该版本已被忽略',
    [K.statusUpToDate]: '已是最新版本',
    [K.statusFailed]: '检查更新失败',

    [K.currentVersion]: '当前版本',
    [K.latestVersion]: '最新版本',
    [K.prereleaseBadge]: '预览版',
    [K.checkButton]: '检查更新',
    [K.checkingButton]: '检查中…',
    [K.installButton]: '立刻更新',
    [K.ignoreButton]: '忽略此版本',
    [K.unignoreButton]: '取消忽略',
    [K.laterButton]: '稍后再说',
    [K.openReleaseButton]: '打开发行页',

    [K.dialogTitle]: '发现新版本 {}',
    [K.dialogPrereleaseWarning]: '这是一个预览版，可能不稳定。',
    [K.dialogNotesTitle]: '更新内容',
    [K.dialogNoNotes]: '本次发行没有提供更新说明。',
    [K.dialogDownloadSize]: '下载大小约 {}',
    [K.downloadSize]: '下载大小',

    [K.installTitle]: '正在更新',
    [K.installDownloading]: '正在下载 {}',
    [K.installApplying]: '下载完成，正在准备替换…',
    [K.installRestarting]: '中间件正在重启',
    [K.installRestartHint]: '中间件会自己关闭并以新版本重新启动，稍后刷新本页即可。',
    [K.installFailed]: '更新失败：{}',

    [K.blockedUnsupportedPlatform]: '当前系统不支持自动更新',
    [K.blockedNoAsset]: '本次发行没有可直接安装的程序文件',
    [K.blockedNotWritable]: '中间件所在目录不可写，无法就地替换',
    [K.blockedUnknown]: '无法自动更新',
    [K.blockedHint]: '请前往发行页手动下载替换。',
  },
  en_US: {
    [K.settingsTitle]: 'Software update',
    [K.settingsDescription]: 'Check for a newer middleware build and install it automatically',

    [K.statusUnknown]: 'Not checked yet',
    [K.statusChecking]: 'Checking for updates…',
    [K.statusAvailable]: 'Update available',
    [K.statusIgnored]: 'This version has been ignored',
    [K.statusUpToDate]: 'Up to date',
    [K.statusFailed]: 'Update check failed',

    [K.currentVersion]: 'Current',
    [K.latestVersion]: 'Latest',
    [K.prereleaseBadge]: 'Pre-release',
    [K.checkButton]: 'Check for updates',
    [K.checkingButton]: 'Checking…',
    [K.installButton]: 'Update now',
    [K.ignoreButton]: 'Ignore this version',
    [K.unignoreButton]: 'Stop ignoring',
    [K.laterButton]: 'Later',
    [K.openReleaseButton]: 'Open release page',

    [K.dialogTitle]: 'Version {} is available',
    [K.dialogPrereleaseWarning]: 'This is a pre-release and may be unstable.',
    [K.dialogNotesTitle]: "What's new",
    [K.dialogNoNotes]: 'This release ships no release notes.',
    [K.dialogDownloadSize]: 'Download size roughly {}',
    [K.downloadSize]: 'Download',

    [K.installTitle]: 'Updating',
    [K.installDownloading]: 'Downloading {}',
    [K.installApplying]: 'Download finished, preparing to replace…',
    [K.installRestarting]: 'Middleware is restarting',
    [K.installRestartHint]:
      'The middleware shuts itself down and comes back as the new version. Reload this page in a moment.',
    [K.installFailed]: 'Update failed: {}',

    [K.blockedUnsupportedPlatform]: 'Automatic updates are not supported on this system',
    [K.blockedNoAsset]: 'This release ships no directly installable executable',
    [K.blockedNotWritable]: 'The middleware directory is not writable, cannot replace in place',
    [K.blockedUnknown]: 'Cannot update automatically',
    [K.blockedHint]: 'Please download and replace it manually from the release page.',
  },
};
