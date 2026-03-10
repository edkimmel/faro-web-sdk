Pod::Spec.new do |s|
  s.name         = "FaroSDK"
  s.version      = "1.0.0"
  s.summary      = "Grafana Faro SDK for iOS"
  s.homepage     = "https://github.com/edkimmel/faro-web-sdk"
  s.license      = "Apache-2.0"
  s.author       = "Edward Kimmel"
  s.source       = { :git => "https://github.com/edkimmel/faro-web-sdk.git", :tag => s.version }

  s.ios.deployment_target = "14.0"
  s.swift_version = "5.9"

  s.source_files = "Sources/FaroSDK/**/*.swift"
end
