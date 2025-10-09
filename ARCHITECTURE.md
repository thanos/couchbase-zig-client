# Architecture and Design

This document describes the architecture and design decisions of the Couchbase Zig Client.

## Overview

The library wraps the libcouchbase C library with an idiomatic Zig API that provides:
- Type safety through Zig's error handling
- Memory safety with explicit allocator usage
- Clean abstraction over C callbacks
- Zero-cost abstractions where possible

## Module Structure

```
couchbase-zig-client/
 src/
    root.zig           # Public API exports
    c.zig              # C bindings via @cImport
    client.zig         # Client connection and high-level API
    operations.zig     # Operation implementations
    error.zig          # Error type mappings
    types.zig          # Common types and enums
 examples/
    basic.zig          # Basic CRUD operations
    kv_operations.zig  # Comprehensive KV examples
    query.zig          # N1QL query examples
 build.zig              # Build configuration
 build.zig.zon          # Package metadata
```

## Design Patterns

### 1. Callback to Synchronous API

libcouchbase uses an asynchronous callback model, but this wrapper presents a synchronous API:

```zig
// Internal: C callback is registered
const callback = struct {
    fn cb(instance: ?*c.lcb_INSTANCE, cbtype: c.lcb_CALLBACK_TYPE, 
          resp: [*c]const c.lcb_RESPGET) callconv(.C) void {
        // Handle response, store in context
    }
}.cb;

// External: User sees synchronous call
var result = try client.get("key");
```

**Why?** Zig doesn't have built-in async/await (yet), and most users prefer synchronous APIs for simplicity.

### 2. Context Structures

Each operation uses a context structure to pass data between the caller and callback:

```zig
const GetContext = struct {
    result: ?GetResult = null,
    err: ?Error = null,
    done: bool = false,
};
```

The context is passed as a "cookie" pointer through libcouchbase and retrieved in the callback.

### 3. Memory Management

All memory allocations are explicit:

- **Input**: Keys and values are NOT copied by default (zero-copy where possible)
- **Output**: Response data IS copied and owned by the caller
- **Cleanup**: All result types have a `deinit()` method

```zig
var result = try client.get("key");
defer result.deinit(); // User responsible for cleanup
```

### 4. Error Handling

libcouchbase status codes are mapped to Zig errors:

```zig
pub fn fromStatusCode(rc: c.lcb_STATUS) Error!void {
    if (rc == c.LCB_SUCCESS) return;
    return switch (@as(c_int, rc)) {
        c.LCB_ERR_DOCUMENT_NOT_FOUND => error.DocumentNotFound,
        c.LCB_ERR_TIMEOUT => error.Timeout,
        // ... more mappings
    };
}
```

This allows idiomatic Zig error handling:

```zig
const result = client.get("key") catch |err| switch (err) {
    error.DocumentNotFound => {
        // Handle specific error
    },
    else => return err,
};
```

### 5. Options Structs

Operations accept option structs with sensible defaults:

```zig
pub const StoreOptions = struct {
    cas: u64 = 0,
    expiry: u32 = 0,
    flags: u32 = 0,
    durability: types.Durability = .{},
};

// Usage
try client.upsert("key", "value", .{
    .expiry = 3600,
    .durability = .{ .level = .majority },
});
```

## Implementation Details

### Connection Management

The `Client` struct wraps a libcouchbase instance:

```zig
pub const Client = struct {
    instance: *c.lcb_INSTANCE,
    allocator: std.mem.Allocator,
    
    pub fn connect(allocator: std.mem.Allocator, options: ConnectOptions) !Client
    pub fn disconnect(self: *Client) void
};
```

Connection is established in `connect()` with:
1. Create connection options
2. Create libcouchbase instance
3. Configure authentication
4. Connect and wait for bootstrap

### Operation Flow

1. **Setup**: Create command structure, set parameters
2. **Callback**: Install callback handler for this operation type
3. **Execute**: Call libcouchbase operation function with context
4. **Wait**: Block on `lcb_wait()` until callback fires
5. **Return**: Check context for error or result

Example from `get()`:

```zig
pub fn get(client: *Client, key: []const u8) Error!GetResult {
    var ctx = GetContext{};
    
    // Setup command
    var cmd: c.lcb_CMDGET = undefined;
    c.lcb_cmdget_create(&cmd);
    defer c.lcb_cmdget_destroy(cmd);
    _ = c.lcb_cmdget_key(cmd, key.ptr, key.len);
    
    // Install callback
    const callback = /* ... */;
    _ = c.lcb_install_callback(client.instance, c.LCB_CALLBACK_GET, @ptrCast(&callback));
    
    // Execute
    var rc = c.lcb_get(client.instance, &ctx, cmd);
    try fromStatusCode(rc);
    
    // Wait
    rc = c.lcb_wait(client.instance, c.LCB_WAIT_DEFAULT);
    try fromStatusCode(rc);
    
    // Return
    if (ctx.err) |err| return err;
    return ctx.result orelse error.Unknown;
}
```

### Query Handling

Queries are streamed row-by-row through callbacks:

```zig
const QueryContext = struct {
    rows: std.ArrayList([]u8),
    meta: ?[]u8 = null,
    err: ?Error = null,
    done: bool = false,
};
```

Each row callback appends to the `ArrayList`, and `is_final()` signals completion.

## Performance Considerations

### Allocation Strategy

- **Temporary allocations**: Use provided allocator for short-lived data
- **Result allocations**: Copy response data for safety
- **Arena allocators**: Consider using for queries with many rows

### Blocking I/O

The current implementation blocks on `lcb_wait()`. For high concurrency:
- Use multiple clients across threads
- Consider connection pooling pattern
- Future: implement async support

### Zero-Copy Opportunities

Keys and values passed to operations are NOT copied:

```zig
const key = "my-key";
const value = try std.json.stringify(...);
try client.upsert(key, value, .{}); // No copy of key/value
```

## Thread Safety

**Not thread-safe**: A single `Client` instance should not be used from multiple threads simultaneously.

**Thread-safe pattern**: Create one client per thread:

```zig
fn worker(allocator: std.mem.Allocator) !void {
    var client = try Client.connect(allocator, conn_opts);
    defer client.disconnect();
    // Use client in this thread only
}
```

## Future Enhancements

### 1. Async/Await Support

When Zig stabilizes async/await, provide async versions:

```zig
pub fn getAsync(self: *Client, key: []const u8) !GetResult {
    suspend {
        // Schedule operation
        // Resume when callback fires
    }
}
```

### 2. Connection Pooling

```zig
pub const Pool = struct {
    clients: []Client,
    pub fn acquire() !*Client
    pub fn release(client: *Client) void
};
```

### 3. Batch Operations

libcouchbase supports batching for better throughput:

```zig
pub fn batchGet(self: *Client, keys: []const []const u8) ![]GetResult
```

### 4. Streaming Queries

Return iterator instead of full result set:

```zig
pub fn queryStream(self: *Client, statement: []const u8) !QueryIterator
```

## Testing Strategy

### Unit Tests

Test individual operations against a running Couchbase instance:

```zig
test "basic get/set" {
    var client = try Client.connect(testing.allocator, .{...});
    defer client.disconnect();
    
    try client.upsert("test-key", "test-value", .{});
    var result = try client.get("test-key");
    defer result.deinit();
    
    try testing.expectEqualStrings("test-value", result.value);
}
```

### Integration Tests

Test complex workflows and error conditions.

### Benchmark Tests

Measure performance vs raw libcouchbase:

```zig
test "benchmark get" {
    var timer = try std.time.Timer.start();
    for (0..10000) |i| {
        _ = try client.get(keys[i]);
    }
    const elapsed = timer.read();
    std.debug.print("Ops/sec: {}\n", .{10000 * 1_000_000_000 / elapsed});
}
```

## Error Handling Guidelines

### Recoverable vs Fatal Errors

- **Recoverable**: `DocumentNotFound`, `DocumentExists`, `Timeout`, `TemporaryFailure`
- **Fatal**: `AuthenticationFailed`, `BucketNotFound`, `InternalError`

### Retry Logic

For `TemporaryFailure`, implement exponential backoff:

```zig
var retries: u32 = 0;
while (retries < 3) : (retries += 1) {
    const result = client.get(key) catch |err| {
        if (err == error.TemporaryFailure) {
            std.time.sleep(std.math.pow(u64, 2, retries) * std.time.ns_per_ms * 100);
            continue;
        }
        return err;
    };
    // Success
    break;
}
```

## Contributing

When adding new operations:

1. Add C binding in `c.zig` if needed
2. Add operation function in `operations.zig`
3. Add convenience method in `client.zig`
4. Add example in `examples/`
5. Update README and this document
6. Add tests

Follow these patterns:
- All allocations use provided allocator
- All results have `deinit()` if they allocate
- Use option structs with defaults
- Map all status codes to errors
- Add doc comments for public API
