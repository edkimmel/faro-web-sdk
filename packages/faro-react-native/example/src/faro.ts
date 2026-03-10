import { Platform } from 'react-native';

import { initializeFaro, getFaro } from '@edkimmel/faro-react-native';
import type { FaroReactNative } from '@edkimmel/faro-react-native';

// ---------- Collector URL ----------
// For the mock collector (tools/mock-collector.mjs), use:
//   iOS Simulator:   http://localhost:6543/collect
//   Android Emulator: http://10.0.2.2:6543/collect
//   Physical device:  http://<your-lan-ip>:6543/collect
//
// For a real Grafana Cloud collector, replace entirely.
const MOCK_COLLECTOR_PORT = 6543;
const COLLECTOR_URL = __DEV__
  ? `http://${Platform.OS === 'android' ? '10.0.2.2' : 'localhost'}:${MOCK_COLLECTOR_PORT}/collect`
  : 'https://your-collector.example.com/collect';

let initPromise: Promise<FaroReactNative> | null = null;

export function getInitPromise(): Promise<FaroReactNative> {
  if (!initPromise) {
    initPromise = initializeFaro({
      url: COLLECTOR_URL,
      app: {
        name: 'FaroReactNativeExample',
        version: '1.0.0',
        environment: __DEV__ ? 'development' : 'production',
      },
      enableCrashReporting: true,
      enableHangDetection: true,
      enableConsoleInstrumentation: true,
      enableJSErrorTracking: true,
      enableFetchInstrumentation: true,
      sessionTracking: {
        enabled: true,
      },
      internalLoggerLevel: __DEV__ ? 'verbose' : 'error',
    });
  }
  return initPromise;
}

export { getFaro };
