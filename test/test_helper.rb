# frozen_string_literal: true

# Load the Redmine helper
# Find Redmine root by looking for the directory containing lib/redmine/version.rb
plugin_test_dir = File.dirname(__FILE__)
plugin_name = 'redmine_auto_close'
redmine_root = nil

# Start from plugin directory and search upward
current = File.expand_path('..', plugin_test_dir)
5.times do
  parent = File.expand_path('..', current)

  # Check all siblings and parent for Redmine installations that have this plugin
  Dir.glob(File.join(parent, '*/')).sort.reverse.each do |dir|
    next unless File.exist?(File.join(dir, 'lib/redmine/version.rb'))
    # Check if this Redmine installation has our plugin (via symlink or direct)
    next unless File.exist?(File.join(dir, 'plugins', plugin_name))

    redmine_root = dir
    break
  end

  break if redmine_root

  current = parent
end

raise 'Could not find Redmine root with this plugin' unless redmine_root

require File.join(redmine_root, 'test/test_helper')
