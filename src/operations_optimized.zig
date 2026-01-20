const std = @import("std");
const c = @import("c.zig");
const Error = @import("error.zig").Error;
const fromStatusCode = @import("error.zig").fromStatusCode;
const types = @import("types.zig");
const Client = @import("client.zig").Client;
const operations = @import("operations.zig");

/// Optimized GetResult that can reuse memory
pub const OptimizedGetResult = struct {
    value: []const u8,
    cas: u64,
    flags: u32,
    arena: ?std.heap.ArenaAllocator = null,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *const OptimizedGetResult) void {
        if (self.arena) |*arena| {
            arena.deinit();
        } else {
            self.allocator.free(self.value);
        }
    }
};

/// Optimized get operation using arena allocator for temporary allocations
pub fn getOptimized(client: *Client, key: []const u8) Error!OptimizedGetResult {
    // Use arena allocator for temporary allocations
    var arena = std.heap.ArenaAllocator.init(client.allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    var ctx = struct {
        result: ?OptimizedGetResult = null,
        err: ?Error = null,
        done: bool = false,
        arena: *std.heap.ArenaAllocator,
    }{ .arena = &arena };

    var cmd: ?*c.lcb_CMDGET = null;
    _ = c.lcb_cmdget_create(&cmd);
    defer _ = c.lcb_cmdget_destroy(cmd);

    _ = c.lcb_cmdget_key(cmd, key.ptr, key.len);

    const callback = struct {
        fn cb(instance: ?*c.lcb_INSTANCE, cbtype: c.lcb_CALLBACK_TYPE, resp: ?*const c.lcb_RESPGET) callconv(.C) void {
            _ = instance;
            _ = cbtype;

            var cookie: ?*anyopaque = null;
            _ = c.lcb_respget_cookie(resp, &cookie);
            var context: *@TypeOf(ctx) = @ptrCast(@alignCast(cookie));

            const rc = c.lcb_respget_status(resp);
            if (rc != c.LCB_SUCCESS) {
                fromStatusCode(rc) catch |err| { context.err = err; };
                context.done = true;
                return;
            }

            var value_ptr: [*c]const u8 = undefined;
            var value_len: usize = undefined;
            _ = c.lcb_respget_value(resp, &value_ptr, &value_len);

            var cas: u64 = undefined;
            _ = c.lcb_respget_cas(resp, &cas);

            var flags: u32 = undefined;
            _ = c.lcb_respget_flags(resp, &flags);

            // Use arena allocator for value copy
            const value_copy = context.arena.allocator().dupe(u8, value_ptr[0..value_len]) catch {
                context.err = error.OutOfMemory;
                context.done = true;
                return;
            };

            // Transfer arena ownership to result
            var arena_copy = context.arena.*;
            context.arena.reset();
            context.arena = undefined;

            context.result = OptimizedGetResult{
                .value = value_copy,
                .cas = cas,
                .flags = flags,
                .arena = arena_copy,
                .allocator = client.allocator,
            };
            context.done = true;
        }
    }.cb;

    _ = c.lcb_install_callback(client.instance, c.LCB_CALLBACK_GET, @ptrCast(&callback));

    var rc = c.lcb_get(client.instance, &ctx, cmd);
    try fromStatusCode(rc);

    rc = c.lcb_wait(client.instance, 0);
    try fromStatusCode(rc);

    if (ctx.err) |err| return err;
    return ctx.result orelse error.Unknown;
}

/// Optimized get with zero-copy when possible (for read-only operations)
pub fn getZeroCopy(client: *Client, key: []const u8, buffer: []u8) Error!struct {
    value: []const u8,
    cas: u64,
    flags: u32,
    copied: bool,
} {
    var ctx = struct {
        value_ptr: ?[*c]const u8 = null,
        value_len: usize = 0,
        cas: u64 = 0,
        flags: u32 = 0,
        err: ?Error = null,
        done: bool = false,
        buffer: []u8,
    }{ .buffer = buffer };

    var cmd: ?*c.lcb_CMDGET = null;
    _ = c.lcb_cmdget_create(&cmd);
    defer _ = c.lcb_cmdget_destroy(cmd);

    _ = c.lcb_cmdget_key(cmd, key.ptr, key.len);

    const callback = struct {
        fn cb(instance: ?*c.lcb_INSTANCE, cbtype: c.lcb_CALLBACK_TYPE, resp: ?*const c.lcb_RESPGET) callconv(.C) void {
            _ = instance;
            _ = cbtype;

            var cookie: ?*anyopaque = null;
            _ = c.lcb_respget_cookie(resp, &cookie);
            var context: *@TypeOf(ctx) = @ptrCast(@alignCast(cookie));

            const rc = c.lcb_respget_status(resp);
            if (rc != c.LCB_SUCCESS) {
                fromStatusCode(rc) catch |err| { context.err = err; };
                context.done = true;
                return;
            }

            var value_ptr: [*c]const u8 = undefined;
            var value_len: usize = undefined;
            _ = c.lcb_respget_value(resp, &value_ptr, &value_len);

            var cas: u64 = undefined;
            _ = c.lcb_respget_cas(resp, &cas);

            var flags: u32 = undefined;
            _ = c.lcb_respget_flags(resp, &flags);

            context.value_ptr = value_ptr;
            context.value_len = value_len;
            context.cas = cas;
            context.flags = flags;
            context.done = true;
        }
    }.cb;

    _ = c.lcb_install_callback(client.instance, c.LCB_CALLBACK_GET, @ptrCast(&callback));

    var rc = c.lcb_get(client.instance, &ctx, cmd);
    try fromStatusCode(rc);

    rc = c.lcb_wait(client.instance, 0);
    try fromStatusCode(rc);

    if (ctx.err) |err| return err;

    // Try to use buffer if value fits, otherwise need to allocate
    if (ctx.value_len <= ctx.buffer.len) {
        @memcpy(ctx.buffer[0..ctx.value_len], ctx.value_ptr.?[0..ctx.value_len]);
        return .{
            .value = ctx.buffer[0..ctx.value_len],
            .cas = ctx.cas,
            .flags = ctx.flags,
            .copied = true,
        };
    } else {
        // Value too large for buffer, need to allocate
        const value_copy = try client.allocator.dupe(u8, ctx.value_ptr.?[0..ctx.value_len]);
        return .{
            .value = value_copy,
            .cas = ctx.cas,
            .flags = ctx.flags,
            .copied = false,
        };
    }
}

/// Batch get operations with optimized memory usage
pub fn getBatchOptimized(client: *Client, allocator: std.mem.Allocator, keys: []const []const u8) Error![]OptimizedGetResult {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    var results = try arena_allocator.alloc(OptimizedGetResult, keys.len);
    var errors = try arena_allocator.alloc(?Error, keys.len);
    @memset(errors, null);

    // Execute gets in parallel where possible
    for (keys, 0..) |key, i| {
        if (getOptimized(client, key)) |result| {
            results[i] = result;
        } else |err| {
            errors[i] = err;
        }
    }

    // Check for any errors
    for (errors, 0..) |err, i| {
        if (err) |e| {
            // Clean up successful results
            for (results[0..i]) |*r| {
                r.deinit();
            }
            return e;
        }
    }

    // Transfer results to caller's allocator
    var final_results = try allocator.alloc(OptimizedGetResult, keys.len);
    @memcpy(final_results, results);
    return final_results;
}
