const std = @import("std");
const c = @import("c.zig");

/// Document representation
pub const Document = struct {
    id: []const u8,
    content: []const u8,
    cas: u64 = 0,
    flags: u32 = 0,
};

/// Durability level for operations
pub const DurabilityLevel = enum(c_uint) {
    none = c.LCB_DURABILITYLEVEL_NONE,
    majority = c.LCB_DURABILITYLEVEL_MAJORITY,
    majority_and_persist_to_active = c.LCB_DURABILITYLEVEL_MAJORITY_AND_PERSIST_TO_ACTIVE,
    persist_to_majority = c.LCB_DURABILITYLEVEL_PERSIST_TO_MAJORITY,
};

/// Durability settings
pub const Durability = struct {
    level: DurabilityLevel = .none,
    timeout_ms: u32 = 0,
};

/// Store operation type
pub const StoreOperation = enum(c_uint) {
    upsert = c.LCB_STORE_UPSERT,
    insert = c.LCB_STORE_INSERT,
    replace = c.LCB_STORE_REPLACE,
    append = c.LCB_STORE_APPEND,
    prepend = c.LCB_STORE_PREPEND,
};

/// Replica mode for get operations
pub const ReplicaMode = enum {
    any,
    all,
    index,
};

/// Subdocument operation type
pub const SubdocOp = enum(c_uint) {
    get = 0,
    exists = 1,
    replace = 2,
    dict_add = 3,
    dict_upsert = 4,
    array_add_first = 5,
    array_add_last = 6,
    array_add_unique = 7,
    array_insert = 8,
    delete = 9,
    counter = 10,
    get_count = 11,
};

/// Scan consistency for queries
pub const ScanConsistency = enum(c_uint) {
    not_bounded = 0,
    request_plus = 1,
};

/// Query profile mode
pub const QueryProfile = enum(c_uint) {
    off = 0,
    phases = 1,
    timings = 2,
};

/// Query consistency mode
pub const QueryConsistency = enum(c_uint) {
    not_bounded = 0,
    request_plus = 1,
    statement_plus = 2,
};

/// Analytics query options
pub const AnalyticsOptions = struct {
    timeout_ms: u32 = 300000,
    priority: bool = false,
    client_context_id: ?[]const u8 = null,
    read_only: bool = false,
    max_parallelism: ?u32 = null,
    pipeline_batch: ?u32 = null,
    pipeline_cap: ?u32 = null,
    scan_cap: ?u32 = null,
    scan_wait: ?u32 = null,
    scan_consistency: ?[]const u8 = null,
    query_context: ?[]const u8 = null,
    pretty: bool = false,
    metrics: bool = true,
    raw: ?[]const u8 = null,
    positional_parameters: ?[]const []const u8 = null,
    named_parameters: ?std.StringHashMap([]const u8) = null,
};

/// Search query options
pub const SearchOptions = struct {
    timeout_ms: u32 = 75000,
    limit: ?u32 = null,
    skip: ?u32 = null,
    explain: bool = false,
    highlight_style: ?[]const u8 = null,
    highlight_fields: ?[]const []const u8 = null,
    sort: ?[]const []const u8 = null,
    facets: ?[]const []const u8 = null,
    fields: ?[]const []const u8 = null,
    disable_scoring: bool = false,
    include_locations: bool = false,
    consistent_with: ?[]const u8 = null,
    client_context_id: ?[]const u8 = null,
    raw: ?[]const u8 = null,
};

/// Prepared statement for query optimization
pub const PreparedStatement = struct {
    statement: []const u8,
    prepared_data: []const u8,
    allocator: std.mem.Allocator,
    created_at: u64,
    
    pub fn deinit(self: *PreparedStatement) void {
        self.allocator.free(self.statement);
        self.allocator.free(self.prepared_data);
    }
    
    pub fn isExpired(self: *const PreparedStatement, max_age_ms: u64) bool {
        const now = @as(u64, @intCast(std.time.timestamp() * 1000)); // Convert to milliseconds
        return (now - self.created_at) > max_age_ms;
    }
};

/// Prepared statement cache configuration
pub const PreparedStatementCache = struct {
    max_size: usize = 100,
    max_age_ms: u64 = 300000, // 5 minutes
    enabled: bool = true,
};

/// Query handle for cancellation
pub const QueryHandle = struct {
    id: u64,
    cancelled: bool,
    allocator: std.mem.Allocator,
    
    pub fn deinit(self: *QueryHandle) void {
        _ = self;
        // Handle cleanup if needed
    }
    
    pub fn cancel(self: *QueryHandle) void {
        self.cancelled = true;
    }
    
    pub fn isCancelled(self: *const QueryHandle) bool {
        return self.cancelled;
    }
};

/// Query cancellation options
pub const QueryCancellationOptions = struct {
    timeout_ms: u32 = 5000, // 5 second timeout for cancellation
    force: bool = false, // Force cancellation even if query is in progress
};

/// Query metrics for performance analysis
pub const QueryMetrics = struct {
    elapsed_time: []const u8,
    execution_time: []const u8,
    result_count: u64,
    result_size: u64,
    mutation_count: u64,
    sort_count: u64,
    error_count: u64,
    warning_count: u64,
    allocator: std.mem.Allocator,
    
    pub fn deinit(self: *QueryMetrics) void {
        self.allocator.free(self.elapsed_time);
        self.allocator.free(self.execution_time);
    }
    
    pub fn parse(self: *QueryMetrics, metrics_json: []const u8) !void {
        var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, metrics_json, .{}) catch return;
        defer parsed.deinit();
        
        if (parsed.value.object.get("elapsedTime")) |elapsed| {
            if (elapsed == .string) {
                self.elapsed_time = try self.allocator.dupe(u8, elapsed.string);
            }
        }
        
        if (parsed.value.object.get("executionTime")) |exec| {
            if (exec == .string) {
                self.execution_time = try self.allocator.dupe(u8, exec.string);
            }
        }
        
        if (parsed.value.object.get("resultCount")) |count| {
            if (count == .integer) {
                self.result_count = @intCast(count.integer);
            }
        }
        
        if (parsed.value.object.get("resultSize")) |size| {
            if (size == .integer) {
                self.result_size = @intCast(size.integer);
            }
        }
        
        if (parsed.value.object.get("mutationCount")) |mut| {
            if (mut == .integer) {
                self.mutation_count = @intCast(mut.integer);
            }
        }
        
        if (parsed.value.object.get("sortCount")) |sort| {
            if (sort == .integer) {
                self.sort_count = @intCast(sort.integer);
            }
        }
        
        if (parsed.value.object.get("errorCount")) |err| {
            if (err == .integer) {
                self.error_count = @intCast(err.integer);
            }
        }
        
        if (parsed.value.object.get("warningCount")) |warn| {
            if (warn == .integer) {
                self.warning_count = @intCast(warn.integer);
            }
        }
    }
};

/// Enhanced query metadata for better observability
pub const QueryMetadata = struct {
    request_id: ?[]const u8 = null,
    client_context_id: ?[]const u8 = null,
    status: ?[]const u8 = null,
    metrics: ?*QueryMetrics = null,
    profile: ?QueryProfile = null,
    signature: ?[]const u8 = null,
    warnings: ?[][]const u8 = null,
    allocator: std.mem.Allocator,
    
    pub fn deinit(self: *QueryMetadata) void {
        if (self.request_id) |id| self.allocator.free(id);
        if (self.client_context_id) |ctx| self.allocator.free(ctx);
        if (self.status) |status| self.allocator.free(status);
        if (self.metrics) |metrics| {
            var mut_metrics = metrics;
            mut_metrics.deinit();
            self.allocator.destroy(mut_metrics);
        }
        if (self.signature) |sig| self.allocator.free(sig);
        if (self.warnings) |warns| {
            for (warns) |warn| self.allocator.free(warn);
            self.allocator.free(warns);
        }
    }
    
    pub fn parse(self: *QueryMetadata, meta_json: []const u8) !void {
        var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, meta_json, .{}) catch return;
        defer parsed.deinit();
        
        if (parsed.value.object.get("requestID")) |req_id| {
            if (req_id == .string) {
                self.request_id = try self.allocator.dupe(u8, req_id.string);
            }
        }
        
        if (parsed.value.object.get("clientContextID")) |ctx_id| {
            if (ctx_id == .string) {
                self.client_context_id = try self.allocator.dupe(u8, ctx_id.string);
            }
        }
        
        if (parsed.value.object.get("status")) |status_val| {
            if (status_val == .string) {
                self.status = try self.allocator.dupe(u8, status_val.string);
            }
        }
        
        if (parsed.value.object.get("signature")) |sig_val| {
            if (sig_val == .string) {
                self.signature = try self.allocator.dupe(u8, sig_val.string);
            }
        }
        
        if (parsed.value.object.get("metrics")) |metrics_val| {
            const metrics = try self.allocator.create(QueryMetrics);
            metrics.allocator = self.allocator;
            try metrics.parse(std.json.stringifyAlloc(self.allocator, metrics_val, .{}) catch return);
            self.metrics = metrics;
        }
        
        if (parsed.value.object.get("warnings")) |warns_val| {
            if (warns_val == .array) {
                const warns = try self.allocator.alloc([]const u8, warns_val.array.items.len);
                for (warns_val.array.items, 0..) |warn, i| {
                    if (warn == .string) {
                        warns[i] = try self.allocator.dupe(u8, warn.string);
                    }
                }
                self.warnings = warns;
            }
        }
    }
};

/// Consistency token for advanced consistency control
pub const ConsistencyToken = struct {
    token: []const u8,
    keyspace: []const u8,
    allocator: std.mem.Allocator,
    
    pub fn deinit(self: *ConsistencyToken) void {
        self.allocator.free(self.token);
        self.allocator.free(self.keyspace);
    }
    
    pub fn parse(self: *ConsistencyToken, token_json: []const u8) !void {
        var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, token_json, .{}) catch return;
        defer parsed.deinit();
        
        if (parsed.value.object.get("token")) |token_val| {
            if (token_val == .string) {
                self.token = try self.allocator.dupe(u8, token_val.string);
            }
        }
        
        if (parsed.value.object.get("keyspace")) |keyspace_val| {
            if (keyspace_val == .string) {
                self.keyspace = try self.allocator.dupe(u8, keyspace_val.string);
            }
        }
    }
};

/// Get and lock operation options
pub const GetAndLockOptions = struct {
    lock_time: u32 = 15, // Lock duration in seconds (default 15 seconds)
    timeout_ms: u32 = 75000, // Operation timeout in milliseconds
    flags: u32 = 0, // Additional flags
    durability: Durability = .{}, // Durability requirements
    
    /// Create get and lock options with custom lock time
    pub fn withLockTime(lock_time: u32) GetAndLockOptions {
        return GetAndLockOptions{
            .lock_time = lock_time,
        };
    }
    
    /// Create get and lock options with durability
    pub fn withDurability(durability: Durability) GetAndLockOptions {
        return GetAndLockOptions{
            .durability = durability,
        };
    }
};

/// Unlock operation options
pub const UnlockOptions = struct {
    timeout_ms: u32 = 75000, // Operation timeout in milliseconds
    flags: u32 = 0, // Additional flags
    
    /// Create unlock options with custom timeout
    pub fn withTimeout(timeout_ms: u32) UnlockOptions {
        return UnlockOptions{
            .timeout_ms = timeout_ms,
        };
    }
};

/// Collection identifier
pub const Collection = struct {
    name: []const u8,
    scope: []const u8,
    allocator: std.mem.Allocator,
    
    /// Create a collection identifier
    pub fn create(allocator: std.mem.Allocator, name: []const u8, scope: []const u8) !Collection {
        return Collection{
            .name = try allocator.dupe(u8, name),
            .scope = try allocator.dupe(u8, scope),
            .allocator = allocator,
        };
    }
    
    /// Create default collection (scope: "_default", collection: "_default")
    pub fn default(allocator: std.mem.Allocator) !Collection {
        return Collection{
            .name = try allocator.dupe(u8, "_default"),
            .scope = try allocator.dupe(u8, "_default"),
            .allocator = allocator,
        };
    }
    
    /// Deinitialize collection
    pub fn deinit(self: *Collection) void {
        self.allocator.free(self.name);
        self.allocator.free(self.scope);
    }
    
    /// Check if this is the default collection
    pub fn isDefault(self: *const Collection) bool {
        return std.mem.eql(u8, self.name, "_default") and std.mem.eql(u8, self.scope, "_default");
    }
};

/// Scope identifier
pub const Scope = struct {
    name: []const u8,
    allocator: std.mem.Allocator,
    
    /// Create a scope identifier
    pub fn create(allocator: std.mem.Allocator, name: []const u8) !Scope {
        return Scope{
            .name = try allocator.dupe(u8, name),
            .allocator = allocator,
        };
    }
    
    /// Create default scope
    pub fn default(allocator: std.mem.Allocator) !Scope {
        return Scope{
            .name = try allocator.dupe(u8, "_default"),
            .allocator = allocator,
        };
    }
    
    /// Deinitialize scope
    pub fn deinit(self: *Scope) void {
        self.allocator.free(self.name);
    }
    
    /// Check if this is the default scope
    pub fn isDefault(self: *const Scope) bool {
        return std.mem.eql(u8, self.name, "_default");
    }
};

/// Collection manifest entry
pub const CollectionManifestEntry = struct {
    name: []const u8,
    scope: []const u8,
    uid: u32,
    max_ttl: u32,
    allocator: std.mem.Allocator,
    
    pub fn deinit(self: *CollectionManifestEntry) void {
        self.allocator.free(self.name);
        self.allocator.free(self.scope);
    }
};

/// Collection manifest
pub const CollectionManifest = struct {
    uid: u64,
    collections: []CollectionManifestEntry,
    allocator: std.mem.Allocator,
    
    pub fn deinit(self: *CollectionManifest) void {
        for (self.collections) |*entry| {
            entry.deinit();
        }
        self.allocator.free(self.collections);
    }
    
    /// Find collection by name and scope
    pub fn findCollection(self: *const CollectionManifest, name: []const u8, scope: []const u8) ?*const CollectionManifestEntry {
        for (self.collections) |*entry| {
            if (std.mem.eql(u8, entry.name, name) and std.mem.eql(u8, entry.scope, scope)) {
                return entry;
            }
        }
        return null;
    }
    
    /// Get all collections in a scope
    pub fn getCollectionsInScope(self: *const CollectionManifest, scope: []const u8, allocator: std.mem.Allocator) ![]CollectionManifestEntry {
        var result = std.ArrayList(CollectionManifestEntry).init(allocator);
        defer result.deinit();
        
        for (self.collections) |entry| {
            if (std.mem.eql(u8, entry.scope, scope)) {
                try result.append(entry);
            }
        }
        
        return result.toOwnedSlice();
    }
};

/// Import Error type
const Error = @import("error.zig").Error;

/// Import operation result types
const GetResult = @import("operations.zig").GetResult;
const UpsertResult = @import("operations.zig").MutationResult;
const InsertResult = @import("operations.zig").MutationResult;
const ReplaceResult = @import("operations.zig").MutationResult;
const RemoveResult = @import("operations.zig").MutationResult;
const TouchResult = @import("operations.zig").MutationResult;
const CounterResult = @import("operations.zig").CounterResult;
const GetAndLockResult = @import("operations.zig").GetAndLockResult;
const UnlockResult = @import("operations.zig").UnlockResult;

/// Import option types
const GetOptions = @import("operations.zig").StoreOptions;
const UpsertOptions = @import("operations.zig").StoreOptions;
const InsertOptions = @import("operations.zig").StoreOptions;
const ReplaceOptions = @import("operations.zig").StoreOptions;
const RemoveOptions = @import("operations.zig").RemoveOptions;
const TouchOptions = @import("operations.zig").StoreOptions;
const CounterOptions = @import("operations.zig").CounterOptions;
const ExistsOptions = @import("operations.zig").StoreOptions;
const SubdocSpec = @import("operations.zig").SubdocSpec;
const SubdocOptions = @import("operations.zig").SubdocOptions;
const SubdocResult = @import("operations.zig").SubdocResult;

/// Batch operation types
pub const BatchOperationType = enum {
    get,
    upsert,
    insert,
    replace,
    remove,
    touch,
    counter,
    exists,
    get_and_lock,
    unlock,
    get_replica,
    lookup_in,
    mutate_in,
};

/// Individual batch operation
pub const BatchOperation = struct {
    operation_type: BatchOperationType,
    key: []const u8,
    value: ?[]const u8 = null,
    delta: ?i64 = null, // For counter operations
    options: union {
        get: GetOptions,
        upsert: UpsertOptions,
        insert: InsertOptions,
        replace: ReplaceOptions,
        remove: RemoveOptions,
        touch: TouchOptions,
        counter: CounterOptions,
        exists: ExistsOptions,
        get_and_lock: GetAndLockOptions,
        unlock: UnlockOptions,
        get_replica: GetOptions,
        lookup_in: struct { specs: []const SubdocSpec },
        mutate_in: struct { specs: []const SubdocSpec, subdoc_options: SubdocOptions },
    },
    collection: ?Collection = null,
    
    /// Create a batch get operation
    pub fn get(key: []const u8, options: GetOptions) BatchOperation {
        return BatchOperation{
            .operation_type = .get,
            .key = key,
            .options = .{ .get = options },
        };
    }
    
    /// Create a batch upsert operation
    pub fn upsert(key: []const u8, value: []const u8, options: UpsertOptions) BatchOperation {
        return BatchOperation{
            .operation_type = .upsert,
            .key = key,
            .value = value,
            .options = .{ .upsert = options },
        };
    }
    
    /// Create a batch insert operation
    pub fn insert(key: []const u8, value: []const u8, options: InsertOptions) BatchOperation {
        return BatchOperation{
            .operation_type = .insert,
            .key = key,
            .value = value,
            .options = .{ .insert = options },
        };
    }
    
    /// Create a batch replace operation
    pub fn replace(key: []const u8, value: []const u8, options: ReplaceOptions) BatchOperation {
        return BatchOperation{
            .operation_type = .replace,
            .key = key,
            .value = value,
            .options = .{ .replace = options },
        };
    }
    
    /// Create a batch remove operation
    pub fn remove(key: []const u8, options: RemoveOptions) BatchOperation {
        return BatchOperation{
            .operation_type = .remove,
            .key = key,
            .options = .{ .remove = options },
        };
    }
    
    /// Create a batch touch operation
    pub fn touch(key: []const u8, options: TouchOptions) BatchOperation {
        return BatchOperation{
            .operation_type = .touch,
            .key = key,
            .options = .{ .touch = options },
        };
    }
    
    /// Create a batch counter operation
    pub fn counter(key: []const u8, delta: i64, options: CounterOptions) BatchOperation {
        return BatchOperation{
            .operation_type = .counter,
            .key = key,
            .delta = delta,
            .options = .{ .counter = options },
        };
    }
    
    /// Create a batch exists operation
    pub fn exists(key: []const u8, options: ExistsOptions) BatchOperation {
        return BatchOperation{
            .operation_type = .exists,
            .key = key,
            .options = .{ .exists = options },
        };
    }
    
    /// Create a batch get and lock operation
    pub fn getAndLock(key: []const u8, options: GetAndLockOptions) BatchOperation {
        return BatchOperation{
            .operation_type = .get_and_lock,
            .key = key,
            .options = .{ .get_and_lock = options },
        };
    }
    
    /// Create a batch unlock operation
    pub fn unlock(key: []const u8, cas: u64, options: UnlockOptions) BatchOperation {
        _ = cas; // Suppress unused parameter warning
        return BatchOperation{
            .operation_type = .unlock,
            .key = key,
            .options = .{ .unlock = options },
        };
    }
    
    /// Create a batch get replica operation
    pub fn getReplica(key: []const u8, options: GetOptions) BatchOperation {
        return BatchOperation{
            .operation_type = .get_replica,
            .key = key,
            .options = .{ .get_replica = options },
        };
    }
    
    /// Create a batch subdocument lookup operation
    pub fn lookupIn(key: []const u8, specs: []const SubdocSpec) BatchOperation {
        return BatchOperation{
            .operation_type = .lookup_in,
            .key = key,
            .options = .{ .lookup_in = .{ .specs = specs } },
        };
    }
    
    /// Create a batch subdocument mutation operation
    pub fn mutateIn(key: []const u8, specs: []const SubdocSpec, subdoc_options: SubdocOptions) BatchOperation {
        return BatchOperation{
            .operation_type = .mutate_in,
            .key = key,
            .options = .{ .mutate_in = .{ .specs = specs, .subdoc_options = subdoc_options } },
        };
    }
    
    /// Set collection for this operation
    pub fn withCollection(self: *const BatchOperation, collection: Collection) BatchOperation {
        var result = self.*;
        result.collection = collection;
        return result;
    }
};

/// Individual batch result
pub const BatchResult = struct {
    operation_type: BatchOperationType,
    key: []const u8,
    success: bool,
    @"error": ?Error = null,
    result: union {
        get: ?GetResult,
        upsert: ?UpsertResult,
        insert: ?InsertResult,
        replace: ?ReplaceResult,
        remove: ?RemoveResult,
        touch: ?TouchResult,
        counter: ?CounterResult,
        exists: ?bool,
        get_and_lock: ?GetAndLockResult,
        unlock: ?UnlockResult,
        get_replica: ?GetResult,
        lookup_in: ?SubdocResult,
        mutate_in: ?SubdocResult,
    },
    allocator: std.mem.Allocator,
    
    pub fn deinit(self: *BatchResult) void {
        switch (self.operation_type) {
            .get => if (self.result.get) |*get_result| get_result.deinit(),
            .upsert => {}, // MutationResult doesn't need cleanup
            .insert => {}, // MutationResult doesn't need cleanup
            .replace => {}, // MutationResult doesn't need cleanup
            .remove => {}, // MutationResult doesn't need cleanup
            .touch => {}, // MutationResult doesn't need cleanup
            .counter => {}, // CounterResult doesn't need cleanup
            .exists => {}, // bool doesn't need cleanup
            .get_and_lock => if (self.result.get_and_lock) |*get_and_lock_result| get_and_lock_result.deinit(),
            .unlock => {}, // UnlockResult doesn't need cleanup
            .get_replica => if (self.result.get_replica) |*get_result| get_result.deinit(),
            .lookup_in => if (self.result.lookup_in) |*subdoc_result| subdoc_result.deinit(),
            .mutate_in => if (self.result.mutate_in) |*subdoc_result| subdoc_result.deinit(),
        }
    }
};

/// Batch operation result
pub const BatchOperationResult = struct {
    results: []BatchResult,
    allocator: std.mem.Allocator,
    
    pub fn deinit(self: *BatchOperationResult) void {
        for (self.results) |*result| {
            result.deinit();
        }
        self.allocator.free(self.results);
    }
    
    /// Get successful results count
    pub fn getSuccessCount(self: *const BatchOperationResult) usize {
        var count: usize = 0;
        for (self.results) |result| {
            if (result.success) count += 1;
        }
        return count;
    }
    
    /// Get failed results count
    pub fn getFailureCount(self: *const BatchOperationResult) usize {
        return self.results.len - self.getSuccessCount();
    }
    
    /// Get results by operation type
    pub fn getResultsByType(self: *const BatchOperationResult, operation_type: BatchOperationType, allocator: std.mem.Allocator) ![]BatchResult {
        var filtered = std.ArrayList(BatchResult).init(allocator);
        defer filtered.deinit();
        
        for (self.results) |result| {
            if (result.operation_type == operation_type) {
                try filtered.append(result);
            }
        }
        
        return filtered.toOwnedSlice();
    }
    
    /// Get successful results only
    pub fn getSuccessfulResults(self: *const BatchOperationResult, allocator: std.mem.Allocator) ![]BatchResult {
        var successful = std.ArrayList(BatchResult).init(allocator);
        defer successful.deinit();
        
        for (self.results) |result| {
            if (result.success) {
                try successful.append(result);
            }
        }
        
        return successful.toOwnedSlice();
    }
    
    /// Get failed results only
    pub fn getFailedResults(self: *const BatchOperationResult, allocator: std.mem.Allocator) ![]BatchResult {
        var failed = std.ArrayList(BatchResult).init(allocator);
        defer failed.deinit();
        
        for (self.results) |result| {
            if (!result.success) {
                try failed.append(result);
            }
        }
        
        return failed.toOwnedSlice();
    }
};

/// View query options
pub const ViewQueryOptions = struct {
    start_key: ?[]const u8 = null,
    end_key: ?[]const u8 = null,
    limit: ?u32 = null,
    skip: ?u32 = null,
    descending: bool = false,
    include_docs: bool = false,
};
