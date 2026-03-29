Pod::Spec.new do |s|
  s.name             = 'PilotSDK'
  s.version          = '1.0.32'
  s.summary          = 'Pilot remote debugging SDK for iOS'
  s.description      = <<-DESC
    PilotSDK provides real-time remote debugging, logging, metrics collection,
    and UI widget interaction for iOS applications via the Pilot web dashboard.
  DESC
  s.homepage         = 'https://github.com/irov/swiftpilot'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'irov' => 'levchenko.yuriy.vladimirovich@gmail.com' }
  s.source           = { :git => 'https://github.com/irov/swiftpilot.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'
  s.macos.deployment_target = '10.15'
  s.swift_versions = ['5.9']

  s.source_files = 'Sources/PilotSDK/**/*.swift'

  s.frameworks = 'Foundation'
  s.ios.frameworks = 'UIKit'
end
