#
#  Copyright © 2020 Bitlica Inc. All rights reserved.
#

Pod::Spec.new do |s|
  s.name         = 'SkarbSDK'
  s.version      = '0.1.8'
  s.swift_version = '5.0'
  s.summary      = 'Summary'
  s.description  = 'Description'
  s.homepage     = 'https://github.com/bitlica/SkarbSDK'
  s.license      = 'MIT'
  s.author       = { "Art" => "support@bitlica.com" }
  s.platform     = :ios, '11.0'
  s.ios.deployment_target = '11.0'
  s.source       = { :git => "https://github.com/bitlica/SkarbSDK.git", :tag => "#{s.version}" }
  s.source_files  = 'SkarbSDK/Classes/**/*'
end
