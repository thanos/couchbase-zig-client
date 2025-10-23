# Couchbase Zig Client

A high-performance, memory-safe Zig client library for Couchbase Server, providing comprehensive access to Couchbase's key-value, query, analytics, and search capabilities.

## Features

### Core Operations
- **Key-Value Operations**: Get, set, delete, touch, and lock operations
- **Collections & Scopes**: Full support for Couchbase collections and scopes
- **Batch Operations**: Efficient batch processing for multiple operations
- **Durability**: Configurable durability requirements and consistency options

### Query & Analytics
- **N1QL Queries**: Full N1QL query support with prepared statements
- **Analytics Queries**: Couchbase Analytics integration
- **Query Options**: Advanced query configuration and optimization
- **Parameterized Queries**: Safe parameter binding and injection prevention

### Transactions
- **ACID Transactions**: Complete transaction support with begin, commit, rollback
- **Transaction Context**: Automatic transaction management and retry logic
- **Nested Operations**: Transaction-aware key-value operations

### Advanced Features
- **Diagnostics & Monitoring**: Health checks, metrics, and performance monitoring
- **Error Handling & Logging**: Comprehensive error context and configurable logging
- **Binary Protocol**: Native binary protocol support with feature negotiation
- **Connection Management**: Connection pooling, failover, and retry policies
- **Certificate Authentication**: X.509 certificate-based authentication
- **DNS SRV**: Advanced DNS resolution and service discovery

### Memory Safety
- **Zero-Copy Operations**: Efficient memory management with minimal allocations
- **Automatic Cleanup**: RAII-style resource management
- **Error Propagation**: Comprehensive error handling with detailed context

## Gap Analysis

| Feature Category | libcouchbase C | Zig Client | Status |
|------------------|----------------|------------|---------|
| **Core KV Operations** | 100% | 100% | Complete |
| **Collections & Scopes** | 100% | 100% | Complete |
| **N1QL Queries** | 100% | 100% | Complete |
| **Analytics Queries** | 100% | 100% | Complete |
| **Search Queries** | 100% | 100% | Complete |
| **Transactions** | 100% | 100% | Complete |
| **Durability** | 100% | 100% | Complete |
| **Batch Operations** | 100% | 100% | Complete |
| **Diagnostics** | 100% | 100% | Complete |
| **Error Handling** | 100% | 100% | Complete |
| **Binary Protocol** | 100% | 100% | Complete |
| **Connection Features** | 100% | 100% | Complete |
| **Views** | 100% | 100% | Complete |
| **Subdocument** | 100% | 100% | Complete |
| **SDK Metrics** | 100% | 100% | Complete |

**Overall Coverage**: 100% of libcouchbase functionality

## Requirements

- **Zig**: 0.11.0 or later
- **libcouchbase**: 3.3.0 or later
- **Couchbase Server**: 7.0 or later (recommended 7.2+)
- **Operating System**: Linux, macOS, Windows

## Installation

### Prerequisites

1. Install Zig 0.11.0 or later:
```bash
   # macOS
   brew install zig
   
   # Linux
   curl -L https://ziglang.org/download/0.11.0/zig-linux-x86_64-0.11.0.tar.xz | tar -xJ
   ```

2. Install libcouchbase:
```bash
   # macOS
   brew install libcouchbase
   
   # Ubuntu/Debian
   sudo apt-get install libcouchbase-dev
   
   # CentOS/RHEL
   sudo yum install libcouchbase-devel
   ```

### Build

```bash
git clone https://github.com/your-org/couchbase-zig-client.git
cd couchbase-zig-client
zig build
```

## Quick Start

### Basic Connection

```zig
const std = @import("std");
const couchbase = @import("couchbase");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Connect to Couchbase
    const client = try couchbase.Client.connect(allocator, .{
        .connection_string = "couchbase://localhost",
        .username = "Administrator",
        .password = "password",
        .bucket = "default",
    });
    defer client.disconnect();

    // Store a document
    const result = try client.upsert("user:123", "{\"name\":\"John Doe\",\"age\":30}", .{});
    std.debug.print("Document stored with CAS: {}\n", .{result.cas});

    // Retrieve the document
    const get_result = try client.get("user:123");
    std.debug.print("Retrieved: {s}\n", .{get_result.value});
}
```

### Collections & Scopes

```zig
// Work with collections
const collection = couchbase.Collection{
    .name = "users",
    .scope = "production",
};

const result = try client.upsertWithCollection("user:456", "{\"name\":\"Jane Doe\"}", collection, .{});
```

### N1QL Queries

```zig
// Execute N1QL query
const query_result = try client.query("SELECT * FROM `default` WHERE type = $1", .{
    .parameters = &[_]couchbase.QueryParameter{
        couchbase.QueryParameter.string("user")
    }
});

for (query_result.rows) |row| {
    std.debug.print("Row: {s}\n", .{row});
}
```

### Transactions

```zig
// Begin transaction
const txn = try client.beginTransaction();

// Perform operations within transaction
try txn.insert("key1", "value1", .{});
try txn.upsert("key2", "value2", .{});

// Commit transaction
try txn.commit();
```

## Documentation

### Examples

- `examples/basic.zig` - Basic CRUD operations
- `examples/kv_operations.zig` - Key-value operations with options
- `examples/query.zig` - N1QL query examples
- `examples/diagnostics.zig` - Diagnostics and monitoring
- `examples/error_handling_logging.zig` - Error handling and logging
- `examples/binary_protocol.zig` - Binary protocol features
- `examples/connection_features.zig` - Advanced connection management

### Build and Run Examples

```bash
zig build examples
zig build run-basic
zig build run-kv_operations
zig build run-query
zig build run-diagnostics
zig build run-error_handling_logging
zig build run-binary_protocol
zig build run-connection_features
```

### API Reference

#### Client Connection

```zig
pub const ConnectOptions = struct {
    connection_string: []const u8,
    username: ?[]const u8 = null,
    password: ?[]const u8 = null,
    bucket: ?[]const u8 = null,
    timeout_ms: u32 = 10000,
    logging_config: ?LoggingConfig = null,
    connection_pool_config: ?ConnectionPoolConfig = null,
    certificate_auth_config: ?CertificateAuthConfig = null,
    dns_srv_config: ?DnsSrvConfig = null,
    failover_config: ?FailoverConfig = null,
    retry_policy: ?RetryPolicy = null,
};
```

#### Key-Value Operations

```zig
// Basic operations
pub fn get(self: *Client, key: []const u8) Error!GetResult
pub fn upsert(self: *Client, key: []const u8, value: []const u8, options: StoreOptions) Error!MutationResult
pub fn insert(self: *Client, key: []const u8, value: []const u8, options: StoreOptions) Error!MutationResult
pub fn replace(self: *Client, key: []const u8, value: []const u8, options: StoreOptions) Error!MutationResult
pub fn remove(self: *Client, key: []const u8, options: RemoveOptions) Error!MutationResult

// Collection-aware operations
pub fn getWithCollection(self: *Client, key: []const u8, collection: Collection) Error!GetResult
pub fn upsertWithCollection(self: *Client, key: []const u8, value: []const u8, collection: Collection, options: StoreOptions) Error!MutationResult
```

#### Query Operations

```zig
// N1QL queries
pub fn query(self: *Client, statement: []const u8, options: QueryOptions) Error!QueryResult
pub fn queryWithNamedParams(self: *Client, statement: []const u8, params: anytype) Error!QueryResult

// Analytics queries
pub fn analyticsQuery(self: *Client, statement: []const u8, options: AnalyticsQueryOptions) Error!AnalyticsResult
```

#### Diagnostics & Monitoring

```zig
// Health checks
pub fn ping(self: *Client, allocator: std.mem.Allocator) Error!PingResult
pub fn diagnostics(self: *Client, allocator: std.mem.Allocator) Error!DiagnosticsResult

// Metrics and tracing
pub fn getSdkMetrics(self: *Client, allocator: std.mem.Allocator) Error!SdkMetricsResult
pub fn enableHttpTracing(self: *Client, allocator: std.mem.Allocator) Error!void
pub fn getHttpTraces(self: *Client, allocator: std.mem.Allocator) Error!HttpTracingResult
```

#### Error Handling & Logging

```zig
// Error context
pub fn createErrorContext(self: *Client, err: Error, operation: []const u8, status_code: c.lcb_STATUS) Error!ErrorContext

// Logging
pub fn log(self: *Client, level: LogLevel, component: []const u8, message: []const u8) void
pub fn logErrorWithContext(self: *Client, context: *ErrorContext, message: []const u8) void
pub fn setLogLevel(self: *Client, level: LogLevel) void
```

#### Connection Features

```zig
// Connection pooling
pub fn getConnectionFromPool(self: *Client) Error!*c.lcb_INSTANCE
pub fn returnConnectionToPool(self: *Client, connection: *c.lcb_INSTANCE) void

// Failover management
pub fn handleConnectionFailure(self: *Client) Error!void
pub fn getCurrentEndpoint(self: *Client) []const u8

// Retry logic
pub fn executeWithRetry(self: *Client, operation: *const fn () anyerror!void) Error!void
```

### Testing

```bash
# Run all tests
zig build test

# Run specific test suites
zig build test-unit
zig build test-integration
zig build test-diagnostics
zig build test-error-handling
zig build test-binary-protocol
zig build test-connection-features
```

### Performance

The Zig client is designed for high performance with:
- Zero-copy operations where possible
- Efficient memory management
- Minimal allocations
- Direct libcouchbase integration
- Connection pooling and reuse

### License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

### Contributing

Contributions are welcome! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Support

- **Documentation**: [Full API Documentation](docs/)
- **Issues**: [GitHub Issues](https://github.com/your-org/couchbase-zig-client/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-org/couchbase-zig-client/discussions)