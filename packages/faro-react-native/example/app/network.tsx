import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
  TextInput,
} from 'react-native';

import { StatusBanner } from '../src/StatusBanner';

export default function NetworkScreen() {
  const [status, setStatus] = useState<'idle' | 'success' | 'error'>('idle');
  const [statusMsg, setStatusMsg] = useState('');
  const [history, setHistory] = useState<string[]>([]);
  const [customUrl, setCustomUrl] = useState('');

  function record(msg: string, isError = false) {
    setHistory((prev) => [msg, ...prev].slice(0, 30));
    setStatus(isError ? 'error' : 'success');
    setStatusMsg(msg);
  }

  async function fetchGet(url: string) {
    try {
      const start = Date.now();
      const resp = await fetch(url);
      const elapsed = Date.now() - start;
      record(`GET ${resp.status} ${url} (${elapsed}ms)`);
    } catch (err) {
      record(`GET FAILED ${url}: ${(err as Error).message}`, true);
    }
  }

  async function fetchPost() {
    const url = 'https://httpbin.org/post';
    try {
      const start = Date.now();
      const resp = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ test: true, timestamp: new Date().toISOString() }),
      });
      const elapsed = Date.now() - start;
      record(`POST ${resp.status} ${url} (${elapsed}ms)`);
    } catch (err) {
      record(`POST FAILED ${url}: ${(err as Error).message}`, true);
    }
  }

  async function fetch404() {
    const url = 'https://httpbin.org/status/404';
    try {
      const start = Date.now();
      const resp = await fetch(url);
      const elapsed = Date.now() - start;
      record(`GET ${resp.status} ${url} (${elapsed}ms)`);
    } catch (err) {
      record(`GET FAILED: ${(err as Error).message}`, true);
    }
  }

  async function fetch500() {
    const url = 'https://httpbin.org/status/500';
    try {
      const start = Date.now();
      const resp = await fetch(url);
      const elapsed = Date.now() - start;
      record(`GET ${resp.status} ${url} (${elapsed}ms)`);
    } catch (err) {
      record(`GET FAILED: ${(err as Error).message}`, true);
    }
  }

  async function fetchTimeout() {
    const url = 'https://httpbin.org/delay/10';
    const controller = new AbortController();
    setTimeout(() => controller.abort(), 3000);

    try {
      const start = Date.now();
      await fetch(url, { signal: controller.signal });
      const elapsed = Date.now() - start;
      record(`GET completed ${url} (${elapsed}ms)`);
    } catch (err) {
      record(`GET ABORTED ${url}: ${(err as Error).message}`, true);
    }
  }

  async function fetchInvalidUrl() {
    const url = 'https://this-domain-does-not-exist-faro-test.invalid/api';
    try {
      await fetch(url);
      record(`GET succeeded unexpectedly: ${url}`);
    } catch (err) {
      record(`GET NETWORK ERROR: ${(err as Error).message}`, true);
    }
  }

  async function fetchParallel() {
    const urls = [
      'https://httpbin.org/get',
      'https://httpbin.org/ip',
      'https://httpbin.org/user-agent',
    ];
    record('Starting 3 parallel requests...');
    const results = await Promise.allSettled(
      urls.map(async (url) => {
        const start = Date.now();
        const resp = await fetch(url);
        return `${resp.status} ${url} (${Date.now() - start}ms)`;
      })
    );
    results.forEach((r) => {
      if (r.status === 'fulfilled') {
        record(`Parallel: ${r.value}`);
      } else {
        record(`Parallel FAILED: ${r.reason}`, true);
      }
    });
  }

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <StatusBanner status={status} message={statusMsg} />

      <View style={styles.card}>
        <Text style={styles.cardTitle}>Fetch Requests</Text>
        <Text style={styles.description}>
          All requests are automatically captured by NetworkInstrumentation and
          forwarded as measurements to the native SDK.
        </Text>
        <Pressable
          style={styles.button}
          onPress={() => fetchGet('https://httpbin.org/get')}
        >
          <Text style={styles.buttonText}>GET (200)</Text>
        </Pressable>
        <Pressable style={styles.button} onPress={fetchPost}>
          <Text style={styles.buttonText}>POST with JSON body</Text>
        </Pressable>
        <Pressable
          style={[styles.button, styles.warnBtn]}
          onPress={fetch404}
        >
          <Text style={styles.buttonText}>GET (404)</Text>
        </Pressable>
        <Pressable
          style={[styles.button, styles.dangerBtn]}
          onPress={fetch500}
        >
          <Text style={styles.buttonText}>GET (500)</Text>
        </Pressable>
      </View>

      <View style={styles.card}>
        <Text style={styles.cardTitle}>Edge Cases</Text>
        <Pressable
          style={[styles.button, styles.dangerBtn]}
          onPress={fetchTimeout}
        >
          <Text style={styles.buttonText}>
            Request Timeout (abort after 3s)
          </Text>
        </Pressable>
        <Pressable
          style={[styles.button, styles.dangerBtn]}
          onPress={fetchInvalidUrl}
        >
          <Text style={styles.buttonText}>Network Error (invalid domain)</Text>
        </Pressable>
        <Pressable style={[styles.button, styles.secondaryBtn]} onPress={fetchParallel}>
          <Text style={styles.buttonText}>3 Parallel Requests</Text>
        </Pressable>
      </View>

      <View style={styles.card}>
        <Text style={styles.cardTitle}>Custom URL</Text>
        <TextInput
          style={styles.input}
          placeholder="https://api.example.com/endpoint"
          value={customUrl}
          onChangeText={setCustomUrl}
          autoCapitalize="none"
          keyboardType="url"
        />
        <Pressable
          style={styles.button}
          onPress={() => {
            if (customUrl.trim()) {
              fetchGet(customUrl.trim());
            }
          }}
        >
          <Text style={styles.buttonText}>Fetch Custom URL</Text>
        </Pressable>
      </View>

      {history.length > 0 && (
        <View style={styles.card}>
          <Text style={styles.cardTitle}>
            Request History ({history.length})
          </Text>
          {history.map((entry, i) => (
            <Text key={i} style={styles.historyEntry}>
              {entry}
            </Text>
          ))}
        </View>
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#f5f5f5' },
  content: { padding: 16 },
  card: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    marginBottom: 16,
    elevation: 2,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 3,
  },
  cardTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
    marginBottom: 12,
  },
  description: {
    fontSize: 13,
    color: '#666',
    marginBottom: 12,
    lineHeight: 20,
  },
  button: {
    backgroundColor: '#F46800',
    padding: 14,
    borderRadius: 8,
    alignItems: 'center',
    marginBottom: 8,
  },
  warnBtn: {
    backgroundColor: '#ffc107',
  },
  dangerBtn: {
    backgroundColor: '#dc3545',
  },
  secondaryBtn: {
    backgroundColor: '#0d6efd',
  },
  buttonText: {
    color: '#fff',
    fontWeight: '600',
    fontSize: 15,
  },
  input: {
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 8,
    padding: 12,
    fontSize: 15,
    marginBottom: 12,
  },
  historyEntry: {
    fontSize: 11,
    color: '#555',
    fontFamily: 'monospace',
    marginBottom: 4,
    paddingVertical: 2,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#eee',
  },
});
