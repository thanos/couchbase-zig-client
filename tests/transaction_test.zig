const std = @import("std");
const testing = std.testing;
const couchbase = @import("couchbase");

const Client = couchbase.Client;
const Error = couchbase.Error;
const TransactionContext = couchbase.TransactionContext;
const TransactionResult = couchbase.TransactionResult;
const TransactionConfig = couchbase.TransactionConfig;
const TransactionOperationOptions = couchbase.TransactionOperationOptions;
const TransactionState = couchbase.TransactionState;
const StoreOptions = couchbase.operations.StoreOptions;
const RemoveOptions = couchbase.operations.RemoveOptions;
const QueryOptions = couchbase.operations.QueryOptions;

// Test configuration
const TEST_HOST = "couchbase://127.0.0.1";
const TEST_USER = "tester";
const TEST_PASSWORD = "csfb2010";
const TEST_BUCKET = "default";

test "transaction - basic transaction lifecycle" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Connect to Couchbase
    var client = try Client.connect(allocator, .{
        .connection_string = TEST_HOST,
        .username = TEST_USER,
        .password = TEST_PASSWORD,
        .bucket = TEST_BUCKET,
    });
    defer client.disconnect();

    // Begin transaction
    var ctx = try client.beginTransaction(allocator);
    defer ctx.deinit();

    try testing.expect(ctx.state == .active);
    try testing.expect(ctx.operations.items.len == 0);

    // Add operations
    try client.addInsertOperation(&ctx, "txn_key1", "value1", null);
    try client.addUpsertOperation(&ctx, "txn_key2", "value2", null);
    try client.addGetOperation(&ctx, "txn_key1", null);

    try testing.expect(ctx.operations.items.len == 3);

    // Commit transaction
    const config = TransactionConfig{};
    const result = try client.commitTransaction(&ctx, config);
    defer result.deinit();

    try testing.expect(result.success);
    try testing.expect(result.operations_executed == 3);
    try testing.expect(ctx.state == .committed);
}

test "transaction - rollback transaction" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Connect to Couchbase
    var client = try Client.connect(allocator, .{
        .connection_string = TEST_HOST,
        .username = TEST_USER,
        .password = TEST_PASSWORD,
        .bucket = TEST_BUCKET,
    });
    defer client.disconnect();

    // Begin transaction
    var ctx = try client.beginTransaction(allocator);
    defer ctx.deinit();

    // Add operations
    try client.addInsertOperation(&ctx, "txn_rollback_key1", "value1", null);
    try client.addUpsertOperation(&ctx, "txn_rollback_key2", "value2", null);

    // Rollback transaction
    const result = try client.rollbackTransaction(&ctx);
    defer result.deinit();

    try testing.expect(result.success);
    try testing.expect(ctx.state == .rolled_back);
}

test "transaction - counter operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Connect to Couchbase
    var client = try Client.connect(allocator, .{
        .connection_string = TEST_HOST,
        .username = TEST_USER,
        .password = TEST_PASSWORD,
        .bucket = TEST_BUCKET,
    });
    defer client.disconnect();

    // Begin transaction
    var ctx = try client.beginTransaction(allocator);
    defer ctx.deinit();

    // Add counter operations
    try client.addIncrementOperation(&ctx, "txn_counter", 10, null);
    try client.addDecrementOperation(&ctx, "txn_counter", 5, null);

    // Commit transaction
    const config = TransactionConfig{};
    const result = try client.commitTransaction(&ctx, config);
    defer result.deinit();

    try testing.expect(result.success);
    try testing.expect(result.operations_executed == 2);
}

test "transaction - touch and unlock operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Connect to Couchbase
    var client = try Client.connect(allocator, .{
        .connection_string = TEST_HOST,
        .username = TEST_USER,
        .password = TEST_PASSWORD,
        .bucket = TEST_BUCKET,
    });
    defer client.disconnect();

    // First, create and lock a document
    const lock_result = try client.getAndLock("txn_lock_key", .{ .lock_time = 30 });
    defer lock_result.deinit();

    // Begin transaction
    var ctx = try client.beginTransaction(allocator);
    defer ctx.deinit();

    // Add touch and unlock operations
    try client.addTouchOperation(&ctx, "txn_lock_key", 60, null);
    try client.addUnlockOperation(&ctx, "txn_lock_key", lock_result.cas, null);

    // Commit transaction
    const config = TransactionConfig{};
    const result = try client.commitTransaction(&ctx, config);
    defer result.deinit();

    try testing.expect(result.success);
    try testing.expect(result.operations_executed == 2);
}

test "transaction - query operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Connect to Couchbase
    var client = try Client.connect(allocator, .{
        .connection_string = TEST_HOST,
        .username = TEST_USER,
        .password = TEST_PASSWORD,
        .bucket = TEST_BUCKET,
    });
    defer client.disconnect();

    // Begin transaction
    var ctx = try client.beginTransaction(allocator);
    defer ctx.deinit();

    // Add query operation
    const query_options = TransactionOperationOptions{
        .query_options = QueryOptions{
            .timeout_ms = 5000,
            .read_only = true,
        },
    };
    const query_str = try std.fmt.allocPrint(allocator, "SELECT * FROM `{s}` LIMIT 1", .{TEST_BUCKET});
    defer allocator.free(query_str);
    try client.addQueryOperation(&ctx, query_str, query_options);

    // Commit transaction
    const config = TransactionConfig{};
    const result = try client.commitTransaction(&ctx, config);
    defer result.deinit();

    try testing.expect(result.success);
    try testing.expect(result.operations_executed == 1);
}

test "transaction - error handling" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Connect to Couchbase
    var client = try Client.connect(allocator, .{
        .connection_string = TEST_HOST,
        .username = TEST_USER,
        .password = TEST_PASSWORD,
        .bucket = TEST_BUCKET,
    });
    defer client.disconnect();

    // Begin transaction
    var ctx = try client.beginTransaction(allocator);
    defer ctx.deinit();

    // Add operations that will fail
    try client.addReplaceOperation(&ctx, "nonexistent_key", "value", null);

    // Commit transaction (should fail)
    const config = TransactionConfig{};
    const result = client.commitTransaction(&ctx, config) catch |err| {
        // Expected to fail
        try testing.expect(err == Error.DocumentNotFound);
        return;
    };
    defer result.deinit();

    // If we get here, the test should fail
    try testing.expect(false);
}

test "transaction - auto rollback on failure" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Connect to Couchbase
    var client = try Client.connect(allocator, .{
        .connection_string = TEST_HOST,
        .username = TEST_USER,
        .password = TEST_PASSWORD,
        .bucket = TEST_BUCKET,
    });
    defer client.disconnect();

    // Begin transaction
    var ctx = try client.beginTransaction(allocator);
    defer ctx.deinit();

    // Add one successful operation
    try client.addInsertOperation(&ctx, "txn_auto_rollback_key", "value", null);

    // Add one operation that will fail
    try client.addReplaceOperation(&ctx, "nonexistent_key", "value", null);

    // Commit transaction with auto rollback enabled
    const config = TransactionConfig{
        .auto_rollback = true,
    };
    const result = try client.commitTransaction(&ctx, config);
    defer result.deinit();

    try testing.expect(!result.success);
    try testing.expect(ctx.state == .failed);
}

test "transaction - transaction state management" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Connect to Couchbase
    var client = try Client.connect(allocator, .{
        .connection_string = TEST_HOST,
        .username = TEST_USER,
        .password = TEST_PASSWORD,
        .bucket = TEST_BUCKET,
    });
    defer client.disconnect();

    // Begin transaction
    var ctx = try client.beginTransaction(allocator);
    defer ctx.deinit();

    try testing.expect(ctx.state == .active);

    // Add operation to committed transaction (should fail)
    const config = TransactionConfig{};
    _ = try client.commitTransaction(&ctx, config);
    try testing.expect(ctx.state == .committed);

    // Try to add operation to committed transaction
    const add_result = client.addInsertOperation(&ctx, "key", "value", null);
    try testing.expect(add_result == Error.TransactionNotActive);
}

test "transaction - complex multi-operation transaction" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Connect to Couchbase
    var client = try Client.connect(allocator, .{
        .connection_string = TEST_HOST,
        .username = TEST_USER,
        .password = TEST_PASSWORD,
        .bucket = TEST_BUCKET,
    });
    defer client.disconnect();

    // Begin transaction
    var ctx = try client.beginTransaction(allocator);
    defer ctx.deinit();

    // Add multiple operations
    try client.addInsertOperation(&ctx, "txn_complex_key1", "value1", null);
    try client.addUpsertOperation(&ctx, "txn_complex_key2", "value2", null);
    try client.addGetOperation(&ctx, "txn_complex_key1", null);
    try client.addIncrementOperation(&ctx, "txn_complex_counter", 5, null);
    try client.addTouchOperation(&ctx, "txn_complex_key1", 300, null);

    // Commit transaction
    const config = TransactionConfig{};
    const result = try client.commitTransaction(&ctx, config);
    defer result.deinit();

    try testing.expect(result.success);
    try testing.expect(result.operations_executed == 5);
}

test "transaction - transaction configuration" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Connect to Couchbase
    var client = try Client.connect(allocator, .{
        .connection_string = TEST_HOST,
        .username = TEST_USER,
        .password = TEST_PASSWORD,
        .bucket = TEST_BUCKET,
    });
    defer client.disconnect();

    // Begin transaction
    var ctx = try client.beginTransaction(allocator);
    defer ctx.deinit();

    // Add operation
    try client.addInsertOperation(&ctx, "txn_config_key", "value", null);

    // Commit with custom configuration
    const config = TransactionConfig{
        .timeout_ms = 10000,
        .retry_attempts = 2,
        .retry_delay_ms = 50,
        .auto_rollback = true,
    };
    const result = try client.commitTransaction(&ctx, config);
    defer result.deinit();

    try testing.expect(result.success);
    try testing.expect(result.operations_executed == 1);
}

test "transaction - memory management" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Connect to Couchbase
    var client = try Client.connect(allocator, .{
        .connection_string = TEST_HOST,
        .username = TEST_USER,
        .password = TEST_PASSWORD,
        .bucket = TEST_BUCKET,
    });
    defer client.disconnect();

    // Begin transaction
    var ctx = try client.beginTransaction(allocator);
    defer ctx.deinit();

    // Add operations with values
    try client.addInsertOperation(&ctx, "txn_memory_key1", "large_value_1", null);
    try client.addUpsertOperation(&ctx, "txn_memory_key2", "large_value_2", null);

    // Commit transaction
    const config = TransactionConfig{};
    const result = try client.commitTransaction(&ctx, config);
    defer result.deinit();

    try testing.expect(result.success);
    try testing.expect(result.operations_executed == 2);

    // Memory should be properly cleaned up by deinit()
}
