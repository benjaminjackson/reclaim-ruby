# frozen_string_literal: true

require 'optparse'

module Reclaim
  # CLI Interface
  class CLI
    def self.add_task_arguments(parser, options)
      parser.on('--title TITLE', 'Task title') { |v| options[:title] = v }
      parser.on('--due DUE', 'Due date (YYYY-MM-DD or YYYY-MM-DDTHH:MM:SS, or "none" to clear)') do |v|
        options[:due_date] = parse_clearable_date(v)
      end
      parser.on('--priority PRIORITY', ['P1', 'P2', 'P3', 'P4'], 'Task priority') { |v| options[:priority] = v.downcase.to_sym }
      parser.on('--duration DURATION', Float, 'Task duration in hours') { |v| options[:duration] = v }
      parser.on('--min-chunk MIN', Float, 'Minimum chunk size in hours') { |v| options[:min_chunk_size] = v }
      parser.on('--max-chunk MAX', Float, 'Maximum chunk size in hours') { |v| options[:max_chunk_size] = v }
      parser.on('--min-work MIN', Float, 'Minimum work duration in hours') { |v| options[:min_work_duration] = v }
      parser.on('--max-work MAX', Float, 'Maximum work duration in hours') { |v| options[:max_work_duration] = v }
      parser.on('--snooze DATETIME', 'Start after this date/time (YYYY-MM-DD or YYYY-MM-DDTHH:MM:SS, or "none" to clear)') do |v|
        options[:snooze_until] = parse_clearable_date(v)
      end
      parser.on('--defer DATETIME', 'Start after this date/time (synonym for --snooze, or "none" to clear)') do |v|
        options[:snooze_until] = parse_clearable_date(v)
      end
      parser.on('--start DATETIME', 'Specific start time (YYYY-MM-DDTHH:MM:SS, or "none" to clear)') do |v|
        options[:start] = parse_clearable_date(v)
      end
      parser.on('--time-scheme SCHEME', 'Time scheme ID or name (e.g., "work", "personal", "Work Hours", or UUID)') { |v| options[:time_scheme] = v }
      parser.on('--split [CHUNK_SIZE]', 'Allow task to be split into smaller chunks. Optional: specify min chunk size in hours (e.g. 0.5 for 30min)') do |v|
        options[:allow_splitting] = true
        options[:split_chunk_size] = v.to_f if v && v.to_f > 0
      end
      parser.on('--private PRIVATE', 'Make task private (true/false)') do |v|
        options[:always_private] = case v.downcase
                                   when 'true', '1', 'yes', 'y' then true
                                   when 'false', '0', 'no', 'n' then false
                                   else
                                     puts "✗ Invalid value for --private. Use true/false"
                                     exit(1)
                                   end
      end
      parser.on('--category CATEGORY', 'Event category') { |v| options[:event_category] = v }
      parser.on('--color COLOR', 'Event color') { |v| options[:event_color] = v }
      parser.on('--notes NOTES', 'Task notes/description') { |v| options[:notes] = v }
    end

    # Parse date values that can be cleared with special keywords
    def self.parse_clearable_date(value)
      return nil if value.nil?
      # Handle special clear keywords
      return nil if ['none', 'clear', 'null', ''].include?(value.downcase.strip)
      # Otherwise return the date string as-is for the API to parse
      value
    end

    def self.show_help_and_exit(message = nil)
      puts "✗ #{message}" if message
      puts <<~HELP
        Reclaim Task CRUD Operations

        Usage: reclaim [COMMAND] [OPTIONS]

        Commands:
          list [FILTER]           List tasks (optional filter: active, completed, overdue)
                                  (default: lists active tasks when no command given)
          create                  Create a new task (requires --title)
          get TASK_ID            Get task details
          update TASK_ID         Update a task
          complete TASK_ID       Mark task as complete (ARCHIVED status)
          delete TASK_ID         Delete a task (permanent deletion)
          list-schemes           List available time schemes
          help                   Show this help message

        Task Options:
          --title TITLE          Task title
          --due DATE             Due date (YYYY-MM-DD or YYYY-MM-DDTHH:MM:SS, or "none" to clear)
          --priority PRIORITY    Task priority (P1, P2, P3, P4)
          --duration HOURS       Task duration in hours (e.g., 0.25 for 15min, 1.5 for 90min)
          --split [CHUNK_SIZE]   Allow task splitting. Optional: min chunk size in hours (default: no splitting)
          --min-chunk HOURS      Minimum chunk size in hours (only with --split)
          --max-chunk HOURS      Maximum chunk size in hours (only with --split)
          --min-work HOURS       Minimum work duration in hours
          --max-work HOURS       Maximum work duration in hours
          --defer DATE           Start after this date/time (synonym for --snooze, or "none" to clear)
          --snooze DATE          Start after this date/time (or "none" to clear)
          --start DATE           Specific start time (or "none" to clear)
          --time-scheme SCHEME   Time scheme ID or name
          --private BOOL         Make task private (true/false)
          --category CATEGORY    Event category
          --color COLOR          Event color
          --notes TEXT           Task notes/description

        Clearing Dates:
          Use "none", "clear", or "null" as the value to remove a date field.
          Examples:
            reclaim update abc123 --due none           # Clear due date
            reclaim update abc123 --defer clear        # Clear deferred start date
            reclaim update abc123 --start null         # Clear specific start time

        Time Scheme Aliases:
          work, working hours, business hours  → Finds schemes containing 'work'
          personal, off hours, private         → Finds schemes containing 'personal'

        Status Values:
          SCHEDULED, IN_PROGRESS, COMPLETE (still active), ARCHIVED (truly complete)

        ID Tracking for GTD Integration:
          Store Reclaim task IDs in NEXT.md as [Reclaim:id] for sync operations.

        Examples:
          reclaim                                   # Lists active tasks (default)
          reclaim list active                       # Lists active tasks (explicit)
          reclaim list completed                    # Lists completed tasks
          reclaim create --title "Important Work" --due 2025-08-15 --priority P1 --duration 2
          reclaim create --title "Research" --duration 3 --split 0.5  # Allow splitting with 30min minimum chunks
          reclaim create --title "Deep Work" --duration 4             # No splitting (default)
          reclaim update abc123 --title "Updated Title" --priority P2
          reclaim complete abc123
          reclaim list-schemes
      HELP
      exit(0)
    end

    def self.run
      command = ARGV.shift || 'list'

      # Handle help flag
      if command == '--help' || command == '-h'
        command = 'help'
      end

      # If no command provided, default to listing active tasks
      if command == 'list' && ARGV.empty?
        ARGV.unshift('active')
      end

      begin
        client = Reclaim::Client.new
      rescue AuthenticationError => e
        puts "✗ #{e.message}"
        exit(1)
      end

      case command
      when 'list'
        filter = ARGV.shift
        if filter && !['active', 'completed', 'overdue'].include?(filter)
          show_help_and_exit("Invalid filter '#{filter}'. Valid options: active, completed, overdue")
        end
        list_tasks(client, filter&.to_sym)

      when 'create'
        options = {}
        parser = OptionParser.new
        add_task_arguments(parser, options)
        parser.parse!(ARGV)

        show_help_and_exit("Task title is required. Use --title TITLE") if options[:title].nil?

        create_task(client, options)

      when 'get'
        task_id = ARGV.shift
        show_help_and_exit("Task ID is required") if task_id.nil?
        get_task(client, task_id)

      when 'update'
        task_id = ARGV.shift
        show_help_and_exit("Task ID is required") if task_id.nil?

        options = {}
        parser = OptionParser.new
        add_task_arguments(parser, options)
        parser.parse!(ARGV)

        show_help_and_exit("No update fields provided") if options.empty?
        update_task(client, task_id, options)

      when 'complete'
        task_id = ARGV.shift
        show_help_and_exit("Task ID is required") if task_id.nil?
        complete_task(client, task_id)

      when 'delete'
        task_id = ARGV.shift
        show_help_and_exit("Task ID is required") if task_id.nil?
        delete_task(client, task_id)

      when 'list-schemes'
        help_aliases = false
        parser = OptionParser.new
        parser.on('--help-aliases', 'Show common aliases for time schemes') { help_aliases = true }
        parser.parse!(ARGV)

        list_time_schemes(client, help_aliases)

      when 'help'
        show_help_and_exit

      else
        show_help_and_exit("Unknown command '#{command}'")
      end

    rescue StandardError => e
      puts "✗ Error: #{e.message}"
      exit(1)
    end

    # CLI command implementations
    def self.list_tasks(client, filter = nil)
      tasks = client.list_tasks(filter: filter)

      if tasks.empty?
        puts "No tasks found#{filter ? " matching filter '#{filter}'" : ''}."
        return
      end

      puts "\nYour Reclaim Tasks#{filter ? " (#{filter})" : ''}:"
      puts '-' * 50

      tasks.each do |task|
        status_icon = task.completed? ? '✓' : '○'
        due_str = task.due_date ? " (due: #{task.due_date_formatted})" : ''

        puts "#{status_icon} #{task.title}#{due_str}"
        puts "   ID: #{task.id} | Priority: #{task.priority} | Status: #{task.status}"
      end

      puts "\nTotal: #{tasks.length} tasks"
    end

    def self.create_task(client, options)
      task = client.create_task(**options)
      puts "✓ Created task: #{task.title} (ID: #{task.id})"
    rescue InvalidRecordError => e
      puts "✗ Error creating task: #{e.message}"
      exit(1)
    end

    def self.get_task(client, task_id)
      task = client.get_task(task_id)

      puts "\nTask: #{task.title}"
      puts "ID: #{task.id}"
      puts "Priority: #{task.priority}"
      puts "Status: #{task.status}"
      puts "Duration: #{task.duration} hours" if task.duration
      puts "Due: #{task.due_date_formatted}" if task.due_date
      puts "Time Scheme: #{task.time_scheme_id}" if task.time_scheme_id
      puts "Private: #{task.always_private}" if task.always_private
      puts "Category: #{task.event_category}" if task.event_category
      puts "Color: #{task.event_color}" if task.event_color
      puts "Notes: #{task.notes}" if task.notes && !task.notes.empty?
    rescue NotFoundError
      puts "✗ Task #{task_id} not found"
      exit(1)
    end

    def self.update_task(client, task_id, options)
      task = client.update_task(task_id, **options)
      puts "✓ Updated task: #{task.title}"
    rescue NotFoundError
      puts "✗ Task #{task_id} not found"
      exit(1)
    rescue InvalidRecordError => e
      puts "✗ Error updating task: #{e.message}"
      exit(1)
    end

    def self.complete_task(client, task_id)
      task = client.complete_task(task_id)
      puts "✓ Completed task: #{task.title}"
    rescue NotFoundError
      puts "✗ Task #{task_id} not found"
      exit(1)
    end

    def self.delete_task(client, task_id)
      client.delete_task(task_id)
      puts "✓ Deleted task: #{task_id}"
    rescue NotFoundError
      puts "✗ Task #{task_id} not found"
      exit(1)
    end

    def self.list_time_schemes(client, help_aliases = false)
      puts client.format_time_schemes

      if help_aliases
        puts "\nCommon Aliases:"
        puts "• work, working hours, business hours → Finds schemes containing 'work'"
        puts "• personal, off hours, off-hours, private → Finds schemes containing 'personal'"
        puts "• You can also use partial matches (e.g., 'Work' matches 'Work Hours')"
      end
    end
  end
end
