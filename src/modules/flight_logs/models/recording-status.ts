export type RecordingStatus = 'completed' | 'incomplete';

export type RecordingEndReason =
  | 'stable_landing'
  | 'touch_and_go'
  | 'user_stopped'
  | 'simulator_disconnected'
  | 'page_closed'
  | 'interrupted';

export function recordingStatusFromRaw(raw: unknown): RecordingStatus {
  return raw === 'incomplete' ? 'incomplete' : 'completed';
}

export function recordingEndReasonFromRaw(raw: unknown): RecordingEndReason | undefined {
  switch (raw) {
    case 'stable_landing':
    case 'touch_and_go':
    case 'user_stopped':
    case 'simulator_disconnected':
    case 'page_closed':
    case 'interrupted':
      return raw;
    default:
      return undefined;
  }
}
