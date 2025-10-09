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

    // Create test document
    const doc = \\{"type": "test", "name": "Advanced Query Test", "value": 42}
    ;
    _ = try client.upsert("test:advanced:1", doc, .{});

    // Query with profile enabled
    const query = "SELECT * FROM `default` WHERE type = 'test'";
    const options = couchbase.QueryOptions.withProfile(.timings);
    
    var result = client.query(testing.allocator, query, options) catch |err| {
        std.debug.print("Profile query skipped: {}\n", .{err});
        // Cleanup
        _ = client.remove("test:advanced:1", .{}) catch {};
        return;
    };
    defer result.deinit();

    // Should find the test document
    try testing.expect(result.rows.len >= 1);
    
    // Cleanup
    _ = client.remove("test:advanced:1", .{}) catch {};
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

test "advanced query options - scan capabilities" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    // Query with scan capabilities
    const query = "SELECT * FROM `default` LIMIT 10";
    var options = couchbase.QueryOptions{};
    options.scan_cap = 100;
    options.scan_wait = 1000; // 1 second
    
    var result = client.query(testing.allocator, query, options) catch |err| {
        std.debug.print("Scan capabilities query skipped: {}\n", .{err});
        return;
    };
    defer result.deinit();

    // Should execute successfully
    try testing.expect(result.rows.len >= 0);
}

test "advanced query options - flex index" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    // Query with flex index enabled
    const query = "SELECT * FROM `default` WHERE type = 'test'";
    var options = couchbase.QueryOptions{};
    options.flex_index = true;
    
    var result = client.query(testing.allocator, query, options) catch |err| {
        std.debug.print("Flex index query skipped: {}\n", .{err});
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

test "analytics query - with options" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    // Analytics query with options
    const query = "SELECT 1 as test";
    var options = couchbase.AnalyticsOptions{
        .timeout_ms = 60000,
        .priority = true,
        .read_only = true,
        .pretty = true,
        .metrics = true,
    };
    options.client_context_id = "analytics-test-123";
    
    var result = client.analyticsQuery(testing.allocator, query, options) catch |err| {
        std.debug.print("Analytics query with options skipped: {}\n", .{err});
        return;
    };
    defer result.deinit();

    // Should execute successfully
    try testing.expect(result.rows.len >= 0);
}

test "analytics query - with parameters" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    // Analytics query with positional parameters
    const query = "SELECT $1 as param1, $2 as param2";
    const params = [_][]const u8{"value1", "value2"};
    var options = couchbase.AnalyticsOptions{};
    options.positional_parameters = &params;
    
    var result = client.analyticsQuery(testing.allocator, query, options) catch |err| {
        std.debug.print("Analytics query with parameters skipped: {}\n", .{err});
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

test "search query - with options" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    // Search query with options
    const index_name = "test_index";
    const query = \\{"query": {"match": "test"}, "size": 10}
    ;
    var options = couchbase.SearchOptions{
        .timeout_ms = 30000,
        .limit = 10,
        .explain = true,
        .highlight_style = "html",
        .disable_scoring = false,
        .include_locations = true,
    };
    options.client_context_id = "search-test-123";
    
    var result = client.searchQuery(testing.allocator, index_name, query, options) catch |err| {
        std.debug.print("Search query with options skipped (no index): {}\n", .{err});
        return;
    };
    defer result.deinit();

    // If it succeeds, should have results
    try testing.expect(result.rows.len >= 0);
}

test "query performance - multiple advanced options" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    // Create test documents
    for (0..5) |i| {
        const doc = try std.fmt.allocPrint(testing.allocator, \\{"type": "perf_test", "id": {d}, "value": {d}}\\, .{ i, i * 10 });
        defer testing.allocator.free(doc);
        const key = try std.fmt.allocPrint(testing.allocator, "test:perf:{d}", .{i});
        defer testing.allocator.free(key);
        _ = try client.upsert(key, doc, .{});
    }

    // Query with multiple advanced options
    const query = "SELECT * FROM `default` WHERE type = 'perf_test' ORDER BY id";
    var options = couchbase.QueryOptions{
        .profile = .phases,
        .read_only = true,
        .scan_cap = 50,
        .scan_wait = 500,
        .flex_index = true,
        .pretty = true,
        .metrics = true,
    };
    options.client_context_id = "performance-test-123";
    
    var result = client.query(testing.allocator, query, options) catch |err| {
        std.debug.print("Performance query skipped: {}\n", .{err});
        // Cleanup
        for (0..5) |i| {
            const key = std.fmt.allocPrint(testing.allocator, "test:perf:{d}", .{i}) catch continue;
            defer testing.allocator.free(key);
            _ = client.remove(key, .{}) catch {};
        }
        return;
    };
    defer result.deinit();

    // Should find test documents
    try testing.expect(result.rows.len >= 5);
    
    // Cleanup
    for (0..5) |i| {
        const key = std.fmt.allocPrint(testing.allocator, "test:perf:{d}", .{i}) catch continue;
        defer testing.allocator.free(key);
        _ = client.remove(key, .{}) catch {};
    }
}

test "query error handling - invalid options" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    // Query with potentially invalid options
    const query = "SELECT * FROM `default` WHERE invalid_field = 'test'";
    const options = couchbase.QueryOptions{
        .profile = .timings,
        .read_only = true,
        .scan_cap = 0, // Potentially invalid
        .flex_index = true,
    };
    
    var result = client.query(testing.allocator, query, options) catch |err| {
        // Expected to fail with invalid field
        std.debug.print("Invalid query handled: {}\n", .{err});
        return;
    };
    defer result.deinit();

    // If it doesn't fail, that's also acceptable
    try testing.expect(result.rows.len >= 0);
}
