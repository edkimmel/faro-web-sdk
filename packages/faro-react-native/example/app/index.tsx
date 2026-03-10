import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Pressable,
} from 'react-native';

import { getFaro } from '../src/faro';

export default function DashboardScreen() {
  const [deviceInfo, setDeviceInfo] = useState<Record<string, unknown> | null>(
    null
  );

  useEffect(() => {
    const faro = getFaro();
    faro?.api.getDeviceInfo().then(setDeviceInfo).catch(() => {});
  }, []);

  const faro = getFaro();

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Text style={styles.title}>Faro React Native Example</Text>
      <Text style={styles.subtitle}>
        SDK Status: {faro ? 'Initialized' : 'Not initialized'}
      </Text>

      <View style={styles.card}>
        <Text style={styles.cardTitle}>Quick Actions</Text>
        <Pressable
          style={styles.button}
          onPress={() => faro?.api.pushLog('Quick test log from dashboard')}
        >
          <Text style={styles.buttonText}>Send Test Log</Text>
        </Pressable>
        <Pressable
          style={styles.button}
          onPress={() =>
            faro?.api.pushEvent('dashboard_action', {
              attributes: { action: 'quick_test' },
            })
          }
        >
          <Text style={styles.buttonText}>Send Test Event</Text>
        </Pressable>
      </View>

      {deviceInfo && (
        <View style={styles.card}>
          <Text style={styles.cardTitle}>Device Info</Text>
          {Object.entries(deviceInfo).map(([key, value]) => (
            <Text key={key} style={styles.infoRow}>
              {key}: {String(value)}
            </Text>
          ))}
        </View>
      )}

      <View style={styles.card}>
        <Text style={styles.cardTitle}>Verification Guide</Text>
        <Text style={styles.guideText}>
          Use each tab to test a specific SDK feature. After triggering actions,
          check your Grafana Cloud / Faro collector to verify signals are
          received.
        </Text>
        <Text style={styles.guideText}>
          {'\u2022'} Logs tab: send logs at various levels{'\n'}
          {'\u2022'} Errors tab: trigger JS errors and promise rejections{'\n'}
          {'\u2022'} Events tab: send custom events and measurements{'\n'}
          {'\u2022'} User tab: set/reset user identity and sessions{'\n'}
          {'\u2022'} Network tab: make HTTP requests to observe fetch
          instrumentation
        </Text>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  content: {
    padding: 16,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 4,
  },
  subtitle: {
    fontSize: 14,
    color: '#666',
    marginBottom: 20,
  },
  card: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    marginBottom: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 3,
    elevation: 2,
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
  buttonText: {
    color: '#fff',
    fontWeight: '600',
    fontSize: 15,
  },
  infoRow: {
    fontSize: 13,
    color: '#555',
    marginBottom: 4,
    fontFamily: 'monospace',
  },
  guideText: {
    fontSize: 14,
    color: '#555',
    lineHeight: 22,
    marginBottom: 8,
  },
});
