# Faro React Native Example App

An Expo-based example app for verifying the `@grafana/faro-react-native` SDK.

## Prerequisites

- Node.js >= 18
- [Expo CLI](https://docs.expo.dev/get-started/installation/)
- For iOS: Xcode with CocoaPods
- For Android: Android Studio with SDK

## Setup

1. Install dependencies:

```bash
cd packages/faro-react-native/example
npm install
```

2. Start the mock collector (see below), or configure a real collector URL in `src/faro.ts`.

3. Start the app:

```bash
# Start Expo dev server
npx expo start

# Or run directly on a platform
npx expo run:ios
npx expo run:android
```

## Mock Collector

A zero-dependency Node.js server that captures signals from the native Faro SDKs and exposes them via HTTP for inspection.

### Start

```bash
node tools/mock-collector.mjs
# Listening on http://0.0.0.0:6543
```

In dev mode the example app automatically points at the mock collector (localhost:6543 for iOS Simulator, 10.0.2.2:6543 for Android Emulator). No config changes needed.

### Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/*` | Ingest signals (any path — the native SDKs POST here) |
| `GET` | `/signals` | List received signals. Query params: `?limit=N&type=log\|error\|measurement\|event` |
| `GET` | `/signals/summary` | Counts by signal type |
| `GET` | `/health` | Liveness check with signal count |
| `DELETE` | `/signals` | Clear all stored signals |

### Examples

```bash
# See what's been received
curl http://localhost:6543/signals/summary

# Get the last 10 log signals
curl 'http://localhost:6543/signals?type=log&limit=10'

# Clear everything
curl -X DELETE http://localhost:6543/signals
```

### Log file

All signals are also appended to `tools/signals.log` (one JSON object per line) for persistent inspection.

## Using with Claude Desktop + mobile-mcp

[mobile-mcp](https://github.com/nichochar/mobile-mcp) gives Claude Desktop the ability to interact with iOS Simulators and Android Emulators (tap, type, screenshot). Combined with the mock collector, Claude can:

1. **Interact with the app** — tap buttons on each tab to trigger SDK actions
2. **Verify signals arrived** — read the collector's HTTP endpoints or `signals.log`

### Setup

1. Install and configure mobile-mcp in Claude Desktop per its README.
2. In a terminal, start the mock collector:
   ```bash
   node tools/mock-collector.mjs
   ```
3. In another terminal, start the Expo app on a simulator:
   ```bash
   npx expo run:ios   # or run:android
   ```
4. In Claude Desktop, instruct Claude to:
   - Use mobile-mcp to navigate the app and tap test buttons
   - Read `http://localhost:6543/signals/summary` to check signal counts
   - Read `http://localhost:6543/signals?type=error&limit=5` to inspect payloads
   - Or read the file at `packages/faro-react-native/example/tools/signals.log`

### What Claude can verify

| Feature | How to trigger (mobile-mcp) | How to verify (mock collector) |
|---------|---------------------------|-------------------------------|
| Logs | Tap "TRACE"..."ERROR" buttons on Logs tab | `GET /signals?type=log` — check level and message |
| Errors | Tap "Send Basic Error" on Errors tab | `GET /signals?type=error` — check type, value, stacktrace |
| Events | Tap "Send Event" on Events tab | `GET /signals?type=event` — check name and attributes |
| Measurements | Tap "Send Random Measurement" on Events tab | `GET /signals?type=measurement` — check numeric values |
| User | Fill fields and tap "Set User" on User tab | Subsequent signals should include user metadata |
| Network | Tap "GET (200)" on Network tab | `GET /signals?type=measurement` — look for http_request type |
| Pause/Unpause | Tap "Pause for 3s" on User tab | Signals sent during pause should not appear |
| Console capture | Tap "console.*" on Logs tab | `GET /signals?type=log` — auto-captured console output |

## What This App Tests

The app has tabbed navigation with a screen for each SDK feature:

### Home (Dashboard)
- Shows SDK initialization status
- Displays device info from the native module
- Quick action buttons for basic smoke tests

### Logs
- Send logs at every level (trace, debug, info, log, warn, error)
- Send logs with custom context
- Test `console.*` auto-capture via `ConsoleInstrumentation`
- Custom log messages

### Errors
- `pushError()` with basic errors, typed errors, and custom stack frames
- Deeply nested errors for stack trace verification
- Unhandled error trigger (tests `ErrorsInstrumentation` global handler)
- Unhandled promise rejection trigger

### Events & Measurements
- `pushEvent()` with attributes and custom domains
- Batch event sending (5 events at once)
- `pushMeasurement()` with random values
- Timed measurement (simulates async work)

### User & Session
- `setUser()` / `resetUser()` with full user metadata
- `setView()` for view tracking
- `setSession()` for manual session ID
- `pause()` / `unpause()` SDK control

### Network
- GET/POST requests to httpbin.org (auto-captured by `NetworkInstrumentation`)
- Error status codes (404, 500)
- Request timeout (abort after 3s)
- Network errors (invalid domain)
- Parallel requests
- Custom URL input
