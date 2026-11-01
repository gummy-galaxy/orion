declare global {
  interface Window {
    /** When the desktop app launched, in milliseconds since the epoch, set by the shell before the page loads. */
    __ORION_LAUNCHED_AT__?: number
  }
}

/**
 * When the app launched, so startup counts the desktop shell's wait for its server too. Outside the desktop app it's
 * when the page started loading.
 */
export const getLaunchTime = (): number => window.__ORION_LAUNCHED_AT__ ?? performance.timeOrigin
