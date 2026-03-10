import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
} from 'react-native';

import { getFaro } from '../src/faro';
import { StatusBanner } from '../src/StatusBanner';

export default function ErrorsScreen() {
  const [status, setStatus] = useState<'idle' | 'success' | 'error'>('idle');
  const [statusMsg, setStatusMsg] = useState('');
  const [history, setHistory] = useState<string[]>([]);

  const faro = getFaro();

  function record(msg: string) {
    setHistory((prev) => [msg, ...prev].slice(0, 20));
    setStatus('success');
    setStatusMsg(msg);
  }

  function sendManualError() {
    const err = new Error('Manual test error from example app');
    faro?.api.pushError(err);
    record('Sent manual Error via pushError');
  }

  function sendTypedError() {
    const err = new TypeError('Type error: expected string but got number');
    faro?.api.pushError(err, {
      type: 'TypeError',
      context: { component: 'ErrorsScreen', action: 'typed_error_test' },
    });
    record('Sent TypeError with context');
  }

  function sendErrorWithStackFrames() {
    faro?.api.pushError(new Error('Error with custom stack frames'), {
      stackFrames: [
        {
          filename: 'ErrorsScreen.tsx',
          function: 'sendErrorWithStackFrames',
          lineno: 42,
          colno: 10,
        },
        {
          filename: 'app/errors.tsx',
          function: 'onPress',
          lineno: 100,
          colno: 5,
        },
      ],
    });
    record('Sent error with custom stack frames');
  }

  function triggerUnhandledError() {
    // This will be caught by ErrorsInstrumentation's global handler
    record('Triggering unhandled error (check global handler)');
    setTimeout(() => {
      throw new Error('Unhandled error from setTimeout');
    }, 100);
  }

  function triggerUnhandledRejection() {
    // This will be caught by ErrorsInstrumentation's promise rejection handler
    record('Triggering unhandled promise rejection');
    Promise.reject(new Error('Unhandled promise rejection test'));
  }

  function sendNestedError() {
    function innerFunction() {
      function deeperFunction() {
        throw new Error('Deeply nested error for stack trace testing');
      }
      deeperFunction();
    }
    try {
      innerFunction();
    } catch (err) {
      faro?.api.pushError(err as Error);
      record('Sent nested error (check stack trace depth)');
    }
  }

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <StatusBanner status={status} message={statusMsg} />

      <View style={styles.card}>
        <Text style={styles.cardTitle}>Manual Errors (via pushError)</Text>
        <Pressable style={styles.button} onPress={sendManualError}>
          <Text style={styles.buttonText}>Send Basic Error</Text>
        </Pressable>
        <Pressable style={styles.button} onPress={sendTypedError}>
          <Text style={styles.buttonText}>Send TypeError with Context</Text>
        </Pressable>
        <Pressable style={styles.button} onPress={sendErrorWithStackFrames}>
          <Text style={styles.buttonText}>Send Error with Custom Stack</Text>
        </Pressable>
        <Pressable style={styles.button} onPress={sendNestedError}>
          <Text style={styles.buttonText}>Send Nested Error</Text>
        </Pressable>
      </View>

      <View style={styles.card}>
        <Text style={styles.cardTitle}>Auto-Capture Tests</Text>
        <Text style={styles.warningText}>
          These trigger real unhandled errors. The app may show an error screen
          in development mode.
        </Text>
        <Pressable
          style={[styles.button, styles.dangerBtn]}
          onPress={triggerUnhandledError}
        >
          <Text style={styles.buttonText}>Trigger Unhandled Error</Text>
        </Pressable>
        <Pressable
          style={[styles.button, styles.dangerBtn]}
          onPress={triggerUnhandledRejection}
        >
          <Text style={styles.buttonText}>
            Trigger Unhandled Promise Rejection
          </Text>
        </Pressable>
      </View>

      {history.length > 0 && (
        <View style={styles.card}>
          <Text style={styles.cardTitle}>History ({history.length})</Text>
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
  button: {
    backgroundColor: '#F46800',
    padding: 14,
    borderRadius: 8,
    alignItems: 'center',
    marginBottom: 8,
  },
  dangerBtn: {
    backgroundColor: '#dc3545',
  },
  buttonText: {
    color: '#fff',
    fontWeight: '600',
    fontSize: 15,
  },
  warningText: {
    fontSize: 13,
    color: '#856404',
    backgroundColor: '#fff3cd',
    padding: 10,
    borderRadius: 6,
    marginBottom: 12,
  },
  historyEntry: {
    fontSize: 12,
    color: '#555',
    fontFamily: 'monospace',
    marginBottom: 4,
    paddingVertical: 2,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#eee',
  },
});
