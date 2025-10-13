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

test "collection-aware store operations" {
    var client = getTestClient(testing.allocator) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    // Use default collection first to test basic functionality
    var collection = try couchbase.Collection.default(testing.allocator);
    defer collection.deinit();

    const key = "collection_store_test_key";
    const value = "{\"message\": \"collection store test\"}";

    // Test upsert with collection
    const upsert_result = try client.upsertWithCollection(key, value, collection, .{});
    try testing.expect(upsert_result.cas > 0);

    // Test get with collection
    var get_result = try client.getWithCollection(key, collection);
    defer get_result.deinit();
    try testing.expectEqualStrings(value, get_result.value);

    // Test replace with collection
    const new_value = "{\"message\": \"collection replace test\"}";
    const replace_result = try client.replaceWithCollection(key, new_value, collection, .{});
    try testing.expect(replace_result.cas > 0);

    // Verify replace worked
    var get_result2 = try client.getWithCollection(key, collection);
    defer get_result2.deinit();
    try testing.expectEqualStrings(new_value, get_result2.value);

    // Test insert with collection (should fail as document exists)
    const insert_result = client.insertWithCollection(key, "{\"message\": \"insert test\"}", collection, .{});
    try testing.expectError(couchbase.Error.DocumentExists, insert_result);

    // Clean up
    _ = client.removeWithCollection(key, collection, .{}) catch {};
}

test "collection-aware remove operation" {
    var client = getTestClient(testing.allocator) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    // Use default collection
    var collection = try couchbase.Collection.default(testing.allocator);
    defer collection.deinit();

    const key = "collection_remove_test_key";
    const value = "{\"message\": \"collection remove test\"}";

    // Upsert document
    _ = try client.upsertWithCollection(key, value, collection, .{});

    // Remove with collection
    const remove_result = try client.removeWithCollection(key, collection, .{});
    try testing.expect(remove_result.cas > 0);

    // Verify document is gone
    try testing.expectError(couchbase.Error.DocumentNotFound, client.getWithCollection(key, collection));
}

test "collection-aware touch operation" {
    var client = getTestClient(testing.allocator) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    // Use default collection
    var collection = try couchbase.Collection.default(testing.allocator);
    defer collection.deinit();

    const key = "collection_touch_test_key";
    const value = "{\"message\": \"collection touch test\"}";

    // Upsert document
    _ = try client.upsertWithCollection(key, value, collection, .{});

    // Touch with collection (expiry in 1 second)
    const touch_result = try client.touchWithCollection(key, collection, 1);
    try testing.expect(touch_result.cas > 0);

    // Wait for expiry
    std.time.sleep(std.time.ns_per_s * 2);

    // Verify document expired
    try testing.expectError(couchbase.Error.DocumentNotFound, client.getWithCollection(key, collection));

    // Clean up (if not expired)
    _ = client.removeWithCollection(key, collection, .{}) catch {};
}

test "collection-aware counter operation" {
    var client = getTestClient(testing.allocator) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    // Use default collection
    var collection = try couchbase.Collection.default(testing.allocator);
    defer collection.deinit();

    const key = "collection_counter_test_key";

    // Counter with collection (initial value 10)
    const counter_result = try client.counterWithCollection(key, collection, 10, .{ .initial = 10 });
    try testing.expect(counter_result.cas > 0);
    try testing.expectEqual(@as(u64, 10), counter_result.value);

    // Increment by 5
    const increment_result = try client.counterWithCollection(key, collection, 5, .{});
    try testing.expect(increment_result.cas > 0);
    try testing.expectEqual(@as(u64, 15), increment_result.value);

    // Decrement by 3
    const decrement_result = try client.counterWithCollection(key, collection, -3, .{});
    try testing.expect(decrement_result.cas > 0);
    try testing.expectEqual(@as(u64, 12), decrement_result.value);

    // Clean up
    _ = client.removeWithCollection(key, collection, .{}) catch {};
}

test "collection-aware exists operation" {
    var client = getTestClient(testing.allocator) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    // Use default collection
    var collection = try couchbase.Collection.default(testing.allocator);
    defer collection.deinit();

    const key1 = "collection_exists_test_key1";
    const key2 = "collection_exists_test_key2";
    const value = "{\"message\": \"collection exists test\"}";

    // Check non-existent document
    const exists1 = try client.existsWithCollection(key1, collection);
    try testing.expect(!exists1);

    // Upsert document
    _ = try client.upsertWithCollection(key1, value, collection, .{});

    // Check existing document
    const exists2 = try client.existsWithCollection(key1, collection);
    try testing.expect(exists2);

    // Check another non-existent document
    const exists3 = try client.existsWithCollection(key2, collection);
    try testing.expect(!exists3);

    // Clean up
    _ = client.removeWithCollection(key1, collection, .{}) catch {};
}

test "collection-aware operations with default collection" {
    var client = getTestClient(testing.allocator) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    // Create default collection
    var default_collection = try couchbase.Collection.default(testing.allocator);
    defer default_collection.deinit();

    const key = "default_collection_test_key";
    const value = "{\"message\": \"default collection test\"}";

    // Test operations with default collection
    const upsert_result = try client.upsertWithCollection(key, value, default_collection, .{});
    try testing.expect(upsert_result.cas > 0);

    var get_result = try client.getWithCollection(key, default_collection);
    defer get_result.deinit();
    try testing.expectEqualStrings(value, get_result.value);

    const exists = try client.existsWithCollection(key, default_collection);
    try testing.expect(exists);

    // Clean up
    _ = client.removeWithCollection(key, default_collection, .{}) catch {};
}

test "collection-aware operations error handling" {
    var client = getTestClient(testing.allocator) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    // Use default collection
    var collection = try couchbase.Collection.default(testing.allocator);
    defer collection.deinit();

    const key = "collection_error_test_key";

    // Test get non-existent document
    try testing.expectError(couchbase.Error.DocumentNotFound, client.getWithCollection(key, collection));

    // Test replace non-existent document
    try testing.expectError(couchbase.Error.DocumentNotFound, client.replaceWithCollection(key, "value", collection, .{}));

    // Test remove non-existent document
    try testing.expectError(couchbase.Error.DocumentNotFound, client.removeWithCollection(key, collection, .{}));

    // Test touch non-existent document
    try testing.expectError(couchbase.Error.DocumentNotFound, client.touchWithCollection(key, collection, 60));
}

test "collection-aware operations with options" {
    var client = getTestClient(testing.allocator) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    // Use default collection
    var collection = try couchbase.Collection.default(testing.allocator);
    defer collection.deinit();

    const key = "collection_options_test_key";
    const value = "{\"message\": \"collection options test\"}";

    // Test with expiry
    const upsert_result = try client.upsertWithCollection(key, value, collection, .{ .expiry = 60 });
    try testing.expect(upsert_result.cas > 0);

    // Test with flags
    const upsert_result2 = try client.upsertWithCollection(key, value, collection, .{ 
        .flags = 0x12345678 
    });
    try testing.expect(upsert_result2.cas > 0);

    // Test counter with options (use different key)
    const counter_key = "collection_counter_options_test_key";
    const counter_result = try client.counterWithCollection(counter_key, collection, 1, .{ 
        .initial = 0,
        .expiry = 30 
    });
    try testing.expect(counter_result.cas > 0);

    // Clean up
    _ = client.removeWithCollection(key, collection, .{}) catch {};
    _ = client.removeWithCollection(counter_key, collection, .{}) catch {};
}
