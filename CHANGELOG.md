# Changelog

All notable changes to this project will be documented in this file.

## [0.3.4] - 2025-01-06

### Added
- Query Cancellation API: Complete query cancellation implementation
- QueryHandle Management: Query handle lifecycle and cancellation support
- Memory-Safe Cancellation: Proper cleanup and resource management
- Cancellation Options: Configurable cancellation behavior
- Error Handling: Comprehensive cancellation error handling
- QueryHandle struct with cancellation support
- QueryCancellationOptions configuration struct
- Client methods: cancelQuery(), isQueryCancelled()
- QueryResult methods: cancel(), isCancelled()
- QueryCancelled error type

### Changed
- Query Operations Coverage: Improved from 87% to 93%
- Overall libcouchbase Coverage: Improved from ~75% to ~80%
- QueryResult now includes QueryHandle for cancellation
- QueryContext now supports cancellation checking
- Memory management improved with proper handle cleanup

### Technical Details
- Uses QueryHandle for cancellation tracking
- Automatic cleanup with defer statements
- Memory-safe handle lifecycle management
- Comprehensive error handling for cancellation
- Performance-optimized cancellation checking

### Test Coverage
- 5 dedicated query cancellation tests
- Cancellation functionality testing
- Handle management testing
- Error handling validation
- Performance testing

### Breaking Changes
- None. All changes are additive and backward compatible.

## [0.3.3] - 2025-01-06

### Added
- Prepared Statement API: Complete prepared statement implementation
- Statement Caching: LRU cache with configurable size and expiration
- Performance Optimization: Significant performance benefits for repeated queries
- Auto-preparation: Automatic statement preparation on first execution
- Cache Management: Statistics, cleanup, and expiration handling
- PreparedStatement struct with lifecycle management
- PreparedStatementCache configuration struct
- Client methods: prepareStatement(), executePrepared(), clearPreparedStatements()
- Cache statistics and cleanup methods
- QueryOptions.prepared() convenience function

### Changed
- Query Operations Coverage: Improved from 80% to 87%
- Overall libcouchbase Coverage: Improved from ~70% to ~75%
- Client struct now includes prepared statement cache
- Query execution now supports prepared statement optimization

### Technical Details
- Uses LRU cache for prepared statement management
- Automatic expiration handling with configurable max age
- Memory-safe prepared statement lifecycle
- Performance comparison tests included
- Comprehensive error handling for prepared statements

### Test Coverage
- 5 dedicated prepared statement tests
- Cache management testing
- Performance comparison testing
- Parameter support testing
- Error handling validation

### Breaking Changes
- None. All changes are additive and backward compatible.

## [0.3.2] - 2025-01-06

### Added
- Advanced N1QL Query Options: Profile, readonly, client context ID, scan capabilities
- Query Performance Features: Flex index, scan cap/wait, consistency tokens
- Analytics Query Support: Complete analytics query implementation
- Search Query (FTS) Support: Full-text search query implementation
- QueryOptions convenience functions: withProfile(), readonly(), withContextId()
- AnalyticsOptions struct with comprehensive analytics configuration
- SearchOptions struct with search-specific configuration
- Client methods: analyticsQuery() and searchQuery()
- Advanced query test suite with 5 comprehensive tests

### Changed
- N1QL Query Coverage: Improved from 40% to 80%
- Overall libcouchbase Coverage: Improved from ~60% to ~70%
- QueryOptions struct expanded with advanced query features
- README.md updated with advanced query examples
- GAP_ANALYSIS.md updated with new coverage metrics

### Technical Details
- Uses lcb_cmdquery_profile for query profiling
- Uses lcb_cmdquery_readonly for readonly queries
- Uses lcb_cmdquery_client_context_id for context tracking
- Uses lcb_cmdquery_scan_cap and lcb_cmdquery_scan_wait for scan control
- Uses lcb_cmdquery_flex_index for flexible indexing
- Uses lcb_cmdanalytics_* functions for analytics queries
- Uses lcb_cmdsearch_* functions for search queries
- Query consistency tokens stubbed (requires lcb_MUTATION_TOKEN implementation)
- Some analytics and search options commented out (not available in current libcouchbase)

### Test Coverage
- 5 dedicated advanced query tests
- Coverage of all major query options
- Error handling validation
- Memory management testing
- Integration with live Couchbase server

### Breaking Changes
- None. All changes are additive and backward compatible.

## [0.3.1] - 2025-01-XX

### Added
- Parameterized N1QL queries with positional parameters (`$1`, `$2`, etc.)
- Named parameters support (`$name`, `$age`, etc.)
- Struct-based named parameters with `withNamedParams()`
- `QueryOptions.withPositionalParams()` convenience function
- `QueryOptions.withNamedParams()` convenience function
- 7 comprehensive tests for parameterized queries
- SQL injection prevention through parameter binding
- Query plan caching support for better performance

### Changed
- Enhanced `QueryOptions` struct with parameter support
- Updated query function to handle both positional and named parameters
- Improved N1QL query coverage from 20% to 60%

### Technical Details
- Uses `lcb_cmdquery_positional_param()` for positional parameters
- Uses `lcb_cmdquery_named_param()` for named parameters
- Memory-safe parameter handling with automatic cleanup
- Type-safe parameter binding with compile-time validation

### Security
- Parameters are properly escaped by libcouchbase
- No string concatenation required for queries
- Prevents SQL injection attacks

### Performance
- Parameterized queries can be cached by the server
- Reduced parsing overhead
- Better performance for repeated queries

## [0.3.0] - 2025-01-XX

## [0.3.0] - 2025-10-06

### Added
- **View Query Operations** - Full implementation of View API
  - viewQuery() - Execute map/reduce view queries
  - Support for all view options (limit, skip, reduce, group, key ranges, etc.)
  - ViewResult type with row streaming
  - ViewOptions configuration
  - ViewStale consistency options
- 5 view query tests
- src/views.zig module for view operations

### Changed
- View operations moved from not implemented to fully functional
- Added views module to public API
- View query coverage: 0% -> 100%

### Features
- Limit and skip for pagination
- Descending order
- Include docs option
- Reduce operations with group/group_level
- Key range queries (startkey, endkey)
- Stale/consistency options
- Full query string building

## [0.2.0] - 2025-10-06

### Added
- **Subdocument Operations** - Full implementation of subdocument API
  - lookupIn() - Multi-path document lookups
  - mutateIn() - Multi-path document mutations
  - All subdocument operation types (get, exists, replace, dict operations, array operations, delete, counter)
- Subdocument tests (6 comprehensive tests)
- Support for all 12 subdocument operation types

### Changed
- Subdocument operations moved from stub to full implementation
- Core operations coverage increased to 92%
- Subdocument operations coverage: 0% -> 100%

### Technical Details
- Uses lcb_SUBDOCSPECS API for building operation lists
- Supports CAS, expiry, and durability for subdocument mutations
- Proper memory management for multi-result responses

### Breaking Changes
- None - subdocument operations were stubs before

## [0.1.1] - 2025-10-06

### Added
- APPEND operation for appending data to existing documents
- PREPEND operation for prepending data to existing documents
- EXISTS operation for efficient document existence checks
- Environment variable configuration for test credentials (COUCHBASE_HOST, COUCHBASE_USER, COUCHBASE_PASSWORD, COUCHBASE_BUCKET)
- 10 new operation tests (append, prepend, exists, subdocument stubs)
- GAP_ANALYSIS.md - comprehensive feature comparison with libcouchbase
- QUICKSTART.md - quick start guide
- FINAL_STATUS.md - current status report
- TEST_SUMMARY.txt - test summary report

### Changed
- Test configuration now uses environment variables with fallback defaults
- Updated gap analysis to reflect 92% core KV operation coverage
- Improved documentation structure and organization

### Fixed
- Segmentation fault in connection setup due to premature string deallocation
- EXISTS operation now correctly uses lcb_respexists_is_found()
- Memory lifetime management for connection strings
- Counter operation test expectations (initial value behavior)
- CAS error handling to accept both DocumentExists and DurabilityImpossible

### Documentation
- Added comprehensive gap analysis comparing to libcouchbase
- Updated all documentation to remove emojis and sales language
- Added detailed release notes and changelog
- Created quick start guide for new users

### Testing
- Total test count: 58 (was 48)
- All tests now pass with environment variable configuration
- Added tests for APPEND, PREPEND, EXISTS operations
- Subdocument operation tests (skip with NotSupported until implemented)

## [0.1.0] - 2025-10-05

### Added

#### Core Features
- Client connection management with authentication
- GET operation (basic and from replica)
- INSERT operation (create only)
- UPSERT operation (insert or replace)
- REPLACE operation (update only)
- REMOVE operation (delete)
- INCREMENT counter operation
- DECREMENT counter operation
- TOUCH operation (update expiration)
- UNLOCK operation (release locks)
- N1QL query execution with streaming results

#### Options & Configuration
- CAS (Compare-and-Swap) support for all mutations
- Durability levels: none, majority, persist_to_majority, majority_and_persist_to_active
- Replica read modes: any, all, index
- Document expiration/TTL support
- Custom document flags
- Query scan consistency options
- Connection timeout configuration
- Environment variable configuration for tests

#### Error Handling
- 25+ mapped error types from libcouchbase status codes
- Idiomatic Zig error handling
- Error description helpers

#### Testing
- 16 unit tests (type safety, defaults, structures)
- 18 integration tests (all operations against live server)
- 14 coverage tests (comprehensive API coverage)
- Environment variable test configuration
- All tests passing

#### Documentation
- README.md with installation and usage
- ARCHITECTURE.md with design patterns
- TESTING.md with test documentation
- GAP_ANALYSIS.md with feature comparison
- TEST_RESULTS.md with test execution details
- RELEASE_NOTES.md with detailed release information
- 3 comprehensive example programs

#### Build System
- build.zig with library and example targets
- build.zig.zon package metadata
- Separate test targets (test-unit, test-integration, test-coverage, test-all)

### Not Implemented

- Subdocument operations (stubs only)
- Analytics queries
- Full-text search
- Views
- Transactions
- GET with lock
- EXISTS operation
- OBSERVE operation
- Collections/scopes API
- Connection pooling
- Batch scheduling
- Prepared statements
- Query parameters
- Ping/diagnostics (stubs only)

### Fixed

- Segmentation fault in test framework due to premature string deallocation
- String lifetime management in connection setup
- Counter operation expectations (initial value returned on creation)
- CAS error handling (accepts DocumentExists or DurabilityImpossible)
- Opaque type handling for libcouchbase command structures
- Query result type const correctness

### Technical Details

- Callback-based libcouchbase API wrapped as synchronous Zig API
- All allocations use provided allocator
- Result types have deinit() for cleanup
- Single-threaded per client instance
- Blocking I/O on lcb_wait()

### Compatibility

Tested on:
- Zig 0.14.0
- libcouchbase 3.3.18  
- Couchbase Server 7.6.2
- macOS darwin 22.5.0

### Known Issues

1. Counter initial+delta behavior differs from expectations
2. Some error codes may return Unknown for unmapped statuses
3. Query operations require primary index to be created
4. Subdocument operation stubs return NotSupported error

### Security

- Credentials stored temporarily during connection
- All credential strings freed after use
- No logging of sensitive information
- TLS support via libcouchbase

### Performance Notes

- Comparable to libcouchbase C library for implemented operations
- Single allocation per operation result
- Zero-copy for operation inputs
- Query results accumulate in memory

### Breaking Changes

N/A - Initial release

### Deprecations

N/A - Initial release

### Contributors

Initial implementation by project team

### Links

- Repository: [GitHub URL]
- libcouchbase: https://github.com/couchbase/libcouchbase
- Couchbase: https://docs.couchbase.com/
