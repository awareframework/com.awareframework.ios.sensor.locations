#
# Be sure to run `pod lib lint com.awareframework.ios.sensor.locations.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'com.awareframework.ios.sensor.locations'
  s.version          = '0.7.2'
  s.summary          = 'A Location Sensor Module for AWARE Framework'
  
  # This description is used to generate tags and improve search results.
  #   * Think: What does it do? Why did you write it? What is the focus?
  #   * Try to keep it short, snappy and to the point.
  #   * Write the description between the DESC delimiters below.
  #   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
The locations sensor provides the best location estimate for the users’ current location, automatically. The location data is provided by [Core Location](https://developer.apple.com/documentation/corelocation).
  DESC

  s.homepage         = 'https://github.com/awareframework/com.awareframework.ios.sensor.locations'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'Apache2', :file => 'LICENSE' }
  s.author           = { 'Yuuki Nishiyama' => 'nishiyama@csis.u-tokyo.ac.jp' }
  s.source           = { :git => 'https://github.com/awareframework/com.awareframework.ios.sensor.locations.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.platform              = :ios, '13.0'
  s.ios.deployment_target = '13.0'

  s.swift_version = '5'

  s.source_files = 'com.awareframework.ios.sensor.locations/Classes/**/*'

  s.frameworks = 'CoreLocation'
  s.dependency 'com.awareframework.ios.sensor.core' , '~> 0.7'

end
