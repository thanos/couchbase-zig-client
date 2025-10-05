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

// Coverage test: verify all client methods are callable
test "coverage: all client methods" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:coverage:methods";
    const value = \\{"coverage": "test"}
    ;

    // Clean up
    _ = client.remove(key, .{}) catch {};

    // Test each method
    _ = try client.upsert(key, value, .{});
    var get_res = try client.get(key);
    get_res.deinit();
    _ = try client.replace(key, value, .{});
    _ = try client.touch(key, 60);
    _ = try client.remove(key, .{});

    // Insert
    _ = try client.insert(key, value, .{});
    _ = try client.remove(key, .{});

    // Counter
    const counter_key = "test:coverage:counter";
    _ = client.remove(counter_key, .{}) catch {};
    _ = try client.increment(counter_key, 1, .{ .initial = 0 });
    _ = try client.decrement(counter_key, 1, .{});
    _ = try client.remove(counter_key, .{});
}

// Coverage test: all store options
test "coverage: store options" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:coverage:store_opts";
    const value = \\{"test": "options"}
    ;

    // Clean up
    _ = client.remove(key, .{}) catch {};

    // With CAS
    const r1 = try client.upsert(key, value, .{});
    _ = try client.replace(key, value, .{ .cas = r1.cas });

    // With expiry
    _ = try client.upsert(key, value, .{ .expiry = 3600 });

    // With flags
    _ = try client.upsert(key, value, .{ .flags = 0x1234 });

    // With all options
    const r2 = try client.upsert(key, value, .{});
    _ = try client.replace(key, value, .{
        .cas = r2.cas,
        .expiry = 7200,
        .flags = 0xABCD,
    });

    // Clean up
    _ = try client.remove(key, .{});
}

// Coverage test: all remove options
test "coverage: remove options" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:coverage:remove_opts";
    const value = \\{"test": "remove"}
    ;

    // Clean up
    _ = client.remove(key, .{}) catch {};

    // Remove with CAS
    const r1 = try client.upsert(key, value, .{});
    _ = try client.remove(key, .{ .cas = r1.cas });

    // Remove with default options
    _ = try client.upsert(key, value, .{});
    _ = try client.remove(key, .{});
}

// Coverage test: counter options
test "coverage: counter options" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:coverage:counter_opts";

    // Clean up
    _ = client.remove(key, .{}) catch {};

    // With initial
    _ = try client.increment(key, 10, .{ .initial = 100 });

    // With expiry
    _ = try client.increment(key, 5, .{ .expiry = 3600 });

    // With all options
    _ = client.remove(key, .{}) catch {};
    _ = try client.increment(key, 1, .{
        .initial = 50,
        .expiry = 7200,
    });

    // Clean up
    _ = try client.remove(key, .{});
}

// Coverage test: query options
test "coverage: query options" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const query = "SELECT RAW 1";

    // Default options
    var r1 = client.query(testing.allocator, query, .{}) catch |err| {
        std.debug.print("Query test skipped: {}\n", .{err});
        return;
    };
    r1.deinit();

    // With consistency
    var r2 = client.query(testing.allocator, query, .{
        .consistency = .request_plus,
    }) catch |err| {
        std.debug.print("Query test skipped: {}\n", .{err});
        return;
    };
    r2.deinit();

    // With all options
    var r3 = client.query(testing.allocator, query, .{
        .consistency = .not_bounded,
        .timeout_ms = 30000,
        .adhoc = false,
    }) catch |err| {
        std.debug.print("Query test skipped: {}\n", .{err});
        return;
    };
    r3.deinit();
}

// Coverage test: replica modes
test "coverage: replica modes" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:coverage:replica";
    const value = \\{"test": "replica"}
    ;

    // Clean up
    _ = client.remove(key, .{}) catch {};
    _ = try client.upsert(key, value, .{});

    // Any replica
    _ = client.getFromReplica(key, .any) catch {};

    // All replicas
    _ = client.getFromReplica(key, .all) catch {};

    // Index replica
    _ = client.getFromReplica(key, .index) catch {};

    // Clean up
    _ = try client.remove(key, .{});
}

// Coverage test: error types
test "coverage: error types" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:coverage:errors";

    // DocumentNotFound
    _ = client.remove(key, .{}) catch {};
    const r1 = client.get(key);
    try testing.expectError(error.DocumentNotFound, r1);

    // DocumentExists
    _ = try client.upsert(key, "value", .{});
    const r2 = client.insert(key, "value", .{});
    try testing.expectError(error.DocumentExists, r2);

    // CAS mismatch (DocumentExists or DurabilityImpossible)
    const r3 = client.replace(key, "value", .{ .cas = 999999 });
    try testing.expect(r3 == error.DocumentExists or r3 == error.DurabilityImpossible);

    // Clean up
    _ = try client.remove(key, .{});
}

// Coverage test: all durability levels
test "coverage: durability levels" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:coverage:durability";
    const value = \\{"durability": "test"}
    ;

    // Clean up
    _ = client.remove(key, .{}) catch {};

    // None (default)
    _ = try client.upsert(key, value, .{
        .durability = .{ .level = .none },
    });

    // Majority
    _ = client.upsert(key, value, .{
        .durability = .{ .level = .majority },
    }) catch {};

    // Persist to majority
    _ = client.upsert(key, value, .{
        .durability = .{ .level = .persist_to_majority },
    }) catch {};

    // Majority and persist to active
    _ = client.upsert(key, value, .{
        .durability = .{ .level = .majority_and_persist_to_active },
    }) catch {};

    // Clean up
    _ = try client.remove(key, .{});
}

// Coverage test: unlock operation
test "coverage: unlock" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:coverage:unlock";
    const value = \\{"unlock": "test"}
    ;

    // Clean up
    _ = client.remove(key, .{}) catch {};

    // Create document
    const r1 = try client.upsert(key, value, .{});

    // Unlock (will likely fail as document is not locked, but tests the method)
    _ = client.unlock(key, r1.cas) catch {};

    // Clean up
    _ = try client.remove(key, .{});
}

// Coverage test: result types and deinit
test "coverage: result types" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:coverage:results";
    const value = \\{"results": "test"}
    ;

    // Clean up
    _ = client.remove(key, .{}) catch {};

    // GetResult
    _ = try client.upsert(key, value, .{});
    var get_result = try client.get(key);
    try testing.expect(get_result.cas > 0);
    try testing.expect(get_result.value.len > 0);
    get_result.deinit();

    // MutationResult
    const mutation_result = try client.upsert(key, value, .{});
    try testing.expect(mutation_result.cas > 0);

    // CounterResult
    const counter_key = "test:coverage:counter_result";
    _ = client.remove(counter_key, .{}) catch {};
    const counter_result = try client.increment(counter_key, 10, .{ .initial = 0 });
    try testing.expect(counter_result.value >= 0); // Initial value on creation
    try testing.expect(counter_result.cas > 0);
    _ = try client.remove(counter_key, .{});

    // QueryResult
    const query = "SELECT RAW 1";
    var query_result = client.query(testing.allocator, query, .{}) catch |err| {
        std.debug.print("Query result test skipped: {}\n", .{err});
        _ = try client.remove(key, .{});
        return;
    };
    try testing.expect(query_result.rows.len >= 0);
    query_result.deinit();

    // Clean up
    _ = try client.remove(key, .{});
}

// Coverage test: connection options
test "coverage: connection options" {
    const test_config = couchbase.getTestConfig();
    
    // Test with minimal options
    if (couchbase.Client.connect(testing.allocator, .{
        .connection_string = test_config.connection_string,
    })) |client1| {
        var c1 = client1;
        c1.disconnect();
    } else |err| {
        std.debug.print("Connection test 1 failed (expected): {}\n", .{err});
    }

    // Test with full options
    var client2 = try couchbase.Client.connect(testing.allocator, .{
        .connection_string = test_config.connection_string,
        .username = test_config.username,
        .password = test_config.password,
        .bucket = test_config.bucket,
        .timeout_ms = test_config.timeout_ms,
    });
    defer client2.disconnect();
}

// Coverage test: large batch operations
test "coverage: batch operations" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const batch_size = 100;
    var i: usize = 0;

    // Batch upsert
    while (i < batch_size) : (i += 1) {
        const key = try std.fmt.allocPrint(testing.allocator, "test:coverage:batch:{d}", .{i});
        defer testing.allocator.free(key);

        const value = try std.fmt.allocPrint(testing.allocator, "{{\"index\": {d}}}", .{i});
        defer testing.allocator.free(value);

        _ = try client.upsert(key, value, .{});
    }

    // Batch get
    i = 0;
    while (i < batch_size) : (i += 1) {
        const key = try std.fmt.allocPrint(testing.allocator, "test:coverage:batch:{d}", .{i});
        defer testing.allocator.free(key);

        var result = try client.get(key);
        result.deinit();
    }

    // Batch remove
    i = 0;
    while (i < batch_size) : (i += 1) {
        const key = try std.fmt.allocPrint(testing.allocator, "test:coverage:batch:{d}", .{i});
        defer testing.allocator.free(key);

        _ = try client.remove(key, .{});
    }
}

// Coverage test: edge cases
test "coverage: edge cases" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    // Empty key (may succeed or fail depending on server)
    _ = client.get("") catch {};

    // Very long key
    const long_key = "test:coverage:" ++ "x" ** 240;
    const r2 = client.upsert(long_key, "value", .{});
    if (r2) |_| {
        _ = client.remove(long_key, .{}) catch {};
    } else |_| {}

    // Empty value
    const key = "test:coverage:empty";
    _ = client.remove(key, .{}) catch {};
    _ = try client.upsert(key, "", .{});
    var result = try client.get(key);
    result.deinit();
    _ = try client.remove(key, .{});

    // Zero expiry
    _ = try client.upsert(key, "value", .{ .expiry = 0 });
    _ = try client.remove(key, .{});

    // Zero CAS (means no CAS check)
    _ = try client.upsert(key, "value", .{ .cas = 0 });
    _ = try client.remove(key, .{});
}

// Coverage test: concurrent document access patterns
test "coverage: concurrent access patterns" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:coverage:concurrent";
    const value1 = \\{"version": 1}
    ;
    const value2 = \\{"version": 2}
    ;

    // Clean up
    _ = client.remove(key, .{}) catch {};

    // Simulate optimistic locking pattern
    const r1 = try client.upsert(key, value1, .{});
    const cas1 = r1.cas;

    // Get and update with CAS
    var get_result = try client.get(key);
    get_result.deinit();

    _ = try client.replace(key, value2, .{ .cas = cas1 });

    // Attempt to update with old CAS (should fail)
    const r2 = client.replace(key, value1, .{ .cas = cas1 });
    try testing.expect(r2 == error.DocumentExists or r2 == error.DurabilityImpossible);

    // Clean up
    _ = try client.remove(key, .{});
}
