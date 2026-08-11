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
 * 这里刻意不接第三方 Markdown 库：release body 是外部文本，通用渲染器
 * （尤其是允许内联 HTML 的那些）会直接把 `<script>`、`<img onerror>`
 * 之类原样吐出来。这里自己写一个只产出白名单标签的小解析器，核心规则
 * 只有一条 —— **先转义、再包标签**：整段文本先过一遍 `escapeHtml`，
 * 后续所有正则只在"已经安全"的文本里找 Markdown 记号往外面套标签，
 * 标记本身（`<script>` 之类）不可能从文本里重新长出来。
 *
 * 支持的结构：
 *   - 块级：标题 `#`、分隔线 `---`、引用 `>`、有序/无序列表（含缩进续行）、段落
 *   - 行内：`` `代码` ``、`**加粗**`、`*斜体*`、`~~删除线~~`、`[文字](链接)`
 *
 * 刻意不支持的部分（都是权衡，不是漏做）：
 *   - 下划线写法的 `__加粗__` / `_斜体_`：项目里路径、字段名大量是
 *     snake_case（`app_settings`、`earth_fix.dat`），按下划线抓斜体
 *     会把标识符中间那一截误判成斜体；星号写法没有这个问题，够用。
 *   - 链接协议只放行 `http(s)`：`javascript:` / `data:` 一律降级成纯文字，
 *     不生成 `<a>`，免得点出去执行伪协议。
 *   - 图片语法 `![alt](url)`：渲染成 `<img>` 会在弹窗一打开就对任意 URL
 *     发起请求（等于把发行说明变成一个追踪像素/内网探测入口），
 *     这里退化成纯文字，可读但不自动发请求。
 *   - 代码块 ```` ``` ````：发行说明里至今没出现过，真要支持可以再加。
 */
export function renderReleaseNotesHtml(markdown: string): string {
  const lines = (markdown ?? '').replace(/\r\n/g, '\n').split('\n');
  return parseBlocks(lines)
    .map(renderBlock)
    .join('');
}

// ────────────────────────────────────────────────────────────────────────────
// 块级解析：把行数组切成标题 / 分隔线 / 引用 / 列表 / 段落
// ────────────────────────────────────────────────────────────────────────────

type Block =
  | { kind: 'heading'; text: string }
  | { kind: 'hr' }
  | { kind: 'quote'; lines: string[] }
  | { kind: 'list'; ordered: boolean; items: string[][] }
  | { kind: 'paragraph'; lines: string[] };

const HEADING_RE = /^#{1,6}\s+(.*)$/;
/** 分隔线：一整行只有 3 个以上同一种符号（可夹空格），如 `---` / `* * *` */
const HR_RE = /^([-*_])(?:\s*\1){2,}$/;
const QUOTE_RE = /^>\s?(.*)$/;
const BULLET_RE = /^[-*+]\s+(.*)$/;
const ORDERED_RE = /^\d+[.)]\s+(.*)$/;

function isBlockBoundary(trimmed: string): boolean {
  return (
    trimmed === '' ||
    HEADING_RE.test(trimmed) ||
    HR_RE.test(trimmed) ||
    QUOTE_RE.test(trimmed) ||
    BULLET_RE.test(trimmed) ||
    ORDERED_RE.test(trimmed)
  );
}

function parseBlocks(lines: string[]): Block[] {
  const blocks: Block[] = [];
  let i = 0;

  while (i < lines.length) {
    const line = lines[i].trim();

    if (line === '') {
      i++;
      continue;
    }

    const heading = HEADING_RE.exec(line);
    if (heading) {
      blocks.push({ kind: 'heading', text: heading[1] });
      i++;
      continue;
    }

    if (HR_RE.test(line)) {
      blocks.push({ kind: 'hr' });
      i++;
      continue;
    }

    if (QUOTE_RE.test(line)) {
      const quoteLines: string[] = [];
      while (i < lines.length) {
        const match = QUOTE_RE.exec(lines[i].trim());
        if (!match) break;
        quoteLines.push(match[1]);
        i++;
      }
      blocks.push({ kind: 'quote', lines: quoteLines });
      continue;
    }

    const bulletHead = BULLET_RE.exec(line);
    const orderedHead = ORDERED_RE.exec(line);
    if (bulletHead || orderedHead) {
      const ordered = orderedHead !== null;
      const items: string[][] = [[(bulletHead ?? orderedHead)![1]]];
      i++;

      // 续行：没有列表标记但有缩进的行，接到上一个列表项后面。
      // 空行仍然结束列表——这是既有约定（下面的单测断言了这一条），不改。
      while (i < lines.length) {
        const raw = lines[i];
        const trimmed = raw.trim();
        if (trimmed === '') break;

        const sameKindHead = ordered ? ORDERED_RE.exec(trimmed) : BULLET_RE.exec(trimmed);
        if (sameKindHead) {
          items.push([sameKindHead[1]]);
          i++;
          continue;
        }
        // 撞上标题/分隔线/引用，或换了一种列表标记：当前列表到此为止
        if (isBlockBoundary(trimmed)) break;

        if (!/^\s+\S/.test(raw)) break; // 没有缩进，不算续行
        items[items.length - 1].push(trimmed);
        i++;
      }

      blocks.push({ kind: 'list', ordered, items });
      continue;
    }

    // 段落：连续的普通行合并成一段，直到空行或其他块级结构开始
    const paragraphLines = [line];
    i++;
    while (i < lines.length && !isBlockBoundary(lines[i].trim())) {
      paragraphLines.push(lines[i].trim());
      i++;
    }
    blocks.push({ kind: 'paragraph', lines: paragraphLines });
  }

  return blocks;
}

function renderBlock(block: Block): string {
  switch (block.kind) {
    case 'heading':
      // 标题一律降到 h4：弹窗里塞更大的标题会把版本号衬得像脚注
      return `<h4 class="owo-update-notes-heading">${renderInline(block.text)}</h4>`;
    case 'hr':
      return '<hr class="owo-update-notes-hr" />';
    case 'quote':
      return `<blockquote class="owo-update-notes-quote"><p>${block.lines
        .map(renderInline)
        .join('<br />')}</p></blockquote>`;
    case 'list': {
      const tag = block.ordered ? 'ol' : 'ul';
      const items = block.items
        .map((itemLines) => `<li>${itemLines.map(renderInline).join(' ')}</li>`)
        .join('');
      return `<${tag} class="owo-update-notes-list">${items}</${tag}>`;
    }
    case 'paragraph':
      return `<p class="owo-update-notes-text">${block.lines.map(renderInline).join('<br />')}</p>`;
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 行内解析：代码 / 加粗 / 斜体 / 删除线 / 链接
// ────────────────────────────────────────────────────────────────────────────

/**
 * 渲染行内标记，返回可以直接拼进 HTML 的字符串。
 *
 * 传入的是**原始**（未转义）文本——转义统一在这里做一次，调用方不需要
 * 自己转义。内部顺序是安全性的关键：
 *
 *   1. 先转义整段文本，后面所有正则都只在安全文本上跑；
 *   2. 代码优先摘出来存成占位符——CommonMark 里代码的优先级最高，
 *      `` `**not bold**` `` 应该原样显示，不能被下一步的加粗规则命中；
 *   3. 链接紧接着也摘成占位符：href 一旦定下来就不能再被后面的
 *      加粗/斜体正则扫到，否则 URL 里偶然出现的 `**` 会在属性值中间
 *      插入一个真标签，把 href 拆烂。label 部分允许带加粗/斜体，
 *      所以摘出来之前先跑一遍 `renderEmphasis`；
 *   4. 加粗/删除线/斜体在剩下的纯文本上跑，不会碰到已摘出的占位符；
 *   5. 最后把占位符换回真实标签——代码可能嵌在链接 label 里
 *      （占位符套占位符），所以这一步要循环到没有残留占位符为止。
 */
function renderInline(rawText: string): string {
  let text = escapeHtml(rawText);

  const stash: string[] = [];
  const store = (html: string): string => {
    stash.push(html);
    return `owoPh${stash.length - 1}phOwo`;
  };

  // 代码：内容原样（此时已转义过），不再参与后面任何规则
  text = text.replace(/`([^`]+)`/g, (_match, code: string) => store(`<code>${code}</code>`));

  // 链接：[文字](url)——协议不可信就只留文字，不生成 <a>
  text = text.replace(/\[([^[\]]+)\]\(([^)\s]+)\)/g, (_match, label: string, url: string) => {
    if (!/^https?:\/\//i.test(url)) return label;
    return store(
      `<a href="${url}" target="_blank" rel="noopener noreferrer">${renderEmphasis(label)}</a>`,
    );
  });

  text = renderEmphasis(text);

  // 还原占位符：占位符用纯 ASCII 记号（owoPh<序号>phOwo），代码可能嵌在
  // 链接 label 里（占位符套占位符），循环到没有残留为止（保底 4 轮足够）。
  // 循环条件用普通子串查找，不复用下面这个全局正则的 test()——
  // 全局正则的 lastIndex 是有状态的，混着 test()/replace() 交替调用
  // 容易埋雷，分开写更直白。
  const placeholderRe = /owoPh(\d+)phOwo/g;
  for (let round = 0; round < 4 && text.includes('owoPh'); round++) {
    text = text.replace(placeholderRe, (_match, index: string) => stash[Number(index)] ?? '');
  }

  return text;
}

/** 加粗 `**x**` / 删除线 `~~x~~` / 斜体 `*x*`——只认星号写法，理由见文件顶部说明 */
function renderEmphasis(text: string): string {
  text = text.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
  text = text.replace(/~~([^~]+)~~/g, '<del>$1</del>');
  text = text.replace(/\*([^\s*][^*]*?)\*/g, '<em>$1</em>');
  return text;
}
