const std = @import("std");
const testing = std.testing;
const couchbase = @import("couchbase");

const TestConfig = couchbase.TestConfig;
const Client = couchbase.Client;
const GetAndLockOptions = couchbase.GetAndLockOptions;
const UnlockOptions = couchbase.UnlockOptions;
const GetAndLockResult = couchbase.GetAndLockResult;
const UnlockResult = couchbase.UnlockResult;

fn getTestClient(allocator: std.mem.Allocator) !Client {
    const test_config = couchbase.getTestConfig();
    return try couchbase.Client.connect(allocator, .{
        .connection_string = test_config.connection_string,
        .username = test_config.username,
        .password = test_config.password,
        .bucket = test_config.bucket,
        .timeout_ms = test_config.timeout_ms,
    });
}

test "get and lock - basic functionality" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:lock:basic";
    const value = "{\"type\": \"test\", \"name\": \"lock_test\", \"value\": 42}";

    // Clean up if exists
    _ = client.remove(key, .{}) catch {};

    // Insert test document
    _ = try client.upsert(key, value, .{});

    // Get and lock the document
    const options = GetAndLockOptions{
        .lock_time = 30, // 30 seconds lock
        .timeout_ms = 10000,
    };

    var result = client.getAndLock(key, options) catch |err| {
        std.debug.print("Get and lock failed: {}\n", .{err});
        _ = client.remove(key, .{}) catch {};
        return;
    };
    defer result.deinit();

    // Verify the result
    try testing.expectEqualStrings(value, result.value);
    try testing.expect(result.cas > 0);
    try testing.expectEqual(@as(u32, 30), result.lock_time);

    // Clean up
    _ = try client.remove(key, .{});
}

test "get and lock - custom lock time" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:lock:custom";
    const value = "{\"type\": \"test\", \"name\": \"custom_lock\"}";

    // Clean up if exists
    _ = client.remove(key, .{}) catch {};

    // Insert test document
    _ = try client.upsert(key, value, .{});

    // Get and lock with custom lock time
    const options = GetAndLockOptions.withLockTime(60); // 60 seconds

    var result = client.getAndLock(key, options) catch |err| {
        std.debug.print("Get and lock with custom time failed: {}\n", .{err});
        _ = client.remove(key, .{}) catch {};
        return;
    };
    defer result.deinit();

    // Verify the result
    try testing.expectEqualStrings(value, result.value);
    try testing.expectEqual(@as(u32, 60), result.lock_time);

    // Clean up
    _ = try client.remove(key, .{});
}

test "get and lock - with durability" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:lock:durability";
    const value = "{\"type\": \"test\", \"name\": \"durability_lock\"}";

    // Clean up if exists
    _ = client.remove(key, .{}) catch {};

    // Insert test document
    _ = try client.upsert(key, value, .{});

    // Get and lock with durability
    const durability = couchbase.types.Durability{
        .level = .majority,
    };
    const options = GetAndLockOptions.withDurability(durability);

    var result = client.getAndLock(key, options) catch |err| {
        std.debug.print("Get and lock with durability failed: {}\n", .{err});
        _ = client.remove(key, .{}) catch {};
        return;
    };
    defer result.deinit();

    // Verify the result
    try testing.expectEqualStrings(value, result.value);
    try testing.expect(result.cas > 0);

    // Clean up
    _ = try client.remove(key, .{});
}

test "unlock - basic functionality" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:unlock:basic";
    const value = "{\"type\": \"test\", \"name\": \"unlock_test\"}";

    // Clean up if exists
    _ = client.remove(key, .{}) catch {};

    // Insert test document
    _ = try client.upsert(key, value, .{});

    // Get and lock the document
    const lock_options = GetAndLockOptions{
        .lock_time = 30,
    };

    var lock_result = client.getAndLock(key, lock_options) catch |err| {
        std.debug.print("Get and lock failed: {}\n", .{err});
        _ = client.remove(key, .{}) catch {};
        return;
    };
    defer lock_result.deinit();

    // Unlock the document
    const unlock_options = UnlockOptions{};
    const unlock_result = client.unlockWithOptions(key, lock_result.cas, unlock_options) catch |err| {
        std.debug.print("Unlock failed: {}\n", .{err});
        _ = client.remove(key, .{}) catch {};
        return;
    };

    // Verify unlock result
    try testing.expect(unlock_result.success);
    try testing.expect(unlock_result.cas > 0);

    // Clean up
    _ = try client.remove(key, .{});
}

test "unlock - with custom timeout" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:unlock:timeout";
    const value = "{\"type\": \"test\", \"name\": \"timeout_unlock\"}";

    // Clean up if exists
    _ = client.remove(key, .{}) catch {};

    // Insert test document
    _ = try client.upsert(key, value, .{});

    // Get and lock the document
    const lock_options = GetAndLockOptions{
        .lock_time = 30,
    };

    var lock_result = client.getAndLock(key, lock_options) catch |err| {
        std.debug.print("Get and lock failed: {}\n", .{err});
        _ = client.remove(key, .{}) catch {};
        return;
    };
    defer lock_result.deinit();

    // Unlock with custom timeout
    const unlock_options = UnlockOptions.withTimeout(15000); // 15 seconds
    const unlock_result = client.unlockWithOptions(key, lock_result.cas, unlock_options) catch |err| {
        std.debug.print("Unlock with timeout failed: {}\n", .{err});
        _ = client.remove(key, .{}) catch {};
        return;
    };

    // Verify unlock result
    try testing.expect(unlock_result.success);

    // Clean up
    _ = try client.remove(key, .{});
}

test "get and lock - non-existent document" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:lock:nonexistent";

    // Ensure document doesn't exist
    _ = client.remove(key, .{}) catch {};

    // Try to get and lock non-existent document
    const options = GetAndLockOptions{
        .lock_time = 30,
    };

    const result = client.getAndLock(key, options);
    try testing.expectError(couchbase.Error.DocumentNotFound, result);
}

test "unlock - invalid cas" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:unlock:invalid_cas";
    const value = "{\"type\": \"test\", \"name\": \"invalid_cas\"}";

    // Clean up if exists
    _ = client.remove(key, .{}) catch {};

    // Insert test document
    _ = try client.upsert(key, value, .{});

    // Try to unlock with invalid CAS
    const unlock_options = UnlockOptions{};
    const result = client.unlockWithOptions(key, 12345, unlock_options); // Invalid CAS

    // Should fail with appropriate error
    try testing.expectError(couchbase.Error.DocumentExists, result);

    // Clean up
    _ = try client.remove(key, .{});
}

test "lock timeout - lock expires" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:lock:timeout";
    const value = "{\"type\": \"test\", \"name\": \"timeout_test\"}";

    // Clean up if exists
    _ = client.remove(key, .{}) catch {};

    // Insert test document
    _ = try client.upsert(key, value, .{});

    // Get and lock with short lock time
    const lock_options = GetAndLockOptions{
        .lock_time = 1, // 1 second lock
    };

    var lock_result = client.getAndLock(key, lock_options) catch |err| {
        std.debug.print("Get and lock failed: {}\n", .{err});
        _ = client.remove(key, .{}) catch {};
        return;
    };
    defer lock_result.deinit();

    // Wait for lock to expire (2 seconds)
    std.time.sleep(2 * std.time.ns_per_s);

    // Try to get and lock again (should succeed as lock expired)
    const second_lock_options = GetAndLockOptions{
        .lock_time = 30,
    };

    var second_lock_result = client.getAndLock(key, second_lock_options) catch |err| {
        std.debug.print("Second get and lock failed: {}\n", .{err});
        _ = client.remove(key, .{}) catch {};
        return;
    };
    defer second_lock_result.deinit();

    // Verify the second lock succeeded
    try testing.expectEqualStrings(value, second_lock_result.value);

    // Clean up
    _ = try client.remove(key, .{});
}

test "concurrent lock attempts" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:lock:concurrent";
    const value = "{\"type\": \"test\", \"name\": \"concurrent_test\"}";

    // Clean up if exists
    _ = client.remove(key, .{}) catch {};

    // Insert test document
    _ = try client.upsert(key, value, .{});

    // First lock
    const first_lock_options = GetAndLockOptions{
        .lock_time = 30,
    };

    var first_lock_result = client.getAndLock(key, first_lock_options) catch |err| {
        std.debug.print("First get and lock failed: {}\n", .{err});
        _ = client.remove(key, .{}) catch {};
        return;
    };
    defer first_lock_result.deinit();

    // Second lock attempt (should fail)
    const second_lock_options = GetAndLockOptions{
        .lock_time = 30,
    };

    const second_lock_result = client.getAndLock(key, second_lock_options);
    try testing.expectError(couchbase.Error.TemporaryFailure, second_lock_result);

    // Unlock first lock
    const unlock_options = UnlockOptions{};
    const unlock_result = client.unlockWithOptions(key, first_lock_result.cas, unlock_options) catch |err| {
        std.debug.print("Unlock failed: {}\n", .{err});
        _ = client.remove(key, .{}) catch {};
        return;
    };

    try testing.expect(unlock_result.success);

    // Clean up
    _ = try client.remove(key, .{});
}

test "lock with different options combinations" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:lock:options";
    const value = "{\"type\": \"test\", \"name\": \"options_test\"}";

    // Clean up if exists
    _ = client.remove(key, .{}) catch {};

    // Insert test document
    _ = try client.upsert(key, value, .{});

    // Test different option combinations
    const test_cases = [_]struct {
        name: []const u8,
        options: GetAndLockOptions,
    }{
        .{
            .name = "default options",
            .options = GetAndLockOptions{},
        },
        .{
            .name = "custom lock time",
            .options = GetAndLockOptions{
                .lock_time = 45,
                .timeout_ms = 5000,
            },
        },
        .{
            .name = "with flags",
            .options = GetAndLockOptions{
                .lock_time = 20,
                .flags = 0x01,
            },
        },
    };

    for (test_cases, 0..) |test_case, i| {
        const test_key = try std.fmt.allocPrint(testing.allocator, "{s}_{d}", .{ key, i });
        defer testing.allocator.free(test_key);

        // Insert test document
        _ = try client.upsert(test_key, value, .{});

        // Get and lock
        var result = client.getAndLock(test_key, test_case.options) catch |err| {
            std.debug.print("Get and lock failed for {s}: {}\n", .{ test_case.name, err });
            _ = client.remove(test_key, .{}) catch {};
            continue;
        };
        defer result.deinit();

        // Verify result
        try testing.expectEqualStrings(value, result.value);
        try testing.expect(result.cas > 0);

        // Unlock
        const unlock_options = UnlockOptions{};
        const unlock_result = client.unlockWithOptions(test_key, result.cas, unlock_options) catch |err| {
            std.debug.print("Unlock failed for {s}: {}\n", .{ test_case.name, err });
            _ = client.remove(test_key, .{}) catch {};
            continue;
        };

        try testing.expect(unlock_result.success);

        // Clean up
        _ = try client.remove(test_key, .{});
    }

    // Clean up
    _ = client.remove(key, .{}) catch {};
}
