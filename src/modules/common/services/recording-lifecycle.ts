export interface RecordingUnloadGuardDependencies {
  flightActive: () => boolean;
  landingActive: () => boolean;
  subscribeFlightActive: (listener: () => void) => () => void;
  subscribeLandingActive: (listener: () => void) => () => void;
  flush: () => Promise<unknown>;
}

/**
 * Protects active durable recordings with the browser's native close prompt.
 *
 * Active archives are kept current during recording. The unload flush can only
 * be best-effort because browsers do not wait for asynchronous work here, and
 * browsers own the confirmation dialog text.
 */
export function installRecordingUnloadGuard({
  flightActive,
  landingActive,
  subscribeFlightActive,
  subscribeLandingActive,
  flush,
}: RecordingUnloadGuardDependencies): () => void {
  let listenerInstalled = false;
  const onBeforeUnload = (event: BeforeUnloadEvent): void => {
    if (!flightActive() && !landingActive()) return;

    void flush();
    event.preventDefault();
    event.returnValue = '';
  };

  const updateListener = (): void => {
    const active = flightActive() || landingActive();
    if (active && !listenerInstalled) {
      window.addEventListener('beforeunload', onBeforeUnload);
      listenerInstalled = true;
    } else if (!active && listenerInstalled) {
      window.removeEventListener('beforeunload', onBeforeUnload);
      listenerInstalled = false;
    }
  };

  const unsubscribeFlight = subscribeFlightActive(updateListener);
  const unsubscribeLanding = subscribeLandingActive(updateListener);
  updateListener();

  return () => {
    unsubscribeFlight();
    unsubscribeLanding();
    if (listenerInstalled) window.removeEventListener('beforeunload', onBeforeUnload);
  };
}
