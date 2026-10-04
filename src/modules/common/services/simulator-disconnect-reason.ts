import { CommonLocalizationKeys as K } from '../localization/common-localization';

/**
 * 把中间件下发的 disconnect_reason 映射成 i18n key。
 * 原因码是稳定的机器标识；展示文案一律走翻译表。
 */
const REASON_KEYS: Record<string, string> = {
  session_expired: K.simLostReasonSessionExpired,
  invalid_token: K.simLostReasonInvalidToken,
  service_stopped: K.simLostReasonServiceStopped,
  no_packets: K.simLostReasonNoPackets,
  no_packets_ever: K.simLostReasonNoPacketsEver,
  simulator_quit: K.simLostReasonSimulatorQuit,
  simconnect_lost: K.simLostReasonSimconnectLost,
  simconnect_error: K.simLostReasonSimconnectError,
  link_timeout: K.simLostReasonLinkTimeout,
  ws_closed: K.simLostReasonWsClosed,
  unknown: K.simLostReasonUnknown,
};

export function simulatorDisconnectReasonKey(reason?: string | null): string {
  const normalized = (reason ?? '').trim().toLowerCase();
  if (normalized.length === 0) return K.simLostReasonUnknown;
  return REASON_KEYS[normalized] ?? K.simLostReasonUnknown;
}
