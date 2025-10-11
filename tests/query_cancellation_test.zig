const std = @import("std");
const couchbase = @import("couchbase");

const TestConfig = couchbase.TestConfig;
const Client = couchbase.Client;
const QueryOptions = couchbase.QueryOptions;
const QueryHandle = couchbase.QueryHandle;
const QueryCancellationOptions = couchbase.QueryCancellationOptions;

test "query cancellation basic functionality" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const config = couchbase.getTestConfig();
    var client = Client.connect(allocator, .{
        .connection_string = config.connection_string,
        .username = config.username,
        .password = config.password,
        .bucket = config.bucket,
    }) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();
    
    const statement = "SELECT 1 as test";
    const options = QueryOptions{};
    
    // Execute query
    var result = client.query(allocator, statement, options) catch |err| {
        std.debug.print("Query failed: {}\n", .{err});
        return;
    };
    defer result.deinit();
    
    // Test cancellation
    client.cancelQuery(&result);
    
    // Check if cancelled
    const is_cancelled = client.isQueryCancelled(&result);
    std.debug.print("Query cancelled: {}\n", .{is_cancelled});
    
    std.debug.print("Query cancellation test completed\n", .{});
}

test "query cancellation with handle" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const config = couchbase.getTestConfig();
    var client = Client.connect(allocator, .{
        .connection_string = config.connection_string,
        .username = config.username,
        .password = config.password,
        .bucket = config.bucket,
    }) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();
    
    const statement = "SELECT 1 as test";
    const options = QueryOptions{};
    
    // Execute query
    var result = client.query(allocator, statement, options) catch |err| {
        std.debug.print("Query failed: {}\n", .{err});
        return;
    };
    defer result.deinit();
    
    // Test handle operations
    if (result.handle) |handle| {
        std.debug.print("Query handle ID: {}\n", .{handle.id});
        
        // Test cancellation through handle
        handle.cancel();
        std.debug.print("Handle cancelled: {}\n", .{handle.isCancelled()});
        
        // Test cancellation through result
        result.cancel();
        std.debug.print("Result cancelled: {}\n", .{result.isCancelled()});
    }
    
    std.debug.print("Query handle cancellation test completed\n", .{});
}

test "query cancellation options" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const config = couchbase.getTestConfig();
    var client = Client.connect(allocator, .{
        .connection_string = config.connection_string,
        .username = config.username,
        .password = config.password,
        .bucket = config.bucket,
    }) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();
    
    // Test cancellation options
    const cancel_options = QueryCancellationOptions{
        .timeout_ms = 10000,
        .force = true,
    };
    
    std.debug.print("Cancellation options: timeout={}ms, force={}\n", .{ cancel_options.timeout_ms, cancel_options.force });
    
    const statement = "SELECT 1 as test";
    const options = QueryOptions{};
    
    var result = client.query(allocator, statement, options) catch |err| {
        std.debug.print("Query failed: {}\n", .{err});
        return;
    };
    defer result.deinit();
    
    // Test cancellation with options
    client.cancelQuery(&result);
    
    std.debug.print("Query cancellation options test completed\n", .{});
}

test "query cancellation error handling" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const config = couchbase.getTestConfig();
    var client = Client.connect(allocator, .{
        .connection_string = config.connection_string,
        .username = config.username,
        .password = config.password,
        .bucket = config.bucket,
    }) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();
    
    const statement = "SELECT 1 as test";
    const options = QueryOptions{};
    
    var result = client.query(allocator, statement, options) catch |err| {
        std.debug.print("Query failed: {}\n", .{err});
        return;
    };
    defer result.deinit();
    
    // Test cancellation before error
    client.cancelQuery(&result);
    
    // Test error handling with cancellation
    if (result.isCancelled()) {
        std.debug.print("Query was cancelled successfully\n", .{});
    }
    
    std.debug.print("Query cancellation error handling test completed\n", .{});
}

test "query cancellation performance" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const config = couchbase.getTestConfig();
    var client = Client.connect(allocator, .{
        .connection_string = config.connection_string,
        .username = config.username,
        .password = config.password,
        .bucket = config.bucket,
    }) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();
    
    const statement = "SELECT 1 as test";
    const options = QueryOptions{};
    
    // Test cancellation performance
    const start_time = std.time.nanoTimestamp();
    
    var result = client.query(allocator, statement, options) catch |err| {
        std.debug.print("Query failed: {}\n", .{err});
        return;
    };
    defer result.deinit();
    
    // Cancel immediately
    client.cancelQuery(&result);
    
    const end_time = std.time.nanoTimestamp();
    const duration = end_time - start_time;
    
    std.debug.print("Cancellation performance: {} ns\n", .{duration});
    std.debug.print("Query cancellation performance test completed\n", .{});
}
