const std = @import("std");
const Error = @import("error.zig").Error;
const types = @import("types.zig");
const operations = @import("operations.zig");
const Client = @import("client.zig").Client;

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
    for (ctx.operations.items, 0..) |operation, i| {
        const result = executeOperation(ctx.client, &operation) catch |err| {
            last_error = err;
            
            // If auto_rollback is enabled, rollback completed operations
            if (config.auto_rollback) {
                operations_rolled_back = try rollbackOperations(ctx, @intCast(i));
            }
            
            ctx.state = .failed;
            break;
        };
        
        operations_executed += 1;
        
        // Store rollback operation if needed
        if (needsRollback(operation.operation_type)) {
            try addRollbackOperation(ctx, &operation, result);
        }
    }
    
    if (last_error != null) {
        ctx.state = .failed;
        return TransactionResult{
            .success = false,
            .operations_executed = operations_executed,
            .operations_rolled_back = operations_rolled_back,
            .error_message = try std.fmt.allocPrint(ctx.allocator, "Transaction failed: {}", .{last_error.?}),
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

/// Execute a single operation
fn executeOperation(client: *Client, operation: *const TransactionOperation) !void {
    switch (operation.operation_type) {
        .get => {
            const result = try operations.get(client, operation.key);
            defer result.deinit();
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
            _ = result;
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
            _ = result;
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
            _ = result;
        },
        .remove => {
            const remove_options = operation.options orelse TransactionOperationOptions{};
            const options = operations.RemoveOptions{
                .cas = remove_options.cas,
                .durability = remove_options.durability,
            };
            const result = try operations.remove(client, operation.key, options);
            _ = result;
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
            _ = result;
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
            _ = result;
        },
        .touch => {
            const touch_options = operation.options orelse TransactionOperationOptions{};
            const result = try operations.touch(client, operation.key, touch_options.expiry);
            _ = result;
        },
        .unlock => {
            const result = try operations.unlock(client, operation.key, operation.cas);
            _ = result;
        },
        .query => {
            const query_options = operation.options orelse TransactionOperationOptions{};
            const options = query_options.query_options orelse operations.QueryOptions{};
            const result = try operations.query(client, client.allocator, operation.query_statement.?, options);
            defer result.deinit();
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
fn addRollbackOperation(ctx: *TransactionContext, operation: *const TransactionOperation, result: anytype) !void {
    // For now, we'll implement a simple rollback strategy
    // In a real implementation, this would be more sophisticated
    _ = result;
    _ = operation;
    _ = ctx;
}

/// Rollback operations
fn rollbackOperations(ctx: *TransactionContext, count: u32) !u32 {
    var rolled_back: u32 = 0;
    
    // Simple rollback implementation
    // In a real implementation, this would execute reverse operations
    for (0..count) |i| {
        if (i < ctx.rollback_operations.items.len) {
            // Execute rollback operation
            _ = try executeOperation(ctx.client, &ctx.rollback_operations.items[i]);
            rolled_back += 1;
        }
    }
    
    return rolled_back;
}
