# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2025-11-14

### Added
- Dotenv support for environment variable management
- Automatic loading of `.env` files for API token configuration
- Development dependency on `dotenv` gem (~> 2.8)

### Changed
- Renamed environment variable from `RECLAIM_TOKEN` to `RECLAIM_API_KEY` for clarity

## [0.1.0] - 2025-10-29

### Added
- Initial release of Reclaim Ruby client
- Complete task management API (CRUD operations)
- Task filtering by status (active, completed, overdue)
- Time scheme support with fuzzy name matching
- Task splitting control (prevent splitting or configure chunk sizes)
- Priority levels (P1-P4)
- Date management (due dates, defer dates, start times)
- Comprehensive error handling with custom exception types
- Command-line interface (`reclaim` executable)
- CLI commands: list, create, get, update, complete, delete, list-schemes
- Full test suite (unit tests + integration tests)
- Zero runtime dependencies (stdlib only)
- Ruby 3.0+ support

### Features
- **Client**: HTTP client with authentication and caching
- **Task Model**: Task representation with status helpers
- **Utils**: Formatting and parsing utilities
- **CLI**: Full-featured command-line interface
- **Errors**: Custom exception hierarchy for better error handling

[Unreleased]: https://github.com/benjaminjackson/reclaim-ruby/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/benjaminjackson/reclaim-ruby/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/benjaminjackson/reclaim-ruby/releases/tag/v0.1.0
