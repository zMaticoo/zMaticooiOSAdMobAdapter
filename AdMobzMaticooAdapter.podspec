#
# Be sure to run `pod lib lint AdMobzMaticooAdapter.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'AdMobzMaticooAdapter'
  s.version          = '2.0.0'
  s.summary          = 'A short description of AdMobzMaticooAdapter.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
This is zMaticoo iOS SDK AdMob Adaper.
                       DESC

  s.homepage         = 'https://www.zmaticoo.com'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { '15967863@qq.com' => 'lovely-kitty@live.cn' }
  s.source           = { :git => 'https://github.com/zMaticoo/zMaticooiOSAdMobAdapter.git', :tag => s.version.to_s }
  
  s.ios.deployment_target = '12.0'
  s.source_files = 'AdMobzMaticooAdapter/Classes/**/*'
  
  # s.resource_bundles = {
  #   'AdMobzMaticooAdapter' => ['AdMobzMaticooAdapter/Assets/*.png']
  # }


# ―――  Spec License  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  Licensing your code is important. See https://choosealicense.com for more info.
  #  CocoaPods will detect a license file if there is a named LICENSE*
  #  Popular ones are 'MIT', 'BSD' and 'Apache License, Version 2.0'.
  #

  #spec.license      = "MIT (example)"
   s.dependency 'Google-Mobile-Ads-SDK'
   s.dependency 'zMaticoo'
   s.static_framework = true

# ――― Source Code ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  CocoaPods is smart about how it includes source code. For source files
  #  giving a folder will include any swift, h, m, mm, c & cpp files.
  #  For header files it will include any header in the folder.
  #  Not including the public_header_files will make all headers public.
  #

  s.source_files  = "Classes", "Classes/**/*.{h,m}"
  #spec.exclude_files = "Classes/Exclude"

  # spec.public_header_files = "Classes/**/*.h"

end
