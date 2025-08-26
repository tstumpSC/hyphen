#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint hyphen_ffi.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'hyphen'
  s.version          = '0.0.1'
  s.summary          = 'Flutter FFI plugin for libhyphen'
  s.description      = 'Static FFI binding to libhyphen using Dart FFI'
  s.homepage         = 'https://your.page'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Name' => 'you@example.com' }
  s.source           = { :path => '.' }

  s.platform         = :ios, '12.0'
  s.dependency       'Flutter'


  s.vendored_frameworks = 'lib/libhyphen.xcframework'
  s.preserve_paths      = 'lib/libhyphen.xcframework'

  s.public_header_files = '../src/wrapper/hyphen_ffi.h'
  s.source_files        = 'Classes/*.{h,m,mm,swift,c}', '../src/wrapper/hyphen_ffi.h'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  }
end
