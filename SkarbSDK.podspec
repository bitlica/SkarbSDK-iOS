#
#  Copyright © 2020 Bitlica Inc. All rights reserved.
#

Pod::Spec.new do |s|
  s.name         = 'SkarbSDK'
  s.version      = '0.3.3'
  s.swift_version = '5.0'
  s.summary      = 'Summary'
  s.description  = 'Description'
  s.homepage     = 'https://github.com/bitlica/SkarbSDK'
  s.license      = 'MIT'
  s.author       = { "Bitlica Inc" => "support@bitlica.com" }
  s.platform     = :ios, '11.2'
  s.ios.deployment_target = '11.2'
  s.source       = { :git => "https://github.com/bitlica/SkarbSDK.git", :tag => "#{s.version}" }
  s.source_files  = 'SkarbSDK/Classes/**/*'
  s.frameworks = 'Foundation', 'AdSupport', 'UIKit', 'StoreKit'
  s.dependency 'gRPC-Swift', '1.0.0-alpha.21'
end
