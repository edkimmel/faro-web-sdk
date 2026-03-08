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
}

export type BeforeSendHook = (item: TransportItem) => TransportItem | null;

export interface TransportItem {
  type: string;
  payload: unknown;
  meta: Record<string, unknown>;
}

export interface ReactNativeConfig {
  // Required
  url: string;
  app: MetaApp;

  // Optional auth
  apiKey?: string;

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

  // Shared
  beforeSend?: BeforeSendHook;
  ignoreErrors?: Array<string | RegExp>;
  ignoreUrls?: Array<string | RegExp>;
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
  internalLoggerLevel: string;
  eventDomain: string;
}
