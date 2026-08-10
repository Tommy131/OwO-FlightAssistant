import { describe, expect, it } from 'vitest';

import {
  type UpdateCheckResult,
  type UpdateProgress,
  type UpdateState,
  downloadPercent,
  escapeHtml,
  formatBytes,
  renderReleaseNotesHtml,
  resolveUpdateStatus,
  shouldPromptForUpdate,
} from './update-model';

function makeResult(overrides: Partial<UpdateCheckResult> = {}): UpdateCheckResult {
  return {
    available: true,
    current: '1.0.9-beta',
    latest: '1.1.0-beta',
    tag: 'v1.1.0-beta',
    releaseName: '1.1.0-beta',
    notes: '### 新增\n- 地形告警',
    htmlUrl: 'https://example.invalid/r/1',
    isPrerelease: true,
    canSelfInstall: true,
    ...overrides,
  };
}

function makeState(overrides: Partial<UpdateState> = {}): UpdateState {
  return { result: makeResult(), ignoredTag: '', ignored: false, checkFailed: false, ...overrides };
}

describe('resolveUpdateStatus', () => {
  it('检查中优先于一切', () => {
    expect(resolveUpdateStatus(makeState(), true)).toBe('checking');
    expect(resolveUpdateStatus(undefined, true)).toBe('checking');
  });

  it('没查过是 unknown', () => {
    expect(resolveUpdateStatus(undefined, false)).toBe('unknown');
    expect(resolveUpdateStatus(makeState({ result: undefined }), false)).toBe('unknown');
  });

  it('查失败是 failed', () => {
    expect(resolveUpdateStatus(makeState({ checkFailed: true }), false)).toBe('failed');
  });

  it('没有新版本是 upToDate', () => {
    expect(resolveUpdateStatus(makeState({ result: makeResult({ available: false }) }), false)).toBe(
      'upToDate',
    );
  });

  it('有新版本且没被忽略是 available', () => {
    expect(resolveUpdateStatus(makeState(), false)).toBe('available');
  });

  // 用户明确说过不想要这一版，设置页要如实说「已忽略」而不是继续催
  it('有新版本但被忽略是 ignored', () => {
    const state = makeState({ ignored: true, ignoredTag: 'v1.1.0-beta' });
    expect(resolveUpdateStatus(state, false)).toBe('ignored');
  });

  it('已忽略优先于可用', () => {
    const state = makeState({ ignored: true, ignoredTag: 'v1.1.0-beta' });
    expect(resolveUpdateStatus(state, false)).not.toBe('available');
  });

  // 查失败时不能因为手上还留着上一次的结果就报「有更新」
  it('查失败优先于旧结果', () => {
    const state = makeState({ checkFailed: true, result: makeResult({ available: true }) });
    expect(resolveUpdateStatus(state, false)).toBe('failed');
  });
});

describe('shouldPromptForUpdate', () => {
  it('有更新且没被忽略才弹', () => {
    expect(shouldPromptForUpdate(makeState())).toBe(true);
  });

  it('被忽略就不弹', () => {
    expect(shouldPromptForUpdate(makeState({ ignored: true }))).toBe(false);
  });

  it('没有更新不弹', () => {
    expect(shouldPromptForUpdate(makeState({ result: makeResult({ available: false }) }))).toBe(false);
  });

  it('查失败不弹', () => {
    expect(shouldPromptForUpdate(makeState({ checkFailed: true }))).toBe(false);
  });

  it('没查过不弹', () => {
    expect(shouldPromptForUpdate(undefined)).toBe(false);
    expect(shouldPromptForUpdate(makeState({ result: undefined }))).toBe(false);
  });

  // 忽略记的是 tag：再发新的一版仍然要弹，否则用户点一次「忽略」
  // 就等于从此再也收不到任何更新提示
  it('忽略的是那一版，新版本照弹', () => {
    const state = makeState({
      result: makeResult({ tag: 'v1.2.0', latest: '1.2.0' }),
      ignoredTag: 'v1.1.0-beta',
      ignored: false,
    });
    expect(shouldPromptForUpdate(state)).toBe(true);
  });
});

describe('escapeHtml', () => {
  it('转义全部五个危险字符', () => {
    expect(escapeHtml(`<>&"'`)).toBe('&lt;&gt;&amp;&quot;&#39;');
  });

  // & 必须最先转，否则 "<" 会先变成 "&lt;" 再被转成 "&amp;lt;"
  it('& 先于其它字符转义，不会二次转义', () => {
    expect(escapeHtml('a<b')).toBe('a&lt;b');
    expect(escapeHtml('&lt;')).toBe('&amp;lt;');
  });

  it('普通文本原样返回', () => {
    expect(escapeHtml('地形告警 1.0.9-beta')).toBe('地形告警 1.0.9-beta');
  });
});

describe('renderReleaseNotesHtml', () => {
  it('标题渲染成 h4', () => {
    expect(renderReleaseNotesHtml('### 新增')).toContain('<h4 class="owo-update-notes-heading">新增</h4>');
  });

  it('列表项渲染成 ul/li 并正确闭合', () => {
    const html = renderReleaseNotesHtml('- 甲\n- 乙');
    expect(html).toBe(
      '<ul class="owo-update-notes-list"><li>甲</li><li>乙</li></ul>',
    );
  });

  it('三种列表符号都认', () => {
    for (const marker of ['-', '*', '+']) {
      expect(renderReleaseNotesHtml(`${marker} 甲`)).toContain('<li>甲</li>');
    }
  });

  it('空行结束列表', () => {
    const html = renderReleaseNotesHtml('- 甲\n\n段落');
    expect(html).toBe(
      '<ul class="owo-update-notes-list"><li>甲</li></ul><p class="owo-update-notes-text">段落</p>',
    );
  });

  it('标题会打断列表', () => {
    const html = renderReleaseNotesHtml('- 甲\n### 修复');
    expect(html.indexOf('</ul>')).toBeLessThan(html.indexOf('<h4'));
  });

  it('结尾未闭合的列表也会闭合', () => {
    const html = renderReleaseNotesHtml('- 甲');
    expect(html.endsWith('</ul>')).toBe(true);
  });

  it('空输入不炸', () => {
    expect(renderReleaseNotesHtml('')).toBe('');
    expect(renderReleaseNotesHtml('\n\n\n')).toBe('');
  });

  it('CRLF 与 LF 结果一致', () => {
    expect(renderReleaseNotesHtml('### 甲\r\n- 乙')).toBe(renderReleaseNotesHtml('### 甲\n- 乙'));
  });

  /*
   * 安全性：发行说明是外部文本，任何有权发 release 的人都能往里写脚本，
   * 中间件地址还可以被改到别人的服务上。渲染必须先转义再包标签 ——
   * 下面每一条都是真实见过的 XSS 载荷形态。
   */
  describe('必须挡住注入', () => {
    const payloads = [
      '<script>alert(1)</script>',
      '<img src=x onerror=alert(1)>',
      '- <img src=x onerror=alert(1)>',
      '### <script>alert(1)</script>',
      '<iframe src="javascript:alert(1)"></iframe>',
      '<svg/onload=alert(1)>',
      '<a href="javascript:alert(1)">click</a>',
      '</p><script>alert(1)</script><p>',
    ];

    for (const payload of payloads) {
      it(`挡住 ${payload.slice(0, 34)}`, () => {
        const html = renderReleaseNotesHtml(payload);
        // 去掉我们自己包的那几个标签之后，**一个裸的尖括号都不该剩下**。
        //
        // 判据只看这一条，不去搜 "onerror=" 之类的子串：载荷被转义之后
        // `&lt;img src=x onerror=alert(1)&gt;` 里确实还留着 "onerror=" 这几个字，
        // 但它已经是纯文本，搜到了也只是误报。真正决定安不安全的是
        // 「浏览器会不会把它当标记解析」，也就是有没有裸的 `<`。
        const stripped = html.replace(
          /<\/?(h4|ul|li|p)(\s+class="owo-update-notes-[a-z]+")?>/g,
          '',
        );
        expect(stripped).not.toContain('<');
        expect(stripped).not.toContain('>');
        // 原文里的尖括号必须以实体的形式出现，说明确实被转义过而不是被丢掉了
        if (payload.includes('<')) expect(html).toContain('&lt;');
      });
    }
  });
});

describe('formatBytes', () => {
  it('按量级选单位', () => {
    expect(formatBytes(512)).toBe('512 B');
    expect(formatBytes(2048)).toBe('2 KB');
    expect(formatBytes(23266304)).toBe('22.2 MB');
    expect(formatBytes(3 * 1024 ** 3)).toBe('3.0 GB');
  });

  it('无效值给占位而不是 NaN', () => {
    expect(formatBytes(0)).toBe('--');
    expect(formatBytes(-1)).toBe('--');
    expect(formatBytes(Number.NaN)).toBe('--');
  });
});

describe('downloadPercent', () => {
  const base: UpdateProgress = { phase: 'downloading', downloadedBytes: 0, totalBytes: 0 };

  it('按比例算', () => {
    expect(downloadPercent({ ...base, downloadedBytes: 50, totalBytes: 200 })).toBe(25);
  });

  it('总大小未知时返回 undefined，界面该显示不确定进度', () => {
    expect(downloadPercent(base)).toBeUndefined();
  });

  it('夹在 0–100 之间', () => {
    expect(downloadPercent({ ...base, downloadedBytes: 300, totalBytes: 200 })).toBe(100);
    expect(downloadPercent({ ...base, downloadedBytes: -5, totalBytes: 200 })).toBe(0);
  });
});
