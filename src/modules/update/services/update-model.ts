/**
 * 自更新的判定与展示逻辑（纯函数）
 *
 * 不碰 React / Zustand / IO / SweetAlert。取数在 `update-api.ts`，
 * 弹窗在 `update-dialog.ts`，这里只负责「拿到检查结果之后该显示成什么样」。
 */

/** 中间件 `/api/v1/update/check` 的结果 */
export interface UpdateCheckResult {
  readonly available: boolean;
  readonly current: string;
  readonly latest: string;
  readonly tag: string;
  readonly releaseName: string;
  readonly notes: string;
  readonly htmlUrl: string;
  readonly isPrerelease: boolean;
  readonly publishedAt?: string;
  readonly asset?: string;
  readonly assetSize?: number;
  readonly canSelfInstall: boolean;
  readonly selfInstallBlockedReason?: string;
}

/** 一次检查的完整状态，含忽略信息 */
export interface UpdateState {
  readonly result?: UpdateCheckResult;
  readonly ignoredTag: string;
  readonly ignored: boolean;
  readonly checkFailed: boolean;
  readonly errorDetail?: string;
}

/** 自更新进度，对应中间件 `update.Progress` */
export interface UpdateProgress {
  readonly phase: 'idle' | 'downloading' | 'applying' | 'restarting' | 'failed';
  readonly tag?: string;
  readonly asset?: string;
  readonly downloadedBytes: number;
  readonly totalBytes: number;
  readonly error?: string;
}

/** 设置页要显示的状态 */
export type UpdateStatusKind =
  | 'unknown' // 还没查过
  | 'checking'
  | 'available'
  | 'ignored' // 有更新，但这一版被用户忽略了
  | 'upToDate'
  | 'failed';

/**
 * 由检查状态推出设置页要显示的状态。
 *
 * 「已忽略」优先于「有可用更新」：用户明确表示过不想要这一版，
 * 设置页要如实说「该版本已被忽略」而不是继续催他更新。
 */
export function resolveUpdateStatus(
  state: UpdateState | undefined,
  checking: boolean,
): UpdateStatusKind {
  if (checking) return 'checking';
  if (!state) return 'unknown';
  if (state.checkFailed) return 'failed';
  if (!state.result) return 'unknown';
  if (!state.result.available) return 'upToDate';
  return state.ignored ? 'ignored' : 'available';
}

/**
 * 是否应当主动弹窗。
 *
 * 只在「确实有更新」且「这一版没被忽略」时弹。忽略记的是 **tag**，
 * 所以再发新的一版仍然会弹 —— 忽略的是那一版，不是从此不再提醒。
 */
export function shouldPromptForUpdate(state: UpdateState | undefined): boolean {
  if (!state || state.checkFailed || !state.result) return false;
  return state.result.available && !state.ignored;
}

/** 把字节数格式化成人看的大小 */
export function formatBytes(bytes: number): string {
  if (!Number.isFinite(bytes) || bytes <= 0) return '--';
  if (bytes >= 1024 ** 3) return `${(bytes / 1024 ** 3).toFixed(1)} GB`;
  if (bytes >= 1024 ** 2) return `${(bytes / 1024 ** 2).toFixed(1)} MB`;
  if (bytes >= 1024) return `${(bytes / 1024).toFixed(0)} KB`;
  return `${Math.round(bytes)} B`;
}

/** 下载进度百分比（0–100）；总大小未知时返回 undefined */
export function downloadPercent(progress: UpdateProgress): number | undefined {
  if (progress.totalBytes <= 0) return undefined;
  const percent = (progress.downloadedBytes / progress.totalBytes) * 100;
  return Math.max(0, Math.min(100, percent));
}

// ────────────────────────────────────────────────────────────────────────────
// 发行说明渲染
// ────────────────────────────────────────────────────────────────────────────

/**
 * HTML 转义。
 *
 * 发行说明是从 GitHub 拿回来的外部文本，**必须**先转义再拼进 HTML。
 * 就算仓库是自己的，任何有权发 release 的人都能往里写 `<script>`；
 * 何况中间件地址是可改的，指向别人的服务就等于把弹窗交给对方写。
 */
export function escapeHtml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/**
 * 把发行说明的 Markdown 渲染成**安全**的 HTML 片段。
 *
 * 这里刻意不接 Markdown 库：release body 是外部文本，通用渲染器
 * （尤其是允许内联 HTML 的那些）会直接把 `<script>`、`<img onerror>`
 * 之类原样吐出来。这里只认三种结构 —— 标题、列表项、普通段落 ——
 * 且**先转义再包标签**，任何标记都不可能从文本里长出来。
 *
 * 代价是渲染不出链接、粗体、代码块。发行说明够用，安全性换得值。
 */
export function renderReleaseNotesHtml(markdown: string): string {
  const lines = (markdown ?? '').replace(/\r\n/g, '\n').split('\n');
  const html: string[] = [];
  let inList = false;

  const closeList = () => {
    if (inList) {
      html.push('</ul>');
      inList = false;
    }
  };

  for (const rawLine of lines) {
    const line = rawLine.trim();
    if (line === '') {
      closeList();
      continue;
    }

    const heading = /^(#{1,6})\s+(.*)$/.exec(line);
    if (heading) {
      closeList();
      // 标题一律降到 h4：弹窗里塞 h1 会把版本号衬得像脚注
      html.push(`<h4 class="owo-update-notes-heading">${escapeHtml(heading[2])}</h4>`);
      continue;
    }

    const bullet = /^[-*+]\s+(.*)$/.exec(line);
    if (bullet) {
      if (!inList) {
        html.push('<ul class="owo-update-notes-list">');
        inList = true;
      }
      html.push(`<li>${escapeHtml(bullet[1])}</li>`);
      continue;
    }

    closeList();
    html.push(`<p class="owo-update-notes-text">${escapeHtml(line)}</p>`);
  }
  closeList();
  return html.join('');
}
