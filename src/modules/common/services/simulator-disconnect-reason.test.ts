import { describe, expect, it } from 'vitest';

import { CommonLocalizationKeys as K } from '../localization/common-localization';
import { simulatorDisconnectReasonKey } from './simulator-disconnect-reason';

describe('simulatorDisconnectReasonKey', () => {
  it('maps known reason codes to i18n keys', () => {
    expect(simulatorDisconnectReasonKey('simconnect_lost')).toBe(K.simLostReasonSimconnectLost);
    expect(simulatorDisconnectReasonKey('no_packets')).toBe(K.simLostReasonNoPackets);
    expect(simulatorDisconnectReasonKey('session_expired')).toBe(K.simLostReasonSessionExpired);
  });

  it('falls back for empty or unknown codes', () => {
    expect(simulatorDisconnectReasonKey('')).toBe(K.simLostReasonUnknown);
    expect(simulatorDisconnectReasonKey(null)).toBe(K.simLostReasonUnknown);
    expect(simulatorDisconnectReasonKey('weird_new_code')).toBe(K.simLostReasonUnknown);
  });
});
