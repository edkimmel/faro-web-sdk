import type { NativeConfig, ReactNativeConfig } from './types';

export function makeNativeConfig(config: ReactNativeConfig): NativeConfig {
  return {
    collectorUrl: config.url,
    apiKey: config.apiKey,
    app: config.app,
    user: config.user,
    sessionTracking: config.sessionTracking,
    enableCrashReporting: config.enableCrashReporting ?? false,
    enableAnrDetection: config.enableAnrDetection ?? true,
    enableHangDetection: config.enableHangDetection ?? true,
    enableLifecycleTracking: config.enableLifecycleTracking ?? true,
    enableNetworkMonitoring: config.enableNativeNetworkMonitoring ?? true,
    batchConfig: config.batching,
    transportHeaders: config.transport?.headers,
    internalLoggerLevel: config.internalLoggerLevel ?? 'error',
    eventDomain: config.eventDomain ?? 'app',
  };
}
