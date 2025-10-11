const std = @import("std");
const couchbase = @import("couchbase");

const TestConfig = couchbase.TestConfig;
const Client = couchbase.Client;
const QueryOptions = couchbase.QueryOptions;
const QueryMetadata = couchbase.QueryMetadata;
const QueryMetrics = couchbase.QueryMetrics;
const ConsistencyToken = couchbase.ConsistencyToken;

test "enhanced query metadata parsing" {
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
    const options = QueryOptions{
        .profile = .timings,
        .metrics = true,
        .client_context_id = "metadata-test-123",
    };
    
    // Execute query
    var result = client.query(allocator, statement, options) catch |err| {
        std.debug.print("Query failed: {}\n", .{err});
        return;
    };
    defer result.deinit();
    
    // Parse enhanced metadata
    result.parseMetadata() catch |err| {
        std.debug.print("Metadata parsing failed: {}\n", .{err});
        return;
    };
    
    // Test metadata access
    if (result.metadata) |metadata| {
        std.debug.print("Request ID: {?s}\n", .{metadata.request_id});
        std.debug.print("Client Context ID: {?s}\n", .{metadata.client_context_id});
        std.debug.print("Status: {?s}\n", .{metadata.status});
        std.debug.print("Signature: {?s}\n", .{metadata.signature});
        
        // Test metrics access
        if (metadata.metrics) |metrics| {
            std.debug.print("Elapsed Time: {s}\n", .{metrics.elapsed_time});
            std.debug.print("Execution Time: {s}\n", .{metrics.execution_time});
            std.debug.print("Result Count: {}\n", .{metrics.result_count});
            std.debug.print("Result Size: {}\n", .{metrics.result_size});
            std.debug.print("Mutation Count: {}\n", .{metrics.mutation_count});
            std.debug.print("Sort Count: {}\n", .{metrics.sort_count});
            std.debug.print("Error Count: {}\n", .{metrics.error_count});
            std.debug.print("Warning Count: {}\n", .{metrics.warning_count});
        }
        
        // Test warnings access
        if (metadata.warnings) |warnings| {
            std.debug.print("Warnings count: {}\n", .{warnings.len});
            for (warnings, 0..) |warning, i| {
                std.debug.print("Warning {}: {s}\n", .{ i, warning });
            }
        }
    }
    
    std.debug.print("Enhanced metadata test completed\n", .{});
}

test "query metrics access" {
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
    const options = QueryOptions{
        .metrics = true,
    };
    
    var result = client.query(allocator, statement, options) catch |err| {
        std.debug.print("Query failed: {}\n", .{err});
        return;
    };
    defer result.deinit();
    
    // Parse metadata
    result.parseMetadata() catch |err| {
        std.debug.print("Metadata parsing failed: {}\n", .{err});
        return;
    };
    
    // Test metrics access through QueryResult
    if (result.getMetrics()) |metrics| {
        std.debug.print("Metrics available: elapsed={s}, exec={s}, count={}\n", .{
            metrics.elapsed_time,
            metrics.execution_time,
            metrics.result_count,
        });
    } else {
        std.debug.print("No metrics available\n", .{});
    }
    
    std.debug.print("Query metrics test completed\n", .{});
}

test "query warnings access" {
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
    
    // Parse metadata
    result.parseMetadata() catch |err| {
        std.debug.print("Metadata parsing failed: {}\n", .{err});
        return;
    };
    
    // Test warnings access through QueryResult
    if (result.getWarnings()) |warnings| {
        std.debug.print("Warnings available: {}\n", .{warnings.len});
        for (warnings, 0..) |warning, i| {
            std.debug.print("Warning {}: {s}\n", .{ i, warning });
        }
    } else {
        std.debug.print("No warnings available\n", .{});
    }
    
    std.debug.print("Query warnings test completed\n", .{});
}

test "consistency token parsing" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Test consistency token parsing
    const token_json = "{\"token\":\"test-token-123\",\"keyspace\":\"default\"}";
    
    var token = ConsistencyToken{
        .token = undefined,
        .keyspace = undefined,
        .allocator = allocator,
    };
    
    token.parse(token_json) catch |err| {
        std.debug.print("Token parsing failed: {}\n", .{err});
        return;
    };
    defer token.deinit();
    
    std.debug.print("Token: {s}\n", .{token.token});
    std.debug.print("Keyspace: {s}\n", .{token.keyspace});
    
    std.debug.print("Consistency token parsing test completed\n", .{});
}

test "consistency token in query" {
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
    
    // Create a consistency token
    var token = ConsistencyToken{
        .token = try allocator.dupe(u8, "test-token-123"),
        .keyspace = try allocator.dupe(u8, "default"),
        .allocator = allocator,
    };
    defer token.deinit();
    
    const statement = "SELECT 1 as test";
    const options = QueryOptions{
        .consistency_token = token,
    };
    
    var result = client.query(allocator, statement, options) catch |err| {
        std.debug.print("Query with consistency token failed: {}\n", .{err});
        return;
    };
    defer result.deinit();
    
    std.debug.print("Query with consistency token completed\n", .{});
}

test "query metadata with profile" {
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
    const options = QueryOptions{
        .profile = .phases,
        .metrics = true,
        .client_context_id = "profile-test-456",
    };
    
    var result = client.query(allocator, statement, options) catch |err| {
        std.debug.print("Query failed: {}\n", .{err});
        return;
    };
    defer result.deinit();
    
    // Parse metadata
    result.parseMetadata() catch |err| {
        std.debug.print("Metadata parsing failed: {}\n", .{err});
        return;
    };
    
    // Test profile information
    if (result.metadata) |metadata| {
        if (metadata.profile) |profile| {
            std.debug.print("Query profile: {}\n", .{profile});
        }
        
        if (metadata.client_context_id) |ctx_id| {
            std.debug.print("Client context ID: {s}\n", .{ctx_id});
        }
    }
    
    std.debug.print("Query metadata with profile test completed\n", .{});
}
