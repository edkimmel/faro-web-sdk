import type { NativeFaroModule } from '../native/FaroNativeModule';
import type { MetaUser } from '../config/types';

export type LogLevel = 'trace' | 'debug' | 'info' | 'log' | 'warn' | 'error';

export interface PushLogOptions {
  context?: Record<string, string>;
  level?: LogLevel;
  timestamp?: string;
}

export interface PushErrorOptions {
  type?: string;
  context?: Record<string, string>;
  stackFrames?: Array<{
    filename: string;
    function: string;
    lineno?: number;
    colno?: number;
  }>;
}

export interface PushMeasurementOptions {
  context?: Record<string, string>;
}

export interface PushEventOptions {
  attributes?: Record<string, string>;
  domain?: string;
}

/**
 * JavaScript API wrapper that delegates all calls to the native Faro SDK
 * via the React Native bridge.
 */
export class FaroReactNativeApi {
  private nativeModule: typeof NativeFaroModule;

  constructor(nativeModule: typeof NativeFaroModule) {
    this.nativeModule = nativeModule;
  }

  pushLog(message: string, options?: PushLogOptions): void {
    const level = options?.level ?? 'log';
    const context = options?.context ? JSON.stringify(options.context) : undefined;
    const timestamp = options?.timestamp;
    this.nativeModule?.pushLog(level, message, context, timestamp);
  }

  pushError(error: Error, options?: PushErrorOptions): void {
    const type = options?.type ?? error.name ?? 'Error';
    const value = error.message ?? 'Unknown error';

    let stacktrace: string | undefined;
    if (options?.stackFrames) {
      stacktrace = JSON.stringify({ frames: options.stackFrames });
    } else if (error.stack) {
      stacktrace = JSON.stringify(this.parseStack(error.stack));
    }

    const context = options?.context ? JSON.stringify(options.context) : undefined;
    this.nativeModule?.pushError(type, value, stacktrace, context);
  }

  pushMeasurement(
    type: string,
    values: Record<string, number>,
    options?: PushMeasurementOptions
  ): void {
    const context = options?.context ? JSON.stringify(options.context) : undefined;
    this.nativeModule?.pushMeasurement(type, JSON.stringify(values), context);
  }

  pushEvent(name: string, options?: PushEventOptions): void {
    const attributes = options?.attributes ? JSON.stringify(options.attributes) : undefined;
    this.nativeModule?.pushEvent(name, attributes, options?.domain);
  }

  setUser(user: MetaUser): void {
    this.nativeModule?.setUser(JSON.stringify(user));
  }

  resetUser(): void {
    this.nativeModule?.resetUser();
  }

  setView(viewName: string): void {
    this.nativeModule?.setView(viewName);
  }

  setSession(sessionId: string): void {
    this.nativeModule?.setSession(sessionId);
  }

  pause(): void {
    this.nativeModule?.pause();
  }

  unpause(): void {
    this.nativeModule?.unpause();
  }

  async getDeviceInfo(): Promise<Record<string, unknown>> {
    const json = await this.nativeModule?.getDeviceInfo();
    return json ? JSON.parse(json) : {};
  }

  private parseStack(
    stack: string
  ): { frames: Array<{ filename: string; function: string; lineno?: number; colno?: number }> } {
    const frames = stack
      .split('\n')
      .slice(1)
      .map((line) => {
        const match =
          line.match(/^\s*at\s+(.+?)\s+\((.+?):(\d+):(\d+)\)\s*$/) ||
          line.match(/^\s*at\s+(.+?):(\d+):(\d+)\s*$/);

        if (match && match.length === 5) {
          return {
            function: match[1] || 'anonymous',
            filename: match[2] || 'unknown',
            lineno: parseInt(match[3], 10) || undefined,
            colno: parseInt(match[4], 10) || undefined,
          };
        }

        return {
          function: line.trim() || 'anonymous',
          filename: 'unknown',
        };
      });

    return { frames };
  }
}
