# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/**/*_test.rb', 'test/**/test_*.rb']
  t.verbose = true
end

begin
  require 'yard'
  YARD::Rake::YardocTask.new do |t|
    t.files = ['lib/**/*.rb']
    t.options = ['--markup', 'markdown', '--no-private']
  end
rescue LoadError
  # YARD not available
end

task default: :test
