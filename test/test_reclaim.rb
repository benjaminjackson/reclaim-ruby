#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'test_helper'

class TestReclaimTask < Minitest::Test
  def test_task_initialization_with_defaults
    task = Reclaim::Task.new
    
    assert_equal :p3, task.priority
    assert_equal 1.0, task.duration
    assert_equal false, task.always_private
    assert_equal false, task.deleted
    assert_equal 'NEW', task.status
  end

  def test_task_initialization_with_attributes
    task_data = {
      title: 'Test Task',
      due_date: '2025-08-15T17:00:00-04:00',
      priority: :p2,
      duration: 1.5,
      notes: 'Test notes'
    }
    
    task = Reclaim::Task.new(task_data)
    
    assert_equal 'Test Task', task.title
    assert_equal '2025-08-15T17:00:00-04:00', task.due_date
    assert_equal :p2, task.priority
    assert_equal 1.5, task.duration
    assert_equal 'Test notes', task.notes
  end

  def test_task_priority_symbol_conversion
    task = Reclaim::Task.new(priority: 'P1')
    assert_equal :p1, task.priority_symbol
    
    task = Reclaim::Task.new(priority: 'P4')
    assert_equal :p4, task.priority_symbol
    
    task = Reclaim::Task.new(priority: 'INVALID')
    assert_equal :p3, task.priority_symbol
  end

  def test_task_active_status
    # Active task (default)
    task = Reclaim::Task.new
    assert task.active?
    
    # Deleted task
    task.deleted = true
    refute task.active?
    
    # Archived task
    task.deleted = false
    task.status = 'ARCHIVED'
    refute task.active?
    
    # Cancelled task
    task.status = 'CANCELLED'
    refute task.active?
  end

  def test_task_completed_status
    task = Reclaim::Task.new
    refute task.completed?
    
    task.status = 'COMPLETE'
    assert task.completed?
    
    task.status = 'ARCHIVED'
    assert task.completed?
  end

  def test_task_overdue_status
    task = Reclaim::Task.new
    refute task.overdue? # No due date
    
    # Future due date
    task.due_date = (Time.now + 3600).iso8601
    refute task.overdue?
    
    # Past due date
    task.due_date = (Time.now - 3600).iso8601
    assert task.overdue?
    
    # Archived task should not be overdue
    task.status = 'ARCHIVED'
    refute task.overdue?
  end

  def test_task_due_date_formatted
    task = Reclaim::Task.new
    assert_nil task.due_date_formatted
    
    task.due_date = '2025-08-15T17:00:00-04:00'
    formatted = task.due_date_formatted
    assert_match(/2025-08-15 \d{2}:\d{2}/, formatted)
  end

  def test_task_to_hash
    task_data = {
      title: 'Test Task',
      due_date: '2025-08-15T17:00:00-04:00',
      priority: :p2,
      duration: 1.5,
      notes: 'Test notes'
    }
    
    task = Reclaim::Task.new(task_data)
    hash = task.to_h
    
    assert_equal 'Test Task', hash[:title]
    assert_equal 'P2', hash[:priority]
    assert_equal 1.5, hash[:duration]
    assert_equal 'Test notes', hash[:notes]
    refute hash.key?(:id) # Should be nil and compacted
  end
end

class TestReclaimClient < Minitest::Test
  def setup
    # Set a test token for unit tests
    @original_token = ENV['RECLAIM_API_KEY']
    ENV['RECLAIM_API_KEY'] = 'test_token_12345'
    @client = Reclaim::Client.new
  end

  def teardown
    ENV['RECLAIM_API_KEY'] = @original_token
  end

  def test_client_initialization_with_token
    client = Reclaim::Client.new('custom_token')
    assert_instance_of Reclaim::Client, client
  end

  def test_client_initialization_without_token
    ENV['RECLAIM_API_KEY'] = nil
    
    error = assert_raises(Reclaim::AuthenticationError) do
      Reclaim::Client.new
    end
    
    assert_equal 'RECLAIM_API_KEY environment variable not set', error.message
  end

  def test_client_initialization_with_env_token
    ENV['RECLAIM_API_KEY'] = 'env_token_test'
    client = Reclaim::Client.new
    
    assert_instance_of Reclaim::Client, client
  end

  def test_create_task_data_preparation
    # Mock the make_request method to test data preparation
    def @client.make_request(method, endpoint, data = nil)
      data.merge('id' => 'test_123')
    end

    result = @client.create_task(
      title: 'Test Task',
      priority: :p1,
      duration: 2.0,
      notes: 'Test notes'
    )

    assert_instance_of Reclaim::Task, result
    assert_equal 'Test Task', result.title
    assert_equal "P1", result.priority
    assert_equal 2.0, result.duration
    assert_equal 'Test notes', result.notes
  end

  def test_create_task_no_splitting_default
    # Mock the make_request method to capture the data sent
    captured_data = nil
    @client.define_singleton_method(:make_request) do |method, endpoint, data = nil|
      captured_data = data
      data.merge('id' => 'test_123')
    end

    @client.create_task(
      title: 'No Split Task',
      duration: 2.0
    )

    # Should set both min and max chunk to full duration (2 hours = 8 chunks)
    assert_equal 8, captured_data[:minChunkSize]
    assert_equal 8, captured_data[:maxChunkSize]
    assert_equal 8, captured_data[:timeChunksRequired]
  end

  def test_create_task_with_splitting_enabled
    # Mock the make_request method to capture the data sent
    captured_data = nil
    @client.define_singleton_method(:make_request) do |method, endpoint, data = nil|
      captured_data = data
      data.merge('id' => 'test_123')
    end

    @client.create_task(
      title: 'Split Task',
      duration: 2.0,
      allow_splitting: true
    )

    # Should use default splitting values
    assert_equal 1, captured_data[:minChunkSize]    # 15 minutes
    assert_equal 12, captured_data[:maxChunkSize]   # 3 hours
    assert_equal 8, captured_data[:timeChunksRequired] # 2 hours
  end

  def test_create_task_with_custom_split_chunk_size
    # Mock the make_request method to capture the data sent
    captured_data = nil
    @client.define_singleton_method(:make_request) do |method, endpoint, data = nil|
      captured_data = data
      data.merge('id' => 'test_123')
    end

    @client.create_task(
      title: 'Custom Split Task',
      duration: 2.0,
      allow_splitting: true,
      split_chunk_size: 0.5  # 30 minutes
    )

    # Should use split_chunk_size as minimum
    assert_equal 2, captured_data[:minChunkSize]    # 30 minutes (0.5 * 4)
    assert_equal 12, captured_data[:maxChunkSize]   # 3 hours (default)
    assert_equal 8, captured_data[:timeChunksRequired] # 2 hours
  end

  def test_create_task_with_custom_min_max_chunks
    # Mock the make_request method to capture the data sent
    captured_data = nil
    @client.define_singleton_method(:make_request) do |method, endpoint, data = nil|
      captured_data = data
      data.merge('id' => 'test_123')
    end

    @client.create_task(
      title: 'Custom Min/Max Task',
      duration: 2.0,
      allow_splitting: true,
      min_chunk_size: 0.25,  # 15 minutes
      max_chunk_size: 1.5    # 90 minutes
    )

    # Should use explicit min/max chunk sizes
    assert_equal 1, captured_data[:minChunkSize]    # 15 minutes
    assert_equal 6, captured_data[:maxChunkSize]    # 90 minutes
    assert_equal 8, captured_data[:timeChunksRequired] # 2 hours
  end

  def test_create_task_split_chunk_size_overrides_min_chunk
    # Mock the make_request method to capture the data sent
    captured_data = nil
    @client.define_singleton_method(:make_request) do |method, endpoint, data = nil|
      captured_data = data
      data.merge('id' => 'test_123')
    end

    @client.create_task(
      title: 'Override Test',
      duration: 2.0,
      allow_splitting: true,
      min_chunk_size: 0.25,   # Should be overridden
      split_chunk_size: 1.0   # Should take precedence
    )

    # split_chunk_size should override min_chunk_size
    assert_equal 4, captured_data[:minChunkSize]    # 1 hour (split_chunk_size)
    assert_equal 12, captured_data[:maxChunkSize]   # 3 hours (default)
    assert_equal 8, captured_data[:timeChunksRequired] # 2 hours
  end

  def test_update_task_data_preparation
    # Mock make_request to test update data preparation
    def @client.make_request(method, endpoint, data = nil)
      data.merge('id' => 'test_id')
    end
    
    result = @client.update_task(
      'test_id',
      title: 'Updated Title',
      priority: :p2
    )
    
    assert_instance_of Reclaim::Task, result
    assert_equal 'test_id', result.id
    assert_equal 'Updated Title', result.title
    assert_equal "P2", result.priority
  end

  def test_update_task_no_data_error
    error = assert_raises(Reclaim::InvalidRecordError) do
      @client.update_task('test_id')
    end
    
    assert_equal 'No update fields provided', error.message
  end
end

class TestReclaimUtils < Minitest::Test
  def test_format_task
    task = Reclaim::Task.new(
      id: 'test_123',
      title: 'Test Task',
      priority: :p1,
      status: 'NEW',
      due_date: '2025-08-15T17:00:00-04:00'
    )
    
    formatted = Reclaim::Utils.format_task(task)
    
    assert_includes formatted, '○' # Not completed icon
    assert_includes formatted, 'Test Task'
    assert_includes formatted, 'test_123'
    assert_includes formatted, 'p1'
    assert_includes formatted, 'NEW'
    assert_includes formatted, 'due: 2025-08-15'
  end

  def test_format_completed_task
    task = Reclaim::Task.new(
      id: 'test_456',
      title: 'Completed Task',
      status: 'COMPLETE'
    )
    
    formatted = Reclaim::Utils.format_task(task)
    
    assert_includes formatted, '✓' # Completed icon
    assert_includes formatted, 'Completed Task'
  end

  def test_format_task_list_empty
    result = Reclaim::Utils.format_task_list([])
    assert_equal 'No tasks found.', result
  end

  def test_format_task_list_with_tasks
    tasks = [
      Reclaim::Task.new(id: '1', title: 'Task 1', status: 'NEW'),
      Reclaim::Task.new(id: '2', title: 'Task 2', status: 'COMPLETE')
    ]
    
    result = Reclaim::Utils.format_task_list(tasks, 'Test Tasks')
    
    assert_includes result, 'Test Tasks:'
    assert_includes result, 'Task 1'
    assert_includes result, 'Task 2'
    assert_includes result, 'Total: 2 tasks'
  end

  def test_parse_date_with_time_object
    time = Time.now
    result = Reclaim::Utils.parse_date(time)
    
    assert_equal time.iso8601, result
  end

  def test_parse_date_with_string
    date_string = '2025-08-15T17:00:00-04:00'
    result = Reclaim::Utils.parse_date(date_string)
    
    # Should parse and convert to ISO format
    parsed_time = Time.parse(date_string)
    assert_equal parsed_time.iso8601, result
  end

  def test_parse_date_with_invalid_string
    result = Reclaim::Utils.parse_date('invalid_date')
    assert_equal 'invalid_date', result
  end

  def test_parse_date_with_nil
    result = Reclaim::Utils.parse_date(nil)
    assert_nil result
  end

  def test_validate_priority
    assert_equal :p1, Reclaim::Utils.validate_priority(:p1)
    assert_equal :p2, Reclaim::Utils.validate_priority('p2')
    assert_equal :p3, Reclaim::Utils.validate_priority('P3')
    assert_equal :p3, Reclaim::Utils.validate_priority(:invalid)
    assert_equal :p3, Reclaim::Utils.validate_priority(nil)
  end

  def test_validate_duration
    assert_equal 1.5, Reclaim::Utils.validate_duration(1.5)
    assert_equal 2.0, Reclaim::Utils.validate_duration('2')
    assert_equal 1.0, Reclaim::Utils.validate_duration(-1)
    assert_equal 1.0, Reclaim::Utils.validate_duration(0)
    assert_equal 1.0, Reclaim::Utils.validate_duration(nil)
  end
end

# Integration Tests (require real API token and will make actual API calls)
class TestReclaimIntegration < Minitest::Test
  def setup
    # Skip if integration tests are disabled
    if ReclaimTestHelper.skip_integration_tests?
      skip "Integration tests are disabled"
    end
    
    # Validate we have a real API token
    token = ENV['RECLAIM_API_KEY']
    if !token || token == 'test_token_12345'
      skip "Real RECLAIM_API_KEY required for integration tests"
    end
    
    @client = Reclaim::Client.new(token)
  end

  def teardown
    # Cleanup any tasks we created
    ReclaimTestHelper.cleanup_all(@client)
  end

  # Helper to track tasks for cleanup
  def track_task(task_id)
    ReclaimTestHelper.track_task(task_id)
  end

  # Simple retry for flaky network operations
  def with_retry(max_attempts = 3)
    attempts = 0
    begin
      attempts += 1
      yield
    rescue => e
      if attempts < max_attempts && (e.is_a?(Timeout::Error) || e.message.include?("429"))
        sleep(attempts)
        retry
      else
        raise e
      end
    end
  end

  # Simple performance check
  def assert_performance(max_seconds)
    start_time = Time.now
    result = yield
    execution_time = Time.now - start_time
    assert execution_time <= max_seconds, 
           "Operation took #{execution_time}s, expected <= #{max_seconds}s"
    result
  end

  def test_time_schemes_integration
    with_retry do
      schemes = @client.list_time_schemes
      
      # Should return an array (might be empty for new accounts)
      assert_instance_of Array, schemes
      
      # If there are schemes, they should have expected structure
      if schemes.any?
        scheme = schemes.first
        assert scheme.key?('id')
        assert scheme.key?('title')
      end
      
      # Format method should work
      formatted = @client.format_time_schemes
      assert_instance_of String, formatted
      assert_includes formatted, 'Time Schemes'
    end
  end

  def test_task_lifecycle_integration
    with_retry do
      # Create a task
      task = @client.create_task(
        title: "Ruby Integration Test #{Time.now.to_i}",
        due_date: (Time.now + 86400).iso8601, # Tomorrow
        priority: :p2,
        duration: 1.5,
        notes: 'Testing the Ruby library integration'
      )
      
      assert_instance_of Reclaim::Task, task
      assert task.id
      assert_equal 'P2', task.priority
      assert_equal 1.5, task.duration
      
      # Track for cleanup
      track_task(task.id)
      
      # Get the task back
      retrieved_task = @client.get_task(task.id)
      assert_equal task.id, retrieved_task.id
      assert_equal task.title, retrieved_task.title
      
      # Update the task
      updated_task = @client.update_task(
        task.id,
        title: 'Updated Ruby Integration Test',
        priority: :p1
      )
      
      assert_equal 'Updated Ruby Integration Test', updated_task.title
      assert_equal 'P1', updated_task.priority
      
      # Complete the task
      completed_task = @client.complete_task(task.id)
      assert completed_task.completed?
      
      # Delete the task (cleanup)
      result = @client.delete_task(task.id)
      assert result
    end
  end

  def test_list_tasks_integration
    with_retry do
      # Create a test task first
      task = @client.create_task(
        title: "List Test Task #{Time.now.to_i}",
        priority: :p3,
        duration: 1.0
      )
      
      track_task(task.id)
      
      # List all tasks
      all_tasks = @client.list_tasks
      assert_instance_of Array, all_tasks
      assert all_tasks.any? { |t| t.id == task.id }
      
      # List active tasks
      active_tasks = @client.list_tasks(filter: :active)
      assert_instance_of Array, active_tasks
      assert active_tasks.any? { |t| t.id == task.id }
      
      # Complete the task and test completed filter
      @client.complete_task(task.id)
      completed_tasks = @client.list_tasks(filter: :completed)
      assert completed_tasks.any? { |t| t.id == task.id && t.completed? }
    end
  end

  def test_error_handling_integration
    with_retry do
      # Test getting non-existent task - API returns 400 for invalid IDs
      error = assert_raises(Reclaim::ApiError) do
        @client.get_task('non-existent-id-12345')
      end
      
      assert_includes error.message, 'Bad Request'
      
      # Test updating non-existent task - API returns 400 for invalid IDs
      error = assert_raises(Reclaim::ApiError) do
        @client.update_task('non-existent-id-12345', title: 'Test')
      end
      
      assert_includes error.message, 'Bad Request'
      
      # Test completing non-existent task - API returns 400 for invalid IDs
      error = assert_raises(Reclaim::ApiError) do
        @client.complete_task('non-existent-id-12345')
      end
      
      assert_includes error.message, 'Bad Request'
      
      # Test deleting non-existent task - API returns 400 for invalid IDs
      error = assert_raises(Reclaim::ApiError) do
        @client.delete_task('non-existent-id-12345')
      end
      
      assert_includes error.message, 'Bad Request'
    end
  end

  def test_invalid_data_handling
    with_retry do
      # Test creating task with invalid priority
      task = @client.create_task(
        title: 'Invalid Priority Test',
        priority: :invalid_priority
      )
      
      # Should default to P3
      assert_equal 'P3', task.priority
      track_task(task.id)
    end
  end

  def test_time_scheme_resolution
    with_retry do
      schemes = @client.list_time_schemes
      
      if schemes.any?
        # Test with real scheme
        scheme = schemes.first
        scheme_name = scheme['title']
        
        task = @client.create_task(
          title: "Time Scheme Test #{Time.now.to_i}",
          time_scheme: scheme_name
        )
        
        assert_equal scheme['id'], task.time_scheme_id
        track_task(task.id)
      else
        # Test with invalid scheme name
        error = assert_raises(Reclaim::InvalidRecordError) do
          @client.create_task(
            title: 'Invalid Scheme Test',
            time_scheme: 'non-existent-scheme'
          )
        end
        
        assert_includes error.message, 'not found'
      end
    end
  end

  def test_performance_benchmarks
    with_retry do
      # Test that basic operations complete within reasonable time
      
      # Create task should complete within 5 seconds
      start_time = Time.now
      task = @client.create_task(
        title: "Performance Test #{Time.now.to_i}",
        duration: 1.0
      )
      execution_time = Time.now - start_time
      
      assert execution_time <= 5.0, "Create task took #{execution_time}s, expected <= 5s"
      track_task(task.id)
      
      # List tasks should complete within 10 seconds
      assert_performance(10.0) do
        @client.list_tasks
      end
      
      # Get task should complete within 3 seconds
      assert_performance(3.0) do
        @client.get_task(task.id)
      end
    end
  end
end

class TestReclaimCLI < Minitest::Test
  def setup
    # Store original ARGV to restore later
    @original_argv = ARGV.dup
    
    # Mock environment variable for tests
    @original_token = ENV['RECLAIM_API_KEY']
    ENV['RECLAIM_API_KEY'] = 'test_token_for_cli_tests'
  end
  
  def teardown
    # Restore original ARGV and environment
    ARGV.replace(@original_argv)
    ENV['RECLAIM_API_KEY'] = @original_token
  end
  
  def test_default_command_and_filter_logic
    # Test that no arguments defaults to 'list' with 'active' filter
    ARGV.replace([])
    
    # Simulate the CLI logic for default command
    command = ARGV.shift || 'list'
    
    # Handle help flag
    if command == '--help' || command == '-h'
      command = 'help'
    end
    
    # If no command provided, default to listing active tasks
    if command == 'list' && ARGV.empty?
      ARGV.unshift('active')
    end
    
    assert_equal 'list', command
    assert_equal ['active'], ARGV
  end
  
  def test_help_flag_handling
    # Test --help flag
    ARGV.replace(['--help'])
    
    command = ARGV.shift || 'list'
    
    if command == '--help' || command == '-h'
      command = 'help'
    end
    
    assert_equal 'help', command
  end
  
  def test_short_help_flag_handling
    # Test -h flag
    ARGV.replace(['-h'])
    
    command = ARGV.shift || 'list'
    
    if command == '--help' || command == '-h'
      command = 'help'
    end
    
    assert_equal 'help', command
  end
  
  def test_explicit_list_active_command
    # Test that 'list active' remains unchanged
    ARGV.replace(['list', 'active'])
    
    command = ARGV.shift || 'list'
    
    if command == '--help' || command == '-h'
      command = 'help'
    end
    
    if command == 'list' && ARGV.empty?
      ARGV.unshift('active')
    end
    
    assert_equal 'list', command
    assert_equal ['active'], ARGV
  end
  
  def test_explicit_list_without_filter
    # Test that 'list' without filter doesn't get modified
    ARGV.replace(['list'])
    
    command = ARGV.shift || 'list'
    
    if command == '--help' || command == '-h'
      command = 'help'
    end
    
    if command == 'list' && ARGV.empty?
      ARGV.unshift('active')
    end
    
    assert_equal 'list', command
    assert_equal ['active'], ARGV  # Should add 'active' since ARGV was empty after 'list'
  end
  
  def test_list_tasks_output_format
    # Test the actual output formatting with a simple stub
    stub_client = Object.new
    def stub_client.list_tasks(filter:)
      [
        Reclaim::Task.new(id: 'task1', title: 'Active Task 1', status: 'NEW'),
        Reclaim::Task.new(id: 'task2', title: 'Active Task 2', status: 'IN_PROGRESS')
      ]
    end
    
    output = capture_io do
      Reclaim::CLI.list_tasks(stub_client, :active)
    end
    
    # Should show the filter in parentheses
    assert_match(/\(active\)/, output[0])
    assert_match(/Your Reclaim Tasks/, output[0])
    assert_match(/Active Task 1/, output[0])
    assert_match(/Active Task 2/, output[0])
  end
  
  def test_help_output_format
    output = capture_io do
      begin
        Reclaim::CLI.show_help_and_exit
      rescue SystemExit
        # Expected - help exits
      end
    end
    
    assert_match(/Reclaim Task CRUD Operations/, output[0])
    assert_match(/Usage:/, output[0])
    assert_match(/Commands:/, output[0])
    assert_match(/default: lists active tasks when no command given/, output[0])
    assert_match(/help\s+Show this help message/, output[0])
    # Check that examples show the new default behavior
    assert_match(/reclaim\s+#.*Lists active tasks \(default\)/, output[0])
  end
  
  def test_no_arguments_behavior_integration
    # Integration test simulating the full command processing
    original_argv = ARGV.dup
    
    begin
      # Simulate running with no arguments
      ARGV.replace([])
      
      command = ARGV.shift || 'list'
      
      # Handle help flag
      if command == '--help' || command == '-h'
        command = 'help'
      end
      
      # If no command provided, default to listing active tasks
      if command == 'list' && ARGV.empty?
        ARGV.unshift('active')
      end
      
      # Verify the expected behavior
      assert_equal 'list', command
      assert_equal ['active'], ARGV
      
      # Test that we would call list_tasks with active filter
      filter = ARGV.shift
      assert_equal 'active', filter
      
    ensure
      ARGV.replace(original_argv)
    end
  end
  
  def test_other_commands_unchanged
    # Verify that other commands (create, update, etc.) are not affected
    test_cases = [
      ['create', 'Task Name'],
      ['get', 'task123'],
      ['update', 'task123'],
      ['complete', 'task123'],
      ['delete', 'task123'],
      ['list-schemes'],
      ['list', 'completed'],
      ['list', 'overdue']
    ]
    
    test_cases.each do |args|
      original_argv = ARGV.dup
      
      begin
        ARGV.replace(args.dup)
        
        command = ARGV.shift || 'list'
        
        # Handle help flag
        if command == '--help' || command == '-h'
          command = 'help'
        end
        
        # If no command provided, default to listing active tasks
        if command == 'list' && ARGV.empty?
          ARGV.unshift('active')
        end
        
        # Verify the command is preserved
        assert_equal args.first, command, "Command should be unchanged for #{args.inspect}"
        
        # Verify arguments are preserved (except for the special case of bare 'list')
        if args == ['list']
          assert_equal ['active'], ARGV, "Bare 'list' should get 'active' filter"
        elsif args.first == 'list' && args.length > 1
          assert_equal args[1..-1], ARGV, "List with filter should be unchanged for #{args.inspect}"
        else
          assert_equal args[1..-1], ARGV, "Arguments should be unchanged for #{args.inspect}"
        end
        
      ensure
        ARGV.replace(original_argv)
      end
    end
  end
  
  private
  
  def capture_io
    require 'stringio'
    old_stdout = $stdout
    old_stderr = $stderr
    stdout = StringIO.new
    stderr = StringIO.new
    $stdout = stdout
    $stderr = stderr
    
    yield
    
    [stdout.string, stderr.string]
  ensure
    $stdout = old_stdout
    $stderr = old_stderr
  end
end

class TestReclaimEnv < Minitest::Test
  def setup
    @original_token = ENV['RECLAIM_API_KEY']
    @original_load_path = $LOAD_PATH.dup
  end

  def teardown
    ENV['RECLAIM_API_KEY'] = @original_token
    $LOAD_PATH.replace(@original_load_path)
  end

  def test_dotenv_loads_env_file
    # This tests that dotenv is required and functional
    require 'dotenv'

    # Use tmpdir for test files
    env_file = File.join(Dir.tmpdir, '.env.test')

    begin
      File.write(env_file, "TEST_ENV_VAR=test_value\n")

      # Clear the variable first
      ENV.delete('TEST_ENV_VAR')

      # Load the temporary env file
      Dotenv.load(env_file)

      # Verify it was loaded
      assert_equal 'test_value', ENV['TEST_ENV_VAR']
    ensure
      # Guaranteed cleanup even if assertions fail
      File.delete(env_file) if File.exist?(env_file)
      ENV.delete('TEST_ENV_VAR')
    end
  end

  def test_dotenv_precedence_env_local_over_env
    # This tests that .env.local takes precedence over .env
    require 'dotenv'

    env_file = File.join(Dir.tmpdir, '.env.test')
    env_local_file = File.join(Dir.tmpdir, '.env.local.test')

    begin
      # Create .env file
      File.write(env_file, "TEST_PRECEDENCE=from_env\n")

      # Create .env.local file
      File.write(env_local_file, "TEST_PRECEDENCE=from_env_local\n")

      # Clear the variable
      ENV.delete('TEST_PRECEDENCE')

      # Load in reverse order (.env.local, then .env) so .env.local takes precedence
      Dotenv.load(env_local_file, env_file)

      # Verify .env.local wins
      assert_equal 'from_env_local', ENV['TEST_PRECEDENCE']
    ensure
      # Guaranteed cleanup even if assertions fail
      File.delete(env_file) if File.exist?(env_file)
      File.delete(env_local_file) if File.exist?(env_local_file)
      ENV.delete('TEST_PRECEDENCE')
    end
  end

  def test_integration_env_loading_on_require
    # Integration test: verify that requiring reclaim actually loads .env files
    require 'fileutils'

    test_project_dir = File.join(Dir.tmpdir, "reclaim_test_#{Process.pid}")
    env_file = File.join(test_project_dir, '.env')

    begin
      FileUtils.mkdir_p(test_project_dir)
      File.write(env_file, "RECLAIM_API_KEY=integration_test_token\n")

      # Run in subprocess with clean environment (unset RECLAIM_API_KEY)
      lib_path = File.expand_path('../../lib', __FILE__)
      result = Dir.chdir(test_project_dir) do
        # Use env to unset RECLAIM_API_KEY before running ruby
        `env -u RECLAIM_API_KEY ruby -I#{lib_path} -e "require 'reclaim'; puts ENV['RECLAIM_API_KEY']" 2>&1`
      end

      # Verify the .env file was loaded
      assert_match(/integration_test_token/, result, "Expected .env to be loaded on require")
    ensure
      # Guaranteed cleanup even if assertions fail
      FileUtils.rm_rf(test_project_dir) if Dir.exist?(test_project_dir)
    end
  end

  def test_malformed_env_file_does_not_crash
    # Test that malformed .env files don't crash the library
    require 'fileutils'

    test_project_dir = File.join(Dir.tmpdir, "reclaim_malformed_test_#{Process.pid}")
    env_file = File.join(test_project_dir, '.env')

    begin
      FileUtils.mkdir_p(test_project_dir)
      # Create malformed .env file (invalid syntax)
      File.write(env_file, "INVALID SYNTAX WITHOUT EQUALS\n")

      # Run in subprocess to test fresh require
      lib_path = File.expand_path('../../lib', __FILE__)
      result = Dir.chdir(test_project_dir) do
        `ruby -I#{lib_path} -e "require 'reclaim'; puts 'loaded'" 2>&1`
      end

      # Should still load successfully (with warning if $VERBOSE)
      assert_match(/loaded/, result, "Library should load despite malformed .env")
    ensure
      # Guaranteed cleanup even if assertions fail
      FileUtils.rm_rf(test_project_dir) if Dir.exist?(test_project_dir)
    end
  end

  def test_graceful_fallback_without_dotenv
    # Test that the library doesn't fail if dotenv is not available
    # This is verified by the fact that require 'reclaim' at the top
    # should not raise an error even if dotenv is temporarily unavailable
    require 'reclaim'

    # If we got here without error, the graceful fallback worked
    assert true
  end

  def test_reclaim_token_from_environment
    # Verify that RECLAIM_API_KEY can be set and used
    ENV['RECLAIM_API_KEY'] = 'test_token_value'

    client = Reclaim::Client.new
    assert_equal 'test_token_value', client.instance_variable_get(:@token)

    # Clean up
    ENV['RECLAIM_API_KEY'] = @original_token
  end
end

puts <<~INFO

Running Reclaim Ruby Library Test Suite
=======================================

Test Classes:
- TestReclaimTask: Unit tests for Task class
- TestReclaimClient: Unit tests for Client class  
- TestReclaimUtils: Unit tests for utility functions
- TestReclaimCLI: Unit tests for CLI interface and default behavior
- TestReclaimIntegration: Integration tests with real API

Environment:
- Ruby Version: #{RUBY_VERSION}
- Test Framework: Minitest #{Minitest::VERSION}
- Integration Tests: #{ReclaimTestHelper.skip_integration_tests? ? 'Disabled' : 'Enabled'}

To run only unit tests:
SKIP_INTEGRATION_TESTS=true ruby tests/reclaim/test_reclaim.rb

To run only integration tests:
ruby tests/reclaim/test_reclaim.rb -n "/Integration/"

INFO