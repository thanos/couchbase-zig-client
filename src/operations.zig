const std = @import("std");
const c = @import("c.zig");
const Error = @import("error.zig").Error;
const fromStatusCode = @import("error.zig").fromStatusCode;
const types = @import("types.zig");
const Client = @import("client.zig").Client;

/// Result of a get operation
pub const GetResult = struct {
    value: []const u8,
    cas: u64,
    flags: u32,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *GetResult) void {
        self.allocator.free(self.value);
    }
};

/// Result of a mutation operation
pub const MutationResult = struct {
    cas: u64,
    mutation_token: ?MutationToken = null,
};

/// Mutation token for durability
pub const MutationToken = struct {
    partition_id: u16,
    partition_uuid: u64,
    sequence_number: u64,
    bucket_name: []const u8,
};

/// Counter operation result
pub const CounterResult = struct {
    value: u64,
    cas: u64,
    mutation_token: ?MutationToken = null,
};

/// Store operation options
pub const StoreOptions = struct {
    cas: u64 = 0,
    expiry: u32 = 0,
    flags: u32 = 0,
    durability: types.Durability = .{},
};

/// Remove operation options
pub const RemoveOptions = struct {
    cas: u64 = 0,
    durability: types.Durability = .{},
};

/// Counter operation options
pub const CounterOptions = struct {
    initial: u64 = 0,
    expiry: u32 = 0,
    durability: types.Durability = .{},
};

/// Query options
pub const QueryOptions = struct {
    consistency: types.ScanConsistency = .not_bounded,
    parameters: ?[]const []const u8 = null,
    timeout_ms: u32 = 75000,
    adhoc: bool = true,
};

/// Query result
pub const QueryResult = struct {
    rows: [][]const u8,
    meta: ?[]const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *QueryResult) void {
        for (self.rows) |row| {
            self.allocator.free(row);
        }
        self.allocator.free(self.rows);
        if (self.meta) |meta| {
            self.allocator.free(meta);
        }
    }
};

/// Subdocument specification
pub const SubdocSpec = struct {
    op: types.SubdocOp,
    path: []const u8,
    value: []const u8 = "",
    flags: u32 = 0,
};

/// Subdocument options
pub const SubdocOptions = struct {
    cas: u64 = 0,
    expiry: u32 = 0,
    durability: types.Durability = .{},
    access_deleted: bool = false,
};

/// Subdocument result
pub const SubdocResult = struct {
    cas: u64,
    values: [][]const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *SubdocResult) void {
        for (self.values) |val| {
            self.allocator.free(val);
        }
        self.allocator.free(self.values);
    }
};

/// Ping result
pub const PingResult = struct {
    id: []const u8,
    services: []ServiceHealth,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *PingResult) void {
        self.allocator.free(self.id);
        for (self.services) |service| {
            self.allocator.free(service.id);
        }
        self.allocator.free(self.services);
    }
};

pub const ServiceHealth = struct {
    id: []const u8,
    latency_us: u64,
    state: ServiceState,
};

pub const ServiceState = enum {
    ok,
    timeout,
    error_other,
};

/// Diagnostics result
pub const DiagnosticsResult = struct {
    id: []const u8,
    services: []ServiceDiagnostics,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *DiagnosticsResult) void {
        self.allocator.free(self.id);
        for (self.services) |service| {
            self.allocator.free(service.id);
        }
        self.allocator.free(self.services);
    }
};

pub const ServiceDiagnostics = struct {
    id: []const u8,
    last_activity_us: u64,
    state: ServiceState,
};

// Callback context structures
const GetContext = struct {
    result: ?GetResult = null,
    err: ?Error = null,
    done: bool = false,
    allocator: std.mem.Allocator,
};

const MutationContext = struct {
    result: MutationResult = .{ .cas = 0 },
    err: ?Error = null,
    done: bool = false,
};

const CounterContext = struct {
    result: CounterResult = .{ .value = 0, .cas = 0 },
    err: ?Error = null,
    done: bool = false,
};

const QueryContext = struct {
    rows: std.ArrayList([]const u8),
    meta: ?[]const u8 = null,
    err: ?Error = null,
    done: bool = false,
    allocator: std.mem.Allocator,
};

/// Get operation
pub fn get(client: *Client, key: []const u8) Error!GetResult {
    var ctx = GetContext{ .allocator = client.allocator };
    
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
            var context: *GetContext = @ptrCast(@alignCast(cookie));
            
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
            
            const value_copy = context.allocator.dupe(u8, value_ptr[0..value_len]) catch {
                context.err = error.OutOfMemory;
                context.done = true;
                return;
            };
            
            context.result = GetResult{
                .value = value_copy,
                .cas = cas,
                .flags = flags,
                .allocator = context.allocator,
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

/// Get from replica
pub fn getFromReplica(client: *Client, key: []const u8, mode: types.ReplicaMode) Error!GetResult {
    var ctx = GetContext{ .allocator = client.allocator };
    
    var cmd: ?*c.lcb_CMDGETREPLICA = null;
    _ = c.lcb_cmdgetreplica_create(&cmd, switch (mode) {
        .any => c.LCB_REPLICA_MODE_ANY,
        .all => c.LCB_REPLICA_MODE_ALL,
        .index => c.LCB_REPLICA_MODE_IDX0,
    });
    defer _ = c.lcb_cmdgetreplica_destroy(cmd);
    
    _ = c.lcb_cmdgetreplica_key(cmd, key.ptr, key.len);
    
    const callback = struct {
        fn cb(instance: ?*c.lcb_INSTANCE, cbtype: c.lcb_CALLBACK_TYPE, resp: ?*const c.lcb_RESPGETREPLICA) callconv(.C) void {
            _ = instance;
            _ = cbtype;
            
            var cookie: ?*anyopaque = null;
            _ = c.lcb_respgetreplica_cookie(resp, &cookie);
            var context: *GetContext = @ptrCast(@alignCast(cookie));
            
            const rc = c.lcb_respgetreplica_status(resp);
            if (rc != c.LCB_SUCCESS) {
                fromStatusCode(rc) catch |err| { context.err = err; };
                context.done = true;
                return;
            }
            
            var value_ptr: [*c]const u8 = undefined;
            var value_len: usize = undefined;
            _ = c.lcb_respgetreplica_value(resp, &value_ptr, &value_len);
            
            var cas: u64 = undefined;
            _ = c.lcb_respgetreplica_cas(resp, &cas);
            
            var flags: u32 = undefined;
            _ = c.lcb_respgetreplica_flags(resp, &flags);
            
            const value_copy = context.allocator.dupe(u8, value_ptr[0..value_len]) catch {
                context.err = error.OutOfMemory;
                context.done = true;
                return;
            };
            
            context.result = GetResult{
                .value = value_copy,
                .cas = cas,
                .flags = flags,
                .allocator = context.allocator,
            };
            context.done = true;
        }
    }.cb;
    
    _ = c.lcb_install_callback(client.instance, c.LCB_CALLBACK_GETREPLICA, @ptrCast(&callback));
    
    var rc = c.lcb_getreplica(client.instance, &ctx, cmd);
    try fromStatusCode(rc);
    
    rc = c.lcb_wait(client.instance, 0);
    try fromStatusCode(rc);
    
    if (ctx.err) |err| return err;
    return ctx.result orelse error.Unknown;
}

/// Store operation (upsert/insert/replace)
pub fn store(client: *Client, key: []const u8, value: []const u8, operation: types.StoreOperation, options: StoreOptions) Error!MutationResult {
    var ctx = MutationContext{};
    
    var cmd: ?*c.lcb_CMDSTORE = null;
    _ = c.lcb_cmdstore_create(&cmd, @intFromEnum(operation));
    defer _ = c.lcb_cmdstore_destroy(cmd);
    
    _ = c.lcb_cmdstore_key(cmd, key.ptr, key.len);
    _ = c.lcb_cmdstore_value(cmd, value.ptr, value.len);
    
    if (options.cas > 0) {
        _ = c.lcb_cmdstore_cas(cmd, options.cas);
    }
    
    if (options.expiry > 0) {
        _ = c.lcb_cmdstore_expiry(cmd, options.expiry);
    }
    
    if (options.flags > 0) {
        _ = c.lcb_cmdstore_flags(cmd, options.flags);
    }
    
    if (options.durability.level != .none) {
        _ = c.lcb_cmdstore_durability(cmd, @intFromEnum(options.durability.level));
    }
    
    const callback = struct {
        fn cb(instance: ?*c.lcb_INSTANCE, cbtype: c.lcb_CALLBACK_TYPE, resp: ?*const c.lcb_RESPSTORE) callconv(.C) void {
            _ = instance;
            _ = cbtype;
            
            var cookie: ?*anyopaque = null;
            _ = c.lcb_respstore_cookie(resp, &cookie);
            var context: *MutationContext = @ptrCast(@alignCast(cookie));
            
            const rc = c.lcb_respstore_status(resp);
            if (rc != c.LCB_SUCCESS) {
                fromStatusCode(rc) catch |err| { context.err = err; };
                context.done = true;
                return;
            }
            
            var cas: u64 = undefined;
            _ = c.lcb_respstore_cas(resp, &cas);
            
            context.result.cas = cas;
            context.done = true;
        }
    }.cb;
    
    _ = c.lcb_install_callback(client.instance, c.LCB_CALLBACK_STORE, @ptrCast(&callback));
    
    var rc = c.lcb_store(client.instance, &ctx, cmd);
    try fromStatusCode(rc);
    
    rc = c.lcb_wait(client.instance, 0);
    try fromStatusCode(rc);
    
    if (ctx.err) |err| return err;
    return ctx.result;
}

/// Remove operation
pub fn remove(client: *Client, key: []const u8, options: RemoveOptions) Error!MutationResult {
    var ctx = MutationContext{};
    
    var cmd: ?*c.lcb_CMDREMOVE = null;
    _ = c.lcb_cmdremove_create(&cmd);
    defer _ = c.lcb_cmdremove_destroy(cmd);
    
    _ = c.lcb_cmdremove_key(cmd, key.ptr, key.len);
    
    if (options.cas > 0) {
        _ = c.lcb_cmdremove_cas(cmd, options.cas);
    }
    
    if (options.durability.level != .none) {
        _ = c.lcb_cmdremove_durability(cmd, @intFromEnum(options.durability.level));
    }
    
    const callback = struct {
        fn cb(instance: ?*c.lcb_INSTANCE, cbtype: c.lcb_CALLBACK_TYPE, resp: ?*const c.lcb_RESPREMOVE) callconv(.C) void {
            _ = instance;
            _ = cbtype;
            
            var cookie: ?*anyopaque = null;
            _ = c.lcb_respremove_cookie(resp, &cookie);
            var context: *MutationContext = @ptrCast(@alignCast(cookie));
            
            const rc = c.lcb_respremove_status(resp);
            if (rc != c.LCB_SUCCESS) {
                fromStatusCode(rc) catch |err| { context.err = err; };
                context.done = true;
                return;
            }
            
            var cas: u64 = undefined;
            _ = c.lcb_respremove_cas(resp, &cas);
            
            context.result.cas = cas;
            context.done = true;
        }
    }.cb;
    
    _ = c.lcb_install_callback(client.instance, c.LCB_CALLBACK_REMOVE, @ptrCast(&callback));
    
    var rc = c.lcb_remove(client.instance, &ctx, cmd);
    try fromStatusCode(rc);
    
    rc = c.lcb_wait(client.instance, 0);
    try fromStatusCode(rc);
    
    if (ctx.err) |err| return err;
    return ctx.result;
}

/// Counter operation
pub fn counter(client: *Client, key: []const u8, delta: i64, options: CounterOptions) Error!CounterResult {
    var ctx = CounterContext{};
    
    var cmd: ?*c.lcb_CMDCOUNTER = null;
    _ = c.lcb_cmdcounter_create(&cmd);
    defer _ = c.lcb_cmdcounter_destroy(cmd);
    
    _ = c.lcb_cmdcounter_key(cmd, key.ptr, key.len);
    _ = c.lcb_cmdcounter_delta(cmd, delta);
    _ = c.lcb_cmdcounter_initial(cmd, options.initial);
    
    if (options.expiry > 0) {
        _ = c.lcb_cmdcounter_expiry(cmd, options.expiry);
    }
    
    if (options.durability.level != .none) {
        _ = c.lcb_cmdcounter_durability(cmd, @intFromEnum(options.durability.level));
    }
    
    const callback = struct {
        fn cb(instance: ?*c.lcb_INSTANCE, cbtype: c.lcb_CALLBACK_TYPE, resp: ?*const c.lcb_RESPCOUNTER) callconv(.C) void {
            _ = instance;
            _ = cbtype;
            
            var cookie: ?*anyopaque = null;
            _ = c.lcb_respcounter_cookie(resp, &cookie);
            var context: *CounterContext = @ptrCast(@alignCast(cookie));
            
            const rc = c.lcb_respcounter_status(resp);
            if (rc != c.LCB_SUCCESS) {
                fromStatusCode(rc) catch |err| { context.err = err; };
                context.done = true;
                return;
            }
            
            var cas: u64 = 0;
            _ = c.lcb_respcounter_cas(resp, &cas);
            
            var value: u64 = 0;
            _ = c.lcb_respcounter_value(resp, &value);
            
            context.result.cas = cas;
            context.result.value = value;
            context.done = true;
        }
    }.cb;
    
    _ = c.lcb_install_callback(client.instance, c.LCB_CALLBACK_COUNTER, @ptrCast(&callback));
    
    var rc = c.lcb_counter(client.instance, &ctx, cmd);
    try fromStatusCode(rc);
    
    rc = c.lcb_wait(client.instance, 0);
    try fromStatusCode(rc);
    
    if (ctx.err) |err| return err;
    return ctx.result;
}

/// Touch operation
pub fn touch(client: *Client, key: []const u8, expiry: u32) Error!MutationResult {
    var ctx = MutationContext{};
    
    var cmd: ?*c.lcb_CMDTOUCH = null;
    _ = c.lcb_cmdtouch_create(&cmd);
    defer _ = c.lcb_cmdtouch_destroy(cmd);
    
    _ = c.lcb_cmdtouch_key(cmd, key.ptr, key.len);
    _ = c.lcb_cmdtouch_expiry(cmd, expiry);
    
    const callback = struct {
        fn cb(instance: ?*c.lcb_INSTANCE, cbtype: c.lcb_CALLBACK_TYPE, resp: ?*const c.lcb_RESPTOUCH) callconv(.C) void {
            _ = instance;
            _ = cbtype;
            
            var cookie: ?*anyopaque = null;
            _ = c.lcb_resptouch_cookie(resp, &cookie);
            var context: *MutationContext = @ptrCast(@alignCast(cookie));
            
            const rc = c.lcb_resptouch_status(resp);
            if (rc != c.LCB_SUCCESS) {
                fromStatusCode(rc) catch |err| { context.err = err; };
                context.done = true;
                return;
            }
            
            var cas: u64 = undefined;
            _ = c.lcb_resptouch_cas(resp, &cas);
            
            context.result.cas = cas;
            context.done = true;
        }
    }.cb;
    
    _ = c.lcb_install_callback(client.instance, c.LCB_CALLBACK_TOUCH, @ptrCast(&callback));
    
    var rc = c.lcb_touch(client.instance, &ctx, cmd);
    try fromStatusCode(rc);
    
    rc = c.lcb_wait(client.instance, 0);
    try fromStatusCode(rc);
    
    if (ctx.err) |err| return err;
    return ctx.result;
}

/// Unlock operation
pub fn unlock(client: *Client, key: []const u8, cas: u64) Error!void {
    var ctx = MutationContext{};
    
    var cmd: ?*c.lcb_CMDUNLOCK = null;
    _ = c.lcb_cmdunlock_create(&cmd);
    defer _ = c.lcb_cmdunlock_destroy(cmd);
    
    _ = c.lcb_cmdunlock_key(cmd, key.ptr, key.len);
    _ = c.lcb_cmdunlock_cas(cmd, cas);
    
    const callback = struct {
        fn cb(instance: ?*c.lcb_INSTANCE, cbtype: c.lcb_CALLBACK_TYPE, resp: ?*const c.lcb_RESPUNLOCK) callconv(.C) void {
            _ = instance;
            _ = cbtype;
            
            var cookie: ?*anyopaque = null;
            _ = c.lcb_respunlock_cookie(resp, &cookie);
            var context: *MutationContext = @ptrCast(@alignCast(cookie));
            
            const rc = c.lcb_respunlock_status(resp);
            if (rc != c.LCB_SUCCESS) {
                fromStatusCode(rc) catch |err| { context.err = err; };
                context.done = true;
                return;
            }
            
            context.done = true;
        }
    }.cb;
    
    _ = c.lcb_install_callback(client.instance, c.LCB_CALLBACK_UNLOCK, @ptrCast(&callback));
    
    var rc = c.lcb_unlock(client.instance, &ctx, cmd);
    try fromStatusCode(rc);
    
    rc = c.lcb_wait(client.instance, 0);
    try fromStatusCode(rc);
    
    if (ctx.err) |err| return err;
}

/// Query operation (N1QL)
pub fn query(client: *Client, allocator: std.mem.Allocator, statement: []const u8, options: QueryOptions) Error!QueryResult {
    var ctx = QueryContext{
        .rows = std.ArrayList([]const u8).init(allocator),
        .allocator = allocator,
    };
    
    var cmd: ?*c.lcb_CMDQUERY = null;
    _ = c.lcb_cmdquery_create(&cmd);
    defer _ = c.lcb_cmdquery_destroy(cmd);
    
    _ = c.lcb_cmdquery_statement(cmd, statement.ptr, statement.len);
    _ = c.lcb_cmdquery_adhoc(cmd, if (options.adhoc) 1 else 0);
    
    const callback = struct {
        fn cb(instance: ?*c.lcb_INSTANCE, cbtype: c.lcb_CALLBACK_TYPE, resp: ?*const c.lcb_RESPQUERY) callconv(.C) void {
            _ = instance;
            _ = cbtype;
            
            var cookie: ?*anyopaque = null;
            _ = c.lcb_respquery_cookie(resp, &cookie);
            var context: *QueryContext = @ptrCast(@alignCast(cookie));
            
            const rc = c.lcb_respquery_status(resp);
            if (rc != c.LCB_SUCCESS) {
                fromStatusCode(rc) catch |err| { context.err = err; };
                context.done = true;
                return;
            }
            
            var row_ptr: [*c]const u8 = undefined;
            var row_len: usize = undefined;
            _ = c.lcb_respquery_row(resp, &row_ptr, &row_len);
            
            if (row_len > 0) {
                const row_copy = context.allocator.dupe(u8, row_ptr[0..row_len]) catch {
                    context.err = error.OutOfMemory;
                    context.done = true;
                    return;
                };
                context.rows.append(row_copy) catch {
                    context.allocator.free(row_copy);
                    context.err = error.OutOfMemory;
                    context.done = true;
                    return;
                };
            }
            
            if (c.lcb_respquery_is_final(resp) != 0) {
                context.done = true;
            }
        }
    }.cb;
    
    _ = c.lcb_install_callback(client.instance, c.LCB_CALLBACK_QUERY, @ptrCast(&callback));
    
    var rc = c.lcb_query(client.instance, &ctx, cmd);
    try fromStatusCode(rc);
    
    rc = c.lcb_wait(client.instance, 0);
    try fromStatusCode(rc);
    
    if (ctx.err) |err| {
        for (ctx.rows.items) |row| {
            allocator.free(row);
        }
        ctx.rows.deinit();
        return err;
    }
    
    return QueryResult{
        .rows = try ctx.rows.toOwnedSlice(),
        .meta = ctx.meta,
        .allocator = allocator,
    };
}

/// EXISTS operation - check if document exists without retrieving
pub fn exists(client: *Client, key: []const u8) Error!bool {
    var ctx = struct {
        exists: bool = false,
        err: ?Error = null,
        done: bool = false,
    }{};
    
    var cmd: ?*c.lcb_CMDEXISTS = null;
    _ = c.lcb_cmdexists_create(&cmd);
    defer _ = c.lcb_cmdexists_destroy(cmd);
    
    _ = c.lcb_cmdexists_key(cmd, key.ptr, key.len);
    
    const callback = struct {
        fn cb(instance: ?*c.lcb_INSTANCE, cbtype: c.lcb_CALLBACK_TYPE, resp: ?*const c.lcb_RESPEXISTS) callconv(.C) void {
            _ = instance;
            _ = cbtype;
            
            var cookie: ?*anyopaque = null;
            _ = c.lcb_respexists_cookie(resp, &cookie);
            const Context = @TypeOf(ctx);
            var context: *Context = @ptrCast(@alignCast(cookie));
            
            const rc = c.lcb_respexists_status(resp);
            
            // Determine if document exists based on status
            if (rc == c.LCB_ERR_DOCUMENT_NOT_FOUND) {
                context.exists = false;
            } else if (rc == c.LCB_SUCCESS) {
                // Check if document actually exists using is_found
                const found = c.lcb_respexists_is_found(resp);
                context.exists = (found != 0);
            } else {
                fromStatusCode(rc) catch |err| { context.err = err; };
            }
            context.done = true;
        }
    }.cb;
    
    _ = c.lcb_install_callback(client.instance, c.LCB_CALLBACK_EXISTS, @ptrCast(&callback));
    
    var rc = c.lcb_exists(client.instance, &ctx, cmd);
    try fromStatusCode(rc);
    
    rc = c.lcb_wait(client.instance, 0);
    try fromStatusCode(rc);
    
    if (ctx.err) |err| return err;
    return ctx.exists;
}

/// Subdocument lookup
pub fn lookupIn(client: *Client, allocator: std.mem.Allocator, key: []const u8, specs: []const SubdocSpec) Error!SubdocResult {
    _ = client;
    _ = key;
    _ = specs;
    // Subdocument API not available in base couchbase.h
    // Requires additional headers or different API approach
    _ = allocator;
    return error.NotSupported;
}

/// Subdocument mutation
pub fn mutateIn(client: *Client, allocator: std.mem.Allocator, key: []const u8, specs: []const SubdocSpec, options: SubdocOptions) Error!SubdocResult {
    _ = client;
    _ = key;
    _ = specs;
    _ = options;
    // Subdocument API not available in base couchbase.h
    // Requires additional headers or different API approach
    _ = allocator;
    return error.NotSupported;
}

/// Ping operation
pub fn ping(client: *Client, allocator: std.mem.Allocator) Error!PingResult {
    _ = allocator;
    _ = client;
    // Simplified stub - full implementation would use lcb_ping
    return error.NotSupported;
}

/// Diagnostics operation
pub fn diagnostics(client: *Client, allocator: std.mem.Allocator) Error!DiagnosticsResult {
    _ = allocator;
    _ = client;
    // Simplified stub - full implementation would use lcb_diag
    return error.NotSupported;
}
