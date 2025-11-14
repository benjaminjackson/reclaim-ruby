# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'
require 'openssl'

module Reclaim
  # HTTP client for Reclaim API interactions
  class Client
    BASE_URL = 'https://api.app.reclaim.ai/api'

    def initialize(token = nil)
      @token = token || ENV['RECLAIM_API_KEY']
      raise AuthenticationError, 'RECLAIM_API_KEY environment variable not set' unless @token

      @time_schemes_cache = nil
    end

    # Create a new task
    def create_task(title:, due_date: nil, priority: :p3, duration: 1.0,
                    min_chunk_size: nil, max_chunk_size: nil, min_work_duration: nil,
                    max_work_duration: nil, snooze_until: nil, start: nil,
                    time_scheme: nil, always_private: nil, event_category: nil,
                    event_color: nil, notes: nil, allow_splitting: false, split_chunk_size: nil)

      # Resolve time scheme if provided
      time_scheme_id = time_scheme ? resolve_time_scheme_id(time_scheme) : nil
      if time_scheme && !time_scheme_id
        raise InvalidRecordError, "Time scheme '#{time_scheme}' not found. Use list_time_schemes to see available options."
      end

      # Set chunk sizes based on splitting preference
      duration_chunks = (duration * 4).to_i # Convert hours to 15-minute chunks
      if allow_splitting
        # Allow splitting: use provided chunk sizes or defaults
        # Use split_chunk_size if provided, otherwise use min_chunk_size or default
        if split_chunk_size
          min_chunk = (split_chunk_size * 4).to_i
        elsif min_chunk_size
          min_chunk = (min_chunk_size * 4).to_i
        else
          min_chunk = 1 # Default 15 minutes
        end

        max_chunk = max_chunk_size ? (max_chunk_size * 4).to_i : 12 # Default 3 hours
      else
        # Prevent splitting: set both min and max to full duration
        min_chunk = duration_chunks
        max_chunk = duration_chunks
      end

      task_data = {
        title: title,
        priority: Task::PRIORITIES[priority] || 'P3',
        timeChunksRequired: duration_chunks,
        eventCategory: event_category || 'WORK',
        eventSubType: 'FOCUS',
        minChunkSize: min_chunk,
        maxChunkSize: max_chunk
      }

      # Add optional fields (using actual API field names)
      task_data[:due] = Utils.format_datetime_for_api(due_date) if due_date
      task_data[:notes] = notes if notes
      # Note: minChunkSize and maxChunkSize are now set above based on allow_splitting
      task_data[:minWorkDuration] = (min_work_duration * 4).to_i if min_work_duration
      task_data[:maxWorkDuration] = (max_work_duration * 4).to_i if max_work_duration
      task_data[:snoozeUntil] = Utils.format_datetime_for_api(snooze_until) if snooze_until
      task_data[:start] = Utils.format_datetime_for_api(start) if start
      task_data[:timeSchemeId] = time_scheme_id if time_scheme_id
      task_data[:alwaysPrivate] = always_private if always_private
      task_data[:eventCategory] = event_category if event_category
      task_data[:eventColor] = event_color if event_color

      response = make_request(:post, '/tasks', task_data)
      Task.new(response)
    end

    # List all tasks with optional filtering
    def list_tasks(filter: nil)
      response = make_request(:get, '/tasks')
      tasks = response.map { |task_data| Task.new(task_data) }

      # Apply client-side filtering since API doesn't support server-side filtering
      case filter
      when :active
        tasks.select(&:active?)
      when :completed
        tasks.select(&:completed?)
      when :overdue
        tasks.select(&:overdue?)
      else
        tasks
      end
    end

    # Get a specific task by ID
    def get_task(task_id)
      response = make_request(:get, "/tasks/#{task_id}")
      Task.new(response)
    rescue ApiError => e
      raise NotFoundError, "Task #{task_id} not found" if e.status_code == 404

      raise
    end

    # Update an existing task
    def update_task(task_id, title: nil, notes: nil, priority: nil, due_date: :unset,
                    duration: nil, min_chunk_size: nil, max_chunk_size: nil,
                    min_work_duration: nil, max_work_duration: nil, snooze_until: :unset,
                    start: :unset, time_scheme: nil, always_private: nil,
                    event_category: nil, event_color: nil)

      # Build update data with only provided fields
      # Use :unset as sentinel to distinguish "not provided" from "explicitly nil (clear)"
      update_data = {}

      update_data[:title] = title if title
      update_data[:notes] = notes if notes
      update_data[:priority] = Task::PRIORITIES[priority] if priority

      # Handle dates: :unset means not provided, nil means clear, value means set
      if due_date != :unset
        update_data[:due] = due_date.nil? ? nil : Utils.format_datetime_for_api(due_date)
      end

      update_data[:timeChunksRequired] = (duration * 4).to_i if duration
      update_data[:minChunkSize] = (min_chunk_size * 4).to_i if min_chunk_size
      update_data[:maxChunkSize] = (max_chunk_size * 4).to_i if max_chunk_size
      update_data[:minWorkDuration] = (min_work_duration * 4).to_i if min_work_duration
      update_data[:maxWorkDuration] = (max_work_duration * 4).to_i if max_work_duration

      # Handle snooze_until (deferred date)
      if snooze_until != :unset
        update_data[:snoozeUntil] = snooze_until.nil? ? nil : Utils.format_datetime_for_api(snooze_until)
      end

      # Handle start date
      if start != :unset
        update_data[:start] = start.nil? ? nil : Utils.format_datetime_for_api(start)
      end

      update_data[:alwaysPrivate] = always_private if always_private
      update_data[:eventCategory] = event_category if event_category
      update_data[:eventColor] = event_color if event_color

      # Resolve time scheme if provided
      if time_scheme
        time_scheme_id = resolve_time_scheme_id(time_scheme)
        if time_scheme_id
          update_data[:timeSchemeId] = time_scheme_id
        else
          raise InvalidRecordError, "Time scheme '#{time_scheme}' not found"
        end
      end

      raise InvalidRecordError, 'No update fields provided' if update_data.empty?

      response = make_request(:patch, "/tasks/#{task_id}", update_data)
      Task.new(response)
    rescue ApiError => e
      raise NotFoundError, "Task #{task_id} not found" if e.status_code == 404

      raise
    end

    # Mark a task as complete
    def complete_task(task_id)
      # Use PATCH to update status to ARCHIVED to match Reclaim app behavior
      response = make_request(:patch, "/tasks/#{task_id}", { status: 'ARCHIVED' })
      Task.new(response)
    rescue ApiError => e
      raise NotFoundError, "Task #{task_id} not found" if e.status_code == 404

      raise
    end

    # Delete a task
    def delete_task(task_id)
      make_request(:delete, "/tasks/#{task_id}")
      true
    rescue ApiError => e
      raise NotFoundError, "Task #{task_id} not found" if e.status_code == 404

      raise
    end

    # List all available time schemes
    def list_time_schemes
      get_time_schemes
    end

    # Get formatted list of time schemes for display
    def format_time_schemes
      schemes = list_time_schemes
      return "No time schemes found." if schemes.empty?

      output = "\nAvailable Time Schemes:\n"
      output += "-" * 50 + "\n"

      schemes.each do |scheme|
        title = scheme['title'] || 'Untitled'
        scheme_id = scheme['id'] || 'N/A'
        policy_type = scheme['policyType'] || 'N/A'

        output += "• #{title}\n"
        output += "  ID: #{scheme_id}\n"
        output += "  Type: #{policy_type}\n\n"
      end

      output += "Usage: time_scheme: \"Work Hours\" or time_scheme: \"work\"\n"
      output
    end

    private

    # Make HTTP request to Reclaim API
    def make_request(method, endpoint, data = nil)
      uri = URI("#{BASE_URL}#{endpoint}")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER

      # Configure certificate store without CRL checking (OpenSSL 3.x compatibility)
      store = OpenSSL::X509::Store.new
      store.set_default_paths
      http.cert_store = store

      request_class = case method
                      when :get then Net::HTTP::Get
                      when :post then Net::HTTP::Post
                      when :patch then Net::HTTP::Patch
                      when :put then Net::HTTP::Put
                      when :delete then Net::HTTP::Delete
                      else
                        raise ArgumentError, "Unsupported HTTP method: #{method}"
                      end

      request = request_class.new(uri)
      request['Authorization'] = "Bearer #{@token}"
      request['Content-Type'] = 'application/json'
      request['User-Agent'] = 'Reclaim Ruby Client/1.0'

      if data && [:post, :patch, :put].include?(method)
        request.body = data.to_json
      end

      response = http.request(request)

      case response.code.to_i
      when 200..299
        return true if response.body.nil? || response.body.strip.empty?

        JSON.parse(response.body)
      when 401
        raise AuthenticationError, 'Invalid or expired API token'
      when 404
        raise ApiError.new('Resource not found', 404, response.body)
      when 422
        error_msg = 'Validation error'
        if response.body
          begin
            error_data = JSON.parse(response.body)
            error_msg = error_data['message'] || error_data['error'] || error_msg
          rescue JSON::ParserError
            # Use default message if JSON parsing fails
          end
        end
        raise InvalidRecordError, error_msg
      else
        error_msg = "HTTP #{response.code}: #{response.message}"
        raise ApiError.new(error_msg, response.code.to_i, response.body)
      end
    rescue JSON::ParserError => e
      raise ApiError, "Invalid JSON response: #{e.message}"
    rescue StandardError => e
      raise ApiError, "Network error: #{e.message}"
    end

    # Get time schemes with caching
    def get_time_schemes
      return @time_schemes_cache if @time_schemes_cache

      response = make_request(:get, '/timeschemes')
      @time_schemes_cache = response || []
    rescue StandardError => e
      warn "Error fetching time schemes: #{e.message}"
      []
    end

    # Resolve time scheme name to ID with fuzzy matching
    def resolve_time_scheme_id(name_or_id)
      return nil unless name_or_id

      name_or_id = name_or_id.to_s

      # If it looks like a UUID, return as-is
      if name_or_id.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
        return name_or_id
      end

      schemes = get_time_schemes
      return nil if schemes.empty?

      name_lower = name_or_id.downcase

      # Common aliases for quick matching
      aliases = {
        'work' => ['work', 'work hours', 'working hours', 'business hours'],
        'personal' => ['personal', 'personal hours', 'off hours', 'off-hours', 'private']
      }

      # Check aliases first
      aliases.each do |alias_key, alias_list|
        if alias_list.include?(name_lower)
          # Find scheme that contains the alias key in its title
          scheme = schemes.find do |s|
            s['title']&.downcase&.include?(alias_key)
          end
          return scheme['id'] if scheme
        end
      end

      # Direct title matching (exact, case-insensitive)
      scheme = schemes.find { |s| s['title']&.downcase == name_lower }
      return scheme['id'] if scheme

      # Partial matching (contains)
      scheme = schemes.find { |s| s['title']&.downcase&.include?(name_lower) }
      return scheme['id'] if scheme

      nil
    end
  end
end
