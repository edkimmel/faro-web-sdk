import { NativeModules, Platform } from 'react-native';

import type { Spec } from './NativeFaroModule';

// Try TurboModule first (New Architecture), fall back to old bridge
let NativeFaroModule: Spec | null = null;

try {
  // New Architecture (TurboModules)
  NativeFaroModule = require('./NativeFaroModule').default;
} catch {
  // Old Architecture fallback
}

if (!NativeFaroModule) {
  const { FaroReactNative } = NativeModules;
  if (!FaroReactNative) {
    throw new Error(
      `FaroReactNative native module not found. Make sure the native module is properly linked.\n` +
        `Platform: ${Platform.OS}\n` +
        `- If you are using React Native >= 0.73 with New Architecture enabled, ` +
        `make sure TurboModules are configured correctly.\n` +
        `- If you are using the old architecture, make sure the native module is linked.`
    );
  }
  NativeFaroModule = FaroReactNative as Spec;
}

export { NativeFaroModule };
