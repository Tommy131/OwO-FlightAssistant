import { currentLanguageCode } from '../../../core/services/localization-service';

/**
 * 检查单内联中英文对照助手
 *
 * 对应 Flutter 版 A320/B737 检查单数据文件里的私有方法 `_l(zh, en)`：
 * 这两份数据的文案没有走 i18n key 表，而是把中英文直接内联在数据里，
 * 按当前语言取其一。非中文（含德语）统一取英文，与桌面版行为一致。
 */
export function l(zh: string, en: string): string {
  return currentLanguageCode() === 'zh_CN' ? zh : en;
}
