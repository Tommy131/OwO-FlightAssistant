/**
 * 航路气象剖面面板
 *
 * 只在导入了计划航路之后才有内容 —— 没有航路就没有「沿航线」可言。
 * 取数是懒的：面板挂上来才去问后端，没人看简报页时不该白打上游。
 */

import { useEffect } from 'react';
import { useTranslate } from '../../../../core/localization/use-translate';
import { Button } from '../../../../core/widgets/common/controls';
import { SectionCard } from '../../../../core/widgets/common/surfaces';
import { usePlannedRouteStore } from '../../../common/providers/planned-route-store';
import { BriefingLocalizationKeys as K } from '../../localization/briefing-localization';
import { useRouteProfileStore } from '../../providers/route-profile-store';
import { RouteProfileChart } from './route-profile-chart';
import styles from '../briefing-page.module.css';

export function RouteProfilePanel() {
  const t = useTranslate();
  const plan = usePlannedRouteStore((s) => s.plan);
  const profile = useRouteProfileStore((s) => s.profile);
  const isLoading = useRouteProfileStore((s) => s.isLoading);
  const errorKey = useRouteProfileStore((s) => s.errorKey);
  const load = useRouteProfileStore((s) => s.load);
  const clear = useRouteProfileStore((s) => s.clear);

  useEffect(() => {
    if (!plan) {
      clear();
      return;
    }
    void load(plan);
  }, [plan, load, clear]);

  return (
    <SectionCard
      title={t(K.profileTitle)}
      icon="air"
      subtitle={t(K.profileSubtitle)}
      trailing={
        <div className={styles.profileHeadActions}>
          {plan?.cruiseAltitudeFt !== undefined && (
            <span className={`${styles.profileCruiseBadge} text-mono`}>
              {t(K.profileCruise)} FL{Math.round(plan.cruiseAltitudeFt / 100)}
            </span>
          )}
          {plan && !isLoading && (
            <Button
              variant="text"
              size="sm"
              icon="refresh"
              onClick={() => {
                clear();
                void load(plan);
              }}
            >
              {t(K.profileRefresh)}
            </Button>
          )}
        </div>
      }
    >
      {!plan ? (
        <div className={styles.profileHint}>{t(K.profileNeedPlan)}</div>
      ) : isLoading ? (
        <div className={styles.profileHint}>{t(K.profileLoading)}</div>
      ) : errorKey || !profile ? (
        <div className={styles.profileHint}>{t(K.profileFailed)}</div>
      ) : (
        <RouteProfileChart samples={profile.samples} plan={plan} />
      )}
    </SectionCard>
  );
}
