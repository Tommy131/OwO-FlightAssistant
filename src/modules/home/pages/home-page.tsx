import { useEffect, useRef, useState } from 'react';
import { useTranslate } from '../../../core/localization/use-translate';
import { NavigationCommandBus } from '../../../core/module-registry/navigation/navigation-registry';
import { Button } from '../../../core/widgets/common/controls';
import { showAdvancedConfirmDialog } from '../../../core/widgets/common/dialog';
import { MaterialIcon } from '../../../core/widgets/common/icon';
import { CommonLocalizationKeys } from '../../common/localization/common-localization';
import { useFlightDataStore } from '../../common/providers/flight-data-store';
import { HomeLocalizationKeys as K } from '../localization/home-localization';
import { FlightDataDashboard } from './widgets/flight-data-dashboard';
import {
  ChecklistPhaseCard,
  FlightNumberCard,
  SimulatorConnectionCard,
  WelcomeCard,
} from './widgets/home-cards';
import styles from './home-page.module.css';

/**
 * 首页
 *
 * 对应 Flutter 版 `modules/home/pages/home_page.dart`。
 * 负责整体布局编排与后端离线遮罩的显示逻辑，
 * 各卡片与面板拆分在 widgets/ 下。
 */
export function HomePage() {
  const t = useTranslate();
  const snapshot = useFlightDataStore((s) => s.snapshot);
  const refreshBackendHealth = useFlightDataStore((s) => s.refreshBackendHealth);

  /** 遮罩是否留在树中 */
  const [showGlassMask, setShowGlassMask] = useState(true);
  /** 遮罩是否展示帮助卡片 */
  const [showConnectionHelpCard, setShowConnectionHelpCard] = useState(false);
  /** 遮罩当前透明度（0 不可见，1 完全显示） */
  const [glassMaskOpacity, setGlassMaskOpacity] = useState(1);
  const [isRetryingBackend, setIsRetryingBackend] = useState(false);

  /** 后端是否持续不可达 */
  const stickyBackendUnavailable = useRef(false);
  /** 已处理的后端中断版本号，防止重复弹窗 */
  const handledOutageVersion = useRef(snapshot.backendOutageVersion);
  const backendDialogVisible = useRef(false);

  const checkBackendAvailability = async (showDialogWhenUnavailable: boolean) => {
    if (isRetryingBackend) return;
    setIsRetryingBackend(true);
    const reachable = await refreshBackendHealth();

    if (reachable) {
      stickyBackendUnavailable.current = false;
      setShowGlassMask(true);
      setShowConnectionHelpCard(false);
      setGlassMaskOpacity(0);
    } else {
      stickyBackendUnavailable.current = true;
      setShowGlassMask(true);
      setShowConnectionHelpCard(true);
      setGlassMaskOpacity(1);
    }
    setIsRetryingBackend(false);

    if (!reachable && showDialogWhenUnavailable) await showBackendUnavailableDialog();
  };

  const showBackendUnavailableDialog = async () => {
    if (backendDialogVisible.current) return;
    backendDialogVisible.current = true;
    const shouldOpenSettings = await showAdvancedConfirmDialog({
      title: t(CommonLocalizationKeys.backendUnavailableTitle),
      content: t(CommonLocalizationKeys.backendUnavailableContent),
      icon: 'cloud_off',
      confirmText: t(CommonLocalizationKeys.goToSettings),
      cancelText: t(K.flightNumberDialogCancel),
    });
    backendDialogVisible.current = false;
    if (shouldOpenSettings === true) NavigationCommandBus.goTo('settings');
  };

  // 首帧探测一次后端可达性
  useEffect(() => {
    void checkBackendAvailability(false);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // 后端中断事件：版本号递增即视为一次新的中断
  useEffect(() => {
    if (snapshot.isBackendReachable) {
      handledOutageVersion.current = snapshot.backendOutageVersion;
      return;
    }
    if (snapshot.backendOutageVersion <= handledOutageVersion.current) return;
    handledOutageVersion.current = snapshot.backendOutageVersion;
    stickyBackendUnavailable.current = true;
    setShowGlassMask(true);
    setShowConnectionHelpCard(true);
    setGlassMaskOpacity(1);
    void showBackendUnavailableDialog();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [snapshot.backendOutageVersion, snapshot.isBackendReachable]);

  // 模拟器已连接时自动隐藏遮罩
  useEffect(() => {
    if (!snapshot.isConnected) return;
    stickyBackendUnavailable.current = false;
    setShowConnectionHelpCard(false);
    setGlassMaskOpacity(0);
    setShowGlassMask(false);
  }, [snapshot.isConnected]);

  const shouldBlockInteraction = showConnectionHelpCard || glassMaskOpacity > 0.01;

  return (
    <div className={styles.page}>
      <div className={`${styles.scroll} scroll-area`}>
        <div className={styles.content}>
          <WelcomeCard />
          <FlightNumberCard />
          <div className={styles.statusRow}>
            <SimulatorConnectionCard />
            <ChecklistPhaseCard />
          </div>
          <FlightDataDashboard />
        </div>
      </div>

      {showGlassMask && (
        <BackendOfflineMask
          opacity={glassMaskOpacity}
          showHelpCard={showConnectionHelpCard}
          isRetrying={isRetryingBackend}
          blockPointer={shouldBlockInteraction}
          onRetry={() => void checkBackendAvailability(true)}
          onFadeEnd={() => {
            if (glassMaskOpacity === 0 && !showConnectionHelpCard) setShowGlassMask(false);
          }}
        />
      )}
    </div>
  );
}

/**
 * 后端离线毛玻璃遮罩
 * 对应 Flutter 版 `modules/home/pages/widgets/mask/backend_offline_mask.dart`
 */
function BackendOfflineMask({
  opacity,
  showHelpCard,
  isRetrying,
  blockPointer,
  onRetry,
  onFadeEnd,
}: {
  opacity: number;
  showHelpCard: boolean;
  isRetrying: boolean;
  blockPointer: boolean;
  onRetry: () => void;
  onFadeEnd: () => void;
}) {
  const t = useTranslate();

  return (
    <div
      className={styles.mask}
      style={{ opacity, pointerEvents: blockPointer ? 'auto' : 'none' }}
      onTransitionEnd={onFadeEnd}
      aria-hidden={!blockPointer}
    >
      {showHelpCard && (
        <div className={styles.maskCard}>
          <MaterialIcon name="cloud_off" size={40} color="var(--color-error)" />
          <h2 className={styles.maskTitle}>{t(K.homeMaskConnectBackendTitle)}</h2>
          <p className={styles.maskSubtitle}>{t(K.homeMaskConnectBackendSubtitle)}</p>
          <div className={styles.maskActions}>
            <Button
              variant="elevated"
              icon="refresh"
              loading={isRetrying}
              onClick={onRetry}
            >
              {isRetrying ? t(K.homeMaskRetryingButton) : t(K.homeMaskRetryButton)}
            </Button>
            <Button
              variant="outlined"
              icon="settings"
              onClick={() => NavigationCommandBus.goTo('settings')}
            >
              {t(CommonLocalizationKeys.goToSettings)}
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}
