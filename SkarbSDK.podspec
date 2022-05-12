#
#  Copyright © 2020 Bitlica Inc. All rights reserved.
#

Pod::Spec.new do |s|
  s.name         = 'SkarbSDK'
  s.version      = '0.5.6'
  s.swift_version = '5.0'
  s.summary      = 'Summary'
  s.description  = 'Description'
  s.homepage     = 'https://github.com/bitlica/SkarbSDK'
  s.license      = 'MIT'
  s.author       = { "Bitlica Inc" => "support@bitlica.com" }
  s.platform     = :ios, '11.3'
  s.ios.deployment_target = '11.3'
  s.source       = { :git => "https://github.com/bitlica/SkarbSDK.git", :tag => "#{s.version}" }
  s.source_files  = 'Sources/SkarbSDK/**/*'
  s.frameworks = 'Foundation', 'AdSupport', 'UIKit', 'StoreKit', 'AppTrackingTransparency', 'AdServices'
  s.dependency 'gRPC-Swift', '1.7.3'
  s.dependency 'ReachabilitySwift', '5.0.0'
end
