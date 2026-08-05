import { useState } from 'react';
import { LocalizationKeys } from '../localization/localization-keys';
import { useTranslate } from '../localization/use-translate';
import { ModuleRegistry } from '../module-registry/module-registry';
import { useWindowWidth } from '../layouts/responsive';
import { MaterialIcon } from '../widgets/common/icon';
import { AboutPage } from './about-page';
import { GeneralSettingsPage } from './general-settings-page';
import { ThemeSettingsPage } from './theme-settings-page';
import styles from './settings-page.module.css';

/**
 * 设置页壳层
 *
 * 对应 Flutter 版 `core/settings_pages/settings_page.dart`：
 * 左侧分类导航（内置三项 + 模块通过 SettingsPageRegistry 注册的项），右侧内容区。
 */

interface SettingsEntry {
  id: string;
  icon: string;
  title: string;
  description?: string;
  render: () => React.ReactNode;
}

export function SettingsPage() {
  const t = useTranslate();
  const width = useWindowWidth();
  const isCompact = width < 900;

  // 内置分类
  const builtinEntries: SettingsEntry[] = [
    {
      id: 'general',
      icon: 'tune',
      title: t(LocalizationKeys.generalSettings),
      description: t(LocalizationKeys.storageLocationDesc),
      render: () => <GeneralSettingsPage />,
    },
    {
      id: 'theme',
      icon: 'palette',
      title: t(LocalizationKeys.themeSettings),
      description: t(LocalizationKeys.themeSettingsDesc),
      render: () => <ThemeSettingsPage />,
    },
  ];

  // 模块注册的设置页（http / map …）
  const moduleEntries: SettingsEntry[] = ModuleRegistry.settingsPages
    .getAllPages()
    .map((page) => ({
      id: page.id,
      icon: page.icon,
      title: page.getTitle(),
      description: page.getDescription?.() ?? undefined,
      render: () => page.render(),
    }));

  const aboutEntry: SettingsEntry = {
    id: 'about',
    icon: 'info',
    title: t(LocalizationKeys.aboutApp),
    description: t(LocalizationKeys.aboutAppDesc),
    render: () => <AboutPage />,
  };

  const entries = [...builtinEntries, ...moduleEntries, aboutEntry];
  const [selectedId, setSelectedId] = useState(entries[0]?.id ?? 'general');
  const selected = entries.find((entry) => entry.id === selectedId) ?? entries[0];

  // 窄屏：先显示分类列表，选中后进入详情
  const [showDetailOnCompact, setShowDetailOnCompact] = useState(false);
  const showList = !isCompact || !showDetailOnCompact;
  const showDetail = !isCompact || showDetailOnCompact;

  return (
    <div className={`${styles.page}${isCompact ? ` ${styles.pageCompact}` : ''}`}>
      {showList && (
        <nav className={`${styles.sidebar} scroll-area`} aria-label={t(LocalizationKeys.settings)}>
          {entries.map((entry) => (
            <button
              key={entry.id}
              type="button"
              onClick={() => {
                setSelectedId(entry.id);
                setShowDetailOnCompact(true);
              }}
              aria-current={entry.id === selectedId ? 'true' : undefined}
              className={`${styles.navItem}${
                entry.id === selectedId && !isCompact ? ` ${styles.navItemSelected}` : ''
              }`}
            >
              <MaterialIcon
                name={entry.icon}
                size={19}
                filled={entry.id === selectedId}
                color={entry.id === selectedId ? 'var(--color-primary)' : undefined}
              />
              <span className={styles.navText}>
                <span className={styles.navTitle}>{entry.title}</span>
                {entry.description && (
                  <span className={styles.navDescription}>{entry.description}</span>
                )}
              </span>
              {isCompact && <MaterialIcon name="chevron_right" size={17} />}
            </button>
          ))}
        </nav>
      )}

      {showDetail && selected && (
        <div className={`${styles.content} scroll-area`}>
          {isCompact && (
            <button
              type="button"
              className={styles.backButton}
              onClick={() => setShowDetailOnCompact(false)}
            >
              <MaterialIcon name="arrow_back" size={17} />
              {t(LocalizationKeys.back)}
            </button>
          )}
          <div className={styles.contentInner}>{selected.render()}</div>
        </div>
      )}
    </div>
  );
}
