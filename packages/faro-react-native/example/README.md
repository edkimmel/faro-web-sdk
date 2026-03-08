# Faro React Native Example App

An Expo-based example app for verifying the `@grafana/faro-react-native` SDK end to end. The app exercises every SDK feature — logs, errors, events, measurements, user metadata, sessions, and network monitoring — and ships with a local mock collector so you can verify signals without a remote backend.

## Prerequisites

- Node.js >= 18
- [Expo CLI](https://docs.expo.dev/get-started/installation/)
- For iOS: Xcode 15+ with CocoaPods (`sudo gem install cocoapods` if missing)
- For Android: Android Studio with SDK 34+, an emulator or connected device

## Quick Start

Run these three commands in separate terminal windows from the `packages/faro-react-native/example` directory.

### 1. Install dependencies

```bash
cd packages/faro-react-native/example
yarn install
```

### 2. Start the mock collector

```bash
node tools/mock-collector.mjs
```

You should see:

```
Mock collector listening on http://0.0.0.0:6543
```

Leave this running. It receives all signals the SDK sends and exposes them via HTTP endpoints.

### 3. Start the app

```bash
# iOS Simulator
yarn ios

# Android Emulator
yarn android
```

The first build takes several minutes as it compiles the native modules. Subsequent launches are fast.

When the app starts, you'll see "Initializing Faro SDK..." followed by a tabbed interface with 6 tabs: **Home**, **Logs**, **Errors**, **Events**, **User**, and **Network**.

## Collector URL Configuration

In dev mode (`__DEV__ === true`), the app auto-selects the correct collector URL:

| Target | URL |
|--------|-----|
| iOS Simulator | `http://localhost:6543/collect` |
| Android Emulator | `http://10.0.2.2:6543/collect` |
| Physical device | Edit `src/faro.ts` — use your machine's LAN IP (e.g. `http://192.168.1.100:6543/collect`) |

No config changes are needed for simulator/emulator testing.

## End-to-End Verification Walkthrough

Follow these steps to verify every SDK feature. After each action, check the mock collector to confirm signals arrived.

### Verify the collector is receiving signals

Before testing individual features, confirm the pipeline works:

```bash
# Check collector health
curl http://localhost:6543/health

# View signal summary (should show counts after app init)
curl http://localhost:6543/signals/summary

# Clear any existing signals for a clean test run
curl -X DELETE http://localhost:6543/signals
```

### Step 1: Logs

1. Tap the **Logs** tab.
2. Tap each log level button: **TRACE**, **DEBUG**, **INFO**, **LOG**, **WARN**, **ERROR**.
3. Type a custom message and tap **Send Custom Log**.
4. Tap **Console Auto-Capture** to test `console.*` interception.

**Verify:**

```bash
curl 'http://localhost:6543/signals?type=log&limit=20'
```

Expected: one signal per button tap. Each should have a `level` field matching the button (trace, debug, info, log, warn, error). Console auto-captured logs appear as separate signals with their console level.

### Step 2: Errors

1. Tap the **Errors** tab.
2. Tap **Send Basic Error** — a standard `Error` object.
3. Tap **Send TypeError** — a typed error with a specific message.
4. Tap **Custom Stack Frames** — an error with manually-provided stack frames.
5. Tap **Deeply Nested Error** — tests stack trace depth handling.

**Verify:**

```bash
curl 'http://localhost:6543/signals?type=error&limit=10'
```

Expected: each error signal should contain `type` (e.g. "Error", "TypeError"), `value` (the message), and a `stacktrace` with frame entries.

#### Unhandled errors (optional — may crash the app)

6. Tap **Trigger Unhandled Error** — throws inside `setTimeout`. The global error handler should catch and report it.
7. Tap **Trigger Unhandled Rejection** — an unresolved promise rejection.

These test the `ErrorsInstrumentation` global handlers. The app may show a red error screen in dev mode — this is expected.

### Step 3: Events and Measurements

1. Tap the **Events** tab.
2. Enter an event name and tap **Send Event**.
3. Tap **Event with Domain** — sends an event with a custom domain attribute.
4. Tap **Send Batch (5 Events)** — fires 5 events rapidly.
5. Tap **Send Random Measurement** — sends a measurement with randomized numeric values.
6. Tap **Timed Measurement** — starts an async timer and reports duration when complete.

**Verify:**

```bash
# Check events
curl 'http://localhost:6543/signals?type=event&limit=10'

# Check measurements
curl 'http://localhost:6543/signals?type=measurement&limit=10'
```

Expected: events should have `name` and optional `attributes`/`domain`. Measurements should have a `type` field and numeric `values` (e.g. `render_duration_ms`, `payload_size_bytes`).

### Step 4: User and Session Metadata

1. Tap the **User** tab.
2. Fill in the user fields (ID, email, username) and tap **Set User**.
3. Go to the **Logs** tab and send a log.
4. Return to the **User** tab and tap **Reset User**.
5. Send another log from the Logs tab.

**Verify:**

```bash
curl 'http://localhost:6543/signals?type=log&limit=5'
```

Expected: logs sent after **Set User** should include user metadata in the signal payload. Logs sent after **Reset User** should not.

#### Session and View tracking

6. Tap **Set View: Home**, **Set View: Profile**, **Set View: Settings** to change the active view.
7. Tap **Set Session** to assign a custom session ID.
8. Tap **Pause for 3s** — the SDK stops sending signals for 3 seconds, then resumes.

**Verify pause behavior:**

```bash
# Clear signals
curl -X DELETE http://localhost:6543/signals

# Immediately tap "Pause for 3s" in the app, then quickly send a log
# Wait 5 seconds, then check:
curl http://localhost:6543/signals/summary
```

Expected: logs sent during the pause window should NOT appear. Logs sent after the 3-second pause ends should appear.

### Step 5: Network Monitoring

1. Tap the **Network** tab.
2. Tap **GET (200)** — a successful HTTP request to httpbin.org.
3. Tap **POST Request** — a POST with a JSON body.
4. Tap **GET (404)** and **GET (500)** — error status codes.
5. Tap **Timeout (3s)** — aborts after 3 seconds on a 10-second delay endpoint.
6. Tap **Invalid Domain** — a request to a non-existent host.
7. Tap **3 Parallel Requests** — fires three requests concurrently.

**Verify:**

```bash
curl 'http://localhost:6543/signals?type=measurement&limit=20'
```

Expected: each network request produces a measurement signal with type `http_request` containing fields like `duration_ms`, `status_code`, `url`, and `method`. Failed requests should include `error` information.

### Step 6: Full Summary Check

After running through all tabs:

```bash
curl http://localhost:6543/signals/summary
```

You should see non-zero counts for `log`, `error`, `event`, and `measurement` types.

## Mock Collector Reference

### Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/*` | Ingest signals (any path — the native SDKs POST here) |
| `GET` | `/signals` | List received signals. Query: `?limit=N&type=log\|error\|measurement\|event` |
| `GET` | `/signals/summary` | Counts by signal type |
| `GET` | `/health` | Liveness check with signal count and log file size |
| `DELETE` | `/signals` | Clear all stored signals |

### Log File

All signals are also appended to `tools/signals.log` (one JSON object per line). You can inspect this file directly:

```bash
# Tail the log file to watch signals arrive in real time
tail -f tools/signals.log | python3 -m json.tool

# Count signals by type
grep -o '"classified_type":"[^"]*"' tools/signals.log | sort | uniq -c
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `6543` | Server port |
| `MAX_LOG_SIZE` | `10485760` (10 MB) | Max log file size before rotation |

### Ring Buffer

The collector keeps the last 500 signals in memory. Older signals are evicted but remain in `signals.log`.

## Using with Claude Desktop + mobile-mcp

[mobile-mcp](https://github.com/nichochar/mobile-mcp) gives Claude Desktop the ability to interact with iOS Simulators and Android Emulators (tap, type, screenshot). Combined with the mock collector, Claude can run the full verification walkthrough autonomously.

### Setup

1. Install and configure mobile-mcp in Claude Desktop per its README.
2. Start the mock collector: `node tools/mock-collector.mjs`
3. Start the app on a simulator: `npx expo run:ios` (or `run:android`)
4. In Claude Desktop, instruct Claude to:
   - Use mobile-mcp to navigate each tab and tap test buttons
   - Read `http://localhost:6543/signals/summary` to check signal counts
   - Read `http://localhost:6543/signals?type=error&limit=5` to inspect payloads
   - Or read the file at `tools/signals.log`

### Verification Matrix

| Feature | Trigger (in app) | Verify (mock collector) |
|---------|-------------------|-------------------------|
| Logs | Tap level buttons on Logs tab | `GET /signals?type=log` — check level and message |
| Errors | Tap "Send Basic Error" on Errors tab | `GET /signals?type=error` — check type, value, stacktrace |
| Events | Tap "Send Event" on Events tab | `GET /signals?type=event` — check name and attributes |
| Measurements | Tap "Send Random Measurement" on Events tab | `GET /signals?type=measurement` — check numeric values |
| User metadata | Fill fields and tap "Set User" on User tab | Subsequent signals include user metadata |
| Network | Tap "GET (200)" on Network tab | `GET /signals?type=measurement` — look for http_request type |
| Pause/Unpause | Tap "Pause for 3s" on User tab | Signals sent during pause should not appear |
| Console capture | Tap "Console Auto-Capture" on Logs tab | `GET /signals?type=log` — auto-captured console output |
| Session | Tap "Set Session" on User tab | Subsequent signals include session ID |
| Views | Tap "Set View: Home" on User tab | Subsequent signals include view name |

## Troubleshooting

### "Faro Init Failed" screen on launch

- Ensure the native module is linked. For iOS, run `cd ios && pod install`. For Android, the auto-linking should handle it.
- Check that you ran `npx expo run:ios` (or `run:android`), not `npx expo start` — the native build is required for the native module.

### No signals appearing in the collector

- Confirm the collector is running: `curl http://localhost:6543/health`
- For Android Emulator: the app uses `10.0.2.2` to reach the host machine's localhost. Make sure nothing is blocking port 6543.
- For physical devices: edit `src/faro.ts` and set `COLLECTOR_URL` to your machine's LAN IP.
- Check the Metro console for errors during initialization.

### iOS build fails with CocoaPods errors

```bash
cd ios
pod deintegrate
pod install
cd ..
npx expo run:ios
```

### Android build fails

- Ensure you have SDK 34 installed in Android Studio's SDK Manager.
- Ensure JDK 17 is installed and `JAVA_HOME` is set.

### Signals log file gets large

The collector auto-rotates `tools/signals.log` at 10 MB (configurable via `MAX_LOG_SIZE`). You can also clear it:

```bash
curl -X DELETE http://localhost:6543/signals
> tools/signals.log   # truncate the log file
```
