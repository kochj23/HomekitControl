#!/usr/bin/env ruby
# Fix widget platform for HomekitControl
# Created by Jordan Koch

require 'xcodeproj'

project_path = '/Volumes/Data/xcode/HomekitControl/HomekitControl.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "Fixing widget platform settings..."

widget_target = project.targets.find { |t| t.name == 'HomekitControl-Widget' }

if widget_target
  widget_target.build_configurations.each do |config|
    config.build_settings['SDKROOT'] = 'macosx'
    config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
    config.build_settings['SUPPORTED_PLATFORMS'] = 'macosx'
    config.build_settings.delete('IPHONEOS_DEPLOYMENT_TARGET')
    config.build_settings.delete('TARGETED_DEVICE_FAMILY')
    puts "Fixed #{config.name} configuration"
  end
else
  puts "Widget target not found"
end

project.save
puts "Done!"
