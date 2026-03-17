#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('/Volumes/Data/xcode/HomekitControl/HomekitControl.xcodeproj')

macos_target = project.targets.find { |t| t.name == 'HomekitControl-macOS' }
widget_target = project.targets.find { |t| t.name == 'HomekitControl-Widget' }

macos_bundle_id = nil
macos_target.build_configurations.each do |config|
  macos_bundle_id = config.build_settings['PRODUCT_BUNDLE_IDENTIFIER']
  break if macos_bundle_id
end

puts "macOS bundle ID: #{macos_bundle_id}"

widget_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "#{macos_bundle_id}.widget"
end

puts "Widget bundle ID set to: #{macos_bundle_id}.widget"

project.save
puts "Done!"
