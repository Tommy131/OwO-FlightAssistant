import { describe, expect, it } from 'vitest';

import {
  formatPlaceholders,
  type ModuleTranslations,
} from '../../../core/services/localization-service';
import { ChecklistLocalizationKeys, checklistTranslations } from '../../checklist/localization/checklist-localization';
import { EfbLocalizationKeys, efbTranslations } from '../../efb/localization/efb-localization';
import { CommonLocalizationKeys, commonModuleTranslations } from './common-localization';

/** 本项目实际提供译文的语言 */
const LOCALES = ['zh_CN', 'en_US'] as const;

function textOf(translations: ModuleTranslations, locale: (typeof LOCALES)[number], key: string) {
  return translations[locale]?.[key];
}

/**
 * 占位符风格一致性
 *
 * `formatPlaceholders` 用位置参数填 `{}`、用对象填 `{name}`。两者混用不会报错，
 * 只会让占位符**原样显示在界面上**（例如按钮上写着「当前：{mode}」）——
 * 这类错误 TypeScript 查不出来，只能靠测试盯。
 */

/** 带位置参数调用的 key：文案里必须是 `{}` 而不是 `{name}` */
const POSITIONAL_KEYS: { label: string; text: string | undefined }[] = LOCALES.flatMap(
  (locale) => [
    {
      label: `efb.lastUpdated[${locale}]`,
      text: textOf(efbTranslations, locale, EfbLocalizationKeys.lastUpdated),
    },
    {
      label: `checklist.templateVersion[${locale}]`,
      text: textOf(checklistTranslations, locale, ChecklistLocalizationKeys.templateVersion),
    },
    {
      label: `checklist.templateRegistration[${locale}]`,
      text: textOf(checklistTranslations, locale, ChecklistLocalizationKeys.templateRegistration),
    },
    {
      label: `checklist.templateSimulator[${locale}]`,
      text: textOf(checklistTranslations, locale, ChecklistLocalizationKeys.templateSimulator),
    },
    {
      label: `common.workflowTooltip[${locale}]`,
      text: textOf(commonModuleTranslations, locale, CommonLocalizationKeys.workflowTooltip),
    },
  ],
);

/** 带命名对象调用的 key：文案里必须是 `{name}` */
const NAMED_KEYS: { label: string; text: string | undefined; name: string }[] = LOCALES.map(
  (locale) => ({
    label: `common.appModeTooltip[${locale}]`,
    text: textOf(commonModuleTranslations, locale, CommonLocalizationKeys.appModeTooltip),
    name: 'mode',
  }),
);

describe('占位符风格', () => {
  it.each(POSITIONAL_KEYS)('$label 用位置占位符 {}', ({ text }) => {
    expect(text).toBeDefined();
    expect(text).toContain('{}');
    // 不能同时混进命名占位符
    expect(text).not.toMatch(/\{\w+\}/);
  });

  it.each(NAMED_KEYS)('$label 用命名占位符', ({ text, name }) => {
    expect(text).toBeDefined();
    expect(text).toContain(`{${name}}`);
  });

  it('位置参数确实能把 {} 填掉', () => {
    expect(formatPlaceholders('飞行任务流 {}/{}', [2, 4])).toBe('飞行任务流 2/4');
  });

  it('命名参数确实能把 {name} 填掉', () => {
    expect(formatPlaceholders('当前：{mode}', [{ mode: '复盘模式' }])).toBe('当前：复盘模式');
  });

  // 这正是要防的那个 bug：命名占位符收到位置参数会原样留在界面上
  it('风格不匹配时占位符会漏到界面上', () => {
    expect(formatPlaceholders('当前：{mode}', ['复盘模式'])).toBe('当前：{mode}');
  });
});
