import { useState } from 'react';
import { HexColorPicker } from 'react-colorful';
import { LocalizationKeys } from '../localization/localization-keys';
import { useTranslate } from '../localization/use-translate';
import {
  presetThemes,
  THEME_MODES,
  ThemeMetrics,
  themeModeIcon,
  themeModeLocalizationKey,
  type AppThemeData,
} from '../theme/app-theme-data';
import { isSameTheme } from '../theme/app-theme-data';
import { useIsDarkMode, useThemeStore } from '../theme/theme-store';
import { Button, Slider, TextField } from '../widgets/common/controls';
import { MaterialIcon } from '../widgets/common/icon';
import { SnackBarHelper } from '../widgets/common/snack-bar';
import { SectionCard } from '../widgets/common/surfaces';
import styles from './settings-forms.module.css';

/**
 * 主题设置页
 *
 * 对应 Flutter 版 `core/settings_pages/theme_settings_page.dart`：
 * 主题模式、6 套预设配色、自定义取色器、明暗对比度调节、设计常量展示。
 */
export function ThemeSettingsPage() {
  const t = useTranslate();
  const isDark = useIsDarkMode();

  const themeMode = useThemeStore((s) => s.themeMode);
  const setThemeMode = useThemeStore((s) => s.setThemeMode);
  const currentTheme = useThemeStore((s) => s.currentTheme);
  const setTheme = useThemeStore((s) => s.setTheme);
  const createCustomTheme = useThemeStore((s) => s.createCustomTheme);
  const lightContrast = useThemeStore((s) => s.lightContrastAdjustment);
  const darkContrast = useThemeStore((s) => s.darkContrastAdjustment);
  const setLightContrast = useThemeStore((s) => s.setLightContrastAdjustment);
  const setDarkContrast = useThemeStore((s) => s.setDarkContrastAdjustment);
  const resetToDefault = useThemeStore((s) => s.resetToDefault);

  const [customColor, setCustomColor] = useState(currentTheme.primaryColor);
  const [customName, setCustomName] = useState('');

  const applyCustom = async () => {
    const name = customName.trim().length > 0 ? customName.trim() : t(LocalizationKeys.customTheme);
    await createCustomTheme(customColor, name);
    SnackBarHelper.showSuccess(t(LocalizationKeys.customThemeApplied));
  };

  return (
    <div className={styles.page}>
      {/* ── 主题模式 ── */}
      <SectionCard title={t(LocalizationKeys.switchThemeMode)} icon="brightness_6">
        <div className={styles.modeRow}>
          {THEME_MODES.map((mode) => (
            <button
              key={mode}
              type="button"
              onClick={() => void setThemeMode(mode)}
              className={`${styles.modeTile}${mode === themeMode ? ` ${styles.modeTileActive}` : ''}`}
            >
              <MaterialIcon name={themeModeIcon(mode)} size={22} filled={mode === themeMode} />
              {t(themeModeLocalizationKey(mode))}
            </button>
          ))}
        </div>
      </SectionCard>

      {/* ── 预设配色 ── */}
      <SectionCard
        title={t(LocalizationKeys.themeColors)}
        icon="palette"
        subtitle={t(LocalizationKeys.themeColorsDesc)}
        trailing={
          <Button variant="text" size="sm" icon="restart_alt" onClick={() => void resetToDefault()}>
            {t(LocalizationKeys.resetToDefault)}
          </Button>
        }
      >
        <div className={styles.themeGrid}>
          {presetThemes.map((theme) => (
            <ThemeSwatch
              key={theme.name}
              theme={theme}
              selected={isSameTheme(theme, currentTheme)}
              label={theme.localizationKey ? t(theme.localizationKey) : theme.name}
              onSelect={() => {
                void setTheme(theme);
                SnackBarHelper.showSuccess(
                  t(
                    LocalizationKeys.themeChangedTo,
                    theme.localizationKey ? t(theme.localizationKey) : theme.name,
                  ),
                );
              }}
            />
          ))}
        </div>
      </SectionCard>

      {/* ── 自定义配色 ── */}
      <SectionCard
        title={t(LocalizationKeys.customTheme)}
        icon="colorize"
        subtitle={t(LocalizationKeys.customThemeDesc)}
      >
        <div className={styles.customRow}>
          <div className={styles.pickerWrap}>
            <HexColorPicker color={customColor} onChange={setCustomColor} />
          </div>

          <div className={styles.customForm}>
            <TextField
              value={customName}
              onChange={setCustomName}
              label={t(LocalizationKeys.themeName)}
              placeholder={t(LocalizationKeys.customTheme)}
            />
            <TextField
              value={customColor}
              onChange={setCustomColor}
              label={t(LocalizationKeys.customThemeColor)}
              monospace
              icon="tag"
            />
            {/* 预览：次色与强调色由主色按 0.7 / 0.5 透明度派生，与桌面版一致 */}
            <div className={styles.previewRow}>
              <span className={styles.previewSwatch} style={{ background: customColor }} />
              <span className={styles.previewLabel}>{t(LocalizationKeys.currentCustomTheme)}</span>
            </div>
            <Button variant="elevated" icon="check" onClick={() => void applyCustom()}>
              {t(LocalizationKeys.createCustomTheme)}
            </Button>
          </div>
        </div>
      </SectionCard>

      {/* ── 对比度调节 ── */}
      <SectionCard title={t(LocalizationKeys.contrastAdjustment)} icon="contrast">
        <div className={styles.settingBlock}>
          <div className={styles.settingText}>
            <span className={styles.settingLabel}>{t(LocalizationKeys.darkModeEnhanced)}</span>
            <span className={styles.settingHint}>{t(LocalizationKeys.darkContrastDesc)}</span>
          </div>
          <Slider
            value={darkContrast}
            min={0}
            max={1}
            step={0.05}
            label={t(LocalizationKeys.darkModeEnhanced)}
            formatValue={(value) =>
              value === 0 ? t(LocalizationKeys.defaultLabel) : `${Math.round(value * 100)}%`
            }
            onChange={(value) => void setDarkContrast(value)}
          />
          <span className={styles.rangeHint}>
            {t(LocalizationKeys.defaultLabel)} → {t(LocalizationKeys.extremeDark)}
          </span>
        </div>

        <div className={styles.settingBlock}>
          <div className={styles.settingText}>
            <span className={styles.settingLabel}>{t(LocalizationKeys.lightModePurified)}</span>
            <span className={styles.settingHint}>{t(LocalizationKeys.lightContrastDesc)}</span>
          </div>
          <Slider
            value={lightContrast}
            min={0}
            max={1}
            step={0.05}
            label={t(LocalizationKeys.lightModePurified)}
            formatValue={(value) =>
              value === 0 ? t(LocalizationKeys.defaultLabel) : `${Math.round(value * 100)}%`
            }
            onChange={(value) => void setLightContrast(value)}
          />
          <span className={styles.rangeHint}>
            {t(LocalizationKeys.defaultLabel)} → {t(LocalizationKeys.pureLight)}
          </span>
        </div>

        <span className={styles.activeModeHint}>
          <MaterialIcon name="info" size={14} />
          {isDark ? t(LocalizationKeys.themeModeDark) : t(LocalizationKeys.themeModeLight)}
        </span>
      </SectionCard>

      {/* ── 设计常量 ── */}
      <SectionCard title={t(LocalizationKeys.designConstants)} icon="straighten">
        <div className={styles.constantGrid}>
          {[
            ['Radius', `${ThemeMetrics.borderRadiusSmall} / ${ThemeMetrics.borderRadiusMedium} / ${ThemeMetrics.borderRadiusLarge}`],
            ['Spacing', `${ThemeMetrics.spacingSmall} / ${ThemeMetrics.spacingMedium} / ${ThemeMetrics.spacingLarge} / ${ThemeMetrics.spacingXLarge}`],
            ['Sidebar', `${ThemeMetrics.sidebarExpandedWidth} ↔ ${ThemeMetrics.sidebarCollapsedWidth}`],
            ['Animation', `${ThemeMetrics.animationDuration}ms`],
          ].map(([label, value]) => (
            <div key={label} className={styles.constantRow}>
              <span className={styles.constantLabel}>{label}</span>
              <span className={`${styles.constantValue} text-mono`}>{value}</span>
            </div>
          ))}
        </div>
      </SectionCard>
    </div>
  );
}

function ThemeSwatch({
  theme,
  selected,
  label,
  onSelect,
}: {
  theme: AppThemeData;
  selected: boolean;
  label: string;
  onSelect: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onSelect}
      className={`${styles.themeTile}${selected ? ` ${styles.themeTileSelected}` : ''}`}
    >
      <span className={styles.swatchRow}>
        <span className={styles.swatch} style={{ background: theme.primaryColor }} />
        <span className={styles.swatchSmall} style={{ background: theme.secondaryColor }} />
        <span className={styles.swatchSmall} style={{ background: theme.accentColor }} />
      </span>
      <span className={styles.themeName}>{label}</span>
      {selected && (
        <MaterialIcon name="check_circle" filled size={16} color="var(--color-primary)" />
      )}
    </button>
  );
}
