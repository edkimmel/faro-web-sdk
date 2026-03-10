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

export default function EventsScreen() {
  const [status, setStatus] = useState<'idle' | 'success' | 'error'>('idle');
  const [statusMsg, setStatusMsg] = useState('');
  const [history, setHistory] = useState<string[]>([]);
  const [eventName, setEventName] = useState('');

  const faro = getFaro();

  function record(msg: string) {
    setHistory((prev) => [msg, ...prev].slice(0, 20));
    setStatus('success');
    setStatusMsg(msg);
  }

  function sendEvent() {
    const name = eventName.trim() || 'test_event';
    faro?.api.pushEvent(name, {
      attributes: {
        source: 'events_screen',
        timestamp: new Date().toISOString(),
      },
    });
    record(`Event: ${name}`);
    setEventName('');
  }

  function sendEventWithDomain() {
    faro?.api.pushEvent('custom_domain_event', {
      attributes: { action: 'test' },
      domain: 'custom.domain',
    });
    record('Event with custom domain');
  }

  function sendMeasurement() {
    const duration = Math.random() * 1000;
    const size = Math.floor(Math.random() * 10000);
    faro?.api.pushMeasurement('app_performance', {
      render_duration_ms: Math.round(duration * 100) / 100,
      payload_size_bytes: size,
      item_count: Math.floor(Math.random() * 50),
    });
    record(
      `Measurement: render=${duration.toFixed(1)}ms, size=${size}b`
    );
  }

  function sendTimedMeasurement() {
    const start = Date.now();
    record('Timer started...');

    // Simulate async work
    setTimeout(() => {
      const elapsed = Date.now() - start;
      faro?.api.pushMeasurement('timed_operation', {
        duration_ms: elapsed,
      }, {
        context: { operation: 'simulated_work' },
      });
      record(`Timed measurement: ${elapsed}ms`);
    }, 500 + Math.random() * 1500);
  }

  function sendBatchEvents() {
    const count = 5;
    for (let i = 0; i < count; i++) {
      faro?.api.pushEvent(`batch_event_${i + 1}`, {
        attributes: {
          index: String(i + 1),
          total: String(count),
        },
      });
    }
    record(`Sent batch of ${count} events`);
  }

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <StatusBanner status={status} message={statusMsg} />

      <View style={styles.card}>
        <Text style={styles.cardTitle}>Custom Events</Text>
        <TextInput
          style={styles.input}
          placeholder="Event name (default: test_event)"
          value={eventName}
          onChangeText={setEventName}
        />
        <Pressable style={styles.button} onPress={sendEvent}>
          <Text style={styles.buttonText}>Send Event</Text>
        </Pressable>
        <Pressable style={styles.button} onPress={sendEventWithDomain}>
          <Text style={styles.buttonText}>Event with Custom Domain</Text>
        </Pressable>
        <Pressable style={styles.button} onPress={sendBatchEvents}>
          <Text style={styles.buttonText}>Send 5 Events (Batch Test)</Text>
        </Pressable>
      </View>

      <View style={styles.card}>
        <Text style={styles.cardTitle}>Measurements</Text>
        <Pressable style={[styles.button, styles.measureBtn]} onPress={sendMeasurement}>
          <Text style={styles.buttonText}>Send Random Measurement</Text>
        </Pressable>
        <Pressable style={[styles.button, styles.measureBtn]} onPress={sendTimedMeasurement}>
          <Text style={styles.buttonText}>Send Timed Measurement</Text>
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
  measureBtn: {
    backgroundColor: '#6f42c1',
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
    fontSize: 12,
    color: '#555',
    fontFamily: 'monospace',
    marginBottom: 4,
    paddingVertical: 2,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#eee',
  },
});
