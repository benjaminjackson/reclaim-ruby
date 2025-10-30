# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'reclaim'

require 'minitest/autorun'
require 'minitest/pride'

# Simple test helper for Reclaim integration tests
module ReclaimTestHelper
  # Simple resource tracking for cleanup
  @@created_task_ids = []

  def self.track_task(task_id)
    @@created_task_ids << task_id
  end

  def self.cleanup_all(client)
    @@created_task_ids.reverse_each do |task_id|
      client.delete_task(task_id)
    rescue StandardError => e
      puts "Warning: Failed to cleanup task #{task_id}: #{e.message}"
    end
    @@created_task_ids.clear
  end

  def self.skip_integration_tests?
    ENV['SKIP_INTEGRATION_TESTS'] == 'true'
  end
end
