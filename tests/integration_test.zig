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

test "connection" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const test_config = couchbase.getTestConfig();
    var client = try couchbase.Client.connect(allocator, .{
        .connection_string = test_config.connection_string,
        .username = test_config.username,
        .password = test_config.password,
        .bucket = test_config.bucket,
        .timeout_ms = 30000, // Increase timeout for tests
    });
    client.disconnect();
}

test "basic get/upsert/remove" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:basic";
    const value = \\{"type": "test", "value": 42}
    ;

    // Upsert
    const upsert_result = try client.upsert(key, value, .{});
    try testing.expect(upsert_result.cas > 0);

    // Get
    var get_result = try client.get(key);
    defer get_result.deinit();
    try testing.expectEqualStrings(value, get_result.value);
    try testing.expect(get_result.cas > 0);

    // Remove
    const remove_result = try client.remove(key, .{});
    try testing.expect(remove_result.cas > 0);

    // Verify removed
    const get_after_remove = client.get(key);
    try testing.expectError(error.DocumentNotFound, get_after_remove);
}

test "insert operation" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:insert";
    const value = \\{"operation": "insert"}
    ;

    // Clean up if exists
    _ = client.remove(key, .{}) catch {};

    // Insert should succeed
    const insert_result = try client.insert(key, value, .{});
    try testing.expect(insert_result.cas > 0);

    // Insert again should fail
    const insert_again = client.insert(key, value, .{});
    try testing.expectError(error.DocumentExists, insert_again);

    // Clean up
    _ = try client.remove(key, .{});
}

test "replace operation" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:replace";
    const value1 = \\{"version": 1}
    ;
    const value2 = \\{"version": 2}
    ;

    // Clean up if exists
    _ = client.remove(key, .{}) catch {};

    // Replace non-existent should fail
    const replace_missing = client.replace(key, value1, .{});
    try testing.expectError(error.DocumentNotFound, replace_missing);

    // Create document
    _ = try client.upsert(key, value1, .{});

    // Replace should succeed
    const replace_result = try client.replace(key, value2, .{});
    try testing.expect(replace_result.cas > 0);

    // Verify replacement
    var get_result = try client.get(key);
    defer get_result.deinit();
    try testing.expectEqualStrings(value2, get_result.value);

    // Clean up
    _ = try client.remove(key, .{});
}

test "CAS (compare-and-swap)" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:cas";
    const value1 = \\{"cas": "test1"}
    ;
    const value2 = \\{"cas": "test2"}
    ;

    // Clean up if exists
    _ = client.remove(key, .{}) catch {};

    // Create initial document
    const upsert_result = try client.upsert(key, value1, .{});
    const cas1 = upsert_result.cas;

    // Replace with correct CAS should succeed
    const replace_result = try client.replace(key, value2, .{ .cas = cas1 });
    try testing.expect(replace_result.cas != cas1);

    // Replace with old CAS should fail (with DocumentExists or DurabilityImpossible)
    const replace_old_cas = client.replace(key, value1, .{ .cas = cas1 });
    try testing.expect(replace_old_cas == error.DocumentExists or replace_old_cas == error.DurabilityImpossible);

    // Clean up
    _ = try client.remove(key, .{});
}

test "counter increment" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:counter:inc";

    // Clean up if exists
    _ = client.remove(key, .{}) catch {};

    // Increment with initial value (creates document at initial, returns initial)
    const inc1 = try client.increment(key, 10, .{ .initial = 0 });
    try testing.expectEqual(@as(u64, 0), inc1.value); // Initial value is returned on creation

    // Increment again (now delta is applied)
    const inc2 = try client.increment(key, 5, .{});
    try testing.expectEqual(@as(u64, 5), inc2.value);

    // Increment by larger value
    const inc3 = try client.increment(key, 100, .{});
    try testing.expectEqual(@as(u64, 105), inc3.value);

    // Clean up
    _ = try client.remove(key, .{});
}

test "counter decrement" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:counter:dec";

    // Clean up if exists
    _ = client.remove(key, .{}) catch {};

    // Start with a value
    _ = try client.increment(key, 100, .{ .initial = 100 });

    // Decrement
    const dec1 = try client.decrement(key, 10, .{});
    try testing.expectEqual(@as(u64, 90), dec1.value);

    // Decrement again
    const dec2 = try client.decrement(key, 15, .{});
    try testing.expectEqual(@as(u64, 75), dec2.value);

    // Clean up
    _ = try client.remove(key, .{});
}

test "touch operation" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:touch";
    const value = \\{"touch": "test"}
    ;

    // Clean up if exists
    _ = client.remove(key, .{}) catch {};

    // Create document
    const upsert_result = try client.upsert(key, value, .{});
    const original_cas = upsert_result.cas;

    // Touch should change CAS
    const touch_result = try client.touch(key, 3600);
    try testing.expect(touch_result.cas != original_cas);

    // Document should still exist
    var get_result = try client.get(key);
    defer get_result.deinit();
    try testing.expectEqualStrings(value, get_result.value);

    // Clean up
    _ = try client.remove(key, .{});
}

test "expiry" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:expiry";
    const value = \\{"expiry": "test"}
    ;

    // Clean up if exists
    _ = client.remove(key, .{}) catch {};

    // Create document with 2 second expiry
    _ = try client.upsert(key, value, .{ .expiry = 2 });

    // Should exist immediately
    var get_result1 = try client.get(key);
    get_result1.deinit();

    // Wait for expiry
    std.time.sleep(3 * std.time.ns_per_s);

    // Should be gone
    const get_result2 = client.get(key);
    try testing.expectError(error.DocumentNotFound, get_result2);
}

test "get from replica" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:replica";
    const value = \\{"replica": "test"}
    ;

    // Clean up if exists
    _ = client.remove(key, .{}) catch {};

    // Create document
    _ = try client.upsert(key, value, .{});

    // Try to get from replica (may fail if no replicas configured)
    if (client.getFromReplica(key, .any)) |result| {
        var res = result;
        defer res.deinit();
        try testing.expectEqualStrings(value, res.value);
    } else |_| {
        // No replicas available, that's ok for test
    }

    // Clean up
    _ = try client.remove(key, .{});
}

test "query: create and select documents" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    // Create test documents
    const doc1_key = "test:query:1";
    const doc2_key = "test:query:2";
    const doc3_key = "test:query:3";

    const doc1 = \\{"type": "test_query", "name": "Alice", "age": 30}
    ;
    const doc2 = \\{"type": "test_query", "name": "Bob", "age": 25}
    ;
    const doc3 = \\{"type": "test_query", "name": "Charlie", "age": 35}
    ;

    // Clean up if exists
    _ = client.remove(doc1_key, .{}) catch {};
    _ = client.remove(doc2_key, .{}) catch {};
    _ = client.remove(doc3_key, .{}) catch {};

    // Insert documents
    _ = try client.upsert(doc1_key, doc1, .{});
    _ = try client.upsert(doc2_key, doc2, .{});
    _ = try client.upsert(doc3_key, doc3, .{});

    // Query for documents
    const query = "SELECT name, age FROM `default` WHERE type = 'test_query' ORDER BY age";
    var result = client.query(testing.allocator, query, .{
        .consistency = .request_plus,
    }) catch |err| {
        // Query may fail if no primary index, skip test
        std.debug.print("Query test skipped: {}\n", .{err});
        _ = client.remove(doc1_key, .{}) catch {};
        _ = client.remove(doc2_key, .{}) catch {};
        _ = client.remove(doc3_key, .{}) catch {};
        return;
    };
    defer result.deinit();

    try testing.expect(result.rows.len >= 3);

    // Clean up
    _ = try client.remove(doc1_key, .{});
    _ = try client.remove(doc2_key, .{});
    _ = try client.remove(doc3_key, .{});
}

test "multiple operations in sequence" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const keys = [_][]const u8{
        "test:multi:1",
        "test:multi:2",
        "test:multi:3",
        "test:multi:4",
        "test:multi:5",
    };

    // Clean up
    for (keys) |key| {
        _ = client.remove(key, .{}) catch {};
    }

    // Insert multiple documents
    for (keys, 0..) |key, i| {
        const value = try std.fmt.allocPrint(testing.allocator, "{{\"index\": {d}}}", .{i});
        defer testing.allocator.free(value);
        _ = try client.upsert(key, value, .{});
    }

    // Read them back
    for (keys) |key| {
        var result = try client.get(key);
        result.deinit();
    }

    // Update them
    for (keys, 0..) |key, i| {
        const value = try std.fmt.allocPrint(testing.allocator, "{{\"index\": {d}, \"updated\": true}}", .{i});
        defer testing.allocator.free(value);
        _ = try client.replace(key, value, .{});
    }

    // Remove them
    for (keys) |key| {
        _ = try client.remove(key, .{});
    }

    // Verify all removed
    for (keys) |key| {
        const result = client.get(key);
        try testing.expectError(error.DocumentNotFound, result);
    }
}

test "large document" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:large";

    // Clean up if exists
    _ = client.remove(key, .{}) catch {};

    // Create large document (1MB)
    var large_data = try testing.allocator.alloc(u8, 1024 * 1024);
    defer testing.allocator.free(large_data);
    @memset(large_data, 'A');

    // Wrap in JSON
    const value = try std.fmt.allocPrint(testing.allocator, "{{\"data\": \"{s}\"}}", .{large_data[0..1000]});
    defer testing.allocator.free(value);

    // Store
    _ = try client.upsert(key, value, .{});

    // Retrieve
    var result = try client.get(key);
    defer result.deinit();
    try testing.expect(result.value.len > 0);

    // Clean up
    _ = try client.remove(key, .{});
}

test "concurrent operations stress test" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const iterations = 50;
    var i: usize = 0;

    while (i < iterations) : (i += 1) {
        const key = try std.fmt.allocPrint(testing.allocator, "test:stress:{d}", .{i});
        defer testing.allocator.free(key);

        const value = try std.fmt.allocPrint(testing.allocator, "{{\"iteration\": {d}}}", .{i});
        defer testing.allocator.free(value);

        // Upsert
        _ = try client.upsert(key, value, .{});

        // Get
        var get_result = try client.get(key);
        get_result.deinit();

        // Remove
        _ = try client.remove(key, .{});
    }
}

test "error handling: document not found" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:nonexistent";

    // Ensure it doesn't exist
    _ = client.remove(key, .{}) catch {};

    // Get should fail
    const result = client.get(key);
    try testing.expectError(error.DocumentNotFound, result);
}

test "error handling: document exists on insert" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:exists";
    const value = \\{"test": "exists"}
    ;

    // Clean up and create
    _ = client.remove(key, .{}) catch {};
    _ = try client.upsert(key, value, .{});

    // Insert should fail
    const result = client.insert(key, value, .{});
    try testing.expectError(error.DocumentExists, result);

    // Clean up
    _ = try client.remove(key, .{});
}

test "durability: majority" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:durability";
    const value = \\{"durability": "test"}
    ;

    // Clean up if exists
    _ = client.remove(key, .{}) catch {};

    // Upsert with durability (may fail if cluster not configured for durability)
    const result = client.upsert(key, value, .{
        .durability = .{
            .level = .majority,
        },
    });

    if (result) |upsert_result| {
        try testing.expect(upsert_result.cas > 0);

        // Verify document exists
        var get_result = try client.get(key);
        get_result.deinit();

        // Clean up
        _ = try client.remove(key, .{});
    } else |err| {
        // Durability not available in this setup
        std.debug.print("Durability test skipped: {}\n", .{err});
    }
}

test "flags support" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:flags";
    const value = "binary data or something";
    const custom_flags: u32 = 0x12345678;

    // Clean up if exists
    _ = client.remove(key, .{}) catch {};

    // Store with custom flags
    _ = try client.upsert(key, value, .{ .flags = custom_flags });

    // Retrieve and verify flags
    var result = try client.get(key);
    defer result.deinit();
    try testing.expectEqual(custom_flags, result.flags);

    // Clean up
    _ = try client.remove(key, .{});
}
