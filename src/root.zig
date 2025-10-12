const std = @import("std");

pub const c = @import("c.zig");
pub const Client = @import("client.zig").Client;
pub const Error = @import("error.zig").Error;
pub const StatusCode = @import("error.zig").StatusCode;
pub const types = @import("types.zig");
pub const operations = @import("operations.zig");
pub const views = @import("views.zig");

// Re-export common types
pub const Document = types.Document;
pub const GetResult = operations.GetResult;
pub const MutationResult = operations.MutationResult;
pub const QueryResult = operations.QueryResult;
pub const QueryOptions = operations.QueryOptions;
pub const ViewResult = views.ViewResult;
pub const ViewOptions = views.ViewOptions;
pub const ViewStale = views.ViewStale;
pub const Durability = types.Durability;
pub const DurabilityLevel = types.DurabilityLevel;

    // Advanced query types
    pub const QueryProfile = types.QueryProfile;
    pub const QueryConsistency = types.QueryConsistency;
    pub const AnalyticsOptions = types.AnalyticsOptions;
    pub const SearchOptions = types.SearchOptions;
    pub const AnalyticsResult = operations.AnalyticsResult;
    pub const SearchResult = operations.SearchResult;
    
    // Prepared statement types
    pub const PreparedStatement = types.PreparedStatement;
    pub const PreparedStatementCache = types.PreparedStatementCache;
    
    // Query cancellation types
    pub const QueryHandle = types.QueryHandle;
    pub const QueryCancellationOptions = types.QueryCancellationOptions;
    
    // Enhanced query metadata types
    pub const QueryMetadata = types.QueryMetadata;
    pub const QueryMetrics = types.QueryMetrics;
    pub const ConsistencyToken = types.ConsistencyToken;
    
    // Lock operation types
    pub const GetAndLockOptions = types.GetAndLockOptions;
    pub const UnlockOptions = types.UnlockOptions;
    pub const GetAndLockResult = operations.GetAndLockResult;
    pub const UnlockResult = operations.UnlockResult;

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
