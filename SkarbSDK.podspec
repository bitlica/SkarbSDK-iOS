#
#  Copyright © 2019 Prodinfire. All rights reserved.
#

Pod::Spec.new do |s|
  s.name         = "SkarbSDK"
  s.version      = "0.1.0"
  s.swift_version = "5.0"
  s.summary      = "Summary"
  s.description  = "Description"
  s.homepage     = "https://github.com/Artfire/SkarbSDK"
  s.license      = "MIT"
  s.author       = { "Artem Hitrik" => "artfire90@gmail.com" }
  s.platform     = :ios, "11.0"
  s.source       = { :git => "https://github.com/Artfire/SkarbSDK.git", :tag => "#{s.version}" }
  s.source_files  = "SkarbSDK/Classes/**/*"
  s.static_framework = true
  #s.vendored_frameworks = 'SkarbSDK/Frameworks/*.framework'
  s.frameworks = 'Foundation'

end
