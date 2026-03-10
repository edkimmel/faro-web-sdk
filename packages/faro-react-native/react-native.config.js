module.exports = {
  dependency: {
    platforms: {
      android: {
        sourceDir: `${__dirname}/android`,
        packageImportPath: 'import com.edkimmel.faro.reactnative.FaroReactNativePackage;',
        packageInstance: 'new FaroReactNativePackage()',
      },
      ios: {
        podspecPath: `${__dirname}/ios/FaroReactNative.podspec`,
      },
    },
  },
};
