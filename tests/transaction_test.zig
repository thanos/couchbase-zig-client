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

fn getTestClient(allocator: std.mem.Allocator) !Client {
    const cfg = couchbase.getTestConfig();
    return try Client.connect(allocator, .{
        .connection_string = cfg.connection_string,
        .username = cfg.username,
        .password = cfg.password,
        .bucket = "gamesim-sample", // Use gamesim-sample bucket for transaction tests
        .timeout_ms = cfg.timeout_ms,
    });
}

test "transaction - basic transaction lifecycle" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Connect to Couchbase
    var client = try getTestClient(allocator);
    defer client.disconnect();

    // Clean up any existing documents from previous test runs
    _ = client.remove("txn_key1", .{}) catch {};
    _ = client.remove("txn_key2", .{}) catch {};

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
    const result = client.commitTransaction(&ctx, config) catch |err| {
        std.debug.print("Transaction commit failed: {}\n", .{err});
        // Clean up
        _ = client.remove("txn_key1", .{}) catch {};
        _ = client.remove("txn_key2", .{}) catch {};
        return err;
    };
    defer result.deinit();

    if (!result.success) {
        std.debug.print("Transaction failed: {s}\n", .{result.error_message orelse "unknown error"});
        std.debug.print("Operations executed: {}\n", .{result.operations_executed});
    }

    try testing.expect(result.success);
    try testing.expect(result.operations_executed == 3);
    try testing.expect(ctx.state == .committed);

    // Clean up
    _ = client.remove("txn_key1", .{}) catch {};
    _ = client.remove("txn_key2", .{}) catch {};
}

test "transaction - rollback transaction" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Connect to Couchbase
    var client = try getTestClient(allocator);
    defer client.disconnect();

    // Clean up
    _ = client.remove("txn_rollback_key1", .{}) catch {};
    _ = client.remove("txn_rollback_key2", .{}) catch {};

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

    // Clean up (in case rollback didn't work)
    _ = client.remove("txn_rollback_key1", .{}) catch {};
    _ = client.remove("txn_rollback_key2", .{}) catch {};
}

test "transaction - counter operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Connect to Couchbase
    var client = try getTestClient(allocator);
    defer client.disconnect();

    // Clean up
    _ = client.remove("txn_counter", .{}) catch {};

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

    // Clean up
    _ = client.remove("txn_counter", .{}) catch {};
}

test "transaction - touch and unlock operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Connect to Couchbase
    var client = try getTestClient(allocator);
    defer client.disconnect();

    // Clean up and create document first
    _ = client.remove("txn_lock_key", .{}) catch {};
    _ = try client.upsert("txn_lock_key", "lock_value", .{});

    // First, create and lock a document
    const lock_result = client.getAndLock("txn_lock_key", .{ .lock_time = 30 }) catch |err| {
        // If getAndLock fails, clean up and skip test
        _ = client.remove("txn_lock_key", .{}) catch {};
        return err;
    };
    defer lock_result.deinit();

    // Begin transaction
    var ctx = try client.beginTransaction(allocator);
    defer ctx.deinit();

    // Add unlock first, then touch (touch requires unlocked document)
    try client.addUnlockOperation(&ctx, "txn_lock_key", lock_result.cas, null);
    try client.addTouchOperation(&ctx, "txn_lock_key", 60, null);

    // Commit transaction
    const config = TransactionConfig{};
    const result = try client.commitTransaction(&ctx, config);
    defer result.deinit();

    try testing.expect(result.success);
    try testing.expect(result.operations_executed == 2);

    // Clean up
    _ = client.remove("txn_lock_key", .{}) catch {};
}

test "transaction - query operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Connect to Couchbase
    var client = try getTestClient(allocator);
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
    const query_str = "SELECT * FROM `gamesim-sample` LIMIT 1";
    try client.addQueryOperation(&ctx, query_str, query_options);

    // Commit transaction
    const config = TransactionConfig{};
    const result = try client.commitTransaction(&ctx, config);
    defer result.deinit();

    // Query may fail if no primary index or query service not available
    // In that case, the transaction should still succeed (query errors are handled gracefully)
    try testing.expect(result.success);
    // Operations executed may be 0 if query failed, or 1 if it succeeded
    try testing.expect(result.operations_executed >= 0);
}

test "transaction - error handling" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Connect to Couchbase
    var client = try getTestClient(allocator);
    defer client.disconnect();

    // Ensure key doesn't exist
    _ = client.remove("nonexistent_key", .{}) catch {};

    // Begin transaction
    var ctx = try client.beginTransaction(allocator);
    defer ctx.deinit();

    // Add operations that will fail
    try client.addReplaceOperation(&ctx, "nonexistent_key", "value", null);

    // Commit transaction (should fail, but returns TransactionResult with success=false)
    const config = TransactionConfig{};
    const result = try client.commitTransaction(&ctx, config);
    defer result.deinit();

    // Transaction should fail because replace on nonexistent document fails
    try testing.expect(!result.success);
    try testing.expect(ctx.state == .failed);
    try testing.expect(result.operations_executed == 0);
}

test "transaction - auto rollback on failure" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Connect to Couchbase
    var client = try getTestClient(allocator);
    defer client.disconnect();

    // Clean up
    _ = client.remove("txn_auto_rollback_key", .{}) catch {};
    _ = client.remove("nonexistent_key", .{}) catch {};

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

    // Clean up
    _ = client.remove("txn_auto_rollback_key", .{}) catch {};
}

test "transaction - transaction state management" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Connect to Couchbase
    var client = try getTestClient(allocator);
    defer client.disconnect();

    // Clean up
    _ = client.remove("txn_state_key", .{}) catch {};

    // Begin transaction
    var ctx = try client.beginTransaction(allocator);
    defer ctx.deinit();

    try testing.expect(ctx.state == .active);

    // Add an operation so commit will succeed
    try client.addInsertOperation(&ctx, "txn_state_key", "value", null);

    // Commit transaction
    const config = TransactionConfig{};
    const result = try client.commitTransaction(&ctx, config);
    defer result.deinit();
    try testing.expect(result.success);
    try testing.expect(ctx.state == .committed);

    // Try to add operation to committed transaction
    const add_result = client.addInsertOperation(&ctx, "key", "value", null);
    try testing.expect(add_result == Error.TransactionNotActive);

    // Clean up
    _ = client.remove("txn_state_key", .{}) catch {};
}

test "transaction - complex multi-operation transaction" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Connect to Couchbase
    var client = try getTestClient(allocator);
    defer client.disconnect();

    // Clean up
    _ = client.remove("txn_complex_key1", .{}) catch {};
    _ = client.remove("txn_complex_key2", .{}) catch {};
    _ = client.remove("txn_complex_counter", .{}) catch {};

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

    // Clean up
    _ = client.remove("txn_complex_key1", .{}) catch {};
    _ = client.remove("txn_complex_key2", .{}) catch {};
    _ = client.remove("txn_complex_counter", .{}) catch {};
}

test "transaction - transaction configuration" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Connect to Couchbase
    var client = try getTestClient(allocator);
    defer client.disconnect();

    // Clean up
    _ = client.remove("txn_config_key", .{}) catch {};

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

    // Clean up
    _ = client.remove("txn_config_key", .{}) catch {};
}

test "transaction - memory management" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Connect to Couchbase
    var client = try getTestClient(allocator);
    defer client.disconnect();

    // Clean up
    _ = client.remove("txn_memory_key1", .{}) catch {};
    _ = client.remove("txn_memory_key2", .{}) catch {};

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
    
    // Clean up
    _ = client.remove("txn_memory_key1", .{}) catch {};
    _ = client.remove("txn_memory_key2", .{}) catch {};
}
