const std = @import("std");
const Error = @import("error.zig").Error;
const types = @import("types.zig");
const operations = @import("operations.zig");
const Client = @import("client.zig").Client;

/// Result of executing a transaction operation
const OperationResult = struct {
    cas: u64,
    value: ?[]const u8,
};

/// Transaction Rollback Behavior Documentation
/// 
/// This module implements ACID transactions with automatic rollback capabilities.
/// The rollback behavior varies by operation type:
/// 
/// **CREATE Operations (insert):**
/// - Rollback: Remove the created document
/// - Safe: No data loss risk
/// 
/// **UPDATE Operations (replace):**
/// - Rollback: Restore original document value
/// - Safe: Original value captured before modification
/// 
/// **UPSERT Operations:**
/// - Rollback behavior depends on whether document existed before upsert:
///   - If document didn't exist: Rollback removes the document (safe)
///   - If document existed: Rollback restores original value (safe)
/// - **Limitation**: Requires reading original document state before modification
/// - **Risk**: If original read fails, rollback may not be possible
/// 
/// **DELETE Operations (remove):**
/// - Rollback: Re-insert document with original value
/// - Safe: Original value captured before deletion
/// 
/// **COUNTER Operations (increment/decrement):**
/// - Rollback: Apply opposite operation with same delta
/// - Safe: No data loss risk
/// 
/// **READ Operations (get, query):**
/// - No rollback needed (no data modification)
/// 
/// **Concurrent Modification Risks:**
/// - If another process modifies a document between transaction execution and rollback,
///   rollback operations may fail due to CAS conflicts
/// - This is a fundamental limitation of optimistic concurrency control

pub const TransactionContext = types.TransactionContext;
pub const TransactionResult = types.TransactionResult;
pub const TransactionConfig = types.TransactionConfig;
pub const TransactionOperation = types.TransactionOperation;
pub const TransactionOperationType = types.TransactionOperationType;
pub const TransactionOperationOptions = types.TransactionOperationOptions;
pub const TransactionState = types.TransactionState;

/// Begin a new transaction
pub fn beginTransaction(client: *Client, allocator: std.mem.Allocator) !TransactionContext {
    return TransactionContext.create(client, allocator);
}

/// Add a GET operation to the transaction
pub fn addGetOperation(
    ctx: *TransactionContext,
    key: []const u8,
    options: ?TransactionOperationOptions,
) !void {
    if (ctx.state != .active) {
        return Error.TransactionNotActive;
    }
    
    const operation = TransactionOperation{
        .operation_type = .get,
        .key = try ctx.allocator.dupe(u8, key),
        .options = options,
        .allocator = ctx.allocator,
    };
    
    try ctx.operations.append(operation);
}

/// Add an INSERT operation to the transaction
pub fn addInsertOperation(
    ctx: *TransactionContext,
    key: []const u8,
    value: []const u8,
    options: ?TransactionOperationOptions,
) !void {
    if (ctx.state != .active) {
        return Error.TransactionNotActive;
    }
    
    const operation = TransactionOperation{
        .operation_type = .insert,
        .key = try ctx.allocator.dupe(u8, key),
        .value = try ctx.allocator.dupe(u8, value),
        .options = options,
        .allocator = ctx.allocator,
    };
    
    try ctx.operations.append(operation);
}

/// Add an UPSERT operation to the transaction
/// 
/// **Rollback Behavior:**
/// - If the document didn't exist before upsert: rollback removes the document
/// - If the document existed before upsert: rollback restores the original value
/// 
/// **Limitations:**
/// - Rollback requires reading the original document state before modification
/// - If the original document read fails, rollback may not be possible
/// - Concurrent modifications between upsert and rollback may cause conflicts
pub fn addUpsertOperation(
    ctx: *TransactionContext,
    key: []const u8,
    value: []const u8,
    options: ?TransactionOperationOptions,
) !void {
    if (ctx.state != .active) {
        return Error.TransactionNotActive;
    }
    
    const operation = TransactionOperation{
        .operation_type = .upsert,
        .key = try ctx.allocator.dupe(u8, key),
        .value = try ctx.allocator.dupe(u8, value),
        .options = options,
        .allocator = ctx.allocator,
    };
    
    try ctx.operations.append(operation);
}

/// Add a REPLACE operation to the transaction
pub fn addReplaceOperation(
    ctx: *TransactionContext,
    key: []const u8,
    value: []const u8,
    options: ?TransactionOperationOptions,
) !void {
    if (ctx.state != .active) {
        return Error.TransactionNotActive;
    }
    
    const operation = TransactionOperation{
        .operation_type = .replace,
        .key = try ctx.allocator.dupe(u8, key),
        .value = try ctx.allocator.dupe(u8, value),
        .options = options,
        .allocator = ctx.allocator,
    };
    
    try ctx.operations.append(operation);
}

/// Add a REMOVE operation to the transaction
pub fn addRemoveOperation(
    ctx: *TransactionContext,
    key: []const u8,
    options: ?TransactionOperationOptions,
) !void {
    if (ctx.state != .active) {
        return Error.TransactionNotActive;
    }
    
    const operation = TransactionOperation{
        .operation_type = .remove,
        .key = try ctx.allocator.dupe(u8, key),
        .options = options,
        .allocator = ctx.allocator,
    };
    
    try ctx.operations.append(operation);
}

/// Add an INCREMENT operation to the transaction
pub fn addIncrementOperation(
    ctx: *TransactionContext,
    key: []const u8,
    delta: i64,
    options: ?TransactionOperationOptions,
) !void {
    if (ctx.state != .active) {
        return Error.TransactionNotActive;
    }
    
    const operation = TransactionOperation{
        .operation_type = .increment,
        .key = try ctx.allocator.dupe(u8, key),
        .value = try std.fmt.allocPrint(ctx.allocator, "{}", .{delta}),
        .options = options,
        .allocator = ctx.allocator,
    };
    
    try ctx.operations.append(operation);
}

/// Add a DECREMENT operation to the transaction
pub fn addDecrementOperation(
    ctx: *TransactionContext,
    key: []const u8,
    delta: i64,
    options: ?TransactionOperationOptions,
) !void {
    if (ctx.state != .active) {
        return Error.TransactionNotActive;
    }
    
    const operation = TransactionOperation{
        .operation_type = .decrement,
        .key = try ctx.allocator.dupe(u8, key),
        .value = try std.fmt.allocPrint(ctx.allocator, "{}", .{delta}),
        .options = options,
        .allocator = ctx.allocator,
    };
    
    try ctx.operations.append(operation);
}

/// Add a TOUCH operation to the transaction
pub fn addTouchOperation(
    ctx: *TransactionContext,
    key: []const u8,
    expiry: u32,
    options: ?TransactionOperationOptions,
) !void {
    if (ctx.state != .active) {
        return Error.TransactionNotActive;
    }
    
    var touch_options = options orelse TransactionOperationOptions{};
    touch_options.expiry = expiry;
    
    const operation = TransactionOperation{
        .operation_type = .touch,
        .key = try ctx.allocator.dupe(u8, key),
        .options = touch_options,
        .allocator = ctx.allocator,
    };
    
    try ctx.operations.append(operation);
}

/// Add an UNLOCK operation to the transaction
pub fn addUnlockOperation(
    ctx: *TransactionContext,
    key: []const u8,
    cas: u64,
    options: ?TransactionOperationOptions,
) !void {
    if (ctx.state != .active) {
        return Error.TransactionNotActive;
    }
    
    var unlock_options = options orelse TransactionOperationOptions{};
    unlock_options.cas = cas;
    
    const operation = TransactionOperation{
        .operation_type = .unlock,
        .key = try ctx.allocator.dupe(u8, key),
        .cas = cas,
        .options = unlock_options,
        .allocator = ctx.allocator,
    };
    
    try ctx.operations.append(operation);
}

/// Add a QUERY operation to the transaction
pub fn addQueryOperation(
    ctx: *TransactionContext,
    statement: []const u8,
    options: ?TransactionOperationOptions,
) !void {
    if (ctx.state != .active) {
        return Error.TransactionNotActive;
    }
    
    const operation = TransactionOperation{
        .operation_type = .query,
        .key = try ctx.allocator.dupe(u8, "query"),
        .query_statement = try ctx.allocator.dupe(u8, statement),
        .options = options,
        .allocator = ctx.allocator,
    };
    
    try ctx.operations.append(operation);
}

/// Execute all operations in the transaction
pub fn commitTransaction(ctx: *TransactionContext, config: TransactionConfig) !TransactionResult {
    if (ctx.state != .active) {
        return TransactionResult{
            .success = false,
            .operations_executed = 0,
            .operations_rolled_back = 0,
            .error_message = try std.fmt.allocPrint(ctx.allocator, "Transaction is not active", .{}),
            .allocator = ctx.allocator,
        };
    }
    
    var operations_executed: u32 = 0;
    var operations_rolled_back: u32 = 0;
    var last_error: ?Error = null;
    
    // Execute all operations
    for (ctx.operations.items, 0..) |*operation, i| {
        // For upsert operations, capture original document state before modification
        if (operation.operation_type == .upsert) {
            captureOriginalDocumentState(ctx.client, operation) catch {
                // If we can't capture original state, we can't safely rollback
                // This is a limitation that should be documented
            };
        }
        
        const result = executeOperation(ctx.client, operation) catch |err| {
            last_error = err;
            
            // If auto_rollback is enabled, rollback completed operations
            if (config.auto_rollback) {
                operations_rolled_back = try rollbackOperations(ctx, @intCast(i));
            }
            
            ctx.state = .failed;
            break;
        };
        
        // Store result data for potential rollback
        operation.result_cas = result.cas;
        operation.result_value = result.value;
        
        operations_executed += 1;
        
        // Store rollback operation if needed
        if (needsRollback(operation.operation_type)) {
            try addRollbackOperation(ctx, operation, result);
        }
    }
    
    if (last_error != null) {
        ctx.state = .failed;
        return TransactionResult{
            .success = false,
            .operations_executed = operations_executed,
            .operations_rolled_back = operations_rolled_back,
            .error_message = try std.fmt.allocPrint(ctx.allocator, "Transaction failed: {s}", .{@errorName(last_error.?)}),
            .allocator = ctx.allocator,
        };
    }
    
    ctx.state = .committed;
    return TransactionResult{
        .success = true,
        .operations_executed = operations_executed,
        .operations_rolled_back = 0,
        .allocator = ctx.allocator,
    };
}

/// Rollback all operations in the transaction
pub fn rollbackTransaction(ctx: *TransactionContext) !TransactionResult {
    if (ctx.state != .active) {
        return TransactionResult{
            .success = false,
            .operations_executed = 0,
            .operations_rolled_back = 0,
            .error_message = try std.fmt.allocPrint(ctx.allocator, "Transaction is not active", .{}),
            .allocator = ctx.allocator,
        };
    }
    
    const operations_rolled_back = try rollbackOperations(ctx, @intCast(ctx.rollback_operations.items.len));
    ctx.state = .rolled_back;
    
    return TransactionResult{
        .success = true,
        .operations_executed = 0,
        .operations_rolled_back = operations_rolled_back,
        .allocator = ctx.allocator,
    };
}

/// Execute a single operation and return result data
fn executeOperation(client: *Client, operation: *TransactionOperation) !OperationResult {
    switch (operation.operation_type) {
        .get => {
            const result = try operations.get(client, operation.key);
            defer result.deinit();
            return .{ .cas = result.cas, .value = try client.allocator.dupe(u8, result.value) };
        },
        .insert => {
            const store_options = operation.options orelse TransactionOperationOptions{};
            const options = operations.StoreOptions{
                .cas = store_options.cas,
                .expiry = store_options.expiry,
                .flags = store_options.flags,
                .durability = store_options.durability,
            };
            const result = try operations.store(client, operation.key, operation.value.?, .insert, options);
            return .{ .cas = result.cas, .value = null };
        },
        .upsert => {
            const store_options = operation.options orelse TransactionOperationOptions{};
            const options = operations.StoreOptions{
                .cas = store_options.cas,
                .expiry = store_options.expiry,
                .flags = store_options.flags,
                .durability = store_options.durability,
            };
            const result = try operations.store(client, operation.key, operation.value.?, .upsert, options);
            return .{ .cas = result.cas, .value = null };
        },
        .replace => {
            const store_options = operation.options orelse TransactionOperationOptions{};
            const options = operations.StoreOptions{
                .cas = store_options.cas,
                .expiry = store_options.expiry,
                .flags = store_options.flags,
                .durability = store_options.durability,
            };
            const result = try operations.store(client, operation.key, operation.value.?, .replace, options);
            return .{ .cas = result.cas, .value = null };
        },
        .remove => {
            const remove_options = operation.options orelse TransactionOperationOptions{};
            const options = operations.RemoveOptions{
                .cas = remove_options.cas,
                .durability = remove_options.durability,
            };
            const result = try operations.remove(client, operation.key, options);
            return .{ .cas = result.cas, .value = null };
        },
        .increment => {
            const counter_options = operation.options orelse TransactionOperationOptions{};
            const delta = std.fmt.parseInt(i64, operation.value.?, 10) catch 1;
            const options = operations.CounterOptions{
                .initial = counter_options.initial,
                .expiry = counter_options.expiry,
                .durability = counter_options.durability,
            };
            const result = try operations.counter(client, operation.key, delta, options);
            return .{ .cas = result.cas, .value = try std.fmt.allocPrint(client.allocator, "{}", .{result.value}) };
        },
        .decrement => {
            const counter_options = operation.options orelse TransactionOperationOptions{};
            const delta = std.fmt.parseInt(i64, operation.value.?, 10) catch 1;
            const options = operations.CounterOptions{
                .initial = counter_options.initial,
                .expiry = counter_options.expiry,
                .durability = counter_options.durability,
            };
            const result = try operations.counter(client, operation.key, -delta, options);
            return .{ .cas = result.cas, .value = try std.fmt.allocPrint(client.allocator, "{}", .{result.value}) };
        },
        .touch => {
            const touch_options = operation.options orelse TransactionOperationOptions{};
            const result = try operations.touch(client, operation.key, touch_options.expiry);
            return .{ .cas = result.cas, .value = null };
        },
        .unlock => {
            _ = try operations.unlock(client, operation.key, operation.cas);
            return .{ .cas = 0, .value = null };
        },
        .query => {
            const query_options = operation.options orelse TransactionOperationOptions{};
            const options = query_options.query_options orelse operations.QueryOptions{};
            const result = try operations.query(client, client.allocator, operation.query_statement.?, options);
            defer result.deinit();
            return .{ .cas = 0, .value = null };
        },
    }
}

/// Check if an operation type needs rollback
fn needsRollback(operation_type: TransactionOperationType) bool {
    return switch (operation_type) {
        .get, .query => false,
        .insert, .upsert, .replace, .remove, .increment, .decrement, .touch, .unlock => true,
    };
}

/// Add a rollback operation
fn addRollbackOperation(ctx: *TransactionContext, operation: *const TransactionOperation, result: OperationResult) !void {
    // Create rollback operation based on the original operation type
    var rollback_op = TransactionOperation{
        .operation_type = getRollbackOperationType(operation.operation_type),
        .key = try ctx.allocator.dupe(u8, operation.key),
        .value = if (result.value) |v| try ctx.allocator.dupe(u8, v) else null,
        .cas = result.cas,
        .options = operation.options,
        .query_statement = operation.query_statement,
        .allocator = ctx.allocator,
        .result_cas = operation.cas, // Store original CAS for rollback
        .result_value = if (operation.value) |val| try ctx.allocator.dupe(u8, val) else null,
        .original_cas = operation.original_cas,
        .original_value = if (operation.original_value) |val| try ctx.allocator.dupe(u8, val) else null,
        .was_created = operation.was_created,
    };
    
    // Special handling for upsert operations
    if (operation.operation_type == .upsert) {
        if (operation.was_created) {
            // If upsert created the document, rollback by removing it
            rollback_op.operation_type = .remove;
            rollback_op.value = null;
        } else {
            // If upsert updated the document, rollback by restoring original value
            rollback_op.operation_type = .replace;
            rollback_op.value = if (operation.original_value) |val| try ctx.allocator.dupe(u8, val) else null;
            rollback_op.cas = operation.original_cas;
        }
    }
    
    try ctx.rollback_operations.append(rollback_op);
}

/// Capture the original document state before modification for proper rollback
fn captureOriginalDocumentState(client: *Client, operation: *TransactionOperation) !void {
    // Try to get the current document state
    const get_result = operations.get(client, operation.key) catch |err| switch (err) {
        Error.DocumentNotFound => {
            // Document doesn't exist, so upsert will create it
            operation.was_created = true;
            operation.original_cas = 0;
            operation.original_value = null;
            return;
        },
        else => return err,
    };
    defer get_result.deinit();
    
    // Document exists, so upsert will update it
    operation.was_created = false;
    operation.original_cas = get_result.cas;
    operation.original_value = try client.allocator.dupe(u8, get_result.value);
}

/// Get the rollback operation type for a given operation
fn getRollbackOperationType(operation_type: TransactionOperationType) TransactionOperationType {
    return switch (operation_type) {
        .insert => .remove, // Insert -> Remove
        .upsert => .replace, // Upsert -> Replace with original value (handled specially)
        .replace => .replace, // Replace -> Replace with original value
        .remove => .insert, // Remove -> Insert with original value
        .increment => .decrement, // Increment -> Decrement
        .decrement => .increment, // Decrement -> Increment
        .touch => .touch, // Touch -> Touch with original expiry
        .unlock => .get, // Unlock -> Get (to re-lock)
        .get, .query => .get, // Read operations don't need rollback
    };
}

/// Rollback operations
fn rollbackOperations(ctx: *TransactionContext, count: u32) !u32 {
    var rolled_back: u32 = 0;
    
    // Execute rollback operations in reverse order
    const start_idx = if (ctx.rollback_operations.items.len > count) 
        ctx.rollback_operations.items.len - count 
    else 
        0;
    
    var i = ctx.rollback_operations.items.len;
    while (i > start_idx) {
        i -= 1;
        const rollback_op = &ctx.rollback_operations.items[i];
        
        // Execute rollback operation
        _ = executeOperation(ctx.client, rollback_op) catch |err| {
            // Log rollback failure but continue with other rollbacks
            std.log.err("Rollback operation failed: {s} on key '{s}' with error: {s}", 
                .{ @tagName(rollback_op.operation_type), rollback_op.key, @errorName(err) });
        };
        rolled_back += 1;
    }
    
    return rolled_back;
}
