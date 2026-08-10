/**
 * 更新提示弹窗（SweetAlert2）
 *
 * 只负责「把已经算好的东西显示出来」——判定与渲染在 `update-model.ts`
 * （纯函数、有单测），本文件不做任何决策。
 */

import Swal from 'sweetalert2';

import { translate } from '../../../core/services/localization-service';
import { UpdateLocalizationKeys as K } from '../localization/update-localization';
import {
  type UpdateCheckResult,
  escapeHtml,
  formatBytes,
  renderReleaseNotesHtml,
} from './update-model';

/** 用户在更新弹窗里的选择 */
export type UpdateChoice = 'install' | 'ignore' | 'later';

/**
 * 让 SweetAlert 跟着应用的深浅色走。
 *
 * SweetAlert 的弹窗挂在 <body> 上、不在应用的容器里，拿不到组件树上的
 * 主题上下文。主题写在 <html> 的 data-brightness 上（见 applyThemeTokens），
 * 直接读那里，同时用主题令牌取色，配色才不会和应用两张皮。
 */
function swalTheme() {
  const root = document.documentElement;
  const styles = getComputedStyle(root);
  const pick = (token: string, fallback: string) =>
    styles.getPropertyValue(token).trim() || fallback;
  const dark = root.dataset.brightness !== 'light';
  return {
    background: pick('--color-surface', dark ? '#161a24' : '#ffffff'),
    color: pick('--color-text-primary', dark ? '#e6e9f0' : '#1d2129'),
  };
}

/**
 * 弹出「发现新版本」。返回用户的选择。
 *
 * 三个出口分得很清楚：**立刻更新**、**忽略此版本**（记下 tag，这一版不再提醒）、
 * **稍后再说**（什么都不记，下次启动照弹）。
 */
export async function showUpdateAvailableDialog(
  result: UpdateCheckResult,
): Promise<UpdateChoice> {
  const notesHtml = result.notes.trim()
    ? renderReleaseNotesHtml(result.notes)
    : `<p class="owo-update-notes-text">${escapeHtml(translate(K.dialogNoNotes))}</p>`;

  const meta: string[] = [
    `<span class="owo-update-meta-item">${escapeHtml(translate(K.currentVersion))}: ${escapeHtml(
      result.current,
    )}</span>`,
    `<span class="owo-update-meta-item">${escapeHtml(translate(K.latestVersion))}: ${escapeHtml(
      result.latest,
    )}</span>`,
  ];
  if (result.isPrerelease) {
    meta.push(`<span class="owo-update-badge">${escapeHtml(translate(K.prereleaseBadge))}</span>`);
  }
  if (result.assetSize && result.assetSize > 0) {
    meta.push(
      `<span class="owo-update-meta-item">${escapeHtml(
        translate(K.dialogDownloadSize).replace('{}', formatBytes(result.assetSize)),
      )}</span>`,
    );
  }

  const warnings: string[] = [];
  if (result.isPrerelease) {
    warnings.push(
      `<p class="owo-update-warning">${escapeHtml(translate(K.dialogPrereleaseWarning))}</p>`,
    );
  }
  if (!result.canSelfInstall) {
    warnings.push(
      `<p class="owo-update-warning">${escapeHtml(
        `${blockedReasonText(result.selfInstallBlockedReason)} ${translate(K.blockedHint)}`,
      )}</p>`,
    );
  }

  const response = await Swal.fire({
    ...swalTheme(),
    title: translate(K.dialogTitle).replace('{}', result.latest),
    // 整段 HTML 里的每一处外部文本都已经过 escapeHtml —— 发行说明来自
    // GitHub，是不可信输入，任何一处漏转义就是一个 XSS
    html: `
      <div class="owo-update-dialog">
        <div class="owo-update-meta">${meta.join('')}</div>
        ${warnings.join('')}
        <h4 class="owo-update-notes-heading">${escapeHtml(translate(K.dialogNotesTitle))}</h4>
        <div class="owo-update-notes">${notesHtml}</div>
      </div>
    `,
    icon: 'info',
    showCancelButton: true,
    showDenyButton: true,
    // 不能自更新时首选按钮改成「打开发行页」，别让用户点一个注定失败的按钮
    confirmButtonText: result.canSelfInstall
      ? translate(K.installButton)
      : translate(K.openReleaseButton),
    denyButtonText: translate(K.ignoreButton),
    cancelButtonText: translate(K.laterButton),
    reverseButtons: true,
    focusConfirm: true,
    width: '38rem',
  });

  if (response.isConfirmed) {
    if (!result.canSelfInstall) {
      openReleasePage(result.htmlUrl);
      return 'later';
    }
    return 'install';
  }
  if (response.isDenied) return 'ignore';
  return 'later';
}

/** 弹出安装进度窗，返回一个可以更新文字/进度的句柄 */
export function showInstallProgressDialog(): {
  setText: (text: string) => void;
  setPercent: (percent: number | undefined) => void;
  close: () => void;
} {
  void Swal.fire({
    ...swalTheme(),
    title: translate(K.installTitle),
    html: `
      <div class="owo-update-progress">
        <p class="owo-update-progress-text"></p>
        <div class="owo-update-progress-track"><div class="owo-update-progress-bar"></div></div>
      </div>
    `,
    allowOutsideClick: false,
    allowEscapeKey: false,
    showConfirmButton: false,
    didOpen: () => Swal.showLoading(undefined),
  });

  const textEl = () => document.querySelector<HTMLElement>('.owo-update-progress-text');
  const barEl = () => document.querySelector<HTMLElement>('.owo-update-progress-bar');

  return {
    setText: (text) => {
      const el = textEl();
      // 用 textContent 而不是 innerHTML：这里的文字可能带资产名，同样是外部串
      if (el) el.textContent = text;
    },
    setPercent: (percent) => {
      const el = barEl();
      if (!el) return;
      if (percent === undefined) {
        el.style.width = '100%';
        el.classList.add('owo-update-progress-indeterminate');
        return;
      }
      el.classList.remove('owo-update-progress-indeterminate');
      el.style.width = `${percent.toFixed(1)}%`;
    },
    close: () => Swal.close(),
  };
}

/** 弹出「即将重启」的收尾提示 */
export async function showRestartingDialog(): Promise<void> {
  await Swal.fire({
    ...swalTheme(),
    title: translate(K.installRestarting),
    text: translate(K.installRestartHint),
    icon: 'success',
    confirmButtonText: 'OK',
  });
}

/** 弹出更新失败 */
export async function showInstallFailedDialog(detail: string, htmlUrl: string): Promise<void> {
  const response = await Swal.fire({
    ...swalTheme(),
    title: translate(K.installFailed).replace('{}', detail),
    text: translate(K.blockedHint),
    icon: 'error',
    showCancelButton: true,
    confirmButtonText: translate(K.openReleaseButton),
    cancelButtonText: 'OK',
    reverseButtons: true,
  });
  if (response.isConfirmed) openReleasePage(htmlUrl);
}

/** 把不可自更新的原因翻成人话 */
export function blockedReasonText(reason: string | undefined): string {
  switch ((reason ?? '').trim()) {
    case 'unsupported_platform':
      return translate(K.blockedUnsupportedPlatform);
    case 'no_matching_asset':
      return translate(K.blockedNoAsset);
    case 'executable_not_writable':
    case 'executable_path_unknown':
      return translate(K.blockedNotWritable);
    default:
      return translate(K.blockedUnknown);
  }
}

/** 在新标签页打开发行页 */
export function openReleasePage(url: string): void {
  const target = (url ?? '').trim();
  // 只放行 https：url 来自接口响应，javascript: 之类的伪协议不能直接开
  if (!target.toLowerCase().startsWith('https://')) return;
  window.open(target, '_blank', 'noopener,noreferrer');
}
