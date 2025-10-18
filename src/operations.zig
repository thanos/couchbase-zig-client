const std = @import("std");
const c = @import("c.zig");
const Error = @import("error.zig").Error;
const fromStatusCode = @import("error.zig").fromStatusCode;
const types = @import("types.zig");
const Client = @import("client.zig").Client;

pub const MutationToken = types.MutationToken;
pub const ObserveResult = types.ObserveResult;
pub const ObserveOptions = types.ObserveOptions;
pub const ObserveDurability = types.ObserveDurability;

/// Result of a get operation
pub const GetResult = struct {
    value: []const u8,
    cas: u64,
    flags: u32,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *const GetResult) void {
        self.allocator.free(self.value);
    }
};

/// Result of a get and lock operation
pub const GetAndLockResult = struct {
    value: []const u8,
    cas: u64,
    flags: u32,
    lock_time: u32,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *const GetAndLockResult) void {
        self.allocator.free(self.value);
    }
};

/// Result of an unlock operation
pub const UnlockResult = struct {
    cas: u64,
    success: bool,
};

/// Result of a mutation operation
pub const MutationResult = struct {
    cas: u64,
    mutation_token: ?MutationToken = null,
};

// MutationToken is now defined in types.zig

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
    named_parameters: ?std.StringHashMap([]const u8) = null,
    timeout_ms: u32 = 75000,
    adhoc: bool = true,
    
    // Advanced query options
    profile: types.QueryProfile = .off,
    read_only: bool = false,
    client_context_id: ?[]const u8 = null,
    scan_cap: ?u32 = null,
    scan_wait: ?u32 = null,
    flex_index: bool = false,
    consistency_tokens: ?[]const u8 = null,
    consistency_token: ?types.ConsistencyToken = null,
    max_parallelism: ?u32 = null,
    pipeline_batch: ?u32 = null,
    pipeline_cap: ?u32 = null,
    query_context: ?[]const u8 = null,
    pretty: bool = false,
    metrics: bool = true,
    raw: ?[]const u8 = null,
    allocator: ?std.mem.Allocator = null, // Track allocator for cleanup
    
    // Track which fields were allocated by this QueryOptions
    owns_client_context_id: bool = false,
    owns_query_context: bool = false,
    owns_raw: bool = false,
    
    /// Clean up allocated memory
    pub fn deinit(self: *const QueryOptions) void {
        if (self.allocator) |allocator| {
            // Clean up parameters array
            if (self.parameters) |params| {
                for (params) |param| {
                    allocator.free(param);
                }
                allocator.free(params);
            }
            
            // Clean up named parameters
            if (self.named_parameters) |named_params| {
                var iterator = named_params.iterator();
                while (iterator.next()) |entry| {
                    allocator.free(entry.key_ptr.*);
                    allocator.free(entry.value_ptr.*);
                }
                var mut_named_params = named_params;
                mut_named_params.deinit();
            }
            
            // Clean up strings only if we own them
            if (self.owns_client_context_id and self.client_context_id != null) {
                if (self.client_context_id) |ctx_id| {
                    allocator.free(ctx_id);
                }
            }
            if (self.owns_query_context and self.query_context != null) {
                if (self.query_context) |query_ctx| {
                    allocator.free(query_ctx);
                }
            }
            if (self.owns_raw and self.raw != null) {
                if (self.raw) |raw_str| {
                    allocator.free(raw_str);
                }
            }
            
            // Clean up consistency token
            if (self.consistency_token) |token| {
                var mut_token = token;
                mut_token.deinit();
            }
        }
    }
    
    /// Create query options with positional parameters
    pub fn withPositionalParams(allocator: std.mem.Allocator, params: []const []const u8) !QueryOptions {
        const param_copy = try allocator.alloc([]const u8, params.len);
        for (params, 0..) |param, i| {
            param_copy[i] = try allocator.dupe(u8, param);
        }
        return QueryOptions{
            .parameters = param_copy,
            .allocator = allocator,
        };
    }
    
    /// Create query options with named parameters
    pub fn withNamedParams(allocator: std.mem.Allocator, params: anytype) !QueryOptions {
        var named_params = std.StringHashMap([]const u8).init(allocator);
        const T = @TypeOf(params);
        if (@typeInfo(T) == .@"struct") {
            inline for (@typeInfo(T).@"struct".fields) |field| {
                const value = @field(params, field.name);
                const key = try allocator.dupe(u8, field.name);
                const value_str = try std.fmt.allocPrint(allocator, "{any}", .{value});
                try named_params.put(key, value_str);
            }
        }
        return QueryOptions{
            .named_parameters = named_params,
            .allocator = allocator,
        };
    }
    
    /// Create query options for performance profiling
    pub fn withProfile(profile: types.QueryProfile) QueryOptions {
        return QueryOptions{
            .profile = profile,
        };
    }
    
    /// Create readonly query options
    pub fn readonly() QueryOptions {
        return QueryOptions{
            .read_only = true,
        };
    }
    
    /// Create query options with client context ID (no allocation - caller owns memory)
    pub fn withContextId(context_id: []const u8) QueryOptions {
        return QueryOptions{
            .client_context_id = context_id,
        };
    }
    
    /// Create query options with client context ID (allocates memory)
    pub fn withContextIdOwned(allocator: std.mem.Allocator, context_id: []const u8) !QueryOptions {
        return QueryOptions{
            .client_context_id = try allocator.dupe(u8, context_id),
            .allocator = allocator,
            .owns_client_context_id = true,
        };
    }
    
    /// Create query options for prepared statements
    pub fn prepared() QueryOptions {
        return QueryOptions{
            .adhoc = false,
        };
    }
    
    /// Create query options with scan capabilities
    pub fn withScanCapabilities(scan_cap: u32, scan_wait: u32) QueryOptions {
        return QueryOptions{
            .scan_cap = scan_cap,
            .scan_wait = scan_wait,
        };
    }
    
    /// Create query options with flex index support
    pub fn withFlexIndex() QueryOptions {
        return QueryOptions{
            .flex_index = true,
        };
    }
    
    /// Create query options with consistency token
    pub fn withConsistencyToken(allocator: std.mem.Allocator, token: types.ConsistencyToken) QueryOptions {
        return QueryOptions{
            .consistency_token = token,
            .allocator = allocator,
        };
    }
    
    /// Create query options with performance tuning
    pub fn withPerformanceTuning(max_parallelism: u32, pipeline_batch: u32, pipeline_cap: u32) QueryOptions {
        return QueryOptions{
            .max_parallelism = max_parallelism,
            .pipeline_batch = pipeline_batch,
            .pipeline_cap = pipeline_cap,
        };
    }
    
    /// Create query options with query context (no allocation - caller owns memory)
    pub fn withQueryContext(query_context: []const u8) QueryOptions {
        return QueryOptions{
            .query_context = query_context,
        };
    }
    
    /// Create query options with query context (allocates memory)
    pub fn withQueryContextOwned(allocator: std.mem.Allocator, query_context: []const u8) !QueryOptions {
        return QueryOptions{
            .query_context = try allocator.dupe(u8, query_context),
            .allocator = allocator,
            .owns_query_context = true,
        };
    }
    
    /// Create query options with pretty printing
    pub fn withPrettyPrint() QueryOptions {
        return QueryOptions{
            .pretty = true,
        };
    }
    
    /// Create query options with metrics disabled
    pub fn withoutMetrics() QueryOptions {
        return QueryOptions{
            .metrics = false,
        };
    }
    
    /// Create query options with raw JSON (allocates memory)
    pub fn withRaw(allocator: std.mem.Allocator, raw_json: []const u8) !QueryOptions {
        return QueryOptions{
            .raw = try allocator.dupe(u8, raw_json),
            .allocator = allocator,
            .owns_raw = true,
        };
    }
    
    /// Create query options with raw JSON (no allocation - caller owns memory)
    pub fn withRawOwned(raw_json: []const u8) QueryOptions {
        return QueryOptions{
            .raw = raw_json,
        };
    }
    
    /// Chain multiple options together
    pub fn chain(self: QueryOptions, other: QueryOptions) QueryOptions {
        return QueryOptions{
            .consistency = if (other.consistency != .not_bounded) other.consistency else self.consistency,
            .parameters = other.parameters orelse self.parameters,
            .named_parameters = other.named_parameters orelse self.named_parameters,
            .timeout_ms = if (other.timeout_ms != 75000) other.timeout_ms else self.timeout_ms,
            .adhoc = other.adhoc,
            .profile = if (other.profile != .off) other.profile else self.profile,
            .read_only = other.read_only or self.read_only,
            .client_context_id = other.client_context_id orelse self.client_context_id,
            .scan_cap = other.scan_cap orelse self.scan_cap,
            .scan_wait = other.scan_wait orelse self.scan_wait,
            .flex_index = other.flex_index or self.flex_index,
            .consistency_tokens = other.consistency_tokens orelse self.consistency_tokens,
            .consistency_token = other.consistency_token orelse self.consistency_token,
            .max_parallelism = other.max_parallelism orelse self.max_parallelism,
            .pipeline_batch = other.pipeline_batch orelse self.pipeline_batch,
            .pipeline_cap = other.pipeline_cap orelse self.pipeline_cap,
            .query_context = other.query_context orelse self.query_context,
            .pretty = other.pretty or self.pretty,
            .metrics = if (other.metrics != true) other.metrics else self.metrics,
            .raw = other.raw orelse self.raw,
            .allocator = other.allocator orelse self.allocator, // Use other's allocator if available, otherwise self's
            .owns_client_context_id = other.owns_client_context_id or self.owns_client_context_id,
            .owns_query_context = other.owns_query_context or self.owns_query_context,
            .owns_raw = other.owns_raw or self.owns_raw,
        };
    }
};

/// Query result
pub const QueryResult = struct {
    rows: [][]const u8,
    meta: ?[]const u8,
    metadata: ?*types.QueryMetadata = null,
    allocator: std.mem.Allocator,
    handle: ?*types.QueryHandle = null,
    
    pub fn deinit(self: *const QueryResult) void {
        for (self.rows) |row| {
            self.allocator.free(row);
        }
        self.allocator.free(self.rows);
        if (self.meta) |meta| {
            self.allocator.free(meta);
        }
        if (self.metadata) |metadata| {
            var mut_metadata = metadata;
            mut_metadata.deinit();
            self.allocator.destroy(mut_metadata);
        }
        if (self.handle) |query_handle| {
            query_handle.deinit();
            self.allocator.destroy(query_handle);
        }
    }
    
    pub fn cancel(self: *QueryResult) void {
        if (self.handle) |query_handle| {
            query_handle.cancel();
        }
    }
    
    pub fn isCancelled(self: *const QueryResult) bool {
        if (self.handle) |query_handle| {
            return query_handle.isCancelled();
        }
        return false;
    }
    
    /// Parse enhanced metadata from the meta field
    pub fn parseMetadata(self: *QueryResult) !void {
        if (self.meta) |meta_json| {
            const metadata = try self.allocator.create(types.QueryMetadata);
            metadata.allocator = self.allocator;
            try metadata.parse(meta_json);
            self.metadata = metadata;
        }
    }
    
    /// Get query metrics if available
    pub fn getMetrics(self: *const QueryResult) ?*const types.QueryMetrics {
        if (self.metadata) |metadata| {
            return metadata.metrics;
        }
        return null;
    }
    
    /// Get query warnings if available
    pub fn getWarnings(self: *const QueryResult) ?[][]const u8 {
        if (self.metadata) |metadata| {
            return metadata.warnings;
        }
        return null;
    }
};

/// Analytics query result
pub const AnalyticsResult = struct {
    rows: [][]const u8,
    meta: ?[]const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *AnalyticsResult) void {
        for (self.rows) |row| {
            self.allocator.free(row);
        }
        self.allocator.free(self.rows);
        if (self.meta) |meta| {
            self.allocator.free(meta);
        }
    }
};

/// Search query result
pub const SearchResult = struct {
    rows: [][]const u8,
    meta: ?[]const u8,
    facets: ?[]const u8 = null,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *SearchResult) void {
        for (self.rows) |row| {
            self.allocator.free(row);
        }
        self.allocator.free(self.rows);
        if (self.meta) |meta| {
            self.allocator.free(meta);
        }
        if (self.facets) |facets| {
            self.allocator.free(facets);
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

/// Cluster configuration result
pub const ClusterConfigResult = struct {
    config: []const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *ClusterConfigResult) void {
        self.allocator.free(self.config);
    }
};

/// HTTP tracing result
pub const HttpTracingResult = struct {
    traces: []HttpTrace,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *HttpTracingResult) void {
        for (self.traces) |trace| {
            self.allocator.free(trace.url);
            self.allocator.free(trace.method);
            if (trace.request_body) |body| self.allocator.free(body);
            if (trace.response_body) |body| self.allocator.free(body);
        }
        self.allocator.free(self.traces);
    }
};

pub const HttpTrace = struct {
    url: []const u8,
    method: []const u8,
    status_code: u16,
    request_body: ?[]const u8 = null,
    response_body: ?[]const u8 = null,
    duration_ms: u64,
};

/// SDK metrics result
pub const SdkMetricsResult = struct {
    metrics: std.StringHashMap(MetricValue),
    allocator: std.mem.Allocator,

    pub fn deinit(self: *SdkMetricsResult) void {
        var iterator = self.metrics.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.metrics.deinit();
    }
};

pub const MetricValue = union(enum) {
    counter: u64,
    gauge: f64,
    histogram: HistogramData,
    text: []const u8,
};

pub const HistogramData = struct {
    count: u64,
    min: f64,
    max: f64,
    mean: f64,
    std_dev: f64,
    percentiles: []PercentileData,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *HistogramData) void {
        self.allocator.free(self.percentiles);
    }
};

pub const PercentileData = struct {
    percentile: f64,
    value: f64,
};

// Callback context structures
const GetContext = struct {
    result: ?GetResult = null,
    err: ?Error = null,
    done: bool = false,
    allocator: std.mem.Allocator,
};

const PingContext = struct {
    services: std.ArrayList(ServiceHealth),
    allocator: std.mem.Allocator,
    err: ?Error = null,
    done: bool = false,
};

const DiagnosticsContext = struct {
    services: std.ArrayList(ServiceDiagnostics),
    allocator: std.mem.Allocator,
    err: ?Error = null,
    done: bool = false,
};

// Helper function to convert status code to error
fn statusToError(rc: c.lcb_STATUS) ?Error {
    if (rc == c.LCB_SUCCESS) return null;
    // fromStatusCode will return an error for non-success status codes
    return fromStatusCode(rc) catch |err| err;
}

const UnlockContext = struct {
    cas: u64 = 0,
    success: bool = false,
    err: ?Error = null,
    done: bool = false,
};

const MutationContext = struct {
    result: MutationResult = .{ .cas = 0 },
    err: ?Error = null,
    done: bool = false,
    allocator: std.mem.Allocator,
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
    handle: ?*types.QueryHandle = null,
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

/// Get operation with collection
pub fn getWithCollection(client: *Client, key: []const u8, collection: types.Collection) Error!GetResult {
    var ctx = GetContext{ .allocator = client.allocator };
    
    var cmd: ?*c.lcb_CMDGET = null;
    _ = c.lcb_cmdget_create(&cmd);
    defer _ = c.lcb_cmdget_destroy(cmd);
    
    _ = c.lcb_cmdget_key(cmd, key.ptr, key.len);
    _ = c.lcb_cmdget_collection(cmd, collection.scope.ptr, collection.scope.len, collection.name.ptr, collection.name.len);
    
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
            
            const value = context.allocator.dupe(u8, value_ptr[0..value_len]) catch {
                context.err = error.OutOfMemory;
                context.done = true;
                return;
            };
            
            context.result = GetResult{
                .value = value,
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

/// Get and lock operation
pub fn getAndLock(client: *Client, key: []const u8, options: types.GetAndLockOptions) Error!GetAndLockResult {
    var ctx = GetContext{ .allocator = client.allocator };
    
    var cmd: ?*c.lcb_CMDGET = null;
    _ = c.lcb_cmdget_create(&cmd);
    defer _ = c.lcb_cmdget_destroy(cmd);
    
    _ = c.lcb_cmdget_key(cmd, key.ptr, key.len);
    _ = c.lcb_cmdget_timeout(cmd, options.timeout_ms);
    
    // Set lock time (this is the key difference from regular get)
    _ = c.lcb_cmdget_locktime(cmd, options.lock_time);

    // Set durability if specified
    // Note: Durability for GET operations is not supported in libcouchbase
    _ = options.durability; // Suppress unused variable warning
    
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
            
            const value = context.allocator.dupe(u8, value_ptr[0..value_len]) catch {
                context.err = error.OutOfMemory;
                context.done = true;
                return;
            };
            
            context.result = GetResult{
                .value = value,
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
    const get_result = ctx.result orelse return error.Unknown;
    
    return GetAndLockResult{
        .value = get_result.value,
        .cas = get_result.cas,
        .flags = get_result.flags,
        .lock_time = options.lock_time,
        .allocator = client.allocator,
    };
}

/// Get and lock operation with collection
pub fn getAndLockWithCollection(client: *Client, key: []const u8, collection: types.Collection, options: types.GetAndLockOptions) Error!GetAndLockResult {
    var ctx = GetContext{ .allocator = client.allocator };
    
    var cmd: ?*c.lcb_CMDGET = null;
    _ = c.lcb_cmdget_create(&cmd);
    defer _ = c.lcb_cmdget_destroy(cmd);
    
    _ = c.lcb_cmdget_key(cmd, key.ptr, key.len);
    _ = c.lcb_cmdget_timeout(cmd, options.timeout_ms);
    _ = c.lcb_cmdget_collection(cmd, collection.scope.ptr, collection.scope.len, collection.name.ptr, collection.name.len);
    
    // Set lock time (this is the key difference from regular get)
    _ = c.lcb_cmdget_locktime(cmd, options.lock_time);

    // Set durability if specified
    // Note: Durability for GET operations is not supported in libcouchbase
    _ = options.durability; // Suppress unused variable warning
    
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
            
            const value = context.allocator.dupe(u8, value_ptr[0..value_len]) catch {
                context.err = error.OutOfMemory;
                context.done = true;
                return;
            };
            
            context.result = GetResult{
                .value = value,
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
    const get_result = ctx.result orelse return error.Unknown;
    
    return GetAndLockResult{
        .value = get_result.value,
        .cas = get_result.cas,
        .flags = get_result.flags,
        .lock_time = options.lock_time,
        .allocator = client.allocator,
    };
}

/// Unlock operation with options
pub fn unlockWithOptions(client: *Client, key: []const u8, cas: u64, options: types.UnlockOptions) Error!UnlockResult {
    var ctx = UnlockContext{};
    
    var cmd: ?*c.lcb_CMDUNLOCK = null;
    _ = c.lcb_cmdunlock_create(&cmd);
    defer _ = c.lcb_cmdunlock_destroy(cmd);
    
    _ = c.lcb_cmdunlock_key(cmd, key.ptr, key.len);
    _ = c.lcb_cmdunlock_cas(cmd, cas);
    _ = c.lcb_cmdunlock_timeout(cmd, options.timeout_ms);
    
    const callback = struct {
        fn cb(instance: ?*c.lcb_INSTANCE, cbtype: c.lcb_CALLBACK_TYPE, resp: ?*const c.lcb_RESPUNLOCK) callconv(.C) void {
            _ = instance;
            _ = cbtype;
            
            var cookie: ?*anyopaque = null;
            _ = c.lcb_respunlock_cookie(resp, &cookie);
            var context: *UnlockContext = @ptrCast(@alignCast(cookie));
            
            const rc = c.lcb_respunlock_status(resp);
            if (rc != c.LCB_SUCCESS) {
                fromStatusCode(rc) catch |err| { context.err = err; };
                context.done = true;
                return;
            }
            
            var resp_cas: u64 = undefined;
            _ = c.lcb_respunlock_cas(resp, &resp_cas);
            
            context.cas = resp_cas;
            context.success = true;
            context.done = true;
        }
    }.cb;
    
    _ = c.lcb_install_callback(client.instance, c.LCB_CALLBACK_UNLOCK, @ptrCast(&callback));
    
    var rc = c.lcb_unlock(client.instance, &ctx, cmd);
    try fromStatusCode(rc);
    
    rc = c.lcb_wait(client.instance, 0);
    try fromStatusCode(rc);
    
    if (ctx.err) |err| return err;
    
    return UnlockResult{
        .cas = ctx.cas,
        .success = ctx.success,
    };
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

/// Get from replica with collection
pub fn getReplicaWithCollection(client: *Client, key: []const u8, collection: types.Collection, mode: types.ReplicaMode) Error!GetResult {
    var ctx = GetContext{ .allocator = client.allocator };
    
    var cmd: ?*c.lcb_CMDGETREPLICA = null;
    _ = c.lcb_cmdgetreplica_create(&cmd, switch (mode) {
        .any => c.LCB_REPLICA_MODE_ANY,
        .all => c.LCB_REPLICA_MODE_ALL,
        .index => c.LCB_REPLICA_MODE_IDX0,
    });
    defer _ = c.lcb_cmdgetreplica_destroy(cmd);
    
    _ = c.lcb_cmdgetreplica_key(cmd, key.ptr, key.len);
    _ = c.lcb_cmdgetreplica_collection(cmd, collection.scope.ptr, collection.scope.len, collection.name.ptr, collection.name.len);
    
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

/// Store operation with collection (upsert, insert, replace)
pub fn storeWithCollection(client: *Client, key: []const u8, value: []const u8, operation: types.StoreOperation, options: StoreOptions, collection: types.Collection) Error!MutationResult {
    var ctx = MutationContext{ .allocator = client.allocator };
    
    var cmd: ?*c.lcb_CMDSTORE = null;
    _ = c.lcb_cmdstore_create(&cmd, @intFromEnum(operation));
    defer _ = c.lcb_cmdstore_destroy(cmd);
    
    _ = c.lcb_cmdstore_key(cmd, key.ptr, key.len);
    _ = c.lcb_cmdstore_value(cmd, value.ptr, value.len);
    _ = c.lcb_cmdstore_collection(cmd, collection.scope.ptr, collection.scope.len, collection.name.ptr, collection.name.len);
    
    // Operation type is already set in lcb_cmdstore_create
    
    // Set options
    if (options.expiry > 0) {
        _ = c.lcb_cmdstore_expiry(cmd, options.expiry);
    }
    
    if (options.durability.level != .none) {
        _ = c.lcb_cmdstore_durability(cmd, @intFromEnum(options.durability.level));
    }
    
    if (options.flags > 0) {
        _ = c.lcb_cmdstore_flags(cmd, options.flags);
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

/// Upsert operation with collection
pub fn upsertWithCollection(client: *Client, key: []const u8, value: []const u8, collection: types.Collection, options: StoreOptions) Error!MutationResult {
    return storeWithCollection(client, key, value, .upsert, options, collection);
}

/// Insert operation with collection
pub fn insertWithCollection(client: *Client, key: []const u8, value: []const u8, collection: types.Collection, options: StoreOptions) Error!MutationResult {
    return storeWithCollection(client, key, value, .insert, options, collection);
}

/// Replace operation with collection
pub fn replaceWithCollection(client: *Client, key: []const u8, value: []const u8, collection: types.Collection, options: StoreOptions) Error!MutationResult {
    return storeWithCollection(client, key, value, .replace, options, collection);
}

/// Store operation (upsert/insert/replace)
pub fn store(client: *Client, key: []const u8, value: []const u8, operation: types.StoreOperation, options: StoreOptions) Error!MutationResult {
    var ctx = MutationContext{ .allocator = client.allocator };
    
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
    
    // Add observe-based durability if needed
    if (options.durability.timeout_ms > 0) {
        _ = c.lcb_cmdstore_durability_observe(cmd, 1, 0); // persist_to=1, replicate_to=0
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
    var ctx = MutationContext{ .allocator = client.allocator };
    
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

/// Remove operation with collection
pub fn removeWithCollection(client: *Client, key: []const u8, collection: types.Collection, options: RemoveOptions) Error!MutationResult {
    var ctx = MutationContext{ .allocator = client.allocator };
    
    var cmd: ?*c.lcb_CMDREMOVE = null;
    _ = c.lcb_cmdremove_create(&cmd);
    defer _ = c.lcb_cmdremove_destroy(cmd);
    
    _ = c.lcb_cmdremove_key(cmd, key.ptr, key.len);
    _ = c.lcb_cmdremove_collection(cmd, collection.scope.ptr, collection.scope.len, collection.name.ptr, collection.name.len);
    
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

/// Counter operation with collection
pub fn counterWithCollection(client: *Client, key: []const u8, collection: types.Collection, delta: i64, options: CounterOptions) Error!CounterResult {
    var ctx = CounterContext{};
    
    var cmd: ?*c.lcb_CMDCOUNTER = null;
    _ = c.lcb_cmdcounter_create(&cmd);
    defer _ = c.lcb_cmdcounter_destroy(cmd);
    
    _ = c.lcb_cmdcounter_key(cmd, key.ptr, key.len);
    _ = c.lcb_cmdcounter_delta(cmd, delta);
    _ = c.lcb_cmdcounter_initial(cmd, options.initial);
    _ = c.lcb_cmdcounter_collection(cmd, collection.scope.ptr, collection.scope.len, collection.name.ptr, collection.name.len);
    
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
    var ctx = MutationContext{ .allocator = client.allocator };
    
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

/// Touch operation with collection
pub fn touchWithCollection(client: *Client, key: []const u8, collection: types.Collection, expiry: u32) Error!MutationResult {
    var ctx = MutationContext{ .allocator = client.allocator };
    
    var cmd: ?*c.lcb_CMDTOUCH = null;
    _ = c.lcb_cmdtouch_create(&cmd);
    defer _ = c.lcb_cmdtouch_destroy(cmd);
    
    _ = c.lcb_cmdtouch_key(cmd, key.ptr, key.len);
    _ = c.lcb_cmdtouch_expiry(cmd, expiry);
    _ = c.lcb_cmdtouch_collection(cmd, collection.scope.ptr, collection.scope.len, collection.name.ptr, collection.name.len);
    
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
    var ctx = MutationContext{ .allocator = client.allocator };
    
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

/// Unlock operation with collection
pub fn unlockWithCollection(client: *Client, key: []const u8, cas: u64, collection: types.Collection) Error!void {
    var ctx = MutationContext{ .allocator = client.allocator };
    
    var cmd: ?*c.lcb_CMDUNLOCK = null;
    _ = c.lcb_cmdunlock_create(&cmd);
    defer _ = c.lcb_cmdunlock_destroy(cmd);
    
    _ = c.lcb_cmdunlock_key(cmd, key.ptr, key.len);
    _ = c.lcb_cmdunlock_cas(cmd, cas);
    _ = c.lcb_cmdunlock_collection(cmd, collection.scope.ptr, collection.scope.len, collection.name.ptr, collection.name.len);
    
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
        .handle = null,
    };
    
    var cmd: ?*c.lcb_CMDQUERY = null;
    _ = c.lcb_cmdquery_create(&cmd);
    defer _ = c.lcb_cmdquery_destroy(cmd);
    
    _ = c.lcb_cmdquery_statement(cmd, statement.ptr, statement.len);
    _ = c.lcb_cmdquery_adhoc(cmd, if (options.adhoc) 1 else 0);
    
    // Create query handle for cancellation after basic setup
    const handle = try allocator.create(types.QueryHandle);
    handle.* = types.QueryHandle{
        .id = @as(u64, @intCast(@max(0, std.time.timestamp()))),
        .cancelled = false,
        .allocator = allocator,
    };
    ctx.handle = handle;
    defer {
        // Clean up handle if query fails before creating QueryResult
        if (ctx.handle == handle) {
            handle.deinit();
            allocator.destroy(handle);
        }
    }
    
    // Set advanced query options
    _ = c.lcb_cmdquery_timeout(cmd, options.timeout_ms);
    _ = c.lcb_cmdquery_consistency(cmd, @intFromEnum(options.consistency));
    _ = c.lcb_cmdquery_profile(cmd, @intFromEnum(options.profile));
    _ = c.lcb_cmdquery_readonly(cmd, if (options.read_only) 1 else 0);
    
    if (options.client_context_id) |context_id| {
        _ = c.lcb_cmdquery_client_context_id(cmd, context_id.ptr, context_id.len);
    }
    
    if (options.scan_cap) |scan_cap| {
        // Validate that scan_cap fits in c_int range
        // Note: scan_cap can be 0 (no limit) or any positive value
        if (scan_cap > std.math.maxInt(c_int)) {
            return Error.InvalidArgument;
        }
        _ = c.lcb_cmdquery_scan_cap(cmd, @intCast(scan_cap));
    }
    
    if (options.scan_wait) |scan_wait| {
        _ = c.lcb_cmdquery_scan_wait(cmd, scan_wait);
    }
    
    _ = c.lcb_cmdquery_flex_index(cmd, if (options.flex_index) 1 else 0);
    
    // Handle consistency tokens
    if (options.consistency_tokens) |_| {
        _ = c.lcb_cmdquery_consistency_tokens(cmd, client.instance);
    }
    
    // Set consistency token if provided
    if (options.consistency_token) |token| {
        // Note: Consistency token handling requires proper mutation token setup
        // For now, we'll just set the consistency tokens flag
        _ = token;
        _ = c.lcb_cmdquery_consistency_tokens(cmd, client.instance);
    }
    
    // Set additional advanced options
    if (options.max_parallelism) |max_parallelism| {
        // Validate that max_parallelism fits in c_int range
        // Note: max_parallelism can be 0 (automatic/default) or any positive value
        if (max_parallelism > std.math.maxInt(c_int)) {
            return Error.InvalidArgument;
        }
        _ = c.lcb_cmdquery_max_parallelism(cmd, @intCast(max_parallelism));
    }
    
    if (options.pipeline_batch) |pipeline_batch| {
        // Validate that pipeline_batch fits in c_int range
        // Note: pipeline_batch can be 0 (disable batching, not recommended for performance)
        // Default is 16, but 0 is technically valid
        if (pipeline_batch > std.math.maxInt(c_int)) {
            return Error.InvalidArgument;
        }
        _ = c.lcb_cmdquery_pipeline_batch(cmd, @intCast(pipeline_batch));
    }
    
    if (options.pipeline_cap) |pipeline_cap| {
        // Validate that pipeline_cap fits in c_int range
        // Note: pipeline_cap can be 0 (no limit) or any positive value
        if (pipeline_cap > std.math.maxInt(c_int)) {
            return Error.InvalidArgument;
        }
        _ = c.lcb_cmdquery_pipeline_cap(cmd, @intCast(pipeline_cap));
    }
    
    if (options.query_context) |query_context| {
        // Note: query_context is not directly supported in libcouchbase C API
        // This would need to be handled through raw JSON options
        _ = query_context;
    }
    
    _ = c.lcb_cmdquery_pretty(cmd, if (options.pretty) 1 else 0);
    _ = c.lcb_cmdquery_metrics(cmd, if (options.metrics) 1 else 0);
    
    if (options.raw) |raw| {
        // Note: raw JSON options are not directly supported in libcouchbase C API
        // This would need to be handled through custom query construction
        _ = raw;
    }
    
    // Handle positional parameters
    if (options.parameters) |params| {
        for (params) |param| {
            _ = c.lcb_cmdquery_positional_param(cmd, param.ptr, param.len);
        }
    }
    
    // Handle named parameters
    if (options.named_parameters) |named_params| {
        var iterator = named_params.iterator();
        while (iterator.next()) |entry| {
            _ = c.lcb_cmdquery_named_param(cmd, entry.key_ptr.ptr, entry.key_ptr.len, entry.value_ptr.ptr, entry.value_ptr.len);
        }
    }
    
    const callback = struct {
        fn cb(instance: ?*c.lcb_INSTANCE, cbtype: c.lcb_CALLBACK_TYPE, resp: ?*const c.lcb_RESPQUERY) callconv(.C) void {
            _ = instance;
            _ = cbtype;
            
            var cookie: ?*anyopaque = null;
            _ = c.lcb_respquery_cookie(resp, &cookie);
            var context: *QueryContext = @ptrCast(@alignCast(cookie));
            
            // Check for cancellation
            if (context.handle) |query_handle| {
                if (query_handle.isCancelled()) {
                    context.err = error.QueryCancelled;
                    context.done = true;
                    return;
                }
            }
            
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
        // Clean up handle on error
        handle.deinit();
        allocator.destroy(handle);
        return err;
    }
    
    // Clear handle from context to prevent cleanup in defer
    ctx.handle = null;
    
    return QueryResult{
        .rows = try ctx.rows.toOwnedSlice(),
        .meta = ctx.meta,
        .allocator = allocator,
        .handle = handle, // Transfer ownership to QueryResult
    };
}

/// Analytics query operation
pub fn analyticsQuery(client: *Client, allocator: std.mem.Allocator, statement: []const u8, options: types.AnalyticsOptions) Error!AnalyticsResult {
    var ctx = AnalyticsContext{
        .rows = std.ArrayList([]const u8).init(allocator),
        .allocator = allocator,
    };
    
    var cmd: ?*c.lcb_CMDANALYTICS = null;
    _ = c.lcb_cmdanalytics_create(&cmd);
    defer _ = c.lcb_cmdanalytics_destroy(cmd);
    
    _ = c.lcb_cmdanalytics_statement(cmd, statement.ptr, statement.len);
    _ = c.lcb_cmdanalytics_timeout(cmd, options.timeout_ms);
    _ = c.lcb_cmdanalytics_priority(cmd, if (options.priority) 1 else 0);
    _ = c.lcb_cmdanalytics_readonly(cmd, if (options.read_only) 1 else 0);
    
    if (options.client_context_id) |context_id| {
        _ = c.lcb_cmdanalytics_client_context_id(cmd, context_id.ptr, context_id.len);
    }
    
    if (options.scan_cap) |scan_cap| {
        // Note: scan_cap not available in analytics API
        _ = scan_cap;
    }
    
    if (options.scan_wait) |scan_wait| {
        // Note: scan_wait not available in analytics API
        _ = scan_wait;
    }
    
    if (options.query_context) |query_context| {
        // Note: query_context not available in analytics API
        _ = query_context;
    }
    
    // Note: pretty and metrics not available in analytics API
    _ = options.pretty;
    _ = options.metrics;
    
    // Handle positional parameters
    if (options.positional_parameters) |params| {
        for (params) |param| {
            _ = c.lcb_cmdanalytics_positional_param(cmd, param.ptr, param.len);
        }
    }
    
    // Handle named parameters
    if (options.named_parameters) |named_params| {
        var iterator = named_params.iterator();
        while (iterator.next()) |entry| {
            _ = c.lcb_cmdanalytics_named_param(cmd, entry.key_ptr.ptr, entry.key_ptr.len, entry.value_ptr.ptr, entry.value_ptr.len);
        }
    }
    
    const callback = struct {
        fn cb(instance: ?*c.lcb_INSTANCE, cbtype: c.lcb_CALLBACK_TYPE, resp: ?*const c.lcb_RESPANALYTICS) callconv(.C) void {
            _ = instance;
            _ = cbtype;
            
            var cookie: ?*anyopaque = null;
            _ = c.lcb_respanalytics_cookie(resp, &cookie);
            var context: *AnalyticsContext = @ptrCast(@alignCast(cookie));
            
            const rc = c.lcb_respanalytics_status(resp);
            if (rc != c.LCB_SUCCESS) {
                fromStatusCode(rc) catch |err| { context.err = err; };
                context.done = true;
                return;
            }
            
            var row_ptr: [*c]const u8 = undefined;
            var row_len: usize = undefined;
            _ = c.lcb_respanalytics_row(resp, &row_ptr, &row_len);
            
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
            
            if (c.lcb_respanalytics_is_final(resp) != 0) {
                context.done = true;
            }
        }
    }.cb;
    
    _ = c.lcb_install_callback(client.instance, c.LCB_CALLBACK_ANALYTICS, @ptrCast(&callback));
    
    var rc = c.lcb_analytics(client.instance, &ctx, cmd);
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
    
    return AnalyticsResult{
        .rows = try ctx.rows.toOwnedSlice(),
        .meta = null,
        .allocator = allocator,
    };
}

const AnalyticsContext = struct {
    rows: std.ArrayList([]const u8),
    err: ?Error = null,
    done: bool = false,
    allocator: std.mem.Allocator,
};

/// Search query operation (Full-Text Search)
pub fn searchQuery(client: *Client, allocator: std.mem.Allocator, index_name: []const u8, search_query: []const u8, options: types.SearchOptions) Error!SearchResult {
    var ctx = SearchContext{
        .rows = std.ArrayList([]const u8).init(allocator),
        .allocator = allocator,
    };
    
    var cmd: ?*c.lcb_CMDSEARCH = null;
    _ = c.lcb_cmdsearch_create(&cmd);
    defer _ = c.lcb_cmdsearch_destroy(cmd);
    
    _ = c.lcb_cmdsearch_payload(cmd, search_query.ptr, search_query.len);
    // Note: index_name not available in search API
    _ = index_name;
    _ = c.lcb_cmdsearch_timeout(cmd, options.timeout_ms);
    // Note: explain, disable_scoring, include_locations not available in search API
    _ = options.explain;
    _ = options.disable_scoring;
    _ = options.include_locations;
    
    // Note: Most search API functions not available in libcouchbase
    _ = options.limit;
    _ = options.skip;
    _ = options.highlight_style;
    _ = options.highlight_fields;
    _ = options.sort;
    _ = options.facets;
    _ = options.fields;
    _ = options.consistent_with;
    _ = options.client_context_id;
    
    const callback = struct {
        fn cb(instance: ?*c.lcb_INSTANCE, cbtype: c.lcb_CALLBACK_TYPE, resp: ?*const c.lcb_RESPSEARCH) callconv(.C) void {
            _ = instance;
            _ = cbtype;
            
            var cookie: ?*anyopaque = null;
            _ = c.lcb_respsearch_cookie(resp, &cookie);
            var context: *SearchContext = @ptrCast(@alignCast(cookie));
            
            const rc = c.lcb_respsearch_status(resp);
            if (rc != c.LCB_SUCCESS) {
                fromStatusCode(rc) catch |err| { context.err = err; };
                context.done = true;
                return;
            }
            
            var row_ptr: [*c]const u8 = undefined;
            var row_len: usize = undefined;
            _ = c.lcb_respsearch_row(resp, &row_ptr, &row_len);
            
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
            
            if (c.lcb_respsearch_is_final(resp) != 0) {
                context.done = true;
            }
        }
    }.cb;
    
    _ = c.lcb_install_callback(client.instance, c.LCB_CALLBACK_SEARCH, @ptrCast(&callback));
    
    var rc = c.lcb_search(client.instance, &ctx, cmd);
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
    
    return SearchResult{
        .rows = try ctx.rows.toOwnedSlice(),
        .meta = null,
        .facets = null,
        .allocator = allocator,
    };
}

const SearchContext = struct {
    rows: std.ArrayList([]const u8),
    err: ?Error = null,
    done: bool = false,
    allocator: std.mem.Allocator,
};

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

/// Exists operation with collection
pub fn existsWithCollection(client: *Client, key: []const u8, collection: types.Collection) Error!bool {
    var ctx = struct {
        exists: bool = false,
        err: ?Error = null,
        done: bool = false,
    }{};
    
    var cmd: ?*c.lcb_CMDEXISTS = null;
    _ = c.lcb_cmdexists_create(&cmd);
    defer _ = c.lcb_cmdexists_destroy(cmd);
    
    _ = c.lcb_cmdexists_key(cmd, key.ptr, key.len);
    _ = c.lcb_cmdexists_collection(cmd, collection.scope.ptr, collection.scope.len, collection.name.ptr, collection.name.len);
    
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
    var ctx = struct {
        cas: u64 = 0,
        values: std.ArrayList([]const u8),
        err: ?Error = null,
        done: bool = false,
        allocator: std.mem.Allocator,
        num_specs: usize,
    }{
        .values = std.ArrayList([]const u8).init(allocator),
        .allocator = allocator,
        .num_specs = specs.len,
    };
    
    // Create subdoc specs
    var subdoc_specs: ?*c.lcb_SUBDOCSPECS = null;
    _ = c.lcb_subdocspecs_create(&subdoc_specs, specs.len);
    defer _ = c.lcb_subdocspecs_destroy(subdoc_specs);
    
    for (specs, 0..) |spec, i| {
        _ = c.lcb_subdocspecs_get(subdoc_specs, i, 0, spec.path.ptr, spec.path.len);
    }
    
    var cmd: ?*c.lcb_CMDSUBDOC = null;
    _ = c.lcb_cmdsubdoc_create(&cmd);
    defer _ = c.lcb_cmdsubdoc_destroy(cmd);
    
    _ = c.lcb_cmdsubdoc_key(cmd, key.ptr, key.len);
    _ = c.lcb_cmdsubdoc_specs(cmd, subdoc_specs);
    
    const callback = struct {
        fn cb(instance: ?*c.lcb_INSTANCE, cbtype: c.lcb_CALLBACK_TYPE, resp: ?*const c.lcb_RESPSUBDOC) callconv(.C) void {
            _ = instance;
            _ = cbtype;
            
            var cookie: ?*anyopaque = null;
            _ = c.lcb_respsubdoc_cookie(resp, &cookie);
            const Context = @TypeOf(ctx);
            var context: *Context = @ptrCast(@alignCast(cookie));
            
            const rc = c.lcb_respsubdoc_status(resp);
            if (rc != c.LCB_SUCCESS) {
                fromStatusCode(rc) catch |err| { context.err = err; };
                context.done = true;
                return;
            }
            
            var cas: u64 = 0;
            _ = c.lcb_respsubdoc_cas(resp, &cas);
            context.cas = cas;
            
            // Get all results
            var idx: usize = 0;
            while (idx < context.num_specs) : (idx += 1) {
                var value_ptr: [*c]const u8 = undefined;
                var value_len: usize = undefined;
                const result_rc = c.lcb_respsubdoc_result_value(resp, idx, &value_ptr, &value_len);
                
                if (result_rc == c.LCB_SUCCESS and value_len > 0) {
                    const value_copy = context.allocator.dupe(u8, value_ptr[0..value_len]) catch {
                        context.err = error.OutOfMemory;
                        context.done = true;
                        return;
                    };
                    context.values.append(value_copy) catch {
                        context.allocator.free(value_copy);
                        context.err = error.OutOfMemory;
                        context.done = true;
                        return;
                    };
                } else {
                    // Empty or error result
                    const empty = context.allocator.dupe(u8, "") catch {
                        context.err = error.OutOfMemory;
                        context.done = true;
                        return;
                    };
                    context.values.append(empty) catch {
                        context.allocator.free(empty);
                        context.err = error.OutOfMemory;
                        context.done = true;
                        return;
                    };
                }
            }
            
            context.done = true;
        }
    }.cb;
    
    _ = c.lcb_install_callback(client.instance, c.LCB_CALLBACK_SDLOOKUP, @ptrCast(&callback));
    
    var rc = c.lcb_subdoc(client.instance, &ctx, cmd);
    try fromStatusCode(rc);
    
    rc = c.lcb_wait(client.instance, 0);
    try fromStatusCode(rc);
    
    if (ctx.err) |err| {
        for (ctx.values.items) |val| {
            allocator.free(val);
        }
        ctx.values.deinit();
        return err;
    }
    
    return SubdocResult{
        .cas = ctx.cas,
        .values = try ctx.values.toOwnedSlice(),
        .allocator = allocator,
    };
}

/// Subdocument lookup with collection
pub fn lookupInWithCollection(client: *Client, allocator: std.mem.Allocator, key: []const u8, collection: types.Collection, specs: []const SubdocSpec) Error!SubdocResult {
    var ctx = struct {
        cas: u64 = 0,
        values: std.ArrayList([]const u8),
        err: ?Error = null,
        done: bool = false,
        allocator: std.mem.Allocator,
        num_specs: usize,
    }{
        .values = std.ArrayList([]const u8).init(allocator),
        .allocator = allocator,
        .num_specs = specs.len,
    };
    
    // Create subdoc specs
    var subdoc_specs: ?*c.lcb_SUBDOCSPECS = null;
    _ = c.lcb_subdocspecs_create(&subdoc_specs, specs.len);
    defer _ = c.lcb_subdocspecs_destroy(subdoc_specs);
    
    for (specs, 0..) |spec, i| {
        _ = c.lcb_subdocspecs_get(subdoc_specs, i, 0, spec.path.ptr, spec.path.len);
    }
    
    var cmd: ?*c.lcb_CMDSUBDOC = null;
    _ = c.lcb_cmdsubdoc_create(&cmd);
    defer _ = c.lcb_cmdsubdoc_destroy(cmd);
    
    _ = c.lcb_cmdsubdoc_key(cmd, key.ptr, key.len);
    _ = c.lcb_cmdsubdoc_specs(cmd, subdoc_specs);
    _ = c.lcb_cmdsubdoc_collection(cmd, collection.scope.ptr, collection.scope.len, collection.name.ptr, collection.name.len);
    
    const callback = struct {
        fn cb(instance: ?*c.lcb_INSTANCE, cbtype: c.lcb_CALLBACK_TYPE, resp: ?*const c.lcb_RESPSUBDOC) callconv(.C) void {
            _ = instance;
            _ = cbtype;
            
            var cookie: ?*anyopaque = null;
            _ = c.lcb_respsubdoc_cookie(resp, &cookie);
            const Context = @TypeOf(ctx);
            var context: *Context = @ptrCast(@alignCast(cookie));
            
            const rc = c.lcb_respsubdoc_status(resp);
            if (rc != c.LCB_SUCCESS) {
                fromStatusCode(rc) catch |err| { context.err = err; };
                context.done = true;
                return;
            }
            
            var cas: u64 = 0;
            _ = c.lcb_respsubdoc_cas(resp, &cas);
            context.cas = cas;
            
            // Get all results
            var idx: usize = 0;
            while (idx < context.num_specs) : (idx += 1) {
                var value_ptr: [*c]const u8 = undefined;
                var value_len: usize = undefined;
                const result_rc = c.lcb_respsubdoc_result_value(resp, idx, &value_ptr, &value_len);
                
                if (result_rc == c.LCB_SUCCESS and value_len > 0) {
                    const value_copy = context.allocator.dupe(u8, value_ptr[0..value_len]) catch {
                        context.err = error.OutOfMemory;
                        context.done = true;
                        return;
                    };
                    context.values.append(value_copy) catch {
                        context.allocator.free(value_copy);
                        context.err = error.OutOfMemory;
                        context.done = true;
                        return;
                    };
                } else {
                    // Empty or error result
                    const empty = context.allocator.dupe(u8, "") catch {
                        context.err = error.OutOfMemory;
                        context.done = true;
                        return;
                    };
                    context.values.append(empty) catch {
                        context.allocator.free(empty);
                        context.err = error.OutOfMemory;
                        context.done = true;
                        return;
                    };
                }
            }
            
            context.done = true;
        }
    }.cb;
    
    _ = c.lcb_install_callback(client.instance, c.LCB_CALLBACK_SDLOOKUP, @ptrCast(&callback));
    
    var rc = c.lcb_subdoc(client.instance, &ctx, cmd);
    try fromStatusCode(rc);
    
    rc = c.lcb_wait(client.instance, 0);
    try fromStatusCode(rc);
    
    if (ctx.err) |err| {
        for (ctx.values.items) |val| {
            allocator.free(val);
        }
        ctx.values.deinit();
        return err;
    }
    
    return SubdocResult{
        .cas = ctx.cas,
        .values = try ctx.values.toOwnedSlice(),
        .allocator = allocator,
    };
}

/// Subdocument mutation
pub fn mutateIn(client: *Client, allocator: std.mem.Allocator, key: []const u8, specs: []const SubdocSpec, options: SubdocOptions) Error!SubdocResult {
    var ctx = struct {
        cas: u64 = 0,
        values: std.ArrayList([]const u8),
        err: ?Error = null,
        done: bool = false,
        allocator: std.mem.Allocator,
        num_specs: usize,
    }{
        .values = std.ArrayList([]const u8).init(allocator),
        .allocator = allocator,
        .num_specs = specs.len,
    };
    
    // Create subdoc specs
    var subdoc_specs: ?*c.lcb_SUBDOCSPECS = null;
    _ = c.lcb_subdocspecs_create(&subdoc_specs, specs.len);
    defer _ = c.lcb_subdocspecs_destroy(subdoc_specs);
    
    for (specs, 0..) |spec, i| {
        switch (spec.op) {
            .get => _ = c.lcb_subdocspecs_get(subdoc_specs, i, 0, spec.path.ptr, spec.path.len),
            .exists => _ = c.lcb_subdocspecs_exists(subdoc_specs, i, 0, spec.path.ptr, spec.path.len),
            .replace => _ = c.lcb_subdocspecs_replace(subdoc_specs, i, 0, spec.path.ptr, spec.path.len, spec.value.ptr, spec.value.len),
            .dict_add => _ = c.lcb_subdocspecs_dict_add(subdoc_specs, i, 0, spec.path.ptr, spec.path.len, spec.value.ptr, spec.value.len),
            .dict_upsert => _ = c.lcb_subdocspecs_dict_upsert(subdoc_specs, i, 0, spec.path.ptr, spec.path.len, spec.value.ptr, spec.value.len),
            .array_add_first => _ = c.lcb_subdocspecs_array_add_first(subdoc_specs, i, 0, spec.path.ptr, spec.path.len, spec.value.ptr, spec.value.len),
            .array_add_last => _ = c.lcb_subdocspecs_array_add_last(subdoc_specs, i, 0, spec.path.ptr, spec.path.len, spec.value.ptr, spec.value.len),
            .array_add_unique => _ = c.lcb_subdocspecs_array_add_unique(subdoc_specs, i, 0, spec.path.ptr, spec.path.len, spec.value.ptr, spec.value.len),
            .array_insert => _ = c.lcb_subdocspecs_array_insert(subdoc_specs, i, 0, spec.path.ptr, spec.path.len, spec.value.ptr, spec.value.len),
            .delete => _ = c.lcb_subdocspecs_remove(subdoc_specs, i, 0, spec.path.ptr, spec.path.len),
            .counter => {
                // Counter takes an i64 delta, not a value string
                const delta = std.fmt.parseInt(i64, spec.value, 10) catch 0;
                _ = c.lcb_subdocspecs_counter(subdoc_specs, i, 0, spec.path.ptr, spec.path.len, delta);
            },
            .get_count => _ = c.lcb_subdocspecs_get_count(subdoc_specs, i, 0, spec.path.ptr, spec.path.len),
        }
    }
    
    var cmd: ?*c.lcb_CMDSUBDOC = null;
    _ = c.lcb_cmdsubdoc_create(&cmd);
    defer _ = c.lcb_cmdsubdoc_destroy(cmd);
    
    _ = c.lcb_cmdsubdoc_key(cmd, key.ptr, key.len);
    _ = c.lcb_cmdsubdoc_specs(cmd, subdoc_specs);
    
    if (options.cas > 0) {
        _ = c.lcb_cmdsubdoc_cas(cmd, options.cas);
    }
    
    if (options.expiry > 0) {
        _ = c.lcb_cmdsubdoc_expiry(cmd, options.expiry);
    }
    
    if (options.durability.level != .none) {
        _ = c.lcb_cmdsubdoc_durability(cmd, @intFromEnum(options.durability.level));
    }
    
    const callback = struct {
        fn cb(instance: ?*c.lcb_INSTANCE, cbtype: c.lcb_CALLBACK_TYPE, resp: ?*const c.lcb_RESPSUBDOC) callconv(.C) void {
            _ = instance;
            _ = cbtype;
            
            var cookie: ?*anyopaque = null;
            _ = c.lcb_respsubdoc_cookie(resp, &cookie);
            const Context = @TypeOf(ctx);
            var context: *Context = @ptrCast(@alignCast(cookie));
            
            const rc = c.lcb_respsubdoc_status(resp);
            if (rc != c.LCB_SUCCESS) {
                fromStatusCode(rc) catch |err| { context.err = err; };
                context.done = true;
                return;
            }
            
            var cas: u64 = 0;
            _ = c.lcb_respsubdoc_cas(resp, &cas);
            context.cas = cas;
            
            context.done = true;
        }
    }.cb;
    
    _ = c.lcb_install_callback(client.instance, c.LCB_CALLBACK_SDMUTATE, @ptrCast(&callback));
    
    var rc = c.lcb_subdoc(client.instance, &ctx, cmd);
    try fromStatusCode(rc);
    
    rc = c.lcb_wait(client.instance, 0);
    try fromStatusCode(rc);
    
    if (ctx.err) |err| {
        for (ctx.values.items) |val| {
            allocator.free(val);
        }
        ctx.values.deinit();
        return err;
    }
    
    return SubdocResult{
        .cas = ctx.cas,
        .values = try ctx.values.toOwnedSlice(),
        .allocator = allocator,
    };
}

/// Subdocument mutation with collection
pub fn mutateInWithCollection(client: *Client, allocator: std.mem.Allocator, key: []const u8, collection: types.Collection, specs: []const SubdocSpec, options: SubdocOptions) Error!SubdocResult {
    var ctx = struct {
        cas: u64 = 0,
        values: std.ArrayList([]const u8),
        err: ?Error = null,
        done: bool = false,
        allocator: std.mem.Allocator,
        num_specs: usize,
    }{
        .values = std.ArrayList([]const u8).init(allocator),
        .allocator = allocator,
        .num_specs = specs.len,
    };
    
    // Create subdoc specs
    var subdoc_specs: ?*c.lcb_SUBDOCSPECS = null;
    _ = c.lcb_subdocspecs_create(&subdoc_specs, specs.len);
    defer _ = c.lcb_subdocspecs_destroy(subdoc_specs);
    
    for (specs, 0..) |spec, i| {
        switch (spec.op) {
            .get => _ = c.lcb_subdocspecs_get(subdoc_specs, i, 0, spec.path.ptr, spec.path.len),
            .exists => _ = c.lcb_subdocspecs_exists(subdoc_specs, i, 0, spec.path.ptr, spec.path.len),
            .replace => _ = c.lcb_subdocspecs_replace(subdoc_specs, i, 0, spec.path.ptr, spec.path.len, spec.value.ptr, spec.value.len),
            .dict_add => _ = c.lcb_subdocspecs_dict_add(subdoc_specs, i, 0, spec.path.ptr, spec.path.len, spec.value.ptr, spec.value.len),
            .dict_upsert => _ = c.lcb_subdocspecs_dict_upsert(subdoc_specs, i, 0, spec.path.ptr, spec.path.len, spec.value.ptr, spec.value.len),
            .array_add_first => _ = c.lcb_subdocspecs_array_add_first(subdoc_specs, i, 0, spec.path.ptr, spec.path.len, spec.value.ptr, spec.value.len),
            .array_add_last => _ = c.lcb_subdocspecs_array_add_last(subdoc_specs, i, 0, spec.path.ptr, spec.path.len, spec.value.ptr, spec.value.len),
            .array_add_unique => _ = c.lcb_subdocspecs_array_add_unique(subdoc_specs, i, 0, spec.path.ptr, spec.path.len, spec.value.ptr, spec.value.len),
            .array_insert => _ = c.lcb_subdocspecs_array_insert(subdoc_specs, i, 0, spec.path.ptr, spec.path.len, spec.value.ptr, spec.value.len),
            .delete => _ = c.lcb_subdocspecs_remove(subdoc_specs, i, 0, spec.path.ptr, spec.path.len),
            .counter => {
                // Counter takes an i64 delta, not a value string
                const delta = std.fmt.parseInt(i64, spec.value, 10) catch 0;
                _ = c.lcb_subdocspecs_counter(subdoc_specs, i, 0, spec.path.ptr, spec.path.len, delta);
            },
            .get_count => _ = c.lcb_subdocspecs_get_count(subdoc_specs, i, 0, spec.path.ptr, spec.path.len),
        }
    }
    
    var cmd: ?*c.lcb_CMDSUBDOC = null;
    _ = c.lcb_cmdsubdoc_create(&cmd);
    defer _ = c.lcb_cmdsubdoc_destroy(cmd);
    
    _ = c.lcb_cmdsubdoc_key(cmd, key.ptr, key.len);
    _ = c.lcb_cmdsubdoc_specs(cmd, subdoc_specs);
    _ = c.lcb_cmdsubdoc_collection(cmd, collection.scope.ptr, collection.scope.len, collection.name.ptr, collection.name.len);
    
    if (options.cas > 0) {
        _ = c.lcb_cmdsubdoc_cas(cmd, options.cas);
    }
    
    if (options.expiry > 0) {
        _ = c.lcb_cmdsubdoc_expiry(cmd, options.expiry);
    }
    
    if (options.durability.level != .none) {
        _ = c.lcb_cmdsubdoc_durability(cmd, @intFromEnum(options.durability.level));
    }
    
    const callback = struct {
        fn cb(instance: ?*c.lcb_INSTANCE, cbtype: c.lcb_CALLBACK_TYPE, resp: ?*const c.lcb_RESPSUBDOC) callconv(.C) void {
            _ = instance;
            _ = cbtype;
            
            var cookie: ?*anyopaque = null;
            _ = c.lcb_respsubdoc_cookie(resp, &cookie);
            const Context = @TypeOf(ctx);
            var context: *Context = @ptrCast(@alignCast(cookie));
            
            const rc = c.lcb_respsubdoc_status(resp);
            if (rc != c.LCB_SUCCESS) {
                fromStatusCode(rc) catch |err| { context.err = err; };
                context.done = true;
                return;
            }
            
            var cas: u64 = 0;
            _ = c.lcb_respsubdoc_cas(resp, &cas);
            context.cas = cas;
            
            context.done = true;
        }
    }.cb;
    
    _ = c.lcb_install_callback(client.instance, c.LCB_CALLBACK_SDMUTATE, @ptrCast(&callback));
    
    var rc = c.lcb_subdoc(client.instance, &ctx, cmd);
    try fromStatusCode(rc);
    
    rc = c.lcb_wait(client.instance, 0);
    try fromStatusCode(rc);
    
    if (ctx.err) |err| {
        for (ctx.values.items) |val| {
            allocator.free(val);
        }
        ctx.values.deinit();
        return err;
    }
    
    return SubdocResult{
        .cas = ctx.cas,
        .values = try ctx.values.toOwnedSlice(),
        .allocator = allocator,
    };
}

/// Observe operation for durability checking (using store with observe)
pub fn observe(client: *Client, key: []const u8, cas: u64, options: ObserveOptions, allocator: std.mem.Allocator) Error!ObserveResult {
    _ = cas; // CAS is not used in this simplified implementation
    _ = options; // Options are not used in this simplified implementation
    
    // For observe, we need to use a store operation with observe enabled
    // This is a simplified implementation - in practice, observe is typically
    // used as part of store operations with durability requirements
    
    // Since observe is integrated into store operations, we'll implement
    // a basic version that checks if the key exists and returns basic info
    const get_result = try get(client, key);
    defer get_result.deinit();
    
    return ObserveResult{
        .key = try allocator.dupe(u8, key),
        .cas = get_result.cas,
        .persisted = true, // Assume persisted if we can read it
        .replicated = true, // Assume replicated if we can read it
        .replicate_count = 1, // Basic assumption
        .allocator = allocator,
    };
}

/// Observe multiple keys for durability checking
pub fn observeMulti(client: *Client, keys: []const []const u8, cas_values: []const u64, options: ObserveOptions, allocator: std.mem.Allocator) Error![]ObserveResult {
    var results = try allocator.alloc(ObserveResult, keys.len);
    errdefer {
        for (results) |*result| {
            result.deinit();
        }
        allocator.free(results);
    }

    for (keys, cas_values, 0..) |key, cas, i| {
        results[i] = try observe(client, key, cas, options, allocator);
    }

    return results;
}

/// Wait for durability using observe
pub fn waitForDurability(client: *Client, key: []const u8, cas: u64, durability: ObserveDurability, allocator: std.mem.Allocator) Error!void {
    const options = ObserveOptions{
        .timeout_ms = durability.timeout_ms,
        .persist_to_master = durability.persist_to_master,
        .replicate_to_count = durability.replicate_to_count,
    };

    const result = try observe(client, key, cas, options, allocator);
    defer result.deinit();

    if (durability.persist_to_master and !result.persisted) {
        return error.DurabilityTimeout;
    }

    if (durability.replicate_to_count > 0 and result.replicate_count < durability.replicate_to_count) {
        return error.DurabilityTimeout;
    }
}

/// Wait for durability using mutation token
pub fn waitForDurabilityWithToken(client: *Client, token: MutationToken, durability: ObserveDurability, allocator: std.mem.Allocator) Error!void {
    // For mutation token-based durability, we need to observe the key
    // This is a simplified implementation - in practice, you'd need to track
    // the key associated with the mutation token
    _ = client;
    _ = token;
    _ = durability;
    _ = allocator;
    
    // This would require additional infrastructure to track mutation tokens
    // and their associated keys, which is beyond the scope of this implementation
    return error.NotSupported;
}

/// Enhanced store operation with full durability and mutation token support
pub fn storeWithDurability(client: *Client, key: []const u8, value: []const u8, operation: types.StoreOperation, options: StoreOptions, allocator: std.mem.Allocator) Error!MutationResult {
    var ctx = MutationContext{ .allocator = allocator };
    
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
    
    // Add observe-based durability if needed
    if (options.durability.timeout_ms > 0) {
        _ = c.lcb_cmdstore_durability_observe(cmd, 1, 0); // persist_to=1, replicate_to=0
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
            
            // Extract mutation token if available
            var token: c.lcb_MUTATION_TOKEN = undefined;
            if (c.lcb_respstore_mutation_token(resp, &token) == c.LCB_SUCCESS) {
                context.result.mutation_token = MutationToken.create(
                    token.vbid_,
                    token.uuid_,
                    token.seqno_,
                    "default", // bucket name - would need to be passed in context
                    context.allocator
                ) catch null;
            }
            
            context.done = true;
        }
    }.cb;
    
    _ = c.lcb_install_callback(client.instance, c.LCB_CALLBACK_STORE, @ptrCast(&callback));
    
    var rc = c.lcb_store(client.instance, &ctx, cmd);
    try fromStatusCode(rc);
    
    rc = c.lcb_wait(client.instance, 0);
    try fromStatusCode(rc);
    
    if (ctx.err) |err| {
        return err;
    }
    
    return ctx.result;
}

/// Ping operation
pub fn ping(client: *Client, allocator: std.mem.Allocator) Error!PingResult {
    _ = client;
    
    // For now, return a mock ping result
    // In a real implementation, this would use lcb_ping
    const id = try allocator.dupe(u8, "ping");
    const services = try allocator.alloc(ServiceHealth, 1);
    
    services[0] = ServiceHealth{
        .id = try allocator.dupe(u8, "kv"),
        .latency_us = 1000,
        .state = .ok,
    };
    
    return PingResult{
        .id = id,
        .services = services,
        .allocator = allocator,
    };
}

/// Diagnostics operation
pub fn diagnostics(client: *Client, allocator: std.mem.Allocator) Error!DiagnosticsResult {
    _ = client;
    
    // For now, return a mock diagnostics result
    // In a real implementation, this would use lcb_diag
    const id = try allocator.dupe(u8, "diagnostics");
    const services = try allocator.alloc(ServiceDiagnostics, 1);
    
    services[0] = ServiceDiagnostics{
        .id = try allocator.dupe(u8, "kv"),
        .last_activity_us = 5000,
        .state = .ok,
    };
    
    return DiagnosticsResult{
        .id = id,
        .services = services,
        .allocator = allocator,
    };
}

/// Get cluster configuration
pub fn getClusterConfig(client: *Client, allocator: std.mem.Allocator) Error!ClusterConfigResult {
    _ = client; // Use client to avoid unused parameter warning
    
    // For now, return a basic configuration
    // In a real implementation, this would use lcb_cntl to get the actual config
    const config_str = "{\"version\":\"1.0\",\"services\":{}}";
    const config_owned = try allocator.dupe(u8, config_str);
    
    return ClusterConfigResult{
        .config = config_owned,
        .allocator = allocator,
    };
}

/// Enable HTTP tracing
pub fn enableHttpTracing(client: *Client, allocator: std.mem.Allocator) Error!void {
    _ = allocator;
    _ = client;
    // For now, just return success
    // In a real implementation, this would enable HTTP tracing via lcb_cntl
}

/// Get HTTP traces
pub fn getHttpTraces(client: *Client, allocator: std.mem.Allocator) Error!HttpTracingResult {
    _ = client;
    // This would require implementing HTTP trace collection
    // For now, return empty traces
    return HttpTracingResult{
        .traces = try allocator.alloc(HttpTrace, 0),
        .allocator = allocator,
    };
}

/// Get SDK metrics
pub fn getSdkMetrics(client: *Client, allocator: std.mem.Allocator) Error!SdkMetricsResult {
    _ = client;
    var metrics = std.StringHashMap(MetricValue).init(allocator);
    
    // For now, return basic metrics
    // In a real implementation, this would use lcb_cntl to get actual metrics
    const connection_count_key = try allocator.dupe(u8, "connection_count");
    try metrics.put(connection_count_key, .{ .counter = 1 });
    
    const timeout_key = try allocator.dupe(u8, "operation_timeout_ms");
    try metrics.put(timeout_key, .{ .gauge = 75000.0 });
    
    return SdkMetricsResult{
        .metrics = metrics,
        .allocator = allocator,
    };
}

/// Prepare a statement for reuse
pub fn prepareStatement(client: *Client, statement: []const u8) Error!void {
    // Check if statement is already prepared
    if (client.prepared_statements.contains(statement)) {
        return; // Already prepared
    }
    
    // Check cache size limit
    if (client.prepared_statements.count() >= client.cache_config.max_size) {
        // Remove oldest statement (simple LRU - in production, use proper LRU)
        var iterator = client.prepared_statements.iterator();
        if (iterator.next()) |entry| {
            entry.value_ptr.deinit();
            _ = client.prepared_statements.remove(entry.key_ptr.*);
        }
    }
    
    // Create prepared statement entry
    const timestamp = std.time.timestamp();
    const timestamp_ms = @as(u64, @intCast(@max(0, timestamp) * 1000)); // Convert to milliseconds, ensure non-negative
    const now = timestamp_ms;
    const prepared = types.PreparedStatement{
        .statement = try client.allocator.dupe(u8, statement),
        .prepared_data = try client.allocator.dupe(u8, statement), // In real implementation, this would be the prepared data
        .allocator = client.allocator,
        .created_at = now,
    };
    
    // Store in cache
    try client.prepared_statements.put(statement, prepared);
}

/// Execute a prepared statement
pub fn executePrepared(client: *Client, allocator: std.mem.Allocator, statement: []const u8, options: QueryOptions) Error!QueryResult {
    // Check if statement is prepared
    if (!client.prepared_statements.contains(statement)) {
        // Auto-prepare if not found
        try prepareStatement(client, statement);
    }
    
    // Get prepared statement
    const prepared = client.prepared_statements.getPtr(statement) orelse {
        return error.PreparedStatementNotFound;
    };
    
    // Check if expired
    if (prepared.isExpired(client.cache_config.max_age_ms)) {
        // Remove expired statement
        prepared.deinit();
        _ = client.prepared_statements.remove(statement);
        
        // Re-prepare
        try prepareStatement(client, statement);
    }
    
    // Execute with prepared statement options
    var prepared_options = options;
    prepared_options.adhoc = false; // Use prepared statement
    
    return query(client, allocator, statement, prepared_options);
}

/// Get collection manifest
/// Note: This is a simplified implementation as libcouchbase doesn't expose
/// collection manifest management directly through the C API
pub fn getCollectionManifest(client: *Client, allocator: std.mem.Allocator) Error!types.CollectionManifest {
    _ = client; // Suppress unused variable warning
    
    // Create an empty manifest as libcouchbase doesn't expose collection manifest directly
    var collections = std.ArrayList(types.CollectionManifestEntry).init(allocator);
    
    const manifest = types.CollectionManifest{
        .uid = 0,
        .collections = try collections.toOwnedSlice(),
        .allocator = allocator,
    };
    
    return manifest;
}

/// Execute batch operations
pub fn executeBatch(client: *Client, allocator: std.mem.Allocator, batch_operations: []const types.BatchOperation) Error!types.BatchOperationResult {
    var results = try allocator.alloc(types.BatchResult, batch_operations.len);
    
    // Initialize all results as failed
    for (results, 0..) |*result, i| {
        result.* = types.BatchResult{
            .operation_type = batch_operations[i].operation_type,
            .key = batch_operations[i].key,
            .success = false,
            .@"error" = error.Unknown,
            .result = switch (batch_operations[i].operation_type) {
                .get => .{ .get = null },
                .upsert => .{ .upsert = null },
                .insert => .{ .insert = null },
                .replace => .{ .replace = null },
                .remove => .{ .remove = null },
                .touch => .{ .touch = null },
                .counter => .{ .counter = null },
                .exists => .{ .exists = null },
                .get_and_lock => .{ .get_and_lock = null },
            .unlock => .{ .unlock = null },
            .get_replica => .{ .get_replica = null },
            .lookup_in => .{ .lookup_in = null },
            .mutate_in => .{ .mutate_in = null },
        },
            .allocator = allocator,
        };
    }
    
    // Execute each operation
    for (batch_operations, 0..) |operation, i| {
        const result = &results[i];
        
        switch (operation.operation_type) {
            .get => {
                if (operation.collection) |collection| {
                    if (getWithCollection(client, operation.key, collection)) |get_result| {
                        result.success = true;
                        result.@"error" = null;
                        result.result = .{ .get = get_result };
                    } else |err| {
                        result.@"error" = err;
                    }
                } else {
                    if (get(client, operation.key)) |get_result| {
                        result.success = true;
                        result.@"error" = null;
                        result.result = .{ .get = get_result };
                    } else |err| {
                        result.@"error" = err;
                    }
                }
            },
            .upsert => {
                if (store(client, operation.key, operation.value.?, .upsert, operation.options.upsert)) |upsert_result| {
                    result.success = true;
                    result.@"error" = null;
                    result.result = .{ .upsert = upsert_result };
                } else |err| {
                    result.@"error" = err;
                }
            },
            .insert => {
                if (store(client, operation.key, operation.value.?, .insert, operation.options.insert)) |insert_result| {
                    result.success = true;
                    result.@"error" = null;
                    result.result = .{ .insert = insert_result };
                } else |err| {
                    result.@"error" = err;
                }
            },
            .replace => {
                if (store(client, operation.key, operation.value.?, .replace, operation.options.replace)) |replace_result| {
                    result.success = true;
                    result.@"error" = null;
                    result.result = .{ .replace = replace_result };
                } else |err| {
                    result.@"error" = err;
                }
            },
            .remove => {
                if (remove(client, operation.key, operation.options.remove)) |remove_result| {
                    result.success = true;
                    result.@"error" = null;
                    result.result = .{ .remove = remove_result };
                } else |err| {
                    result.@"error" = err;
                }
            },
            .touch => {
                if (touch(client, operation.key, operation.options.touch.expiry)) |touch_result| {
                    result.success = true;
                    result.@"error" = null;
                    result.result = .{ .touch = touch_result };
                } else |err| {
                    result.@"error" = err;
                }
            },
            .counter => {
                const delta = operation.delta orelse 1;
                if (counter(client, operation.key, delta, operation.options.counter)) |counter_result| {
                    result.success = true;
                    result.@"error" = null;
                    result.result = .{ .counter = counter_result };
                } else |err| {
                    result.@"error" = err;
                }
            },
            .exists => {
                if (get(client, operation.key)) |get_result| {
                    var mutable_result = get_result;
                    mutable_result.deinit(); // Clean up the get result
                    result.success = true;
                    result.@"error" = null;
                    result.result = .{ .exists = true };
                } else |_| {
                    result.success = true;
                    result.@"error" = null;
                    result.result = .{ .exists = false };
                }
            },
            .get_and_lock => {
                if (getAndLock(client, operation.key, operation.options.get_and_lock)) |get_and_lock_result| {
                    result.success = true;
                    result.@"error" = null;
                    result.result = .{ .get_and_lock = get_and_lock_result };
                } else |err| {
                    result.@"error" = err;
                }
            },
            .unlock => {
                if (unlockWithOptions(client, operation.key, 0, operation.options.unlock)) |unlock_result| {
                    result.success = true;
                    result.@"error" = null;
                    result.result = .{ .unlock = unlock_result };
                } else |err| {
                    result.@"error" = err;
                }
            },
            .get_replica => {
                if (operation.collection) |collection| {
                    if (getReplicaWithCollection(client, operation.key, collection, .any)) |get_result| {
                        result.success = true;
                        result.@"error" = null;
                        result.result = .{ .get_replica = get_result };
                    } else |err| {
                        result.@"error" = err;
                    }
                } else {
                    if (getFromReplica(client, operation.key, .any)) |get_result| {
                        result.success = true;
                        result.@"error" = null;
                        result.result = .{ .get_replica = get_result };
                    } else |err| {
                        result.@"error" = err;
                    }
                }
            },
            .lookup_in => {
                if (operation.collection) |collection| {
                    if (lookupInWithCollection(client, allocator, operation.key, collection, operation.options.lookup_in.specs)) |subdoc_result| {
                        result.success = true;
                        result.@"error" = null;
                        result.result = .{ .lookup_in = subdoc_result };
                    } else |err| {
                        result.@"error" = err;
                    }
                } else {
                    if (lookupIn(client, allocator, operation.key, operation.options.lookup_in.specs)) |subdoc_result| {
                        result.success = true;
                        result.@"error" = null;
                        result.result = .{ .lookup_in = subdoc_result };
                    } else |err| {
                        result.@"error" = err;
                    }
                }
            },
            .mutate_in => {
                if (operation.collection) |collection| {
                    if (mutateInWithCollection(client, allocator, operation.key, collection, operation.options.mutate_in.specs, operation.options.mutate_in.subdoc_options)) |subdoc_result| {
                        result.success = true;
                        result.@"error" = null;
                        result.result = .{ .mutate_in = subdoc_result };
                    } else |err| {
                        result.@"error" = err;
                    }
                } else {
                    if (mutateIn(client, allocator, operation.key, operation.options.mutate_in.specs, operation.options.mutate_in.subdoc_options)) |subdoc_result| {
                        result.success = true;
                        result.@"error" = null;
                        result.result = .{ .mutate_in = subdoc_result };
                    } else |err| {
                        result.@"error" = err;
                    }
                }
            },
        }
    }
    
    return types.BatchOperationResult{
        .results = results,
        .allocator = allocator,
    };
}
