platform :ios, '9.0'
ENV['COCOAPODS_DISABLE_STATS'] = "true"

def shared_pods
  pod 'zipzap'
  pod 'Reusable'
  pod 'SnapKit'
  pod 'Fabric'
  pod 'Crashlytics'
end

target 'Certificate' do
  use_frameworks!
  shared_pods
end

target 'Inspect' do
  use_frameworks!
  shared_pods
  target 'InspectTests' do
    inherit! :search_paths
  end
end
