/**
 * Mock Faro Collector
 *
 * A minimal HTTP server that accepts payloads from the native Faro Android/iOS
 * SDKs and writes them to a log file that Claude (via mobile-mcp or file read)
 * can inspect.
 *
 * The native SDKs POST JSON payloads to the collector URL. This server:
 *   1. Accepts any POST to any path
 *   2. Parses and pretty-prints the payload
 *   3. Appends to signals.log (newest last)
 *   4. Exposes GET /signals — returns the last N signals as JSON
 *   5. Exposes GET /signals/summary — returns counts by signal type
 *   6. Exposes GET /health — liveness check
 *   7. Exposes DELETE /signals — clears the log
 *
 * Usage:
 *   node mock-collector.mjs                     # default port 6543
 *   PORT=8080 node mock-collector.mjs           # custom port
 */

import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PORT = parseInt(process.env.PORT || '6543', 10);
const LOG_FILE = path.join(__dirname, 'signals.log');
const MAX_SIGNALS_IN_MEMORY = 500;

// In-memory ring buffer of received signals
const signals = [];

function timestamp() {
  return new Date().toISOString();
}

function appendToLog(entry) {
  const line = JSON.stringify(entry) + '\n';
  fs.appendFileSync(LOG_FILE, line);
}

function classifySignal(payload) {
  // The native Faro SDKs send different signal types. Try to detect them.
  if (payload.logs || payload.log) return 'log';
  if (payload.exceptions || payload.exception || payload.error) return 'error';
  if (payload.measurements || payload.measurement) return 'measurement';
  if (payload.events || payload.event) return 'event';
  if (payload.traces || payload.resourceSpans) return 'trace';
  return 'unknown';
}

function handlePost(req, res) {
  let body = '';
  req.on('data', (chunk) => { body += chunk; });
  req.on('end', () => {
    let parsed;
    try {
      parsed = JSON.parse(body);
    } catch {
      parsed = { rawBody: body };
    }

    const entry = {
      receivedAt: timestamp(),
      method: req.method,
      path: req.url,
      headers: {
        'content-type': req.headers['content-type'],
        'user-agent': req.headers['user-agent'],
        'x-api-key': req.headers['x-api-key'],
      },
      signalType: classifySignal(parsed),
      payload: parsed,
    };

    signals.push(entry);
    if (signals.length > MAX_SIGNALS_IN_MEMORY) {
      signals.splice(0, signals.length - MAX_SIGNALS_IN_MEMORY);
    }

    appendToLog(entry);

    const count = signals.length;
    console.log(
      `[${entry.receivedAt}] ${entry.signalType.toUpperCase()} received ` +
      `(${req.url}) — ${count} total`
    );

    // Native SDKs expect 2xx
    res.writeHead(202, {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    });
    res.end(JSON.stringify({ status: 'accepted' }));
  });
}

function handleGetSignals(req, res) {
  const url = new URL(req.url, `http://localhost:${PORT}`);
  const limit = Math.min(parseInt(url.searchParams.get('limit') || '50', 10), MAX_SIGNALS_IN_MEMORY);
  const typeFilter = url.searchParams.get('type');

  let filtered = typeFilter
    ? signals.filter((s) => s.signalType === typeFilter)
    : signals;

  const result = filtered.slice(-limit);

  res.writeHead(200, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
  });
  res.end(JSON.stringify({
    total: signals.length,
    returned: result.length,
    filter: typeFilter || 'all',
    signals: result,
  }, null, 2));
}

function handleGetSummary(req, res) {
  const counts = {};
  for (const s of signals) {
    counts[s.signalType] = (counts[s.signalType] || 0) + 1;
  }

  res.writeHead(200, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
  });
  res.end(JSON.stringify({
    total: signals.length,
    counts,
    lastReceivedAt: signals.length > 0 ? signals[signals.length - 1].receivedAt : null,
  }, null, 2));
}

function handleDelete(req, res) {
  signals.length = 0;
  try { fs.unlinkSync(LOG_FILE); } catch {}
  res.writeHead(200, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
  });
  res.end(JSON.stringify({ status: 'cleared' }));
  console.log(`[${timestamp()}] Signals cleared`);
}

function handleHealth(req, res) {
  res.writeHead(200, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
  });
  res.end(JSON.stringify({
    status: 'ok',
    uptime: process.uptime(),
    signalCount: signals.length,
  }));
}

const server = http.createServer((req, res) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, x-api-key, Authorization',
    });
    res.end();
    return;
  }

  // Route
  if (req.method === 'GET' && req.url === '/health') {
    return handleHealth(req, res);
  }
  if (req.method === 'GET' && req.url?.startsWith('/signals/summary')) {
    return handleGetSummary(req, res);
  }
  if (req.method === 'GET' && req.url?.startsWith('/signals')) {
    return handleGetSignals(req, res);
  }
  if (req.method === 'DELETE' && req.url?.startsWith('/signals')) {
    return handleDelete(req, res);
  }

  // Everything else (POST, PUT) — treat as signal ingestion
  if (req.method === 'POST' || req.method === 'PUT') {
    return handlePost(req, res);
  }

  res.writeHead(404);
  res.end('Not found');
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`
╔══════════════════════════════════════════════════════════════╗
║  Faro Mock Collector running on http://0.0.0.0:${String(PORT).padEnd(5)}        ║
║                                                              ║
║  Endpoints:                                                  ║
║    POST   /*              — ingest signals (any path)        ║
║    GET    /signals        — list signals (?limit=N&type=X)   ║
║    GET    /signals/summary — counts by type                  ║
║    GET    /health         — liveness                         ║
║    DELETE /signals        — clear all                        ║
║                                                              ║
║  Log file: signals.log                                       ║
║                                                              ║
║  For the example app, set COLLECTOR_URL to:                  ║
║    iOS Simulator:  http://localhost:${String(PORT).padEnd(5)}/collect          ║
║    Android Emu:    http://10.0.2.2:${String(PORT).padEnd(5)}/collect           ║
║    Physical device: http://<your-ip>:${String(PORT).padEnd(5)}/collect        ║
╚══════════════════════════════════════════════════════════════╝
  `);
});
