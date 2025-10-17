
# couchbase-zig-client

Zig wrapper for the libcouchbase C library.


<img width="500"  alt="couchbase-zig-client-4" src="https://github.com/user-attachments/assets/4d05609a-be78-4ee6-a973-335568dab896" />





## Version 0.5.1 - Advanced N1QL Query Options

### New Features
- Query Profile support (off, phases, timings modes)
- Readonly queries functionality
- Client Context ID for query traceability
- Scan capabilities configuration (scan cap and wait times)
- Flex index support for flexible index usage
- Consistency tokens for advanced consistency control
- Performance tuning options (max parallelism, pipeline batch/cap)
- Pretty print formatting and metrics control
- Query context specification and raw JSON options
- Query option chaining with fluent API

### Technical Details
- Direct libcouchbase C API integration
- Enhanced QueryMetadata parsing with profile information
- Comprehensive query options builder methods
- Type-safe option handling with graceful degradation
- Eight new test cases for advanced N1QL features

## Version 0.5.0 - Transaction Functionality Implementation

### New Features
- Complete Transaction functionality for ACID compliance
- Transaction management operations (begin, commit, rollback)
- Transaction-aware KV operations (get, insert, upsert, replace, remove)
- Transaction-aware counter operations (increment, decrement)
- Transaction-aware advanced operations (touch, unlock, query)
- Comprehensive transaction configuration and error handling
- Automatic rollback on operation failure
- Transaction test suite with 11 test cases

### Technical Details
- TransactionContext and TransactionResult data structures
- TransactionConfig for comprehensive configuration
- Transaction state management (active, committed, rolled_back, failed)
- Memory-safe implementation with proper cleanup
- Comprehensive error handling and rollback logic

## Version 0.4.6 - Durability & Consistency Implementation

### New Features
- Complete Durability & Consistency functionality
- Observe-based durability operations (observe, observeMulti, waitForDurability)
- Mutation token management with automatic extraction
- Enhanced store operations with full durability support
- Support for all Couchbase durability levels
- Comprehensive durability test suite with 13 test cases

### Technical Details
- ObserveDurability, ObserveResult, and ObserveOptions data structures
- Mutation token creation, validation, and memory management
- Timeout handling for durability operations
- Error handling for durability-specific errors
- Memory-safe implementation with proper cleanup

## Version 0.4.5 - Spatial Views Implementation (Deprecated)

### New Features
- Spatial Views implementation for backward compatibility
- spatialViewQuery() function with geospatial parameters
- BoundingBox and SpatialRange data structures for geospatial queries
- Comprehensive spatial view test suite with 8 test cases
- Deprecation warnings and migration guidance to Full-Text Search (FTS)

### Technical Details
- Backward compatibility with older Couchbase Server versions
- Automatic deprecation warnings for spatial view usage
- Clear migration guidance to modern FTS geospatial queries
- Comprehensive error handling for unsupported operations

**Note**: Spatial views are deprecated in Couchbase Server 6.0+. Users are strongly encouraged to migrate to Full-Text Search (FTS) for geospatial queries.

## Version 0.4.4 - Enhanced Batch Operations with Collections

### New Features
- Enhanced batch operations with collection support
- New batch operation types: get_replica, lookup_in, mutate_in
- Collection-aware batch operations via withCollection() method
- Enhanced counter operations with direct delta parameter
- Comprehensive enhanced batch test suite with 4 test cases
- Support for all collection-aware operations in batch processing

### Technical Details
- Complete batch operation coverage for all collection-aware operations
- Seamless integration with existing collection-aware operations
- Improved memory management and error handling for batch operations
- Backward compatibility maintained with clear migration path
- Production-ready batch processing for multi-tenant applications

## Version 0.4.3 - Collections & Scopes API Complete

### New Features
- Collections & Scopes API Phase 3: Advanced operations with collections
- getReplicaWithCollection(): Collection-aware replica document retrieval
- lookupInWithCollection(): Collection-aware subdocument lookup operations
- mutateInWithCollection(): Collection-aware subdocument mutation operations
- Comprehensive Advanced Operations Testing: 7 test cases covering replica and subdocument operations
- Full Collections & Scopes API Coverage: 100% feature parity with C library

### Technical Details
- Phase 1: Core KV operations (upsert, insert, replace, remove, touch, counter, exists)
- Phase 2: Lock operations (getAndLock, unlock)
- Phase 3: Advanced operations (replica, subdocument lookup/mutation)
- All operations maintain Zig idiomatic style with proper memory management
- Full integration with libcouchbase C library collection functions

## Version 0.4.1 - Collections & Scopes API Phase 1 & 2

### New Features
- Collections & Scopes API Phase 1 & 2: Core KV and lock operations with collections
- Collection Type: Collection identifier with name, scope, and memory management
- Scope Type: Scope identifier with name and memory management
- CollectionManifest: Collection manifest management with search and filtering
- CollectionManifestEntry: Individual collection metadata with UID and TTL
- getWithCollection(): Collection-aware document retrieval
- getCollectionManifest(): Collection manifest retrieval (simplified implementation)
- Comprehensive Collection Testing: 11 test cases covering all collection scenarios

## Version 0.4.0 - GET with Lock Operations

### New Features
- GET with Lock Operation: Complete implementation matching libcouchbase functionality
- GetAndLockOptions: Comprehensive configuration for lock operations
- UnlockOptions: Flexible unlock operation configuration
- GetAndLockResult: Detailed result structure with lock time information
- UnlockResult: Success status and CAS information for unlock operations
- Comprehensive Lock Testing: 10 test cases covering all lock scenarios

## Features

- Key-value operations: get, insert, upsert, replace, remove, touch, counter
- GET with Lock: getAndLock() and unlockWithOptions() operations
- Collections & Scopes: Complete collection-aware operations (100% feature parity)
- N1QL query execution
- Subdocument operations: Complete implementation with collection support
- Batch operations: Execute multiple operations in single call
- CAS (compare-and-swap) support
- Durability levels
- Replica reads with collection support
- Error type mappings

## Requirements

- Zig 0.11.0 or later
- libcouchbase 3.x
- Couchbase Server

## Installation

### libcouchbase

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
sudo apt-get install libcouchbase-dev libcouchbase3 libcouchbase3-tools
```

### Project Integration

Add to `build.zig.zon`:
```zig
.dependencies = .{
    .couchbase = .{
        .url = "https://github.com/yourusername/couchbase-zig-client/archive/main.tar.gz",
    },
},
```

Add to `build.zig`:
```zig
const couchbase = b.dependency("couchbase", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("couchbase", couchbase.module("couchbase"));
```

## Usage

```zig
const std = @import("std");
const couchbase = @import("couchbase");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = try couchbase.Client.connect(allocator, .{
        .connection_string = "couchbase://localhost",
        .username = "Administrator",
        .password = "password",
        .bucket = "default",
    });
    defer client.disconnect();

    const result = try client.upsert("user:123", \\{"name": "John Doe", "age": 30}, .{});
    
    var get_result = try client.get("user:123");
    defer get_result.deinit();
}
```

## Examples

- `examples/basic.zig` - CRUD operations
- `examples/kv_operations.zig` - Key-value operations
- `examples/query.zig` - N1QL queries

Build and run:
```bash
zig build examples
zig build run-basic
zig build run-kv_operations
zig build run-query
```

## API

### Connection

```zig
var client = try couchbase.Client.connect(allocator, .{
    .connection_string = "couchbase://localhost",
    .username = "Administrator",
    .password = "password",
    .bucket = "default",
    .timeout_ms = 10000,
});
defer client.disconnect();
```

### Key-Value Operations

```zig
// Get document
var result = try client.get("doc-id");
defer result.deinit();

// Insert (fails if exists)
_ = try client.insert("doc-id", content, .{});

// Upsert (insert or replace)
_ = try client.upsert("doc-id", content, .{});

// Replace (fails if not exists)
_ = try client.replace("doc-id", content, .{ .cas = existing_cas });

// Remove
_ = try client.remove("doc-id", .{});

// Counter operations
const result = try client.increment("counter-id", 10, .{ .initial = 0 });
const result = try client.decrement("counter-id", 5, .{});

// Touch (update expiration)
_ = try client.touch("doc-id", 3600);
```

### Durability

```zig
_ = try client.upsert("doc-id", content, .{
    .durability = .{
        .level = .majority,
    },
});
```

### Queries

```zig
// Basic N1QL query
const query = "SELECT * FROM `default` WHERE type = $1";
var result = try client.query(allocator, query, .{
    .consistency = .request_plus,
    .adhoc = true,
});
defer result.deinit();

// Advanced query with profiling and performance options
const advanced_query = "SELECT * FROM `default` WHERE type = 'user' ORDER BY created_at";
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
var advanced_result = try client.query(allocator, advanced_query, options);
defer advanced_result.deinit();

// Analytics query
const analytics_query = "SELECT COUNT(*) as total FROM `default` WHERE type = 'user'";
const analytics_options = AnalyticsOptions{
    .timeout_ms = 300000,
    .priority = true,
    .read_only = true,
    .client_context_id = "analytics-123",
};
var analytics_result = try client.analyticsQuery(allocator, analytics_query, analytics_options);
defer analytics_result.deinit();

// Search query (Full-Text Search)
const search_query = \\{"query": {"match": "user"}, "size": 10}
;
const search_options = SearchOptions{
    .timeout_ms = 30000,
    .limit = 10,
    .explain = true,
    .highlight_style = "html",
};
var search_result = try client.searchQuery(allocator, "user_index", search_query, search_options);
defer search_result.deinit();

for (result.rows) |row| {
    std.debug.print("Row: {s}\n", .{row});
}
```

### Error Handling

```zig
const result = client.get("doc-id") catch |err| switch (err) {
    error.DocumentNotFound => {
        return;
    },
    error.Timeout => {
        return;
    },
    else => return err,
};
```

## Client Methods

- `connect(allocator, options)` - Connect to cluster
- `disconnect()` - Disconnect and cleanup
- `get(key)` - Get document
- `getFromReplica(key, mode)` - Get from replica
- `insert(key, value, options)` - Insert document
- `upsert(key, value, options)` - Insert or replace document
- `replace(key, value, options)` - Replace document
- `remove(key, options)` - Remove document
- `increment(key, delta, options)` - Increment counter
- `decrement(key, delta, options)` - Decrement counter
- `touch(key, expiry)` - Update expiration
- `unlock(key, cas)` - Unlock document
- `query(allocator, statement, options)` - Execute N1QL query
- `lookupIn(allocator, key, specs)` - Subdocument lookup
- `mutateIn(allocator, key, specs, options)` - Subdocument mutation
- `ping(allocator)` - Ping services (stub)
- `diagnostics(allocator)` - Get diagnostics (stub)

## Error Types

- `error.DocumentNotFound`
- `error.DocumentExists`
- `error.DocumentLocked`
- `error.Timeout`
- `error.AuthenticationFailed`
- `error.BucketNotFound`
- `error.TemporaryFailure`
- `error.DurabilityAmbiguous`
- `error.InvalidArgument`

## Building

```bash
zig build
zig build test
zig build examples
```

## Testing

Tests require a running Couchbase Server instance. Configure via environment variables:

```bash
export COUCHBASE_HOST="couchbase://127.0.0.1"  # or any connection string
export COUCHBASE_USER="tester"                  # default: tester
export COUCHBASE_PASSWORD="password"            # default: password
export COUCHBASE_BUCKET="default"               # default: default
```

Defaults (if env vars not set):
- Host: couchbase://127.0.0.1
- User: tester
- Password: password
- Bucket: default

### Setup Couchbase for Testing

Start server with Docker:
```bash
docker run -d --name couchbase \
  -p 8091-8096:8091-8096 \
  -p 11210-11211:11210-11211 \
  couchbase:community
```

Then configure it:
1. Go to http://localhost:8091
2. Setup cluster (click "Setup New Cluster")
3. Create admin user (can use tester/password)
4. Create a bucket named "default" in the Buckets section
5. Grant the user full access to the bucket

Or use the CLI:
```bash
# Wait for server to start
sleep 20

# Initialize cluster
docker exec couchbase couchbase-cli cluster-init \
  --cluster localhost \
  --cluster-username tester \
  --cluster-password password \
  --services data,index,query \
  --cluster-ramsize 512 \
  --cluster-index-ramsize 256

# Create bucket
docker exec couchbase couchbase-cli bucket-create \
  --cluster localhost \
  --username tester \
  --password password \
  --bucket default \
  --bucket-type couchbase \
  --bucket-ramsize 256
```

Run tests:
```bash
# Unit tests only (no server required)
zig build test-unit

# Integration tests (requires server)
zig build test-integration

# Coverage tests (requires server)
zig build test-coverage

# All tests
zig build test-all
```

Test configuration uses environment variables. See `src/root.zig` (getTestConfig function).

See TESTING.md and GAP_ANALYSIS.md for detailed testing documentation and feature comparison.

## Structure

- `src/c.zig` - C bindings
- `src/error.zig` - Error types
- `src/types.zig` - Common types
- `src/client.zig` - Client interface
- `src/operations.zig` - Operation implementations
- `src/root.zig` - Public API

## Implementation Notes

- Uses callbacks internally, presents synchronous API
- Copies string data for memory safety
- Single-threaded per client instance
- Blocking I/O on lcb_wait

## Status

Beta. API may change before 1.0 release.

Implemented:
- Connection management with env vars
- KV operations (get, insert, upsert, replace, remove, append, prepend)
- EXISTS operation
- Subdocument operations (lookupIn, mutateIn with all 12 operation types)
- View queries (map/reduce with all options)
- Counter operations
- Touch and unlock
- CAS support
- Durability levels
- N1QL queries
- Replica reads
- Error handling
- 69 comprehensive tests

Not implemented:
- Analytics queries
- Full-text search
- Spatial views
- Transactions
- Connection pooling
- Async support

## License

MIT License

## Links

- [libcouchbase](https://github.com/couchbase/libcouchbase)
- [Couchbase Documentation](https://docs.couchbase.com/)
- [libcouchbase Documentation](https://docs.couchbase.com/c-sdk/current/hello-world/start-using-sdk.html)

(First beta release of the Couchbase Zig Client, an idiomatic Zig wrapper for libcouchbase. This release provides type-safe, memory-safe access to Couchbase Server with support for core key-value operations and N1QL queries.)
