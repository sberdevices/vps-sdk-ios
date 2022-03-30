Pod::Spec.new do |s|
  s.name             = 'VPSNMobile'
  s.version          = '0.3.0'
  s.summary          = 'VPSNMobile'
  s.homepage         = 'https://github.com/sberdevices/vps-sdk-ios'
  s.license          = { :type => 'Sber Public License at-nc-sa v.2', :file => 'LICENSE' }
  s.author           = { "ARVRLab" => "arvrlab@sberbank.ru" }
  s.source           = { :git => 'https://github.com/sberdevices/vps-sdk-ios.git', :tag => "#{s.version}" }
  s.ios.deployment_target = '12.0'
  s.swift_version = '5.0'
  s.source_files = 'VPSNMobile/**/*.{swift}'
  s.frameworks   = 'Foundation', 'UIKit', 'CoreLocation', 'SceneKit', 'Accelerate'
  s.weak_frameworks   = 'ARKit'
  s.requires_arc = true
  s.static_framework = true
  s.dependency 'TensorFlowLiteSwift', '2.6.0'
  s.dependency 'TensorFlowLiteSwift/Metal', '2.6.0'
  s.pod_target_xcconfig = {
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64'
  }
  s.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
end
