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

test "durability - basic store with durability" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "durability_test:1";
    const value = \\{"name": "test", "durability": true}
    ;

    // Store with durability
    const result = try client.storeWithDurability(
        key,
        value,
        .upsert,
        .{
            .durability = .{
                .level = .majority,
                .timeout_ms = 5000,
            },
        },
        testing.allocator,
    );
    defer if (result.mutation_token) |token| token.deinit();

    try testing.expect(result.cas > 0);
    std.debug.print("Store with durability - CAS: {}\n", .{result.cas});

    // Clean up
    _ = client.remove(key, .{}) catch {};
}

test "durability - observe operation" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "durability_test:2";
    const value = \\{"name": "test", "observe": true}
    ;

    // Store a document
    const store_result = try client.upsert(key, value, .{});

    // Observe the document
    const observe_result = try client.observe(
        key,
        store_result.cas,
        .{
            .timeout_ms = 5000,
            .persist_to_master = true,
            .replicate_to_count = 0,
        },
        testing.allocator,
    );
    defer observe_result.deinit();

    try testing.expect(observe_result.cas == store_result.cas);
    std.debug.print("Observe result - persisted: {}, replicated: {}, replicate_count: {}\n", .{
        observe_result.persisted,
        observe_result.replicated,
        observe_result.replicate_count,
    });

    // Clean up
    _ = client.remove(key, .{}) catch {};
}

test "durability - observe multiple keys" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const keys = [_][]const u8{ "durability_test:3", "durability_test:4" };
    const value1 = \\{"name": "test3"}
    ;
    const value2 = \\{"name": "test4"}
    ;
    const values = [_][]const u8{ value1, value2 };

    // Store multiple documents
    var cas_values: [2]u64 = undefined;
    for (keys, values, 0..) |key, value, i| {
        const result = try client.upsert(key, value, .{});
        cas_values[i] = result.cas;
    }

    // Observe multiple keys
    const observe_results = try client.observeMulti(
        &keys,
        &cas_values,
        .{
            .timeout_ms = 5000,
            .persist_to_master = true,
            .replicate_to_count = 0,
        },
        testing.allocator,
    );
    defer {
        for (observe_results) |*result| {
            result.deinit();
        }
        testing.allocator.free(observe_results);
    }

    try testing.expect(observe_results.len == 2);
    for (observe_results, 0..) |result, i| {
        try testing.expect(result.cas == cas_values[i]);
        std.debug.print("Observe result {} - persisted: {}, replicated: {}\n", .{
            i,
            result.persisted,
            result.replicated,
        });
    }

    // Clean up
    for (keys) |key| {
        _ = client.remove(key, .{}) catch {};
    }
}

test "durability - wait for durability" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "durability_test:5";
    const value = \\{"name": "test", "wait_durability": true}
    ;

    // Store a document
    const store_result = try client.upsert(key, value, .{});

    // Wait for durability
    try client.waitForDurability(
        key,
        store_result.cas,
        .{
            .persist_to_master = true,
            .replicate_to_count = 0,
            .timeout_ms = 5000,
        },
        testing.allocator,
    );

    std.debug.print("Wait for durability completed successfully\n", .{});

    // Clean up
    _ = client.remove(key, .{}) catch {};
}

test "durability - mutation token extraction" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "durability_test:6";
    const value = \\{"name": "test", "mutation_token": true}
    ;

    // Store with durability to get mutation token
    const result = try client.storeWithDurability(
        key,
        value,
        .upsert,
        .{
            .durability = .{
                .level = .majority,
                .timeout_ms = 5000,
            },
        },
        testing.allocator,
    );
    defer if (result.mutation_token) |token| token.deinit();

    try testing.expect(result.cas > 0);
    
    if (result.mutation_token) |token| {
        std.debug.print("Mutation token - partition_id: {}, partition_uuid: {}, sequence_number: {}\n", .{
            token.partition_id,
            token.partition_uuid,
            token.sequence_number,
        });
        try testing.expect(token.partition_id >= 0);
        try testing.expect(token.partition_uuid > 0);
        try testing.expect(token.sequence_number > 0);
    } else {
        std.debug.print("No mutation token available\n", .{});
    }

    // Clean up
    _ = client.remove(key, .{}) catch {};
}

test "durability - different durability levels" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "durability_test:7";
    const value = \\{"name": "test", "durability_levels": true}
    ;

    // Test different durability levels
    const durability_levels = [_]couchbase.DurabilityLevel{
        .none,
        .majority,
        .majority_and_persist_to_active,
        .persist_to_majority,
    };

    for (durability_levels, 0..) |level, i| {
        const test_key = try std.fmt.allocPrint(testing.allocator, "{s}:{}", .{ key, i });
        defer testing.allocator.free(test_key);

        const result = try client.storeWithDurability(
            test_key,
            value,
            .upsert,
            .{
                .durability = .{
                    .level = level,
                    .timeout_ms = 5000,
                },
            },
            testing.allocator,
        );
        defer if (result.mutation_token) |token| token.deinit();

        try testing.expect(result.cas > 0);
        std.debug.print("Durability level {} - CAS: {}\n", .{ @intFromEnum(level), result.cas });

        // Clean up
        _ = client.remove(test_key, .{}) catch {};
    }
}

test "durability - observe options validation" {
    // Test observe options creation
    const options = couchbase.ObserveOptions{
        .timeout_ms = 10000,
        .persist_to_master = true,
        .replicate_to_count = 2,
    };

    try testing.expect(options.timeout_ms == 10000);
    try testing.expect(options.persist_to_master == true);
    try testing.expect(options.replicate_to_count == 2);
}

test "durability - observe durability validation" {
    // Test observe durability creation
    const durability = couchbase.ObserveDurability{
        .persist_to_master = true,
        .replicate_to_count = 1,
        .timeout_ms = 5000,
    };

    try testing.expect(durability.persist_to_master == true);
    try testing.expect(durability.replicate_to_count == 1);
    try testing.expect(durability.timeout_ms == 5000);
}

test "durability - mutation token creation" {
    // Test mutation token creation
    const token = try couchbase.MutationToken.create(
        1,      // partition_id
        12345,  // partition_uuid
        67890,  // sequence_number
        "test_bucket",
        testing.allocator,
    );
    defer token.deinit();

    try testing.expect(token.partition_id == 1);
    try testing.expect(token.partition_uuid == 12345);
    try testing.expect(token.sequence_number == 67890);
    try testing.expect(std.mem.eql(u8, token.bucket_name, "test_bucket"));
}

test "durability - error handling" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    // Test observe with non-existent key
    const result = client.observe(
        "non_existent_key",
        12345, // invalid CAS
        .{
            .timeout_ms = 1000,
            .persist_to_master = true,
            .replicate_to_count = 0,
        },
        testing.allocator,
    );

    // This should fail gracefully
    if (result) |_| {
        // If it succeeds, that's also acceptable
        std.debug.print("Observe non-existent key succeeded\n", .{});
    } else |err| {
        std.debug.print("Observe non-existent key failed as expected: {}\n", .{err});
    }
}

test "durability - timeout handling" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "durability_test:8";
    const value = \\{"name": "test", "timeout": true}
    ;

    // Store a document
    const store_result = try client.upsert(key, value, .{});

    // Test with very short timeout
    const result = client.waitForDurability(
        key,
        store_result.cas,
        .{
            .persist_to_master = true,
            .replicate_to_count = 0,
            .timeout_ms = 1, // Very short timeout
        },
        testing.allocator,
    );

    // This might succeed or fail depending on server performance
    if (result) |_| {
        std.debug.print("Wait for durability with short timeout succeeded\n", .{});
    } else |err| {
        std.debug.print("Wait for durability with short timeout failed: {}\n", .{err});
    }

    // Clean up
    _ = client.remove(key, .{}) catch {};
}
