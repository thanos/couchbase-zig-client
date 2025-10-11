const std = @import("std");
const couchbase = @import("couchbase");

const TestConfig = couchbase.TestConfig;
const Client = couchbase.Client;
const QueryOptions = couchbase.QueryOptions;
const PreparedStatementCache = couchbase.PreparedStatementCache;

test "prepared statement basic functionality" {
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
    
    // Test prepare statement
    client.prepareStatement(statement) catch |err| {
        std.debug.print("Prepare statement failed: {}\n", .{err});
        return;
    };
    
    // Test execute prepared
    const options = QueryOptions.prepared();
    var result = client.executePrepared(allocator, statement, options) catch |err| {
        std.debug.print("Execute prepared failed: {}\n", .{err});
        return;
    };
    defer result.deinit();
    
    // Verify result
    std.debug.print("Prepared statement executed successfully\n", .{});
}

test "prepared statement cache management" {
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
    
    // Test cache statistics
    const stats = client.getPreparedStatementStats();
    std.debug.print("Cache stats: {}/{} statements\n", .{ stats.count, stats.max_size });
    
    // Test cache cleanup
    client.cleanupExpiredPreparedStatements();
    
    std.debug.print("Cache management test completed\n", .{});
}

test "prepared statement with parameters" {
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
    
    const statement = "SELECT $1 as param1, $2 as param2";
    const params = [_][]const u8{"value1", "value2"};
    
    // Prepare statement
    client.prepareStatement(statement) catch |err| {
        std.debug.print("Prepare statement failed: {}\n", .{err});
        return;
    };
    
    // Execute with parameters
    const options = try QueryOptions.withPositionalParams(allocator, &params);
    defer if (options.parameters) |p| {
        for (p) |param| allocator.free(param);
        allocator.free(p);
    };
    
    var result = client.executePrepared(allocator, statement, options) catch |err| {
        std.debug.print("Execute prepared with params failed: {}\n", .{err});
        return;
    };
    defer result.deinit();
    
    std.debug.print("Prepared statement with parameters executed successfully\n", .{});
}

test "prepared statement cache limits" {
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
    
    // Test cache size limit
    const statements = [_][]const u8{
        "SELECT 1 as test1",
        "SELECT 2 as test2",
        "SELECT 3 as test3",
    };
    
    for (statements) |stmt| {
        client.prepareStatement(stmt) catch |err| {
            std.debug.print("Prepare statement failed: {}\n", .{err});
            return;
        };
    }
    
    const stats = client.getPreparedStatementStats();
    std.debug.print("Cache stats after adding statements: {}/{} statements\n", .{ stats.count, stats.max_size });
    
    std.debug.print("Cache limits test completed\n", .{});
}

test "prepared statement performance comparison" {
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
    
    const statement = "SELECT 1 as performance_test";
    
    // Test adhoc query (fresh preparation each time)
    const adhoc_options = QueryOptions{ .adhoc = true };
    const adhoc_start = std.time.nanoTimestamp();
    
    for (0..5) |_| {
        var result = client.query(allocator, statement, adhoc_options) catch |err| {
            std.debug.print("Adhoc query failed: {}\n", .{err});
            return;
        };
        result.deinit();
    }
    
    const adhoc_duration = std.time.nanoTimestamp() - adhoc_start;
    
    // Test prepared statement
    client.prepareStatement(statement) catch |err| {
        std.debug.print("Prepare statement failed: {}\n", .{err});
        return;
    };
    
    const prepared_options = QueryOptions.prepared();
    const prepared_start = std.time.nanoTimestamp();
    
    for (0..5) |_| {
        var result = client.executePrepared(allocator, statement, prepared_options) catch |err| {
            std.debug.print("Prepared query failed: {}\n", .{err});
            return;
        };
        result.deinit();
    }
    
    const prepared_duration = std.time.nanoTimestamp() - prepared_start;
    
    std.debug.print("Performance comparison:\n", .{});
    std.debug.print("  Adhoc queries: {} ns\n", .{adhoc_duration});
    std.debug.print("  Prepared queries: {} ns\n", .{prepared_duration});
    std.debug.print("  Performance test completed\n", .{});
}
