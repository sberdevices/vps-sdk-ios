Pod::Spec.new do |s|
  s.name             = 'VPSNMobile'
  s.version          = '0.1.0'
  s.summary          = 'VPSNMobile'
  s.homepage         = 'https://gitlab.com/labsallday/vps-client-apps/vpsnmobile'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { "Eugene Smolyakov" => "jendby@gmail.com" }
  s.source           = { :git => 'https://gitlab.com/labsallday/vps-client-apps/vpsnmobile.git', :tag => "#{s.version}" }
  s.ios.deployment_target = '12.0'
  s.swift_version = '5.0'
  s.source_files = 'VPSNMobile/**/*.{swift}'
  s.frameworks   = 'Foundation', 'UIKit', 'CoreLocation', 'SceneKit', 'Accelerate'
  s.weak_frameworks   = 'ARKit'
  s.requires_arc = true
  s.static_framework = true
  s.dependency 'TensorFlowLiteSwift', '2.5.0'
  s.pod_target_xcconfig = {
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64'
  }
  s.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
end
