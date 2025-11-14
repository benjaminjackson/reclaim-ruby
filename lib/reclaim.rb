# frozen_string_literal: true

# Reclaim API Ruby Library
#
# A comprehensive Ruby library for interacting with the Reclaim.ai API.
# Provides task management functionality with proper error handling,
# time scheme resolution, and caching.
#
# Environment Variables:
#   RECLAIM_API_KEY - Your Reclaim API token
#
# Usage:
#   require 'reclaim'
#
#   client = Reclaim::Client.new
#
#   # Create a task
#   task = client.create_task(
#     title: 'Important Work',
#     due_date: '2025-08-15T17:00:00-04:00',
#     priority: :p1,
#     duration: 2.0,
#     time_scheme: 'work'
#   )
#
#   # List tasks
#   tasks = client.list_tasks(filter: :active)
#
#   # Update a task
#   client.update_task(task.id, title: 'Updated Title')
#
#   # Complete a task
#   client.complete_task(task.id)

# Optionally load environment variables from .env files if dotenv is available.
# This maintains zero runtime dependencies while supporting convenient local development.
# Dotenv.load does not overwrite existing ENV vars, so shell variables take precedence.
# .env files are loaded from the current working directory.
begin
  require 'dotenv'
  Dotenv.load('.env.local', '.env')
rescue LoadError
  # dotenv not installed, skip .env loading
rescue => e
  # Malformed .env file or other dotenv error - warn but don't crash
  warn "Warning: Could not load .env file: #{e.message}" if $VERBOSE
end

require_relative 'reclaim/version'
require_relative 'reclaim/errors'
require_relative 'reclaim/task'
require_relative 'reclaim/utils'
require_relative 'reclaim/client'
require_relative 'reclaim/cli'

module Reclaim
end
