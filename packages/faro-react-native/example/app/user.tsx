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

export default function UserScreen() {
  const [status, setStatus] = useState<'idle' | 'success' | 'error'>('idle');
  const [statusMsg, setStatusMsg] = useState('');
  const [userId, setUserId] = useState('user-123');
  const [userEmail, setUserEmail] = useState('test@example.com');
  const [userName, setUserName] = useState('Test User');
  const [currentUser, setCurrentUser] = useState<string>('(not set)');

  const faro = getFaro();

  function setUser() {
    const user = {
      id: userId,
      email: userEmail,
      username: userName,
      attributes: {
        plan: 'pro',
        region: 'us-east-1',
      },
    };
    faro?.api.setUser(user);
    setCurrentUser(JSON.stringify(user, null, 2));
    setStatus('success');
    setStatusMsg(`User set: ${userId}`);
  }

  function resetUser() {
    faro?.api.resetUser();
    setCurrentUser('(not set)');
    setStatus('success');
    setStatusMsg('User reset');
  }

  function setView(viewName: string) {
    faro?.api.setView(viewName);
    setStatus('success');
    setStatusMsg(`View set: ${viewName}`);
  }

  function setSession() {
    const sessionId = `session-${Date.now()}`;
    faro?.api.setSession(sessionId);
    setStatus('success');
    setStatusMsg(`Session set: ${sessionId}`);
  }

  function testPauseUnpause() {
    faro?.pause();
    setStatus('success');
    setStatusMsg('SDK paused - signals will be dropped');

    setTimeout(() => {
      faro?.unpause();
      setStatus('success');
      setStatusMsg('SDK unpaused - signals flowing again');
    }, 3000);
  }

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <StatusBanner status={status} message={statusMsg} />

      <View style={styles.card}>
        <Text style={styles.cardTitle}>Set User Identity</Text>
        <TextInput
          style={styles.input}
          placeholder="User ID"
          value={userId}
          onChangeText={setUserId}
        />
        <TextInput
          style={styles.input}
          placeholder="Email"
          value={userEmail}
          onChangeText={setUserEmail}
        />
        <TextInput
          style={styles.input}
          placeholder="Username"
          value={userName}
          onChangeText={setUserName}
        />
        <Pressable style={styles.button} onPress={setUser}>
          <Text style={styles.buttonText}>Set User</Text>
        </Pressable>
        <Pressable style={[styles.button, styles.dangerBtn]} onPress={resetUser}>
          <Text style={styles.buttonText}>Reset User</Text>
        </Pressable>
      </View>

      <View style={styles.card}>
        <Text style={styles.cardTitle}>Current User</Text>
        <Text style={styles.userInfo}>{currentUser}</Text>
      </View>

      <View style={styles.card}>
        <Text style={styles.cardTitle}>View Tracking</Text>
        <View style={styles.buttonRow}>
          <Pressable
            style={[styles.button, styles.viewBtn]}
            onPress={() => setView('HomeScreen')}
          >
            <Text style={styles.buttonText}>Home</Text>
          </Pressable>
          <Pressable
            style={[styles.button, styles.viewBtn]}
            onPress={() => setView('ProfileScreen')}
          >
            <Text style={styles.buttonText}>Profile</Text>
          </Pressable>
          <Pressable
            style={[styles.button, styles.viewBtn]}
            onPress={() => setView('SettingsScreen')}
          >
            <Text style={styles.buttonText}>Settings</Text>
          </Pressable>
        </View>
      </View>

      <View style={styles.card}>
        <Text style={styles.cardTitle}>Session</Text>
        <Pressable style={styles.button} onPress={setSession}>
          <Text style={styles.buttonText}>Set New Session ID</Text>
        </Pressable>
      </View>

      <View style={styles.card}>
        <Text style={styles.cardTitle}>SDK Control</Text>
        <Pressable style={[styles.button, styles.controlBtn]} onPress={testPauseUnpause}>
          <Text style={styles.buttonText}>
            Pause for 3s then Unpause
          </Text>
        </Pressable>
      </View>
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
  viewBtn: {
    backgroundColor: '#0d6efd',
    flex: 1,
  },
  controlBtn: {
    backgroundColor: '#6c757d',
  },
  buttonText: {
    color: '#fff',
    fontWeight: '600',
    fontSize: 15,
  },
  buttonRow: {
    flexDirection: 'row',
    gap: 8,
  },
  input: {
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 8,
    padding: 12,
    fontSize: 15,
    marginBottom: 8,
  },
  userInfo: {
    fontFamily: 'monospace',
    fontSize: 13,
    color: '#555',
    backgroundColor: '#f8f9fa',
    padding: 12,
    borderRadius: 8,
  },
});
