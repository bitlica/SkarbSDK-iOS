#
#  Copyright © 2020 Bitlica Inc. All rights reserved.
#

Pod::Spec.new do |s|
  s.name         = "SkarbSDK"
  s.version      = "0.1.2"
  s.swift_version = "5.0"
  s.summary      = "Summary"
  s.description  = "Description"
  s.homepage     = "https://github.com/Artfire/SkarbSDK"
  s.license      = "MIT"
  s.author       = { "Art" => "support@bitlica.com" }
  s.platform     = :ios, "11.0"
  s.source       = { :git => "https://github.com/bitlica/SkarbSDK", :tag => "#{s.version}" }
  s.source_files  = "SkarbSDK/Classes/**/*"
  s.static_framework = true
  s.frameworks = 'Foundation', 'StoreKit'

end
