import { AppConstants, fullVersionString } from '../constants/app-constants';
import { LocalizationKeys } from '../localization/localization-keys';
import { useTranslate } from '../localization/use-translate';
import { ModuleRegistry } from '../module-registry/module-registry';
import { MaterialIcon } from '../widgets/common/icon';
import { SectionCard } from '../widgets/common/surfaces';
import styles from './settings-forms.module.css';

/**
 * 关于页
 *
 * 对应 Flutter 版 `core/settings_pages/about_page.dart`：
 * 应用信息、开发者信息、社区链接、开源许可，
 * 外加模块通过 AboutPageRegistry 注册的自定义区块。
 */
export function AboutPage() {
  const t = useTranslate();
  const moduleItems = ModuleRegistry.aboutPages.getAllItems();

  const infoRows: [string, string][] = [
    [t(LocalizationKeys.appNameLabel), AppConstants.appName],
    [t(LocalizationKeys.packageNameLabel), AppConstants.appPackageName],
    [t(LocalizationKeys.versionLabel), fullVersionString()],
  ];

  const developerRows: [string, string][] = [
    [t(LocalizationKeys.developerLabel), AppConstants.developerName],
    [t(LocalizationKeys.emailLabel), AppConstants.developerEmail],
  ];

  const links: { icon: string; label: string; url: string }[] = [
    {
      icon: 'code',
      label: t(LocalizationKeys.projectSourceCode),
      url: AppConstants.githubRepoUrl,
    },
    {
      icon: 'forum',
      label: t(LocalizationKeys.joinDiscord),
      url: AppConstants.discordInviteUrl,
    },
    { icon: 'send', label: 'Telegram', url: AppConstants.telegramUrl },
    { icon: 'volunteer_activism', label: 'Donation', url: AppConstants.donationUrl },
  ];

  return (
    <div className={styles.page}>
      <div className={styles.aboutHeader}>
        <img src={AppConstants.assetIconPath} alt="" className={styles.aboutLogo} />
        <div className={styles.aboutTitles}>
          <h2 className={styles.aboutName}>{AppConstants.appName}</h2>
          <span className={styles.aboutVersion}>v{fullVersionString()}</span>
        </div>
      </div>

      <SectionCard title={t(LocalizationKeys.appInfo)} icon="info">
        <InfoRows rows={infoRows} />
      </SectionCard>

      <SectionCard title={t(LocalizationKeys.developerInfo)} icon="person">
        <InfoRows rows={developerRows} />
      </SectionCard>

      <SectionCard title={t(LocalizationKeys.community)} icon="public">
        <div className={styles.linkGrid}>
          {links.map((link) => (
            <a
              key={link.url}
              href={link.url}
              target="_blank"
              rel="noopener noreferrer"
              className={styles.linkTile}
            >
              <MaterialIcon name={link.icon} size={19} color="var(--color-primary)" />
              <span className={styles.linkLabel}>{link.label}</span>
              <MaterialIcon name="open_in_new" size={14} color="var(--color-text-secondary)" />
            </a>
          ))}
        </div>
      </SectionCard>

      <SectionCard title={t(LocalizationKeys.openSourceLicense)} icon="gavel">
        <InfoRows rows={[[t(LocalizationKeys.licenseLabel), AppConstants.license]]} />
        <p className={styles.copyright}>{AppConstants.copyright}</p>
        <p className={styles.disclaimer}>
          本项目仅用于模拟飞行训练、学习与研究，请勿用于真实飞行操作。
        </p>
      </SectionCard>

      {/* 模块注册的自定义区块 */}
      {moduleItems.map((item) => (
        <div key={item.id}>{item.render()}</div>
      ))}
    </div>
  );
}

function InfoRows({ rows }: { rows: [string, string][] }) {
  return (
    <dl className={styles.infoList}>
      {rows.map(([label, value]) => (
        <div key={label} className={styles.infoRow}>
          <dt className={styles.infoLabel}>{label}</dt>
          <dd className={`${styles.infoValue} text-mono`}>{value}</dd>
        </div>
      ))}
    </dl>
  );
}
