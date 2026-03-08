import { TurboModuleRegistry, type TurboModule } from 'react-native';

/**
 * TurboModule spec for the Faro native module (New Architecture).
 */
export interface Spec extends TurboModule {
  initialize(config: string): Promise<void>;

  // Signals
  pushLog(level: string, message: string, context?: string, timestamp?: string): void;
  pushError(type: string, value: string, stacktrace?: string, context?: string): void;
  pushMeasurement(type: string, values: string, context?: string): void;
  pushEvent(name: string, attributes?: string, domain?: string): void;

  // Meta management
  setUser(user: string): void;
  resetUser(): void;
  setSession(session: string): void;
  setView(view: string): void;

  // Control
  pause(): void;
  unpause(): void;

  // Device info
  getDeviceInfo(): Promise<string>;
}

export default TurboModuleRegistry.get<Spec>('FaroReactNative');
