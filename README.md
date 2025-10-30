# Reclaim Ruby Client

[![Gem Version](https://badge.fury.io/rb/reclaim.svg)](https://badge.fury.io/rb/reclaim)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.0.0-ruby.svg)](https://www.ruby-lang.org/)

A comprehensive Ruby library for interacting with the [Reclaim.ai](https://reclaim.ai) API. Manage your tasks programmatically with proper error handling, time scheme resolution, caching, and a powerful command-line interface.

## Features

- **Complete Task Management**: Create, read, update, delete, and complete tasks
- **Time Scheme Support**: Resolve time schemes by name with fuzzy matching
- **Task Filtering**: Filter tasks by status (active, completed, overdue)
- **Flexible Scheduling**: Control task splitting, chunk sizes, and defer dates
- **CLI Tool**: Full-featured command-line interface for task management
- **Error Handling**: Comprehensive exception handling with custom error types
- **Zero Dependencies**: Uses only Ruby stdlib (no runtime dependencies)
- **Well Tested**: Extensive test coverage with unit and integration tests

## Installation

Install the gem:

```bash
gem install reclaim
```

Or add to your Gemfile:

```ruby
gem 'reclaim'
```

## Configuration

Set your Reclaim.ai API token as an environment variable:

```bash
export RECLAIM_TOKEN='your_api_token_here'
```

Get your API token from your [Reclaim.ai settings](https://app.reclaim.ai/settings/developer).

## Usage

### Ruby Library

```ruby
require 'reclaim'

# Initialize client (uses ENV['RECLAIM_TOKEN'] by default)
client = Reclaim::Client.new

# Or pass token explicitly
client = Reclaim::Client.new('your_api_token')

# Create a task
task = client.create_task(
  title: 'Important Work',
  due_date: '2025-12-31T17:00:00Z',
  priority: :p1,
  duration: 2.0,  # hours
  notes: 'This is important!',
  time_scheme: 'work'
)

puts "Created task: #{task.title} (#{task.id})"

# List tasks
active_tasks = client.list_tasks(filter: :active)
completed_tasks = client.list_tasks(filter: :completed)
overdue_tasks = client.list_tasks(filter: :overdue)
all_tasks = client.list_tasks  # No filter

active_tasks.each do |task|
  puts "#{task.title} - #{task.status} (Priority: #{task.priority})"
end

# Get a specific task
task = client.get_task('task_id_here')

# Update a task
updated_task = client.update_task(
  task.id,
  title: 'Updated Title',
  priority: :p2,
  duration: 3.0
)

# Mark task as complete (archives it)
completed_task = client.complete_task(task.id)

# Delete a task
client.delete_task(task.id)

# List available time schemes
schemes = client.list_time_schemes
schemes.each do |scheme|
  puts "#{scheme['title']} (#{scheme['id']})"
end

# Get formatted time schemes
puts client.format_time_schemes
```

### Task Priorities

Tasks support four priority levels:

- `:p1` - Highest priority (P1)
- `:p2` - High priority (P2)
- `:p3` - Normal priority (P3, default)
- `:p4` - Low priority (P4)

### Task Splitting

Control whether tasks can be split into smaller chunks:

```ruby
# Prevent splitting (default)
task = client.create_task(
  title: 'Deep Work Session',
  duration: 4.0  # Must be scheduled as a single 4-hour block
)

# Allow splitting with default chunk sizes
task = client.create_task(
  title: 'Flexible Task',
  duration: 3.0,
  allow_splitting: true  # Can be split into 15min-3hr chunks
)

# Allow splitting with custom minimum chunk size
task = client.create_task(
  title: 'Research',
  duration: 4.0,
  allow_splitting: true,
  split_chunk_size: 0.5  # Minimum 30-minute chunks
)

# Full control over chunk sizes
task = client.create_task(
  title: 'Writing',
  duration: 6.0,
  allow_splitting: true,
  min_chunk_size: 1.0,   # Minimum 1 hour
  max_chunk_size: 2.0    # Maximum 2 hours
)
```

### Time Schemes

Time schemes control when tasks can be scheduled. You can reference them by name:

```ruby
# Use exact name
task = client.create_task(
  title: 'Work Task',
  time_scheme: 'Work Hours'
)

# Use alias (fuzzy matching)
task = client.create_task(
  title: 'Work Task',
  time_scheme: 'work'  # Finds "Work Hours"
)

# Supported aliases:
# - 'work', 'working hours', 'business hours' → finds schemes with 'work'
# - 'personal', 'off hours', 'private' → finds schemes with 'personal'
```

### Error Handling

The library provides specific exception types:

```ruby
begin
  client = Reclaim::Client.new('invalid_token')
rescue Reclaim::AuthenticationError => e
  puts "Authentication failed: #{e.message}"
end

begin
  task = client.get_task('nonexistent_id')
rescue Reclaim::NotFoundError => e
  puts "Task not found: #{e.message}"
end

begin
  task = client.create_task(title: '', time_scheme: 'invalid')
rescue Reclaim::InvalidRecordError => e
  puts "Validation error: #{e.message}"
end

begin
  # Network or API errors
  tasks = client.list_tasks
rescue Reclaim::ApiError => e
  puts "API error: #{e.message}"
  puts "Status: #{e.status_code}" if e.status_code
end
```

### Command-Line Interface

The gem includes a full-featured CLI:

```bash
# List active tasks (default)
reclaim
reclaim list active

# List completed or overdue tasks
reclaim list completed
reclaim list overdue

# Create a task
reclaim create --title "Important Meeting Prep" \
  --due 2025-12-31 \
  --priority P1 \
  --duration 2

# Create a task that allows splitting
reclaim create --title "Research Project" \
  --duration 4 \
  --split 0.5  # 30-minute minimum chunks

# Get task details
reclaim get TASK_ID

# Update a task
reclaim update TASK_ID \
  --title "Updated Title" \
  --priority P2

# Clear a date field
reclaim update TASK_ID --due none
reclaim update TASK_ID --defer clear

# Mark task as complete
reclaim complete TASK_ID

# Delete a task
reclaim delete TASK_ID

# List available time schemes
reclaim list-schemes

# Get help
reclaim help
reclaim --help
```

## Development

### Setup

```bash
git clone https://github.com/benjaminjackson/reclaim-ruby.git
cd reclaim-ruby
bundle install
```

### Running Tests

```bash
# Run unit tests only (no API calls)
SKIP_INTEGRATION_TESTS=true bundle exec rake test

# Run all tests (requires RECLAIM_TOKEN)
bundle exec rake test

# Run only integration tests
bundle exec rake test TESTOPTS='-n /Integration/'
```

### Building the Gem

```bash
gem build reclaim.gemspec
gem install ./reclaim-0.1.0.gem
```

## API Reference

### Reclaim::Client

Main client for API interactions.

**Methods:**

- `initialize(token = nil)` - Create client (uses ENV['RECLAIM_TOKEN'] if token not provided)
- `create_task(**options)` - Create a new task
- `list_tasks(filter: nil)` - List all tasks (filter: :active, :completed, :overdue, or nil)
- `get_task(task_id)` - Get a specific task by ID
- `update_task(task_id, **options)` - Update an existing task
- `complete_task(task_id)` - Mark task as complete (ARCHIVED status)
- `delete_task(task_id)` - Permanently delete a task
- `list_time_schemes` - Get available time schemes
- `format_time_schemes` - Get formatted time schemes for display

### Reclaim::Task

Task model with properties and helper methods.

**Properties:**

- `id`, `title`, `notes`, `due_date`, `priority`, `duration`
- `status`, `time_scheme_id`, `always_private`, `event_category`, `event_color`
- `min_chunk_size`, `max_chunk_size`, `snooze_until`, `start`

**Methods:**

- `active?` - Check if task is active (not deleted/archived/cancelled)
- `completed?` - Check if task is completed (COMPLETE or ARCHIVED status)
- `overdue?` - Check if task is past its due date
- `due_date_formatted` - Get formatted due date string
- `priority_symbol` - Get priority as symbol (:p1, :p2, :p3, :p4)

### Exception Classes

- `Reclaim::Error` - Base exception class
- `Reclaim::AuthenticationError` - Authentication/token errors
- `Reclaim::ApiError` - API/network errors (includes status_code and response_body)
- `Reclaim::NotFoundError` - Resource not found (404)
- `Reclaim::InvalidRecordError` - Validation errors (422)

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/benjaminjackson/reclaim-ruby.

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).

## Links

- **RubyGems**: https://rubygems.org/gems/reclaim
- **Source Code**: https://github.com/benjaminjackson/reclaim-ruby
- **Bug Reports**: https://github.com/benjaminjackson/reclaim-ruby/issues
- **Reclaim.ai**: https://reclaim.ai
- **API Documentation**: https://reclaim.ai/api
