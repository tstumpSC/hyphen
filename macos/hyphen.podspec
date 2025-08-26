Pod::Spec.new do |s|
  s.name             = 'hyphen'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter FFI plugin project.'
  s.description      = <<-DESC
  A new Flutter FFI plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }

  s.source           = { :path => '.' }

  s.public_header_files = '../src/hyphen_ffi.h'
  s.source_files = 'Classes/*.{h,m,mm,swift,c}', '../src/hyphen_ffi.h'
  s.vendored_libraries = 'lib/libhyphen_ffi.a'
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
  s.pod_target_xcconfig = {
    'OTHER_CFLAGS' => '-Wno-shorten-64-to-32 -Wno-sign-conversion -Wno-implicit-int-conversion',
    'GCC_WARN_64_TO_32_BIT_CONVERSION' => 'NO'
  }
end
