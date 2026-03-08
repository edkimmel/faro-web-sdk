import React from 'react';
import { View, Text, StyleSheet } from 'react-native';

interface StatusBannerProps {
  status: 'idle' | 'success' | 'error';
  message: string;
}

export function StatusBanner({ status, message }: StatusBannerProps) {
  if (status === 'idle') return null;

  return (
    <View
      style={[
        styles.banner,
        status === 'success' ? styles.success : styles.error,
      ]}
    >
      <Text style={styles.text}>
        {status === 'success' ? '\u2713' : '\u2717'} {message}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  banner: {
    padding: 12,
    borderRadius: 8,
    marginVertical: 8,
  },
  success: {
    backgroundColor: '#d4edda',
  },
  error: {
    backgroundColor: '#f8d7da',
  },
  text: {
    fontSize: 14,
    color: '#333',
  },
});
