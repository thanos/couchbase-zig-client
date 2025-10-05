# Release Notes

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
