#!/usr/bin/env ruby
# Add widget dependency to HomekitControl macOS target
# Created by Jordan Koch

require 'xcodeproj'

project_path = '/Volumes/Data/xcode/HomekitControl/HomekitControl.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "Adding widget dependency to macOS target..."

# Find targets
macos_target = project.targets.find { |t| t.name == 'HomekitControl-macOS' }
widget_target = project.targets.find { |t| t.name == 'HomekitControl-Widget' }

if macos_target && widget_target
  # Check if already has dependency
  existing = macos_target.dependencies.find { |d| d.target == widget_target }

  if existing
    puts "Dependency already exists"
  else
    # Add dependency
    macos_target.add_dependency(widget_target)
    puts "Added widget dependency"
  end

  # Check for embed phase
  embed_phase = macos_target.build_phases.find { |p|
    p.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase) &&
    p.name == 'Embed App Extensions'
  }

  unless embed_phase
    embed_phase = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
    embed_phase.name = 'Embed App Extensions'
    embed_phase.dst_subfolder_spec = '13'  # PlugIns folder
    embed_phase.dst_path = ''
    macos_target.build_phases << embed_phase
    puts "Created Embed App Extensions phase"
  end

  # Add widget to embed phase if not already there
  widget_product = widget_target.product_reference
  existing_file = embed_phase.files.find { |f| f.file_ref == widget_product }

  unless existing_file
    build_file = embed_phase.add_file_reference(widget_product)
    build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
    puts "Added widget to embed phase"
  end
else
  puts "Could not find targets"
  puts "macOS target: #{macos_target}"
  puts "Widget target: #{widget_target}"
end

project.save
puts "Done!"
