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

2. Configure the collector URL in `src/faro.ts`:

```typescript
const COLLECTOR_URL = 'https://your-collector.example.com/collect';
```

3. Start the app:

```bash
# Start Expo dev server
npx expo start

# Or run directly on a platform
npx expo run:ios
npx expo run:android
```

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

## Verifying Correctness

After triggering actions in the app:

1. Check your Faro collector / Grafana Cloud for received signals
2. Verify logs appear with correct levels and context
3. Verify errors include stack traces with correct frame information
4. Verify events have correct attributes and domains
5. Verify measurements have expected numeric values
6. Verify user metadata is attached to subsequent signals
7. Verify network requests are captured with status codes and durations
8. Verify pause/unpause correctly stops and resumes signal delivery
