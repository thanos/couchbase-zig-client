
# couchbase-zig-client

Zig wrapper for the libcouchbase C library.

<img width="512" height="512" alt="Gemini_Generated_Image_2djlhc2djlhc2djl (1)" src="https://github.com/user-attachments/assets/be04a5c1-5d8c-43aa-9073-0a249f51044f" />







## Features

- Key-value operations: get, insert, upsert, replace, remove, touch, counter
- N1QL query execution
- Subdocument operations (partial implementation)
- CAS (compare-and-swap) support
- Durability levels
- Replica reads
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
const query = "SELECT * FROM `default` WHERE type = $1";
var result = try client.query(allocator, query, .{
    .consistency = .request_plus,
    .adhoc = true,
});
defer result.deinit();

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
- `lookupIn(allocator, key, specs)` - Subdocument lookup (stub)
- `mutateIn(allocator, key, specs, options)` - Subdocument mutation (stub)
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
- Connection management
- KV operations (get, insert, upsert, replace, remove)
- Counter operations
- Touch and unlock
- CAS support
- Durability levels
- N1QL queries
- Replica reads
- Error handling

Not implemented:
- Subdocument operations (partial)
- Analytics queries
- Full-text search
- Views
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
