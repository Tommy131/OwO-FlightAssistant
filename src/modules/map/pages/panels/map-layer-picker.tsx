/**
 * 底图样式选择器
 */

import { useTranslate } from '../../../../core/localization/use-translate';
import { MaterialIcon } from '../../../../core/widgets/common/icon';
import { MapLocalizationKeys as K } from '../../localization/map-localization';
import {
  MAP_LAYER_STYLES,
  type MapLayerStyle,
} from '../../models/map-models';
import { useMapStore } from '../../providers/map-store';
import styles from '../map-page.module.css';

// ──────────────────────────────────────────────────────────────────────────
// 图层选择器
// ──────────────────────────────────────────────────────────────────────────

const LAYER_LABEL_KEY: Record<MapLayerStyle, string> = {
  dark: K.layerDark,
  satellite: K.layerSatellite,
  terrain: K.layerTerrain,
  taxiway: K.layerTaxiway,
};

const LAYER_ICON: Record<MapLayerStyle, string> = {
  dark: 'dark_mode',
  satellite: 'satellite_alt',
  terrain: 'terrain',
  taxiway: 'map',
};

export function MapLayerPicker({ onClose }: { onClose: () => void }) {
  const t = useTranslate();
  const layerStyle = useMapStore((s) => s.layerStyle);
  const setLayerStyle = useMapStore((s) => s.setLayerStyle);

  return (
    <div className={styles.pickerScrim} onClick={onClose} role="presentation">
      <div className={styles.pickerCard} onClick={(event) => event.stopPropagation()}>
        <div className={styles.pickerHead}>
          <MaterialIcon name="layers" size={17} color="var(--color-primary)" />
          <span>{t(K.layerTitle)}</span>
        </div>
        <div className={styles.pickerGrid}>
          {MAP_LAYER_STYLES.map((style) => (
            <button
              key={style}
              type="button"
              className={`${styles.pickerItem}${style === layerStyle ? ` ${styles.pickerItemActive}` : ''}`}
              onClick={() => {
                void setLayerStyle(style);
                onClose();
              }}
            >
              <MaterialIcon name={LAYER_ICON[style]} size={22} filled={style === layerStyle} />
              {t(LAYER_LABEL_KEY[style])}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
