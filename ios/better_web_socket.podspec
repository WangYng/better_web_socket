#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint better_web_socket.podspec' to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'better_web_socket'
  s.version          = '0.0.5'
  s.summary          = 'Advanced web socket based on web_socket_channel.'
  s.description      = <<-DESC
Advanced web socket based on web_socket_channel.
                       DESC
  s.homepage         = 'https://github.com/WangYng/better_web_socket'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'wangyng' => 'wangyangisgood@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.platform = :ios, '8.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
end
