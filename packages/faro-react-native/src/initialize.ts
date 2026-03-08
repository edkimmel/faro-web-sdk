import { FaroReactNativeApi } from './api/FaroReactNativeApi';
import { makeNativeConfig } from './config/makeNativeConfig';
import type { ReactNativeConfig } from './config/types';
import { ConsoleInstrumentation } from './instrumentations/ConsoleInstrumentation';
import { ErrorsInstrumentation } from './instrumentations/ErrorsInstrumentation';
import { NetworkInstrumentation } from './instrumentations/NetworkInstrumentation';
import { NativeFaroModule } from './native/FaroNativeModule';

export interface FaroReactNative {
  api: FaroReactNativeApi;
  pause: () => void;
  unpause: () => void;
}

let faroInstance: FaroReactNative | null = null;

/**
 * Initialize the Faro React Native SDK.
 *
 * This configures and initializes the native Faro SDK on both Android and iOS,
 * then sets up JavaScript-side instrumentations (console, errors, network).
 *
 * @example
 * ```typescript
 * import { initializeFaro } from '@grafana/faro-react-native';
 *
 * const faro = await initializeFaro({
 *   url: 'https://your-collector.example.com/collect',
 *   app: { name: 'MyApp', version: '1.0.0', environment: 'production' },
 *   enableCrashReporting: true,
 * });
 *
 * // Send a log
 * faro.api.pushLog('User logged in', { level: 'info' });
 *
 * // Send an error
 * faro.api.pushError(new Error('Something went wrong'));
 *
 * // Set user info
 * faro.api.setUser({ id: '123', email: 'user@example.com' });
 * ```
 */
export async function initializeFaro(
  config: ReactNativeConfig
): Promise<FaroReactNative> {
  if (faroInstance) {
    console.warn(
      '[Faro] Already initialized. Use the existing instance or call resetFaro() first.'
    );
    return faroInstance;
  }

  // 1. Build native config and initialize native SDK
  const nativeConfig = makeNativeConfig(config);
  await NativeFaroModule?.initialize(JSON.stringify(nativeConfig));

  // 2. Create JS API wrapper
  const api = new FaroReactNativeApi(NativeFaroModule);

  // 3. Build ignore patterns for JS instrumentations
  const ignoreUrls: Array<string | RegExp> = [
    config.url, // Always ignore collector URL
    ...(config.ignoreUrls ?? []),
  ];

  // 4. Install JS-side instrumentations
  const instrumentations: Array<{ uninstall: () => void }> = [];

  if (config.enableJSErrorTracking !== false) {
    const errors = new ErrorsInstrumentation(
      NativeFaroModule,
      config.ignoreErrors
    );
    errors.install();
    instrumentations.push(errors);
  }

  if (config.enableConsoleInstrumentation !== false) {
    const console = new ConsoleInstrumentation(NativeFaroModule);
    console.install();
    instrumentations.push(console);
  }

  if (config.enableFetchInstrumentation !== false) {
    const network = new NetworkInstrumentation(NativeFaroModule, ignoreUrls);
    network.install();
    instrumentations.push(network);
  }

  // 5. Build the faro instance
  faroInstance = {
    api,
    pause: () => {
      api.pause();
    },
    unpause: () => {
      api.unpause();
    },
  };

  return faroInstance;
}

/**
 * Get the current Faro instance if initialized.
 */
export function getFaro(): FaroReactNative | null {
  return faroInstance;
}

/**
 * Reset the Faro instance. Primarily for testing.
 */
export function resetFaro(): void {
  faroInstance = null;
}
