import { initializeFaro, getFaro } from '@grafana/faro-react-native';
import type { FaroReactNative } from '@grafana/faro-react-native';

// Replace with your Faro collector URL
const COLLECTOR_URL = 'https://your-collector.example.com/collect';

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
      enableAnrDetection: true,
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
