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

test "collection-aware get and lock operation" {
    var client = getTestClient(testing.allocator) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    // Use default collection
    var collection = try couchbase.Collection.default(testing.allocator);
    defer collection.deinit();

    const key = "collection_lock_test_key";
    const value = "{\"message\": \"collection lock test\"}";

    // First upsert a document
    const upsert_result = try client.upsertWithCollection(key, value, collection, .{});
    try testing.expect(upsert_result.cas > 0);

    // Get and lock the document
    const lock_options = couchbase.types.GetAndLockOptions{
        .lock_time = 10, // 10 seconds lock time
        .timeout_ms = 5000,
    };
    var lock_result = try client.getAndLockWithCollection(key, collection, lock_options);
    defer lock_result.deinit();

    try testing.expectEqualStrings(value, lock_result.value);
    try testing.expect(lock_result.cas > 0);
    try testing.expect(lock_result.lock_time == 10);

    // Unlock the document
    try client.unlockWithCollection(key, lock_result.cas, collection);

    // Clean up
    _ = client.removeWithCollection(key, collection, .{}) catch {};
}

test "collection-aware lock operation error handling" {
    var client = getTestClient(testing.allocator) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    // Use default collection
    var collection = try couchbase.Collection.default(testing.allocator);
    defer collection.deinit();

    const key = "nonexistent_lock_key";

    // Try to lock a non-existent document
    const lock_options = couchbase.types.GetAndLockOptions{
        .lock_time = 10,
        .timeout_ms = 5000,
    };
    try testing.expectError(couchbase.Error.DocumentNotFound, client.getAndLockWithCollection(key, collection, lock_options));
}

test "collection-aware unlock operation error handling" {
    var client = getTestClient(testing.allocator) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    // Use default collection
    var collection = try couchbase.Collection.default(testing.allocator);
    defer collection.deinit();

    const key = "unlock_error_test_key";

    // Try to unlock with invalid CAS
    try testing.expectError(couchbase.Error.DocumentNotFound, client.unlockWithCollection(key, 12345, collection));
}

test "collection-aware lock operations with options" {
    var client = getTestClient(testing.allocator) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    // Use default collection
    var collection = try couchbase.Collection.default(testing.allocator);
    defer collection.deinit();

    const key = "collection_lock_options_test_key";
    const value = "{\"message\": \"collection lock options test\"}";

    // Upsert a document
    const upsert_result = try client.upsertWithCollection(key, value, collection, .{});
    try testing.expect(upsert_result.cas > 0);

    // Test with different lock times
    const short_lock_options = couchbase.types.GetAndLockOptions{
        .lock_time = 5, // 5 seconds
        .timeout_ms = 2000,
    };
    var short_lock_result = try client.getAndLockWithCollection(key, collection, short_lock_options);
    defer short_lock_result.deinit();

    try testing.expectEqualStrings(value, short_lock_result.value);
    try testing.expect(short_lock_result.lock_time == 5);

    // Unlock
    try client.unlockWithCollection(key, short_lock_result.cas, collection);

    // Test with longer lock time
    const long_lock_options = couchbase.types.GetAndLockOptions{
        .lock_time = 30, // 30 seconds
        .timeout_ms = 5000,
    };
    var long_lock_result = try client.getAndLockWithCollection(key, collection, long_lock_options);
    defer long_lock_result.deinit();

    try testing.expectEqualStrings(value, long_lock_result.value);
    try testing.expect(long_lock_result.lock_time == 30);

    // Unlock
    try client.unlockWithCollection(key, long_lock_result.cas, collection);

    // Clean up
    _ = client.removeWithCollection(key, collection, .{}) catch {};
}

test "collection-aware lock timeout handling" {
    var client = getTestClient(testing.allocator) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    // Use default collection
    var collection = try couchbase.Collection.default(testing.allocator);
    defer collection.deinit();

    const key = "collection_lock_timeout_test_key";
    const value = "{\"message\": \"collection lock timeout test\"}";

    // Upsert a document
    const upsert_result = try client.upsertWithCollection(key, value, collection, .{});
    try testing.expect(upsert_result.cas > 0);

    // Test with very short timeout
    const timeout_options = couchbase.types.GetAndLockOptions{
        .lock_time = 10,
        .timeout_ms = 1, // Very short timeout
    };

    // This might succeed or timeout depending on server response time
    const result = client.getAndLockWithCollection(key, collection, timeout_options);
    if (result) |lock_result| {
        var mutable_result = lock_result;
        defer mutable_result.deinit();
        try client.unlockWithCollection(key, mutable_result.cas, collection);
    } else |err| {
        // Timeout is acceptable
        try testing.expect(err == couchbase.Error.Timeout);
    }

    // Clean up
    _ = client.removeWithCollection(key, collection, .{}) catch {};
}
