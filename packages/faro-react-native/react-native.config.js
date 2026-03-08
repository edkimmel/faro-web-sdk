module.exports = {
  dependency: {
    platforms: {
      ios: {
        podspecPath: `${__dirname}/ios/FaroReactNative.podspec`,
      },
      android: {
        sourceDir: `${__dirname}/android`,
      },
    },
  },
};
