export interface RecordingUnloadGuardDependencies {
  flightActive: () => boolean;
  landingActive: () => boolean;
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
  flush,
}: RecordingUnloadGuardDependencies): () => void {
  const onBeforeUnload = (event: BeforeUnloadEvent): void => {
    if (!flightActive() && !landingActive()) return;

    void flush();
    event.preventDefault();
    event.returnValue = '';
  };

  window.addEventListener('beforeunload', onBeforeUnload);
  return () => window.removeEventListener('beforeunload', onBeforeUnload);
}
