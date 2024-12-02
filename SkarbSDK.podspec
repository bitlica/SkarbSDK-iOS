#
#  Copyright © 2020 Bitlica Inc. All rights reserved.
#

Pod::Spec.new do |s|
  s.name         = 'SkarbSDK'
  s.version      = '0.6.20'
  s.swift_version = '5.4'
  s.summary      = 'Summary'
  s.description  = 'Description'
  s.homepage     = 'https://github.com/bitlica/SkarbSDK'
  s.license      = 'MIT'
  s.author       = { "Bitlica Inc" => "support@bitlica.com" }
  s.platform     = :ios, '12.'
  s.ios.deployment_target = '12.0'
  s.source       = { :git => "https://github.com/bitlica/SkarbSDK.git", :tag => "#{s.version}" }
  s.source_files  = 'Sources/SkarbSDK/**/*'
  s.frameworks = 'Foundation', 'AdSupport', 'UIKit', 'StoreKit', 'AppTrackingTransparency', 'AdServices'
  s.dependency 'gRPC-Swift', '1.8.0'
  s.dependency 'SwiftProtobuf', '1.24.0'
  s.dependency 'ReachabilitySwift', '5.2.4'
end
