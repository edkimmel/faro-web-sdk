# Faro React Native SDK — Comprehensive Specification

## Part 1: Current Faro Web SDK Feature Inventory

### Architecture Overview
The Faro Web SDK is a monorepo with 4 packages:
- **`@grafana/faro-core`** — Platform-agnostic core: APIs, transports, metas, instrumentations framework
- **`@grafana/faro-web-sdk`** — Browser-specific: fetch transport, browser instrumentations, web vitals
- **`@grafana/faro-web-tracing`** — OpenTelemetry distributed tracing integration
- **`@grafana/faro-react`** — React framework integration (error boundaries, profiler, router)

### Signal Types Collected
| Signal | Type Key | Description |
|--------|----------|-------------|
| **Logs** | `log` | Structured log messages with level (TRACE, DEBUG, INFO, LOG, WARN, ERROR) |
| **Exceptions** | `exception` | Errors with type, value, stacktrace (frames: filename, function, lineno, colno) |
| **Measurements** | `measurement` | Numeric key-value pairs with type label (e.g., web vitals, custom metrics) |
| **Events** | `event` | Named events with attributes and domain (e.g., "click", "page_load") |
| **Traces** | `trace` | OpenTelemetry spans serialized as `resourceSpans[]` |

### Meta (Context) System
Every signal includes a `Meta` envelope:
```
Meta {
  sdk:     { name, version, integrations[] }
  app:     { name, namespace, release, version, environment, bundleId }
  user:    { email, id, username, fullName, roles, hash, attributes{} }
  session: { id, attributes{}, overrides{ serviceName, geoLocationTrackingEnabled } }
  page:    { id, url, attributes{} }
  browser: { name, version, os, mobile, userAgent, language, brands, viewportWidth/Height }
  view:    { name }
  k6:      { isK6Browser, testRunId }
}
```

### Transport Layer
- **Wire format**: HTTP POST to `/collect` endpoint, `Content-Type: application/json`
- **Payload structure**:
  ```json
  {
    "meta": { Meta object },
    "logs": [ LogEvent[] ],
    "exceptions": [ ExceptionEvent[] ],
    "measurements": [ MeasurementEvent[] ],
    "events": [ EventEvent[] ],
    "traces": { "resourceSpans": [...] }
  }
  ```
- **Headers**: `x-api-key` (optional), `x-faro-session-id`
- **Batching**: Configurable `itemLimit` (default 30) and `sendTimeout`
- **Rate limiting**: Honors `429` responses with `Retry-After` header, default 5s backoff
- **Keepalive**: Uses `keepalive: true` for bodies < 60KB

### Instrumentations (Web)
1. **ConsoleInstrumentation** — Intercepts `console.*` calls, forwards as logs
2. **ErrorsInstrumentation** — Global `window.onerror` + `unhandledrejection` handlers
3. **WebVitalsInstrumentation** — CLS, FCP, FID, INP, LCP, TTFB via `web-vitals` library
4. **PerformanceInstrumentation** — Resource timings, navigation timings via Performance API
5. **SessionInstrumentation** — Session ID generation, persistence (localStorage/sessionStorage), sampling, expiry
6. **ViewInstrumentation** — View name tracking for SPA navigation
7. **CSPInstrumentation** — Content Security Policy violation reporting
8. **UserActionInstrumentation** — Click tracking with `data-faro-user-action-name` attribute
9. **NavigationInstrumentation** — Experimental SPA navigation tracking

### React Integration
- **FaroErrorBoundary** — React error boundary that reports caught errors
- **FaroProfiler** — React Profiler wrapper that reports render timings as measurements
- **Router integration** — React Router v4/v5/v6/v7 route change tracking

### API Surface
```typescript
faro.api.pushLog(args, options?)           // Send log
faro.api.pushError(error, options?)        // Send exception
faro.api.pushMeasurement(payload, options?) // Send measurement
faro.api.pushEvent(name, attributes?, domain?, options?) // Send event
faro.api.pushTraces(traces)                // Send OTEL traces
faro.api.setUser(user)                     // Set user metadata
faro.api.resetUser()                       // Clear user metadata
faro.api.setSession(session)               // Set session metadata
faro.api.getSession()                      // Get current session
faro.api.setView(view)                     // Set current view
faro.api.getOTEL()                         // Get OTEL trace/context APIs
faro.api.getTraceContext()                 // Get current trace_id/span_id
faro.pause() / faro.unpause()              // Control data collection
```

---

## Part 2: Native SDK Specifications

### Design Principles
- **Standalone**: Each native SDK works independently for pure native apps
- **Singleton access**: Initialized instance accessible from anywhere via `Faro.getInstance()`
- **Disk buffering**: All signals persist to disk before sending, surviving app kills and crashes
- **Same wire format**: Uses identical JSON payload and `/collect` endpoint as web SDK
- **Non-conflicting crash reporting**: Optional native crash capture that can coexist with Crashlytics

---

### 2a. Faro Android SDK (Kotlin)

#### Package Structure
```
packages/faro-android-sdk/
├── build.gradle.kts
├── src/main/kotlin/com/grafana/faro/
│   ├── Faro.kt                          # Singleton entry point
│   ├── FaroConfig.kt                    # Configuration
│   ├── api/
│   │   ├── FaroApi.kt                   # Public API (pushLog, pushError, etc.)
│   │   ├── models/                      # Signal data classes
│   │   │   ├── LogEvent.kt
│   │   │   ├── ExceptionEvent.kt
│   │   │   ├── MeasurementEvent.kt
│   │   │   ├── EventEvent.kt
│   │   │   └── Meta.kt
│   │   └── LogLevel.kt
│   ├── transport/
│   │   ├── Transport.kt                 # Transport interface
│   │   ├── HttpTransport.kt             # OkHttp-based HTTP transport
│   │   ├── TransportBody.kt             # JSON serialization
│   │   ├── BatchExecutor.kt             # Batching logic
│   │   └── DiskBufferTransport.kt       # Disk persistence wrapper
│   ├── persistence/
│   │   ├── DiskBuffer.kt                # File-based signal queue
│   │   ├── SignalFile.kt                # Individual signal file management
│   │   └── FileRotation.kt             # Old file cleanup
│   ├── instrumentations/
│   │   ├── Instrumentation.kt           # Base interface
│   │   ├── lifecycle/
│   │   │   └── AppLifecycleInstrumentation.kt   # Foreground/background/launch
│   │   ├── crash/
│   │   │   └── CrashInstrumentation.kt          # UncaughtExceptionHandler
│   │   ├── anr/
│   │   │   └── AnrInstrumentation.kt            # ANR detection (watchdog thread)
│   │   └── network/
│   │       └── OkHttpInstrumentation.kt         # OkHttp interceptor
│   ├── session/
│   │   ├── SessionManager.kt            # Session ID lifecycle
│   │   └── SessionStore.kt              # SharedPreferences persistence
│   └── internal/
│       ├── InternalLogger.kt
│       └── Clock.kt
```

#### Configuration
```kotlin
data class FaroConfig(
    val collectorUrl: String,
    val apiKey: String? = null,
    val app: AppMeta,                        // name, version, environment, etc.
    val sessionTracking: SessionConfig = SessionConfig(),
    val enableCrashReporting: Boolean = false, // opt-in, won't conflict with Crashlytics
    val enableAnrDetection: Boolean = true,
    val enableLifecycleTracking: Boolean = true,
    val enableNetworkMonitoring: Boolean = true,
    val batchConfig: BatchConfig = BatchConfig(),
    val diskBufferConfig: DiskBufferConfig = DiskBufferConfig(),
    val beforeSend: ((TransportItem) -> TransportItem?)? = null,
    val ignoreErrors: List<Regex> = emptyList(),
    val maxDiskUsageBytes: Long = 5 * 1024 * 1024, // 5MB default
)
```

#### Singleton Pattern
```kotlin
object Faro {
    private var instance: FaroInstance? = null

    fun initialize(context: Context, config: FaroConfig): FaroInstance {
        val inst = FaroInstance(context.applicationContext, config)
        instance = inst
        inst.start()
        return inst
    }

    fun getInstance(): FaroInstance {
        return instance ?: throw IllegalStateException("Faro not initialized")
    }
}
```

#### Disk Buffering Strategy
- Signals written to app-private files in `{cacheDir}/faro/signals/`
- Each file = one JSON batch (up to `itemLimit` signals)
- Files named with timestamp + UUID for ordering
- On send success, file is deleted
- On send failure, file is retained for retry
- File rotation: delete files older than 24 hours, cap total disk at `maxDiskUsageBytes`
- Crash data written synchronously to a dedicated crash file
- On next app launch, crash file is read and sent first

#### ANR Detection
- Background watchdog thread pings main thread every 5 seconds
- If main thread doesn't respond within 5 seconds, report ANR event
- Capture main thread stacktrace at time of ANR

#### Network Monitoring
- OkHttp Interceptor that captures: URL, method, status code, request/response size, duration
- Reports as `MeasurementEvent` with type `"http_request"`
- Opt-in via `enableNetworkMonitoring`

#### Lifecycle Events
- `ActivityLifecycleCallbacks` for foreground/background transitions
- `ProcessLifecycleOwner` for app-level lifecycle
- Report as `EventEvent` with domain `"app"`: `app_start`, `app_foreground`, `app_background`
- Cold/warm start time as `MeasurementEvent`

---

### 2b. Faro iOS SDK (Swift)

#### Package Structure
```
packages/faro-ios-sdk/
├── Package.swift
├── Sources/FaroSDK/
│   ├── Faro.swift                         # Singleton entry point
│   ├── FaroConfig.swift                   # Configuration
│   ├── API/
│   │   ├── FaroApi.swift                  # Public API
│   │   ├── Models/
│   │   │   ├── LogEvent.swift
│   │   │   ├── ExceptionEvent.swift
│   │   │   ├── MeasurementEvent.swift
│   │   │   ├── EventEvent.swift
│   │   │   └── Meta.swift
│   │   └── LogLevel.swift
│   ├── Transport/
│   │   ├── Transport.swift                # Protocol
│   │   ├── HttpTransport.swift            # URLSession-based transport
│   │   ├── TransportBody.swift            # JSON serialization (Codable)
│   │   ├── BatchExecutor.swift            # Batching logic
│   │   └── DiskBufferTransport.swift      # Disk persistence wrapper
│   ├── Persistence/
│   │   ├── DiskBuffer.swift               # File-based signal queue
│   │   ├── SignalFile.swift
│   │   └── FileRotation.swift
│   ├── Instrumentations/
│   │   ├── Instrumentation.swift          # Protocol
│   │   ├── Lifecycle/
│   │   │   └── AppLifecycleInstrumentation.swift
│   │   ├── Crash/
│   │   │   └── CrashInstrumentation.swift # NSException + signal handlers
│   │   ├── Hang/
│   │   │   └── HangInstrumentation.swift  # Main thread hang detection
│   │   └── Network/
│   │       └── URLSessionInstrumentation.swift  # URLSession monitoring
│   ├── Session/
│   │   ├── SessionManager.swift
│   │   └── SessionStore.swift             # UserDefaults + Keychain
│   └── Internal/
│       ├── InternalLogger.swift
│       └── Clock.swift
```

#### Configuration
```swift
public struct FaroConfig {
    let collectorUrl: String
    let apiKey: String?
    let app: AppMeta
    let sessionTracking: SessionConfig
    let enableCrashReporting: Bool          // opt-in, non-conflicting with Crashlytics
    let enableHangDetection: Bool
    let enableLifecycleTracking: Bool
    let enableNetworkMonitoring: Bool
    let batchConfig: BatchConfig
    let diskBufferConfig: DiskBufferConfig
    let beforeSend: ((TransportItem) -> TransportItem?)?
    let ignoreErrors: [NSRegularExpression]
    let maxDiskUsageBytes: Int64
}
```

#### Singleton Pattern
```swift
public final class Faro {
    public static let shared = Faro()
    private var instance: FaroInstance?

    public func initialize(config: FaroConfig) -> FaroInstance { ... }
    public func getInstance() -> FaroInstance { ... }
}
```

#### Crash Reporting (Non-conflicting)
- Uses `NSSetUncaughtExceptionHandler` but chains to previous handler if present
- For signal-based crashes (SIGABRT, etc.), only installs if no existing handler
- Config option `enableCrashReporting: Bool` (default `false`)
- Crash data written synchronously to disk, sent on next launch

#### Hang Detection
- Uses `CFRunLoopObserver` on main run loop
- Reports if main thread blocked for > 2 seconds (configurable)
- Captures main thread backtrace

#### Network Monitoring
- URLSession monitoring via `URLProtocol` subclass (opt-in)
- Captures: URL, method, status, request/response size, duration, error
- Reports as `MeasurementEvent` with type `"http_request"`

---

## Part 3: React Native SDK Specification

### Package Structure
```
packages/faro-react-native/
├── package.json
├── tsconfig.json
├── src/
│   ├── index.ts                           # Public API exports
│   ├── initialize.ts                      # JS initialization
│   ├── config/
│   │   ├── types.ts                       # ReactNativeConfig type
│   │   └── makeNativeConfig.ts            # Config serialization for native
│   ├── api/
│   │   └── FaroReactNativeApi.ts          # JS API wrapping native calls
│   ├── transport/
│   │   └── NativeBridgeTransport.ts       # Transport that forwards to native SDK
│   ├── instrumentations/
│   │   ├── ErrorsInstrumentation.ts       # Global JS error handler
│   │   ├── ConsoleInstrumentation.ts      # Console interception
│   │   └── NetworkInstrumentation.ts      # fetch/XMLHttpRequest interception
│   ├── metas/
│   │   ├── deviceMeta.ts                  # Device info from native (model, OS, etc.)
│   │   └── appMeta.ts                     # App version, bundle ID from native
│   └── native/
│       ├── NativeFaroModule.ts            # TurboModule spec (New Architecture)
│       └── FaroNativeModule.ts            # Legacy bridge module fallback
├── android/
│   ├── build.gradle.kts
│   └── src/main/kotlin/com/grafana/faro/reactnative/
│       ├── FaroReactNativeModule.kt       # Native module (bridge)
│       └── FaroReactNativePackage.kt      # React Native package registration
├── ios/
│   ├── FaroReactNative.podspec
│   └── FaroReactNative/
│       ├── FaroReactNativeModule.swift     # Native module (bridge)
│       └── FaroReactNativeModule.m        # ObjC bridging header
```

### Initialization Flow
```
1. JS: import { initializeFaro } from '@grafana/faro-react-native'
2. JS: faro = initializeFaro({ url, app, ... })
3. JS → Native Bridge: configure(serializedConfig)
4. Native: Faro.initialize(context/config) on background thread
5. Native: Begin disk buffering immediately
6. JS: Set up JS-side instrumentations (console, errors, fetch)
7. JS: Forward JS signals → Native bridge → Native SDK → disk → collector
```

### Configuration
```typescript
interface ReactNativeConfig {
  // Required
  url: string;
  app: { name: string; version?: string; environment?: string; };

  // Optional
  apiKey?: string;
  user?: MetaUser;
  sessionTracking?: SessionConfig;

  // Native features (opt-in)
  enableCrashReporting?: boolean;       // Default: false
  enableAnrDetection?: boolean;         // Default: true
  enableLifecycleTracking?: boolean;    // Default: true
  enableNativeNetworkMonitoring?: boolean; // Default: true

  // JS features
  enableConsoleInstrumentation?: boolean; // Default: true
  enableJSErrorTracking?: boolean;      // Default: true
  enableFetchInstrumentation?: boolean; // Default: true

  // Shared
  beforeSend?: BeforeSendHook;
  ignoreErrors?: Patterns;
  ignoreUrls?: Patterns;
  batching?: BatchConfig;
}
```

### Bridge Methods (Native Module)
```typescript
interface FaroNativeModule {
  // Initialization
  initialize(config: string): Promise<void>;  // JSON config string

  // Signals (called from JS, forwarded to native SDK)
  pushLog(level: string, message: string, context?: string, timestamp?: string): void;
  pushError(type: string, value: string, stacktrace?: string, context?: string): void;
  pushMeasurement(type: string, values: string, context?: string): void;
  pushEvent(name: string, attributes?: string, domain?: string): void;

  // Meta management
  setUser(user: string): void;           // JSON string
  resetUser(): void;
  setSession(session: string): void;
  setView(view: string): void;

  // Control
  pause(): void;
  unpause(): void;

  // Device info (native → JS)
  getDeviceInfo(): Promise<string>;       // Returns JSON device meta
}
```

### JS-Side Instrumentations

#### ErrorsInstrumentation
- Sets global `ErrorUtils.setGlobalHandler` (React Native's error handler)
- Captures unhandled promise rejections via `tracking-promise-rejections`
- Forwards errors to native SDK via bridge

#### ConsoleInstrumentation
- Patches `console.log/warn/error/info/debug`
- Forwards to native SDK, same filtering as web SDK (`disabledLevels`)

#### NetworkInstrumentation
- Patches global `fetch` and `XMLHttpRequest`
- Captures: URL, method, status, duration, request/response size
- Forwards as measurements to native SDK
- Respects `ignoreUrls` to avoid tracking collector requests

### Device Meta (from native)
```typescript
interface MetaDevice {
  platform: 'android' | 'ios';
  osName: string;          // "Android" | "iOS"
  osVersion: string;       // "14" | "17.2"
  deviceModel: string;     // "Pixel 7" | "iPhone 15"
  deviceManufacturer: string;
  screenWidth: number;
  screenHeight: number;
  screenDensity: number;
  isEmulator: boolean;
  appVersion: string;      // From native build config
  appBuildNumber: string;
}
```

### Data Flow Architecture
```
┌─────────────────────────────────────────┐
│           React Native JS               │
│  ┌─────────────────────────────────┐    │
│  │  Console / Errors / Fetch       │    │
│  │  Instrumentations               │    │
│  └──────────┬──────────────────────┘    │
│             │ pushLog/pushError/etc.     │
│  ┌──────────▼──────────────────────┐    │
│  │  NativeBridgeTransport          │    │
│  │  (serializes → bridge call)     │    │
│  └──────────┬──────────────────────┘    │
└─────────────┼───────────────────────────┘
              │ React Native Bridge / TurboModule
┌─────────────▼───────────────────────────┐
│           Native SDK                     │
│  ┌─────────────────────────────────┐    │
│  │  FaroInstance                    │    │
│  │  (also receives native signals) │    │
│  └──────────┬──────────────────────┘    │
│             │                            │
│  ┌──────────▼──────────────────────┐    │
│  │  DiskBuffer                     │    │
│  │  (persist all signals to disk)  │    │
│  └──────────┬──────────────────────┘    │
│             │                            │
│  ┌──────────▼──────────────────────┐    │
│  │  BatchExecutor                  │    │
│  │  (batch & send via HTTP)        │    │
│  └──────────┬──────────────────────┘    │
│             │ HTTP POST                  │
└─────────────┼───────────────────────────┘
              │
    ┌─────────▼─────────┐
    │  Faro Collector    │
    │  /collect endpoint │
    └────────────────────┘
```

### Configuration Persistence
The React Native module serializes the JS config to JSON and passes it to the native side during initialization. The native SDK stores this config in SharedPreferences (Android) / UserDefaults (iOS) so that:
1. The native SDK can reinitialize on subsequent app launches before JS boots
2. Crash reports captured before JS initialization can include proper metadata
3. Background threads can access configuration without waiting for JS
