const std = @import("std");

pub const c = @import("c.zig");
pub const Client = @import("client.zig").Client;
pub const Error = @import("error.zig").Error;
pub const StatusCode = @import("error.zig").StatusCode;
pub const types = @import("types.zig");
pub const operations = @import("operations.zig");

// Re-export common types
pub const Document = types.Document;
pub const GetResult = operations.GetResult;
pub const MutationResult = operations.MutationResult;
pub const QueryResult = operations.QueryResult;
pub const QueryOptions = operations.QueryOptions;
pub const Durability = types.Durability;
pub const DurabilityLevel = types.DurabilityLevel;

// Test configuration from environment variables
pub fn getTestConfig() TestConfig {
    return TestConfig{
        .connection_string = std.process.getEnvVarOwned(std.heap.page_allocator, "COUCHBASE_HOST") catch "couchbase://127.0.0.1",
        .username = std.process.getEnvVarOwned(std.heap.page_allocator, "COUCHBASE_USER") catch "tester",
        .password = std.process.getEnvVarOwned(std.heap.page_allocator, "COUCHBASE_PASSWORD") catch "csfb2010",
        .bucket = std.process.getEnvVarOwned(std.heap.page_allocator, "COUCHBASE_BUCKET") catch "default",
        .timeout_ms = 30000,
    };
}

pub const TestConfig = struct {
    connection_string: []const u8,
    username: []const u8,
    password: []const u8,
    bucket: []const u8,
    timeout_ms: u32,
};

test {
    std.testing.refAllDecls(@This());
}
