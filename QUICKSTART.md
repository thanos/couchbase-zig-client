# Quick Start Guide

## Installation

Install libcouchbase:
```bash
# macOS
brew install libcouchbase

# Ubuntu/Debian
sudo apt-get install libcouchbase-dev libcouchbase3
```

Clone repository:
```bash
git clone [repository-url]
cd couchbase-zig-client
```

## Basic Usage

Create a file `main.zig`:

```zig
const std = @import("std");
const couchbase = @import("couchbase");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Connect
    var client = try couchbase.Client.connect(allocator, .{
        .connection_string = "couchbase://localhost",
        .username = "Administrator",
        .password = "password",
        .bucket = "default",
    });
    defer client.disconnect();

    // Store document
    const doc_id = "user:alice";
    const doc_data = \\{"name": "Alice", "email": "alice@example.com"}
    ;
    
    _ = try client.upsert(doc_id, doc_data, .{});
    std.debug.print("Document stored\n", .{});

    // Retrieve document
    var result = try client.get(doc_id);
    defer result.deinit();
    
    std.debug.print("Retrieved: {s}\n", .{result.value});

    // Remove document
    _ = try client.remove(doc_id, .{});
    std.debug.print("Document removed\n", .{});
}
```

Build and run:
```bash
zig build-exe main.zig --dep couchbase -Mcouchbase=src/root.zig \
  -lc -lcouchbase
./main
```

## Common Operations

### Counter
```zig
const views = try client.increment("counter:page-views", 1, .{ .initial = 0 });
std.debug.print("Page views: {d}\n", .{views.value});
```

### CAS (Optimistic Locking)
```zig
var result = try client.get("doc");
defer result.deinit();

_ = try client.replace("doc", new_value, .{ .cas = result.cas });
```

### Query
```zig
var result = try client.query(allocator, 
    "SELECT * FROM `default` WHERE type = 'user'", 
    .{});
defer result.deinit();

for (result.rows) |row| {
    std.debug.print("{s}\n", .{row});
}
```

### Expiration
```zig
_ = try client.upsert("temp", "data", .{ .expiry = 3600 }); // 1 hour
```

### Durability
```zig
_ = try client.upsert("important", data, .{
    .durability = .{ .level = .majority },
});
```

## Environment Variables

Configure tests:
```bash
export COUCHBASE_HOST="couchbase://localhost"
export COUCHBASE_USER="username"
export COUCHBASE_PASSWORD="password"
export COUCHBASE_BUCKET="bucket"
```

## Run Examples

```bash
zig build examples
zig build run-basic
zig build run-kv_operations
zig build run-query
```

## Run Tests

```bash
# No server required
zig build test-unit

# Requires server
zig build test-integration
zig build test-coverage

# All tests
zig build test-all
```

## Next Steps

- Read README.md for full API documentation
- Check examples/ for more code samples
- See ARCHITECTURE.md for design details
- Review GAP_ANALYSIS.md for feature roadmap
