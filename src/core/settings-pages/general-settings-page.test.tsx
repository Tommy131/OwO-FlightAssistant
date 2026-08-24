// @vitest-environment jsdom

import { fireEvent, render, screen } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import {
  setAutomaticLandingReportsSettings,
  type AutomaticLandingReportsSettings,
} from '../services/automatic-landing-reports-settings';
import { useLocalizationStore } from '../services/localization-service';
import { GeneralSettingsPage } from './general-settings-page';

describe('GeneralSettingsPage automatic landing reports setting', () => {
  let setEnabled: (enabled: boolean) => Promise<void>;

  beforeEach(() => {
    vi.stubGlobal(
      'ResizeObserver',
      class {
        observe() {}
        unobserve() {}
        disconnect() {}
      },
    );
    useLocalizationStore.setState({ locale: 'en_US' });
    setEnabled = vi.fn().mockResolvedValue(undefined);
    setAutomaticLandingReportsSettings(enabledSettingsAdapter(setEnabled));
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    setAutomaticLandingReportsSettings(null);
  });

  it('shows automatic landing reports enabled by default and persists changes', () => {
    render(<GeneralSettingsPage />);

    const toggle = screen.getByRole('switch', {
      name: /automatically record landing reports/i,
    });
    expect(toggle).toBeChecked();
    expect(
      screen.getByText(
        /only while this web app is open.*separate from manual flight-log recording/i,
      ),
    ).toBeInTheDocument();

    fireEvent.click(toggle);

    expect(setEnabled).toHaveBeenCalledWith(false);
  });

  it('uses the Chinese automatic landing reports label and description', () => {
    useLocalizationStore.setState({ locale: 'zh_CN' });

    render(<GeneralSettingsPage />);

    expect(
      screen.getByRole('switch', { name: '自动生成落地报告' }),
    ).toBeChecked();
    expect(
      screen.getByText('仅在此 Web 应用保持打开时自动收集落地报告，且与手动飞行日志记录相互独立。'),
    ).toBeInTheDocument();
  });
});

function enabledSettingsAdapter(
  setEnabled: (enabled: boolean) => Promise<void>,
): AutomaticLandingReportsSettings {
  return {
    getEnabled: () => true,
    setEnabled,
    subscribe: () => () => {},
  };
}
