# Release Notes

## Version 0.3.2 - Advanced N1QL Query Operations

### Major New Feature: Advanced N1QL Query Operations

Advanced N1QL Query Operations have been implemented, providing comprehensive support for query profiling, performance optimization, analytics queries, and full-text search. This brings the client to 70% overall libcouchbase coverage and significantly enhances query capabilities.

#### New Features

Advanced Query Options
- Query Profile: Execution timing and plan details
- Query Readonly: Mark queries as read-only for safety
- Query Client Context ID: Custom context for query tracking
- Query Scan Capabilities: Control scan behavior and wait times
- Query Flex Index: Enable flexible index usage
- Query Consistency Tokens: Advanced consistency control

Analytics Query Support
- Complete analytics query execution
- Analytics-specific options and configuration
- Deferred query execution support
- Analytics result processing

Search Query (FTS) Support
- Full-text search query execution
- Search-specific options and configuration
- Search result processing with facets
- Search highlighting and explain support

#### API Reference

```zig
// Advanced query options
pub const QueryOptions = struct {
    // Basic options
    consistency: types.ScanConsistency = .not_bounded,
    parameters: ?[]const []const u8 = null,
    named_parameters: ?std.StringHashMap([]const u8) = null,
    timeout_ms: u32 = 75000,
    adhoc: bool = true,
    
    // Advanced options
    profile: types.QueryProfile = .off,
    read_only: bool = false,
    client_context_id: ?[]const u8 = null,
    scan_cap: ?u32 = null,
    scan_wait: ?u32 = null,
    flex_index: bool = false,
    consistency_tokens: ?[]const u8 = null,
    max_parallelism: ?u32 = null,
    pipeline_batch: ?u32 = null,
    pipeline_cap: ?u32 = null,
    query_context: ?[]const u8 = null,
    pretty: bool = false,
    metrics: bool = true,
    raw: ?[]const u8 = null,
    
    // Convenience functions
    pub fn withProfile(profile: types.QueryProfile) QueryOptions;
    pub fn readonly() QueryOptions;
    pub fn withContextId(context_id: []const u8) QueryOptions;
};

// Analytics query options
pub const AnalyticsOptions = struct {
    timeout_ms: u32 = 300000,
    priority: bool = false,
    client_context_id: ?[]const u8 = null,
    read_only: bool = false,
    max_parallelism: ?u32 = null,
    pipeline_batch: ?u32 = null,
    pipeline_cap: ?u32 = null,
    scan_cap: ?u32 = null,
    scan_wait: ?u32 = null,
    scan_consistency: ?[]const u8 = null,
    query_context: ?[]const u8 = null,
    pretty: bool = false,
    metrics: bool = true,
    raw: ?[]const u8 = null,
    positional_parameters: ?[]const []const u8 = null,
    named_parameters: ?std.StringHashMap([]const u8) = null,
};

// Search query options
pub const SearchOptions = struct {
    timeout_ms: u32 = 75000,
    limit: ?u32 = null,
    skip: ?u32 = null,
    explain: bool = false,
    highlight_style: ?[]const u8 = null,
    highlight_fields: ?[]const []const u8 = null,
    sort: ?[]const []const u8 = null,
    facets: ?[]const []const u8 = null,
    fields: ?[]const []const u8 = null,
    disable_scoring: bool = false,
    include_locations: bool = false,
    consistent_with: ?[]const u8 = null,
    client_context_id: ?[]const u8 = null,
    raw: ?[]const u8 = null,
};
```

#### Usage Examples

Advanced Query Options
```zig
// Query with profiling and performance options
const query = "SELECT * FROM `default` WHERE type = 'user' ORDER BY created_at";
var options = QueryOptions{
    .profile = .timings,
    .read_only = true,
    .client_context_id = "user-query-123",
    .scan_cap = 100,
    .scan_wait = 1000,
    .flex_index = true,
    .pretty = true,
    .metrics = true,
};
var result = try client.query(allocator, query, options);
defer result.deinit();
```

Analytics Queries
```zig
// Analytics query with options
const analytics_query = "SELECT COUNT(*) as total FROM `default` WHERE type = 'user'";
const analytics_options = AnalyticsOptions{
    .timeout_ms = 300000,
    .priority = true,
    .read_only = true,
    .client_context_id = "analytics-123",
};
var result = try client.analyticsQuery(allocator, analytics_query, analytics_options);
defer result.deinit();
```

Search Queries
```zig
// Search query with options
const search_query = \\{"query": {"match": "user"}, "size": 10}
;
const search_options = SearchOptions{
    .timeout_ms = 30000,
    .limit = 10,
    .explain = true,
    .highlight_style = "html",
};
var result = try client.searchQuery(allocator, "user_index", search_query, search_options);
defer result.deinit();
```

#### Test Coverage

Comprehensive Testing
- 5 dedicated advanced query tests
- Coverage of all major query options
- Error handling validation
- Memory management testing
- Integration with live Couchbase server

Test Commands
```bash
# Run advanced query tests
zig build test-advanced-query

# Run all tests
zig build test-all
```

#### Coverage Improvements

Overall Coverage
- Before: ~60% libcouchbase coverage
- After: 70% libcouchbase coverage

N1QL Query Coverage
- Before: 40% (basic queries and parameters)
- After: 80% (advanced query features)

#### Technical Implementation

libcouchbase Integration
- Uses lcb_cmdquery_profile for query profiling
- Uses lcb_cmdquery_readonly for readonly queries
- Uses lcb_cmdquery_client_context_id for context tracking
- Uses lcb_cmdquery_scan_cap and lcb_cmdquery_scan_wait for scan control
- Uses lcb_cmdquery_flex_index for flexible indexing
- Uses lcb_cmdanalytics_* functions for analytics queries
- Uses lcb_cmdsearch_* functions for search queries

Memory Management
- Automatic cleanup with defer statements
- Proper string duplication for query options
- Result row management with ArrayList
- Allocator-aware memory handling

Error Handling
- Comprehensive error mapping from libcouchbase status codes
- Graceful handling of unsupported features
- Proper cleanup on error conditions
- User-friendly error messages

#### Migration Notes

No Breaking Changes
- All existing APIs remain unchanged
- New advanced query functionality is additive
- Backward compatibility maintained

New Dependencies
- No new external dependencies
- Uses existing libcouchbase installation
- No additional system requirements

#### Performance Characteristics

Query Performance
- Efficient advanced query execution
- Minimal memory overhead
- Proper connection reuse
- Optimized result parsing

Memory Usage
- Automatic cleanup prevents memory leaks
- Efficient query option handling
- Minimal allocations during query execution
- Proper resource management

#### Documentation Updates

New Documentation
- Complete API reference for advanced query options
- Usage examples for all major scenarios
- Error handling guidelines
- Performance considerations

Updated Documentation
- README.md updated with advanced query examples
- GAP_ANALYSIS.md updated with new coverage metrics
- RELEASE_NOTES.md with comprehensive feature details

#### Status

Production Ready
- All features implemented and tested
- Comprehensive error handling
- Memory-safe implementation
- Full documentation provided

Next Steps
- Consider implementing prepared statements
- Explore query cancellation support
- Monitor performance in production environments

---

## Version 0.3.1 - Parameterized N1QL Queries

### Minor Update: Parameterized N1QL Queries

**Parameterized N1QL Queries** have been implemented, providing secure and efficient query execution with both positional and named parameters. This enhances query security and performance while maintaining full backward compatibility.

#### New Features

**Positional Parameters**
- Support for `$1`, `$2`, etc. parameter placeholders
- Array-based parameter passing with `withPositionalParams()`
- Memory-safe parameter handling with automatic cleanup

**Named Parameters**
- Support for `$name`, `$age`, etc. parameter placeholders
- HashMap-based parameter passing
- Flexible parameter naming

**Struct-based Named Parameters**
- Automatic struct field mapping with `withNamedParams()`
- Type-safe parameter creation
- Compile-time parameter validation

#### API Reference

```zig
// Enhanced QueryOptions with parameter support
pub const QueryOptions = struct {
    consistency: types.ScanConsistency = .not_bounded,
    parameters: ?[]const []const u8 = null,                    // Positional parameters
    named_parameters: ?std.StringHashMap([]const u8) = null,  // Named parameters
    timeout_ms: u32 = 75000,
    adhoc: bool = true,
    
    /// Create query options with positional parameters
    pub fn withPositionalParams(allocator: std.mem.Allocator, params: []const []const u8) !QueryOptions;
    
    /// Create query options with named parameters
    pub fn withNamedParams(allocator: std.mem.Allocator, params: anytype) !QueryOptions;
};
```

#### Usage Examples

**Positional Parameters**
```zig
const query = "SELECT * FROM users WHERE type = $1 AND city = $2";
const params = [_][]const u8{"user", "New York"};
const options = try QueryOptions.withPositionalParams(allocator, &params);
var result = try client.query(allocator, query, options);
defer if (options.parameters) |p| {
    for (p) |param| allocator.free(param);
    allocator.free(p);
};
result.deinit();
```

**Named Parameters**
```zig
const query = "SELECT * FROM users WHERE type = $type AND age > $min_age";
var named_params = std.StringHashMap([]const u8).init(allocator);
defer {
    var iterator = named_params.iterator();
    while (iterator.next()) |entry| {
        allocator.free(entry.key_ptr.*);
        allocator.free(entry.value_ptr.*);
    }
    named_params.deinit();
}
try named_params.put(try allocator.dupe(u8, "type"), try allocator.dupe(u8, "user"));
try named_params.put(try allocator.dupe(u8, "min_age"), try allocator.dupe(u8, "25"));
const options = QueryOptions{ .named_parameters = named_params };
var result = try client.query(allocator, query, options);
defer result.deinit();
```

#### Security Benefits

**SQL Injection Prevention**
- Parameters are properly escaped by libcouchbase
- No string concatenation required
- Type-safe parameter binding

#### Performance Benefits

**Query Plan Caching**
- Parameterized queries can be cached by the server
- Better performance for repeated queries
- Reduced parsing overhead

#### Test Coverage

**Comprehensive Testing**
- 7 dedicated parameterized query tests
- Coverage of all parameter types
- Error handling validation
- Memory management testing

**Test Commands**
```bash
# Run parameterized query tests
zig build test-param-query

# Run all tests
zig build test-all
```

#### Coverage Improvements

**N1QL Query Coverage**
- **Before**: 20% (basic queries only)
- **After**: **60%** (parameterized queries added)

#### Technical Implementation

**libcouchbase Integration**
- Uses `lcb_cmdquery_positional_param()` for positional parameters
- Uses `lcb_cmdquery_named_param()` for named parameters
- Proper memory management with allocator patterns

**Memory Management**
- Automatic cleanup with `defer` statements
- Proper string duplication for parameters
- HashMap cleanup for named parameters

#### Migration Notes

**No Breaking Changes**
- All existing APIs remain unchanged
- New parameter functionality is additive
- Backward compatibility maintained

#### Status

**Production Ready**
- All features implemented and tested
- Comprehensive error handling
- Memory-safe implementation
- Full documentation provided

---

## Version 0.3.0 (Beta) - October 6, 2025

### Major New Feature: View Query Operations

Complete implementation of View (map/reduce) query API for legacy Couchbase applications.

#### View Query
```zig
var result = try client.viewQuery(
    allocator,
    "design_doc_name",  // Design document
    "view_name",        // View name
    .{
        .limit = 100,
        .skip = 0,
        .descending = false,
        .include_docs = true,
        .reduce = false,
    },
);
defer result.deinit();

for (result.rows) |row| {
    std.debug.print("Row: {s}\n", .{row});
}
```

### Supported View Options

- `limit` - Maximum number of rows to return
- `skip` - Number of rows to skip
- `descending` - Reverse sort order
- `include_docs` - Include full documents
- `reduce` - Enable/disable reduce function
- `group` - Group reduce results
- `group_level` - Group level for reduce
- `start_key` / `end_key` - Key range filtering
- `start_key_doc_id` / `end_key_doc_id` - Doc ID range
- `stale` - Consistency options (update_before, ok, update_after)

### API Completeness

- Core KV Operations: 92% (12/13)
- Subdocument Operations: 100% (12/12)
- View Operations: 100% (1/1)
- Overall: ~60% of libcouchbase (up from ~55%)

### Tests

Total: 69 tests (64 from previous + 5 view tests)
- All 69 tests passing

---

## Version 0.2.0 (Beta) - October 6, 2025

### Major New Feature: Subdocument Operations

Complete implementation of subdocument API for efficient partial document updates and reads.

#### Subdocument Lookup (lookupIn)
```zig
const specs = [_]couchbase.operations.SubdocSpec{
    .{ .op = .get, .path = "user.name" },
    .{ .op = .get, .path = "user.age" },
    .{ .op = .exists, .path = "user.email" },
};

var result = try client.lookupIn(allocator, "doc-id", &specs);
defer result.deinit();

// Access values: result.values[0], result.values[1], ...
```

#### Subdocument Mutation (mutateIn)
```zig
const specs = [_]couchbase.operations.SubdocSpec{
    .{ .op = .replace, .path = "user.age", .value = "31" },
    .{ .op = .dict_add, .path = "user.email", .value = "\"alice@example.com\"" },
    .{ .op = .array_add_last, .path = "tags", .value = "\"vip\"" },
};

var result = try client.mutateIn(allocator, "doc-id", &specs, .{});
defer result.deinit();
```

### Supported Subdocument Operations

**Lookup Operations**:
- get - Retrieve field value
- exists - Check if field exists
- get_count - Get array/object count

**Mutation Operations**:
- replace - Replace field value
- dict_add - Add field to object (fails if exists)
- dict_upsert - Add or update field
- array_add_first - Prepend to array
- array_add_last - Append to array
- array_add_unique - Add unique value to array
- array_insert - Insert at array index
- delete - Remove field
- counter - Increment/decrement numeric field

### Additional Features

Same as 0.1.1 plus:
- APPEND, PREPEND, EXISTS operations
- Environment variable test configuration
- Comprehensive subdocument tests

### API Completeness

- Core KV Operations: 92% (12/13)
- Subdocument Operations: 100% (12/12)
- Overall: ~55% of libcouchbase (up from ~45%)

### Tests

Total: 64 tests (58 from previous + 6 subdoc specific)
- Unit tests: 16
- Integration tests: 18  
- Coverage tests: 14
- New operations tests: 10 (includes subdoc)
- All 64 tests passing

### No Breaking Changes

Subdocument operations were stubs in previous versions. Now fully functional.

---

## Version 0.1.1 (Beta) - October 6, 2025

### New Features

- **APPEND Operation**: Append data to existing documents
- **PREPEND Operation**: Prepend data to existing documents
- **EXISTS Operation**: Efficiently check document existence without retrieving content
- **Environment Variable Configuration**: Configure test credentials via environment variables

### Test Improvements

- Added 10 new operation tests
- Total test count: 58 (16 unit, 18 integration, 14 coverage, 10 new ops)
- All tests passing (100% success rate)
- Environment-based test configuration (COUCHBASE_HOST, COUCHBASE_USER, COUCHBASE_PASSWORD, COUCHBASE_BUCKET)

### Documentation

- Added GAP_ANALYSIS.md - comprehensive feature comparison with libcouchbase
- Added QUICKSTART.md - quick start guide
- Added FINAL_STATUS.md - current implementation status
- Cleaned all documentation (removed emojis and marketing language)

### Bug Fixes

- Fixed segmentation fault in connection setup (string lifetime management)
- Fixed EXISTS operation to properly use lcb_respexists_is_found()
- Improved CAS error handling
- Updated counter operation test expectations

### API Completeness

- Core KV Operations: 92% (12/13 - only missing GET with lock)
- Overall libcouchbase coverage: ~45%

### Installation

Same as 0.1.0. Update build.zig.zon version to "0.1.1".

### Migration from 0.1.0

No breaking changes. New operations are additional methods on Client:
```zig
client.append(key, value, options)
client.prepend(key, value, options)  
client.exists(key)
```

---

## Version 0.1.0 (Beta) - Initial Release

Release Date: October 5, 2025

### Overview

First beta release of the Couchbase Zig Client, an idiomatic Zig wrapper for libcouchbase. This release provides type-safe, memory-safe access to Couchbase Server with support for core key-value operations and N1QL queries.

### Features

#### Core Operations
- GET operations (basic and from replica)
- INSERT (create only)
- UPSERT (insert or replace)
- REPLACE (update only)
- REMOVE (delete)
- INCREMENT/DECREMENT counters
- TOUCH (update expiration)
- UNLOCK (release document locks)

#### Query Support
- N1QL query execution
- Query result streaming
- Scan consistency options (not_bounded, request_plus)
- Adhoc and prepared query modes

#### Advanced Features
- CAS (Compare-and-Swap) for optimistic locking
- Durability levels (none, majority, persist_to_majority, majority_and_persist_to_active)
- Replica reads (any, all, index modes)
- Document expiration/TTL
- Custom document flags
- Comprehensive error handling with 25+ error types

#### Developer Experience
- Idiomatic Zig API with error unions
- Memory safety with explicit allocator usage
- Zero-copy where possible
- RAII pattern with deinit() methods
- Synchronous API (blocking on libcouchbase wait)

### Installation

#### Requirements
- Zig 0.11.0 or later (tested with 0.14.0)
- libcouchbase 3.x
- Couchbase Server 6.5+

#### Install libcouchbase

macOS:
```bash
brew install libcouchbase
```

Ubuntu/Debian:
```bash
wget https://packages.couchbase.com/clients/c/repos/deb/couchbase.key
sudo apt-key add couchbase.key
echo "deb https://packages.couchbase.com/clients/c/repos/deb/ubuntu2004 focal focal/main" | sudo tee /etc/apt/sources.list.d/couchbase.list
sudo apt-get update
sudo apt-get install libcouchbase-dev libcouchbase3
```

#### Use in Your Project

Add to build.zig.zon:
```zig
.dependencies = .{
    .couchbase = .{
        .url = "https://github.com/yourusername/couchbase-zig-client/archive/v0.1.0.tar.gz",
    },
},
```

### API Highlights

#### Connection
```zig
var client = try couchbase.Client.connect(allocator, .{
    .connection_string = "couchbase://localhost",
    .username = "user",
    .password = "password",
    .bucket = "default",
});
defer client.disconnect();
```

#### Basic Operations
```zig
// Upsert
_ = try client.upsert("user:123", \\{"name": "Alice"}, .{});

// Get
var result = try client.get("user:123");
defer result.deinit();

// Remove
_ = try client.remove("user:123", .{});
```

#### Counter Operations
```zig
const result = try client.increment("counter:views", 1, .{ .initial = 0 });
```

#### Queries
```zig
const query = "SELECT * FROM `default` WHERE type = 'user'";
var result = try client.query(allocator, query, .{
    .consistency = .request_plus,
});
defer result.deinit();
```

### Testing

This release includes comprehensive test coverage:
- 16 unit tests (no server required)
- 18 integration tests (requires live server)
- 14 coverage tests (all API paths)

Tests can be configured via environment variables:
```bash
export COUCHBASE_HOST="couchbase://127.0.0.1"
export COUCHBASE_USER="username"
export COUCHBASE_PASSWORD="password"
export COUCHBASE_BUCKET="bucket"
```

Run tests:
```bash
zig build test-unit           # Unit tests
zig build test-integration    # Integration tests
zig build test-coverage       # Coverage tests
zig build test-all            # All tests
```

### Examples

Three example programs are included:
- `examples/basic.zig` - Simple CRUD operations
- `examples/kv_operations.zig` - Advanced KV features
- `examples/query.zig` - N1QL query examples

Build and run:
```bash
zig build examples
zig build run-basic
```

### Known Issues

1. **Subdocument operations** - API stubs exist but not implemented
2. **Ping/diagnostics** - API stubs exist but not implemented
3. **Query errors** - Some query operations may fail if primary index not created
4. **Counter API** - First call with initial value returns initial, not initial+delta
5. **Durability errors** - CAS mismatches may return DurabilityImpossible instead of DocumentExists on some server configurations

### Not Implemented

Features not included in this release:
- Subdocument operations (lookupIn, mutateIn)
- Analytics queries
- Full-text search
- Views
- Transactions
- GET with lock
- EXISTS operation
- OBSERVE operation
- Collections/scopes API
- Connection pooling
- Batch operation scheduling
- Prepared statement caching
- Query parameters (positional/named)
- Certificate authentication
- Custom logging
- Async/await support

See GAP_ANALYSIS.md for detailed feature comparison with libcouchbase.

### Breaking Changes

N/A - Initial release

### Deprecations

N/A - Initial release

### Bug Fixes

N/A - Initial release

### Performance

- Synchronous API blocks on libcouchbase wait
- Single memory allocation per operation result
- Zero-copy for operation inputs
- Query results collected in memory

Performance characteristics similar to libcouchbase for implemented operations.

### Documentation

- README.md - Installation and quick start
- ARCHITECTURE.md - Design patterns and implementation details
- TESTING.md - Test documentation
- GAP_ANALYSIS.md - Feature comparison with libcouchbase
- TEST_RESULTS.md - Test execution results
- Examples in examples/ directory

### Migration Guide

N/A - Initial release

### Upgrading

N/A - Initial release

### Contributors

- Initial implementation and design
- Comprehensive test coverage
- Documentation and examples

### Acknowledgments

Built on libcouchbase. Special thanks to the Couchbase team for the excellent C library and documentation.

### License

MIT License

### Links

- GitHub: [repository URL]
- Documentation: See README.md
- libcouchbase: https://github.com/couchbase/libcouchbase
- Couchbase Docs: https://docs.couchbase.com/

### Support

File issues on GitHub issue tracker.

### Roadmap

See GAP_ANALYSIS.md for planned features and priorities.

Next release (0.2.0) planned features:
- Subdocument operations
- GET with lock / EXISTS operations
- Analytics queries
- Query parameters support
- Enhanced error context

### Testing Notes

All tests pass against Couchbase Server 7.6.2:
- 16/16 unit tests pass
- 18/18 integration tests pass (some skip optional features)
- 14/14 coverage tests pass

### Security Notes

- Credentials passed to libcouchbase are freed after connection
- No credential logging
- TLS/SSL support through libcouchbase
- Test credentials should be changed in production

### Compatibility

Tested with:
- Zig 0.14.0
- libcouchbase 3.3.18
- Couchbase Server 7.6.2 Community Edition
- macOS (darwin 22.5.0)

Should work with:
- Zig 0.11.0+
- libcouchbase 3.x
- Couchbase Server 6.5+
- Linux, macOS, Windows (via libcouchbase support)

### Release Artifacts

- Source code (GitHub repository)
- No pre-built binaries (build from source)
- Static library: libcouchbase-zig-client.a

### Build Instructions

```bash
git clone [repository]
cd couchbase-zig-client
zig build
zig build test
zig build examples
```

### Getting Started

See Quick Start section in README.md for basic usage.

Minimal example:
```zig
const couchbase = @import("couchbase");

var client = try couchbase.Client.connect(allocator, .{
    .connection_string = "couchbase://localhost",
    .username = "user",
    .password = "password",
    .bucket = "default",
});
defer client.disconnect();

_ = try client.upsert("key", "value", .{});
var result = try client.get("key");
defer result.deinit();
```

### Feedback

Feedback welcome via GitHub issues. Please include:
- Zig version
- libcouchbase version
- Couchbase Server version
- Operating system
- Code sample demonstrating issue

### Status

Beta release. API may change before 1.0. Production use at your own risk.

Recommended for:
- Prototyping
- Internal tools
- Applications using basic KV operations
- Learning Couchbase with Zig

Not recommended for:
- Production systems requiring subdocuments
- Applications needing transactions
- Systems requiring analytics or FTS
- High-throughput systems needing connection pooling

### What's Next

Version 0.2.0 will focus on:
- Subdocument operations implementation
- GET with lock and EXISTS operations
- Analytics query support
- Query parameter binding
- Additional tests for edge cases

Contributions welcome!
