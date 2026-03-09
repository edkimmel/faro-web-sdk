export interface MetaApp {
  name: string;
  version?: string;
  environment?: string;
  namespace?: string;
  release?: string;
  bundleId?: string;
}

export interface MetaUser {
  email?: string;
  id?: string;
  username?: string;
  fullName?: string;
  roles?: string;
  hash?: string;
  attributes?: Record<string, string>;
}

export interface SessionConfig {
  enabled?: boolean;
  persistent?: boolean;
  maxSessionDurationMs?: number;
  sessionTimeoutMs?: number;
  samplingRate?: number;
}

export interface BatchConfig {
  itemLimit?: number;
  sendTimeoutMs?: number;
  maxBufferSize?: number;
}

export interface TransportConfig {
  headers?: Record<string, string>;
}

export interface MetaPage {
  id?: string;
  url?: string;
  attributes?: Record<string, string>;
}

export interface ReactNativeConfig {
  // Required
  url: string;
  app: MetaApp;

  // Optional auth
  apiKey?: string;

  // Transport
  transport?: TransportConfig;

  // User
  user?: MetaUser;

  // Session
  sessionTracking?: SessionConfig;

  // Native features (opt-in)
  enableCrashReporting?: boolean;
  enableAnrDetection?: boolean;
  enableHangDetection?: boolean;
  enableLifecycleTracking?: boolean;
  enableNativeNetworkMonitoring?: boolean;

  // JS features
  enableConsoleInstrumentation?: boolean;
  enableJSErrorTracking?: boolean;
  enableFetchInstrumentation?: boolean;

  // Filtering (applied JS-side before signals cross the bridge)
  ignoreErrors?: Array<string | RegExp>;
  ignoreUrls?: Array<string | RegExp>;

  // Batching
  batching?: BatchConfig;

  // Internal
  internalLoggerLevel?: 'verbose' | 'debug' | 'info' | 'warn' | 'error' | 'none';
  eventDomain?: string;
}

export interface NativeConfig {
  collectorUrl: string;
  apiKey?: string;
  app: MetaApp;
  user?: MetaUser;
  sessionTracking?: SessionConfig;
  enableCrashReporting: boolean;
  enableAnrDetection: boolean;
  enableHangDetection: boolean;
  enableLifecycleTracking: boolean;
  enableNetworkMonitoring: boolean;
  batchConfig?: BatchConfig;
  transportHeaders?: Record<string, string>;
  internalLoggerLevel: string;
  eventDomain: string;
}
