# Podfile
use_frameworks!

target 'QuickToDo' do
    pod 'RxSwift',    '~> 3.0.0-beta.1'
    pod 'RxCocoa',    '~> 3.0.0-beta.1'
end

target 'Quick ToDo Sum' do
    pod 'RxSwift',    '~> 3.0.0-beta.1'
    pod 'RxCocoa',    '~> 3.0.0-beta.1'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['SWIFT_VERSION'] = '3.0'
      config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '10.10'
    end
  end
end
