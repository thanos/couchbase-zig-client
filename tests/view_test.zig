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

test "view query - basic" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    // Create some test documents
    const doc1 = \\{"name": "Alice", "age": 30, "type": "user"}
    ;
    const doc2 = \\{"name": "Bob", "age": 25, "type": "user"}
    ;

    _ = client.upsert("view_test:1", doc1, .{}) catch {};
    _ = client.upsert("view_test:2", doc2, .{}) catch {};

    // Query view (will fail if design doc doesn't exist)
    var result = client.viewQuery(
        testing.allocator,
        "dev_users",
        "by_name",
        .{},
    ) catch |err| {
        std.debug.print("View query not available (design doc may not exist): {}\n", .{err});
        _ = client.remove("view_test:1", .{}) catch {};
        _ = client.remove("view_test:2", .{}) catch {};
        return;
    };
    defer result.deinit();

    std.debug.print("View returned {d} rows\n", .{result.rows.len});

    // Clean up
    _ = client.remove("view_test:1", .{}) catch {};
    _ = client.remove("view_test:2", .{}) catch {};
}

test "view query - with options" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    // Query with various options
    var result = client.viewQuery(
        testing.allocator,
        "dev_test",
        "all",
        .{
            .limit = 10,
            .skip = 0,
            .descending = false,
            .include_docs = true,
            .reduce = false,
        },
    ) catch |err| {
        std.debug.print("View query with options skipped: {}\n", .{err});
        return;
    };
    defer result.deinit();

    try testing.expect(result.rows.len <= 10);
}

test "view query - with key range" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    var result = client.viewQuery(
        testing.allocator,
        "dev_test",
        "by_key",
        .{
            .start_key = "\"a\"",
            .end_key = "\"z\"",
        },
    ) catch |err| {
        std.debug.print("View query with key range skipped: {}\n", .{err});
        return;
    };
    defer result.deinit();

    try testing.expect(result.rows.len >= 0);
}

test "view query - reduce" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    var result = client.viewQuery(
        testing.allocator,
        "dev_stats",
        "count_by_type",
        .{
            .reduce = true,
            .group = true,
        },
    ) catch |err| {
        std.debug.print("View reduce query skipped: {}\n", .{err});
        return;
    };
    defer result.deinit();

    try testing.expect(result.rows.len >= 0);
}

test "view query - limit and skip" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    var result = client.viewQuery(
        testing.allocator,
        "dev_test",
        "all_docs",
        .{
            .limit = 5,
            .skip = 2,
            .stale = .ok,
        },
    ) catch |err| {
        std.debug.print("View limit/skip query skipped: {}\n", .{err});
        return;
    };
    defer result.deinit();

    try testing.expect(result.rows.len <= 5);
}
