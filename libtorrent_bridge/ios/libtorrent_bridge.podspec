#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint libtorrent_bridge.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'libtorrent_bridge'
  s.version          = '0.0.1'
  s.summary          = 'Flutter bridge for LibTorrent-Swift'
  s.description      = <<-DESC
Flutter bridge for LibTorrent-Swift
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Vendor the LibTorrent framework compiled from the Swift project
  s.vendored_frameworks = 'Frameworks/LibTorrent.framework'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.9'
end
