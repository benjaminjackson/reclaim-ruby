# frozen_string_literal: true

require_relative 'lib/reclaim/version'

Gem::Specification.new do |spec|
  spec.name = 'reclaim'
  spec.version = Reclaim::VERSION
  spec.authors = ['Benjamin Jackson']
  spec.email = ['ben@hearmeout.co']

  spec.summary = 'Ruby client for Reclaim.ai API'
  spec.description = 'A comprehensive Ruby library for interacting with the Reclaim.ai API. ' \
                     'Provides task management functionality with proper error handling, ' \
                     'time scheme resolution, caching, and a command-line interface.'
  spec.homepage = 'https://github.com/benjaminjackson/reclaim-ruby'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.0.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/benjaminjackson/reclaim-ruby'
  spec.metadata['changelog_uri'] = 'https://github.com/benjaminjackson/reclaim-ruby/blob/main/CHANGELOG.md'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/benjaminjackson/reclaim-ruby/issues'

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir['lib/**/*.rb', 'bin/*', 'LICENSE.txt', 'README.md', 'CHANGELOG.md']
  spec.bindir = 'bin'
  spec.executables = ['reclaim']
  spec.require_paths = ['lib']

  # No runtime dependencies - uses stdlib only
  # Development dependencies are specified in Gemfile
end
