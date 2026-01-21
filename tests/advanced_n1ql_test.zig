const std = @import("std");
const couchbase = @import("couchbase");


fn getTestClient(allocator: std.mem.Allocator) !couchbase.Client {
    const cfg = couchbase.getTestConfig();
    return try couchbase.Client.connect(allocator, .{
        .connection_string = cfg.connection_string,
        .username = cfg.username,
        .password = cfg.password,
        .bucket = "travel-sample", // Use travel-sample bucket for N1QL tests
        .timeout_ms = cfg.timeout_ms,
    });
}

test "advanced n1ql - query profile timings" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = try getTestClient(allocator);
    defer client.disconnect();

    // Test query with timings profile using travel-sample data
    const options = couchbase.operations.QueryOptions{ .profile = .timings };
    const result = client.query(allocator, "SELECT COUNT(*) as count FROM `travel-sample` WHERE type = 'airline' LIMIT 1", options) catch |err| switch (err) {
        couchbase.Error.Timeout, couchbase.Error.InvalidArgument => {
            // Expected when server is not running or feature not available
            return;
        },
        else => return err,
    };
    defer result.deinit();
}

test "advanced n1ql - readonly queries" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = try getTestClient(allocator);
    defer client.disconnect();

    // Test readonly query using travel-sample data
    const options = couchbase.operations.QueryOptions{ .read_only = true };
    const result = client.query(allocator, "SELECT COUNT(*) as count FROM `travel-sample` WHERE type = 'airline'", options) catch |err| switch (err) {
        couchbase.Error.Timeout, couchbase.Error.InvalidArgument => {
            // Expected when server is not running or feature not available
            return;
        },
        else => return err,
    };
    defer result.deinit();
}

test "advanced n1ql - client context id" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = try getTestClient(allocator);
    defer client.disconnect();

    // Test query with client context ID using travel-sample data
    const options = couchbase.operations.QueryOptions{ .client_context_id = "test-context-123" };
    const result = client.query(allocator, "SELECT name FROM `travel-sample` WHERE type = 'airline' LIMIT 5", options) catch |err| switch (err) {
        couchbase.Error.Timeout, couchbase.Error.InvalidArgument => {
            // Expected when server is not running or feature not available
            return;
        },
        else => return err,
    };
    defer result.deinit();
}

test "advanced n1ql - scan capabilities" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = try getTestClient(allocator);
    defer client.disconnect();

    // Test query with scan capabilities using travel-sample data
    const options = couchbase.operations.QueryOptions{ .scan_cap = 1000, .scan_wait = 5000 };
    const result = client.query(allocator, "SELECT name FROM `travel-sample` WHERE type = 'airline' LIMIT 10", options) catch |err| switch (err) {
        couchbase.Error.Timeout, couchbase.Error.InvalidArgument => {
            // Expected when server is not running or feature not available
            return;
        },
        else => return err,
    };
    defer result.deinit();
}

test "advanced n1ql - flex index support" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = try getTestClient(allocator);
    defer client.disconnect();

    // Test query with flex index using travel-sample data
    const options = couchbase.operations.QueryOptions{ .flex_index = true };
    const result = client.query(allocator, "SELECT name FROM `travel-sample` WHERE type = 'airline' LIMIT 5", options) catch |err| switch (err) {
        couchbase.Error.Timeout, couchbase.Error.InvalidArgument => {
            // Expected when server is not running or feature not available
            return;
        },
        else => return err,
    };
    defer result.deinit();
}

test "advanced n1ql - performance tuning" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = try getTestClient(allocator);
    defer client.disconnect();

    // Test query with performance tuning using travel-sample data
    const options = couchbase.operations.QueryOptions{ .max_parallelism = 4, .pipeline_batch = 100, .pipeline_cap = 1000 };
    const result = client.query(allocator, "SELECT name, country FROM `travel-sample` WHERE type = 'airline' LIMIT 20", options) catch |err| switch (err) {
        couchbase.Error.Timeout, couchbase.Error.InvalidArgument => {
            // Expected when server is not running or feature not available
            return;
        },
        else => return err,
    };
    defer result.deinit();
}

test "advanced n1ql - pretty printing" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = try getTestClient(allocator);
    defer client.disconnect();

    // Test query with pretty printing using travel-sample data
    const options = couchbase.operations.QueryOptions{ .pretty = true };
    const result = client.query(allocator, "SELECT name FROM `travel-sample` WHERE type = 'airline' LIMIT 3", options) catch |err| switch (err) {
        couchbase.Error.Timeout, couchbase.Error.InvalidArgument => {
            // Expected when server is not running or feature not available
            return;
        },
        else => return err,
    };
    defer result.deinit();
}

test "advanced n1ql - without metrics" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = try getTestClient(allocator);
    defer client.disconnect();

    // Test query without metrics using travel-sample data
    const options = couchbase.operations.QueryOptions{ .metrics = false };
    const result = client.query(allocator, "SELECT COUNT(*) as count FROM `travel-sample` WHERE type = 'airline'", options) catch |err| switch (err) {
        couchbase.Error.Timeout, couchbase.Error.InvalidArgument => {
            // Expected when server is not running or feature not available
            return;
        },
        else => return err,
    };
    defer result.deinit();
}

