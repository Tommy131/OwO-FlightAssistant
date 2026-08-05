import { useMemo, useState } from 'react';
import { useTranslate } from '../../../../core/localization/use-translate';
import { Select, TextField } from '../../../../core/widgets/common/controls';
import { EmptyState, SectionCard } from '../../../../core/widgets/common/surfaces';
import { aviationTerms } from '../../data/aviation-terms';
import { unitConversionOptions } from '../../data/unit-conversion-options';
import { ToolboxLocalizationKeys as K } from '../../localization/toolbox-localization';
import styles from './toolbox-tabs.module.css';

/**
 * 单位换算 与 术语翻译 两个 tab
 *
 * 对应 Flutter 版 `unit_conversion_tab.dart` 与 `terms_translation_tab.dart`。
 */

// ──────────────────────────────────────────────────────────────────────────
// 单位换算
// ──────────────────────────────────────────────────────────────────────────

export function UnitConversionTab() {
  const t = useTranslate();
  const [optionIndex, setOptionIndex] = useState(0);
  const [input, setInput] = useState('');

  const option = unitConversionOptions[optionIndex];
  const parsed = Number.parseFloat(input.trim());
  const hasValue = input.trim().length > 0;
  const isValid = hasValue && Number.isFinite(parsed);
  const converted = isValid ? option.converter(parsed) : null;

  return (
    <div className={styles.tab}>
      <SectionCard title={t(K.unitSectionTitle)} icon="swap_horiz">
        <div className={styles.formGrid}>
          <Select
            value={String(optionIndex)}
            options={unitConversionOptions.map((item, index) => ({
              value: String(index),
              label: t(item.labelKey),
            }))}
            onChange={(value) => setOptionIndex(Number.parseInt(value, 10))}
            label={t(K.unitSectionTitle)}
            icon="calculate"
          />
          <TextField
            value={input}
            onChange={setInput}
            label={t(K.commonInputHint)}
            type="number"
            monospace
            error={hasValue && !isValid ? t(K.commonInvalidNumber) : undefined}
          />
        </div>

        <div className={styles.conversionResult}>
          <span className={`${styles.conversionValue} text-mono`}>
            {converted === null ? '--' : formatConverted(converted)}
          </span>
          <span className={styles.conversionUnit}>{option.resultUnit}</span>
        </div>
      </SectionCard>
    </div>
  );
}

/** 结果保留 4 位有效小数并去掉末尾多余的 0 */
function formatConverted(value: number): string {
  const text = Math.abs(value) >= 1000 ? value.toFixed(2) : value.toFixed(4);
  return text.replace(/\.?0+$/, '');
}

// ──────────────────────────────────────────────────────────────────────────
// 术语翻译
// ──────────────────────────────────────────────────────────────────────────

export function TermsTranslationTab() {
  const t = useTranslate();
  const [keyword, setKeyword] = useState('');

  const filtered = useMemo(() => {
    const query = keyword.trim().toLowerCase();
    if (query.length === 0) return aviationTerms;
    return aviationTerms.filter(
      (term) =>
        term.abbreviation.toLowerCase().includes(query) ||
        term.fullName.toLowerCase().includes(query) ||
        term.chineseName.includes(keyword.trim()) ||
        (term.description ?? '').includes(keyword.trim()),
    );
  }, [keyword]);

  return (
    <div className={styles.tab}>
      <SectionCard
        title={t(K.termsSectionTitle)}
        icon="translate"
        trailing={<span className={styles.countBadge}>{filtered.length}</span>}
      >
        <TextField
          value={keyword}
          onChange={setKeyword}
          label={t(K.termsSearchLabel)}
          placeholder={t(K.termsSearchHint)}
          icon="search"
          type="search"
        />

        {filtered.length === 0 ? (
          <EmptyState icon="search_off" title={t(K.termsNotFound)} />
        ) : (
          <div className={styles.termList}>
            {filtered.map((term) => (
              <div key={term.abbreviation} className={styles.termCard}>
                <div className={styles.termHead}>
                  <span className={`${styles.termAbbr} text-mono`}>{term.abbreviation}</span>
                  <span className={styles.termChinese}>{term.chineseName}</span>
                </div>
                <span className={styles.termFullName}>{term.fullName}</span>
                {term.description && (
                  <p className={styles.termDescription}>{term.description}</p>
                )}
              </div>
            ))}
          </div>
        )}
      </SectionCard>
    </div>
  );
}
