# frozen_string_literal: true

module Reclaim
  # Represents a Reclaim task with all its properties and methods
  class Task
    # Task priority levels matching Reclaim API
    PRIORITIES = {
      p1: 'P1',
      p2: 'P2',
      p3: 'P3',
      p4: 'P4'
    }.freeze

    # Task status values
    STATUSES = %w[
      NEW SCHEDULED IN_PROGRESS COMPLETE ARCHIVED CANCELLED
    ].freeze

    # Event colors for calendar display
    EVENT_COLORS = %w[
      BLUE GREEN YELLOW ORANGE RED PURPLE PINK BROWN GRAY
    ].freeze

    # All task attributes with accessor methods
    attr_accessor :id, :title, :notes, :due_date, :priority, :duration,
                  :min_chunk_size, :max_chunk_size, :min_work_duration,
                  :max_work_duration, :snooze_until, :start, :time_scheme_id,
                  :always_private, :event_category, :event_color, :status,
                  :created_at, :updated_at, :deleted

    def initialize(attributes = {})
      # Convert API field names to internal format
      converted_attrs = {}
      attributes.each do |key, value|
        case key.to_s
        when 'timeChunksRequired'
          converted_attrs['duration'] = (value / 4.0) # Convert from 15-min chunks to hours
        when 'timeSchemeId'
          converted_attrs['time_scheme_id'] = value
        when 'alwaysPrivate'
          converted_attrs['always_private'] = value
        when 'eventCategory'
          converted_attrs['event_category'] = value
        when 'eventColor'
          converted_attrs['event_color'] = value
        when 'minChunkSize'
          converted_attrs['min_chunk_size'] = (value / 4.0) if value
        when 'maxChunkSize'
          converted_attrs['max_chunk_size'] = (value / 4.0) if value
        when 'due'
          converted_attrs['due_date'] = value
        else
          converted_attrs[key.to_s] = value
        end
      end

      converted_attrs.each do |key, value|
        setter = "#{key}="
        public_send(setter, value) if respond_to?(setter)
      end

      # Set defaults
      @priority ||= :p3
      @duration ||= 1.0
      @always_private ||= false
      @deleted ||= false
      @status ||= 'NEW'
    end

    # Convert task to hash for API requests
    def to_h
      {
        id: id,
        title: title,
        notes: notes,
        due_date: due_date,
        priority: priority_for_api,
        duration: duration,
        min_chunk_size: min_chunk_size,
        max_chunk_size: max_chunk_size,
        min_work_duration: min_work_duration,
        max_work_duration: max_work_duration,
        snooze_until: snooze_until,
        start: start,
        time_scheme_id: time_scheme_id,
        always_private: always_private,
        event_category: event_category,
        event_color: event_color,
        status: status,
        created_at: created_at,
        updated_at: updated_at,
        deleted: deleted
      }.compact
    end

    # Check if task is active (not deleted and not archived/cancelled)
    def active?
      !deleted && !%w[ARCHIVED CANCELLED].include?(status)
    end

    # Check if task is completed
    def completed?
      %w[COMPLETE ARCHIVED].include?(status)
    end

    # Check if task is overdue
    def overdue?
      return false unless due_date && active?

      due_time = parse_datetime(due_date)
      due_time && due_time < Time.now
    end

    # Get formatted due date string
    def due_date_formatted
      return nil unless due_date

      parsed = parse_datetime(due_date)
      parsed&.strftime('%Y-%m-%d %H:%M')
    end

    # Get priority as symbol
    def priority_symbol
      case priority
      when 'P1' then :p1
      when 'P2' then :p2
      when 'P3' then :p3
      when 'P4' then :p4
      else :p3
      end
    end

    private

    # Convert priority symbol to API format
    def priority_for_api
      PRIORITIES[priority] || PRIORITIES[priority_symbol] || 'P3'
    end

    # Parse various datetime formats
    def parse_datetime(date_string)
      return nil unless date_string

      Time.parse(date_string.to_s)
    rescue ArgumentError
      nil
    end
  end
end
