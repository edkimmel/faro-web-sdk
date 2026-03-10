module.exports = {
  dependency: {
    platforms: {
      android: {
        packageImportPath: 'import com.grafana.faro.reactnative.FaroReactNativePackage;',
        packageInstance: 'new FaroReactNativePackage()',
      },
      ios: {
        podspecPath: './ios/FaroReactNative.podspec',
      },
    },
  },
};
