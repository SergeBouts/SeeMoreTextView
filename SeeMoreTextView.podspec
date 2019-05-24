Pod::Spec.new do |spec|
  spec.name         = 'SeeMoreTextView'
  spec.version      = '1.0.0'
  spec.summary      = 'Text view with an expandable See More link'
  spec.homepage     = 'https://github.com/SergeBouts/SeeMoreTextView'
  spec.screenshots  = "#{spec.homepage}/blob/master/screenshot.gif"
  spec.license      = { :type => 'MIT', :file => 'LICENSE' }
  spec.author       = { 'Serge Bouts' => 'sergebouts@gmail.com' }
  spec.platform     = :osx, '10.12'
  spec.osx.deployment_target = '10.12'
  spec.swift_version = '4.2'
  spec.source        = { :git => "#{spec.homepage}.git", :tag => "#{spec.version}" }
  spec.source_files  = 'SeeMoreTextView/**/*.swift'
end