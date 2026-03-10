import type { NativeFaroModule } from '../native/FaroNativeModule';

type ErrorUtils = {
  setGlobalHandler: (handler: (error: Error, isFatal?: boolean) => void) => void;
  getGlobalHandler: () => (error: Error, isFatal?: boolean) => void;
};

declare const global: {
  ErrorUtils?: ErrorUtils;
};

/**
 * Captures unhandled JavaScript errors in React Native using ErrorUtils
 * and unhandled promise rejections.
 */
export class ErrorsInstrumentation {
  private nativeModule: typeof NativeFaroModule;
  private previousHandler?: (error: Error, isFatal?: boolean) => void;
  private ignorePatterns: Array<string | RegExp>;

  constructor(
    nativeModule: typeof NativeFaroModule,
    ignorePatterns: Array<string | RegExp> = []
  ) {
    this.nativeModule = nativeModule;
    this.ignorePatterns = ignorePatterns;
  }

  install(): void {
    this.installGlobalErrorHandler();
    this.installPromiseRejectionHandler();
  }

  private installGlobalErrorHandler(): void {
    if (!global.ErrorUtils) return;

    this.previousHandler = global.ErrorUtils.getGlobalHandler();

    global.ErrorUtils.setGlobalHandler((error: Error, isFatal?: boolean) => {
      this.handleError(error, isFatal);

      // Forward to previous handler
      if (this.previousHandler) {
        this.previousHandler(error, isFatal);
      }
    });
  }

  private installPromiseRejectionHandler(): void {
    const originalHandler = (global as any).__promiseRejectionTrackingOptions?.onUnhandled;

    // React Native's promise rejection tracking
    if (typeof (global as any).HermesInternal !== 'undefined') {
      // Hermes engine
      (global as any).__promiseRejectionTrackingOptions = {
        ...(global as any).__promiseRejectionTrackingOptions,
        onUnhandled: (id: number, rejection: unknown) => {
          const error =
            rejection instanceof Error
              ? rejection
              : new Error(String(rejection));
          this.handleError(error, false);
          originalHandler?.(id, rejection);
        },
      };
    }
  }

  private handleError(error: Error, isFatal?: boolean): void {
    if (this.shouldIgnore(error.message)) return;

    const context: Record<string, string> = {
      source: 'js_error',
    };
    if (isFatal !== undefined) {
      context['isFatal'] = String(isFatal);
    }

    const stacktrace = error.stack
      ? this.parseStackTrace(error.stack)
      : undefined;

    this.nativeModule?.pushError(
      error.name || 'Error',
      error.message || 'Unknown error',
      stacktrace ? JSON.stringify(stacktrace) : undefined,
      JSON.stringify(context)
    );
  }

  private parseStackTrace(
    stack: string
  ): { frames: Array<{ filename: string; function: string; lineno?: number; colno?: number }> } {
    const frames = stack
      .split('\n')
      .slice(1) // Skip the error message line
      .map((line) => {
        const match = line.match(/^\s*at\s+(.+?)\s+\((.+?):(\d+):(\d+)\)\s*$/) ||
                      line.match(/^\s*at\s+(.+?):(\d+):(\d+)\s*$/);

        if (match) {
          if (match.length === 5) {
            return {
              function: match[1] || 'anonymous',
              filename: match[2] || 'unknown',
              lineno: parseInt(match[3], 10) || undefined,
              colno: parseInt(match[4], 10) || undefined,
            };
          }
          return {
            function: 'anonymous',
            filename: match[1] || 'unknown',
            lineno: parseInt(match[2], 10) || undefined,
            colno: parseInt(match[3], 10) || undefined,
          };
        }

        return {
          function: line.trim(),
          filename: 'unknown',
        };
      })
      .filter((frame) => frame.filename !== 'unknown' || frame.function !== '');

    return { frames };
  }

  private shouldIgnore(message: string): boolean {
    return this.ignorePatterns.some((pattern) => {
      if (typeof pattern === 'string') {
        return message.includes(pattern);
      }
      return pattern.test(message);
    });
  }

  uninstall(): void {
    if (this.previousHandler && global.ErrorUtils) {
      global.ErrorUtils.setGlobalHandler(this.previousHandler);
    }
  }
}
