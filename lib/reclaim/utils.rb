# frozen_string_literal: true

require 'time'
require 'date'

module Reclaim
  # Utility methods for common operations
  module Utils
    # Format task for display
    def self.format_task(task)
      status_icon = task.completed? ? "✓" : "○"
      due_str = task.due_date ? " (due: #{task.due_date_formatted})" : ""

      "#{status_icon} #{task.title}#{due_str}\n" \
      "   ID: #{task.id} | Priority: #{task.priority} | Status: #{task.status}"
    end

    # Format task list for display
    def self.format_task_list(tasks, title = "Tasks")
      return "No tasks found." if tasks.empty?

      output = "\n#{title}:\n"
      output += "-" * 50 + "\n"

      tasks.each do |task|
        output += format_task(task) + "\n"
      end

      output += "\nTotal: #{tasks.length} tasks\n"
      output
    end

    # Parse various date formats into ISO string
    def self.parse_date(date_input)
      return nil unless date_input

      case date_input
      when Time
        date_input.iso8601
      when Date
        date_input.to_time.iso8601
      when String
        # Try to parse and convert to ISO format
        Time.parse(date_input).iso8601
      else
        date_input.to_s
      end
    rescue ArgumentError
      date_input.to_s
    end

    # Format datetime for API (UTC with Z suffix like the Python SDK)
    def self.format_datetime_for_api(date_input)
      return nil unless date_input

      case date_input
      when Time
        date_input.utc.iso8601
      when Date
        date_input.to_time.utc.iso8601
      when String
        # Try to parse and convert to UTC ISO format with Z suffix
        Time.parse(date_input).utc.iso8601
      else
        Time.parse(date_input.to_s).utc.iso8601
      end
    rescue ArgumentError
      date_input.to_s
    end

    # Validate priority value
    def self.validate_priority(priority)
      return :p3 unless priority

      priority = priority.to_s.downcase.to_sym
      Task::PRIORITIES.key?(priority) ? priority : :p3
    end

    # Validate duration value
    def self.validate_duration(duration)
      return 1.0 unless duration

      duration = duration.to_f
      duration.positive? ? duration : 1.0
    end
  end
end
