import type { NativeFaroModule } from '../native/FaroNativeModule';

type LogLevel = 'trace' | 'debug' | 'info' | 'log' | 'warn' | 'error';

const consoleToLogLevel: Record<string, LogLevel> = {
  trace: 'trace',
  debug: 'debug',
  info: 'info',
  log: 'log',
  warn: 'warn',
  error: 'error',
};

const defaultDisabledLevels: LogLevel[] = ['trace', 'debug', 'log'];

/**
 * Intercepts console.* calls and forwards them to the native Faro SDK.
 */
export class ConsoleInstrumentation {
  private nativeModule: typeof NativeFaroModule;
  private originalMethods: Partial<Record<string, (...args: unknown[]) => void>> = {};
  private disabledLevels: Set<LogLevel>;

  constructor(
    nativeModule: typeof NativeFaroModule,
    disabledLevels: LogLevel[] = defaultDisabledLevels
  ) {
    this.nativeModule = nativeModule;
    this.disabledLevels = new Set(disabledLevels);
  }

  install(): void {
    const methods = ['trace', 'debug', 'info', 'log', 'warn', 'error'] as const;

    for (const method of methods) {
      const level = consoleToLogLevel[method];
      if (!level || this.disabledLevels.has(level)) continue;

      this.originalMethods[method] = console[method];

      console[method] = (...args: unknown[]) => {
        // Call original first
        this.originalMethods[method]?.apply(console, args);

        // Forward to native
        const message = args
          .map((arg) => {
            if (typeof arg === 'string') return arg;
            try {
              return JSON.stringify(arg);
            } catch {
              return String(arg);
            }
          })
          .join(' ');

        this.nativeModule?.pushLog(level, message);
      };
    }
  }

  uninstall(): void {
    for (const [method, original] of Object.entries(this.originalMethods)) {
      if (original) {
        (console as any)[method] = original;
      }
    }
    this.originalMethods = {};
  }
}
