module.exports = {
  dependency: {
    platforms: {
      android: {
        packageImportPath: 'import com.edkimmel.faro.reactnative.FaroReactNativePackage;',
        packageInstance: 'new FaroReactNativePackage()',
      },
      ios: {
        podspecPath: './ios/FaroReactNative.podspec',
      },
    },
  },
};
