import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
  TextInput,
} from 'react-native';

import { getFaro } from '../src/faro';
import { StatusBanner } from '../src/StatusBanner';
import type { LogLevel } from '@grafana/faro-react-native';

const LOG_LEVELS: LogLevel[] = ['trace', 'debug', 'info', 'log', 'warn', 'error'];

export default function LogsScreen() {
  const [customMessage, setCustomMessage] = useState('');
  const [status, setStatus] = useState<'idle' | 'success' | 'error'>('idle');
  const [statusMsg, setStatusMsg] = useState('');
  const [sentLogs, setSentLogs] = useState<string[]>([]);

  const faro = getFaro();

  function sendLog(level: LogLevel, message?: string) {
    const msg = message || `Test ${level} log at ${new Date().toISOString()}`;
    try {
      faro?.api.pushLog(msg, { level });
      setSentLogs((prev) => [`[${level}] ${msg}`, ...prev].slice(0, 20));
      setStatus('success');
      setStatusMsg(`Sent ${level} log`);
    } catch (err) {
      setStatus('error');
      setStatusMsg(String(err));
    }
  }

  function sendLogWithContext() {
    try {
      faro?.api.pushLog('Log with context data', {
        level: 'info',
        context: {
          screen: 'logs',
          action: 'test_context',
          timestamp: new Date().toISOString(),
        },
      });
      setSentLogs((prev) =>
        ['[info] Log with context data', ...prev].slice(0, 20)
      );
      setStatus('success');
      setStatusMsg('Sent log with context');
    } catch (err) {
      setStatus('error');
      setStatusMsg(String(err));
    }
  }

  function sendConsoleLog() {
    // This tests the ConsoleInstrumentation - these should be auto-captured
    console.info('Console.info captured by Faro');
    console.warn('Console.warn captured by Faro');
    console.error('Console.error captured by Faro');
    setSentLogs((prev) =>
      [
        '[console] info, warn, error sent via console.*',
        ...prev,
      ].slice(0, 20)
    );
    setStatus('success');
    setStatusMsg('Sent console.info/warn/error (check auto-capture)');
  }

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <StatusBanner status={status} message={statusMsg} />

      <View style={styles.card}>
        <Text style={styles.cardTitle}>Send by Log Level</Text>
        <View style={styles.buttonGrid}>
          {LOG_LEVELS.map((level) => (
            <Pressable
              key={level}
              style={[styles.button, styles[`btn_${level}` as keyof typeof styles] as any]}
              onPress={() => sendLog(level)}
            >
              <Text style={styles.buttonText}>{level.toUpperCase()}</Text>
            </Pressable>
          ))}
        </View>
      </View>

      <View style={styles.card}>
        <Text style={styles.cardTitle}>Custom Log Message</Text>
        <TextInput
          style={styles.input}
          placeholder="Enter a custom log message..."
          value={customMessage}
          onChangeText={setCustomMessage}
        />
        <Pressable
          style={styles.button}
          onPress={() => {
            if (customMessage.trim()) {
              sendLog('info', customMessage.trim());
              setCustomMessage('');
            }
          }}
        >
          <Text style={styles.buttonText}>Send Custom Log</Text>
        </Pressable>
      </View>

      <View style={styles.card}>
        <Text style={styles.cardTitle}>Special Cases</Text>
        <Pressable style={styles.button} onPress={sendLogWithContext}>
          <Text style={styles.buttonText}>Log with Context</Text>
        </Pressable>
        <Pressable style={[styles.button, styles.secondaryBtn]} onPress={sendConsoleLog}>
          <Text style={styles.buttonText}>
            console.* (Auto-capture Test)
          </Text>
        </Pressable>
      </View>

      {sentLogs.length > 0 && (
        <View style={styles.card}>
          <Text style={styles.cardTitle}>
            Sent Logs ({sentLogs.length})
          </Text>
          {sentLogs.map((log, i) => (
            <Text key={i} style={styles.logEntry}>
              {log}
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
  buttonGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  button: {
    backgroundColor: '#F46800',
    padding: 12,
    borderRadius: 8,
    alignItems: 'center',
    marginBottom: 8,
    minWidth: 90,
    flex: 1,
  },
  secondaryBtn: {
    backgroundColor: '#555',
  },
  buttonText: {
    color: '#fff',
    fontWeight: '600',
    fontSize: 13,
  },
  input: {
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 8,
    padding: 12,
    fontSize: 15,
    marginBottom: 12,
  },
  logEntry: {
    fontSize: 12,
    color: '#555',
    fontFamily: 'monospace',
    marginBottom: 4,
    paddingVertical: 2,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#eee',
  },
  btn_trace: { backgroundColor: '#999' },
  btn_debug: { backgroundColor: '#6c757d' },
  btn_info: { backgroundColor: '#0d6efd' },
  btn_log: { backgroundColor: '#198754' },
  btn_warn: { backgroundColor: '#ffc107' },
  btn_error: { backgroundColor: '#dc3545' },
});
