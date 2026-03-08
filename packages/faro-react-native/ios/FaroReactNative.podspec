Pod::Spec.new do |s|
  s.name         = "FaroReactNative"
  s.version      = "1.0.0"
  s.summary      = "Grafana Faro React Native SDK - native bridge module"
  s.homepage     = "https://github.com/grafana/faro-web-sdk"
  s.license      = "Apache-2.0"
  s.author       = "Grafana Labs"
  s.source       = { :git => "https://github.com/grafana/faro-web-sdk.git", :tag => s.version }

  s.ios.deployment_target = "14.0"
  s.swift_version = "5.9"

  s.source_files = "FaroReactNative/**/*.{swift,h,m,mm}"

  install_modules_dependencies(s)
  s.dependency "FaroSDK"
end
