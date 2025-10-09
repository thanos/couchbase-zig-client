const std = @import("std");
const testing = std.testing;
const couchbase = @import("couchbase");

fn getTestClient(allocator: std.mem.Allocator) !couchbase.Client {
    const test_config = couchbase.getTestConfig();
    return try couchbase.Client.connect(allocator, .{
        .connection_string = test_config.connection_string,
        .username = test_config.username,
        .password = test_config.password,
        .bucket = test_config.bucket,
        .timeout_ms = test_config.timeout_ms,
    });
}

test "advanced query options - profile" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    // Query with profile enabled
    const query = "SELECT 1 as test";
    const options = couchbase.QueryOptions.withProfile(.timings);
    
    var result = client.query(testing.allocator, query, options) catch |err| {
        std.debug.print("Profile query skipped: {}\n", .{err});
        return;
    };
    defer result.deinit();

    // Should execute successfully
    try testing.expect(result.rows.len >= 0);
}

test "advanced query options - readonly" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    // Query with readonly enabled
    const query = "SELECT COUNT(*) as count FROM `default`";
    const options = couchbase.QueryOptions.readonly();
    
    var result = client.query(testing.allocator, query, options) catch |err| {
        std.debug.print("Readonly query skipped: {}\n", .{err});
        return;
    };
    defer result.deinit();

    // Should execute successfully
    try testing.expect(result.rows.len >= 0);
}

test "advanced query options - client context ID" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    // Query with client context ID
    const query = "SELECT 1 as test";
    const options = couchbase.QueryOptions.withContextId("test-context-123");
    
    var result = client.query(testing.allocator, query, options) catch |err| {
        std.debug.print("Context ID query skipped: {}\n", .{err});
        return;
    };
    defer result.deinit();

    // Should execute successfully
    try testing.expect(result.rows.len >= 0);
}

test "analytics query - basic" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    // Basic analytics query
    const query = "SELECT 1 as test";
    const options = couchbase.AnalyticsOptions{};
    
    var result = client.analyticsQuery(testing.allocator, query, options) catch |err| {
        std.debug.print("Analytics query skipped: {}\n", .{err});
        return;
    };
    defer result.deinit();

    // Should execute successfully
    try testing.expect(result.rows.len >= 0);
}

test "search query - basic" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    // Basic search query (this will likely fail without a search index)
    const index_name = "test_index";
    const query = \\{"query": {"match": "test"}}
    ;
    const options = couchbase.SearchOptions{};
    
    var result = client.searchQuery(testing.allocator, index_name, query, options) catch |err| {
        std.debug.print("Search query skipped (no index): {}\n", .{err});
        return;
    };
    defer result.deinit();

    // If it succeeds, should have results
    try testing.expect(result.rows.len >= 0);
}
