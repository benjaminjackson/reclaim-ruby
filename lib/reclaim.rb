# frozen_string_literal: true

# Reclaim API Ruby Library
#
# A comprehensive Ruby library for interacting with the Reclaim.ai API.
# Provides task management functionality with proper error handling,
# time scheme resolution, and caching.
#
# Environment Variables:
#   RECLAIM_TOKEN - Your Reclaim API token
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

require_relative 'reclaim/version'
require_relative 'reclaim/errors'
require_relative 'reclaim/task'
require_relative 'reclaim/utils'
require_relative 'reclaim/client'
require_relative 'reclaim/cli'

module Reclaim
end
