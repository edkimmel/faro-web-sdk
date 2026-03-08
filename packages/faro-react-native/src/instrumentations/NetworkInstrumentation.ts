import type { NativeFaroModule } from '../native/FaroNativeModule';

/**
 * Intercepts global fetch and XMLHttpRequest to monitor HTTP requests
 * from the JavaScript layer and forward metrics to the native SDK.
 */
export class NetworkInstrumentation {
  private nativeModule: typeof NativeFaroModule;
  private originalFetch?: typeof global.fetch;
  private originalXHROpen?: XMLHttpRequest['open'];
  private originalXHRSend?: XMLHttpRequest['send'];
  private ignorePatterns: Array<string | RegExp>;

  constructor(
    nativeModule: typeof NativeFaroModule,
    ignorePatterns: Array<string | RegExp> = []
  ) {
    this.nativeModule = nativeModule;
    this.ignorePatterns = ignorePatterns;
  }

  install(): void {
    this.instrumentFetch();
    this.instrumentXHR();
  }

  private instrumentFetch(): void {
    if (typeof global.fetch !== 'function') return;

    this.originalFetch = global.fetch;

    global.fetch = async (input: RequestInfo | URL, init?: RequestInit): Promise<Response> => {
      const url = typeof input === 'string' ? input : input instanceof URL ? input.toString() : input.url;
      const method = init?.method || 'GET';

      if (this.shouldIgnore(url)) {
        return this.originalFetch!(input, init);
      }

      const startTime = Date.now();
      let response: Response | undefined;
      let error: Error | undefined;

      try {
        response = await this.originalFetch!(input, init);
        return response;
      } catch (e) {
        error = e instanceof Error ? e : new Error(String(e));
        throw e;
      } finally {
        const durationMs = Date.now() - startTime;
        this.reportRequest(url, method, response?.status, durationMs, error);
      }
    };
  }

  private instrumentXHR(): void {
    if (typeof XMLHttpRequest === 'undefined') return;

    this.originalXHROpen = XMLHttpRequest.prototype.open;
    this.originalXHRSend = XMLHttpRequest.prototype.send;
    const self = this;

    XMLHttpRequest.prototype.open = function (
      this: XMLHttpRequest,
      method: string,
      url: string | URL,
      ...args: any[]
    ): void {
      (this as any).__faro_url = typeof url === 'string' ? url : url.toString();
      (this as any).__faro_method = method;
      return self.originalXHROpen!.apply(this, [method, url, ...args] as any);
    };

    XMLHttpRequest.prototype.send = function (
      this: XMLHttpRequest,
      body?: XMLHttpRequestBodyInit | null
    ): void {
      const url = (this as any).__faro_url as string;
      const method = (this as any).__faro_method as string;

      if (self.shouldIgnore(url)) {
        return self.originalXHRSend!.apply(this, [body]);
      }

      const startTime = Date.now();

      this.addEventListener('loadend', () => {
        const durationMs = Date.now() - startTime;
        self.reportRequest(url, method, this.status, durationMs);
      });

      this.addEventListener('error', () => {
        const durationMs = Date.now() - startTime;
        self.reportRequest(
          url,
          method,
          undefined,
          durationMs,
          new Error('XHR request failed')
        );
      });

      return self.originalXHRSend!.apply(this, [body]);
    };
  }

  private reportRequest(
    url: string,
    method: string,
    statusCode?: number,
    durationMs?: number,
    error?: Error
  ): void {
    const values: Record<string, number> = {};
    if (durationMs !== undefined) values['duration_ms'] = durationMs;
    if (statusCode !== undefined) values['status_code'] = statusCode;

    const context: Record<string, string> = {
      url,
      method,
    };
    if (statusCode !== undefined) context['status_code'] = String(statusCode);
    if (error) context['error'] = error.message;

    this.nativeModule?.pushMeasurement(
      'http_request',
      JSON.stringify(values),
      JSON.stringify(context)
    );
  }

  private shouldIgnore(url: string): boolean {
    return this.ignorePatterns.some((pattern) => {
      if (typeof pattern === 'string') {
        return url.includes(pattern);
      }
      return pattern.test(url);
    });
  }

  uninstall(): void {
    if (this.originalFetch) {
      global.fetch = this.originalFetch;
    }
    if (this.originalXHROpen) {
      XMLHttpRequest.prototype.open = this.originalXHROpen as any;
    }
    if (this.originalXHRSend) {
      XMLHttpRequest.prototype.send = this.originalXHRSend;
    }
  }
}
