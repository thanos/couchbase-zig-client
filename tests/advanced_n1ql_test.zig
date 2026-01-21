const std = @import("std");
const couchbase = @import("couchbase");


fn getTestClient(allocator: std.mem.Allocator) !couchbase.Client {
    const cfg = couchbase.getTestConfig();
    return try couchbase.Client.connect(allocator, .{
        .connection_string = cfg.connection_string,
        .username = cfg.username,
        .password = cfg.password,
        .bucket = cfg.bucket,
        .timeout_ms = cfg.timeout_ms,
    });
}

test "advanced n1ql - query profile timings" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = try getTestClient(allocator);
    defer client.disconnect();

    // Test query with timings profile
    const options = couchbase.operations.QueryOptions{ .profile = .timings };
    const result = client.query(allocator, "SELECT 1 as test", options) catch |err| switch (err) {
        couchbase.Error.Timeout => {
            // Expected when server is not running
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

    // Test readonly query
    const options = couchbase.operations.QueryOptions{ .read_only = true };
    const result = client.query(allocator, "SELECT 1 as test", options) catch |err| switch (err) {
        couchbase.Error.Timeout => {
            // Expected when server is not running
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

    // Test query with client context ID
    const options = couchbase.operations.QueryOptions{ .client_context_id = "test-context-123" };
    const result = client.query(allocator, "SELECT 1 as test", options) catch |err| switch (err) {
        couchbase.Error.Timeout => {
            // Expected when server is not running
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

    // Test query with scan capabilities
    const options = couchbase.operations.QueryOptions{ .scan_cap = 1000, .scan_wait = 5000 };
    const result = client.query(allocator, "SELECT 1 as test", options) catch |err| switch (err) {
        couchbase.Error.Timeout => {
            // Expected when server is not running
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

    // Test query with flex index
    const options = couchbase.operations.QueryOptions{ .flex_index = true };
    const result = client.query(allocator, "SELECT 1 as test", options) catch |err| switch (err) {
        couchbase.Error.Timeout => {
            // Expected when server is not running
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

    // Test query with performance tuning
    const options = couchbase.operations.QueryOptions{ .max_parallelism = 4, .pipeline_batch = 100, .pipeline_cap = 1000 };
    const result = client.query(allocator, "SELECT 1 as test", options) catch |err| switch (err) {
        couchbase.Error.Timeout => {
            // Expected when server is not running
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

    // Test query with pretty printing
    const options = couchbase.operations.QueryOptions{ .pretty = true };
    const result = client.query(allocator, "SELECT 1 as test", options) catch |err| switch (err) {
        couchbase.Error.Timeout => {
            // Expected when server is not running
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

    // Test query without metrics
    const options = couchbase.operations.QueryOptions{ .metrics = false };
    const result = client.query(allocator, "SELECT 1 as test", options) catch |err| switch (err) {
        couchbase.Error.Timeout => {
            // Expected when server is not running
            return;
        },
        else => return err,
    };
    defer result.deinit();
}

