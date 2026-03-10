import React, { useEffect, useState } from 'react';
import { Tabs } from 'expo-router';
import { Text, View, StyleSheet, ActivityIndicator } from 'react-native';

import { getInitPromise } from '../src/faro';

export default function RootLayout() {
  const [ready, setReady] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    getInitPromise()
      .then(() => setReady(true))
      .catch((err) => setError(String(err)));
  }, []);

  if (error) {
    return (
      <View style={styles.center}>
        <Text style={styles.errorTitle}>Faro Init Failed</Text>
        <Text style={styles.errorText}>{error}</Text>
        <Text style={styles.hint}>
          Check that the native module is linked and the collector URL is set in
          src/faro.ts
        </Text>
      </View>
    );
  }

  if (!ready) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#F46800" />
        <Text style={styles.loadingText}>Initializing Faro SDK...</Text>
      </View>
    );
  }

  return (
    <Tabs
      screenOptions={{
        tabBarActiveTintColor: '#F46800',
        headerStyle: { backgroundColor: '#F46800' },
        headerTintColor: '#fff',
      }}
    >
      <Tabs.Screen
        name="index"
        options={{ title: 'Dashboard', tabBarLabel: 'Home' }}
      />
      <Tabs.Screen
        name="logs"
        options={{ title: 'Logs', tabBarLabel: 'Logs' }}
      />
      <Tabs.Screen
        name="errors"
        options={{ title: 'Errors', tabBarLabel: 'Errors' }}
      />
      <Tabs.Screen
        name="events"
        options={{ title: 'Events & Measurements', tabBarLabel: 'Events' }}
      />
      <Tabs.Screen
        name="user"
        options={{ title: 'User & Session', tabBarLabel: 'User' }}
      />
      <Tabs.Screen
        name="network"
        options={{ title: 'Network', tabBarLabel: 'Network' }}
      />
    </Tabs>
  );
}

const styles = StyleSheet.create({
  center: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 24,
    backgroundColor: '#fff',
  },
  loadingText: {
    marginTop: 16,
    fontSize: 16,
    color: '#666',
  },
  errorTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#cc0000',
    marginBottom: 12,
  },
  errorText: {
    fontSize: 14,
    color: '#333',
    textAlign: 'center',
    marginBottom: 12,
  },
  hint: {
    fontSize: 13,
    color: '#888',
    textAlign: 'center',
    fontStyle: 'italic',
  },
});
