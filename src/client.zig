const std = @import("std");
const c = @import("c.zig");
const Error = @import("error.zig").Error;
const fromStatusCode = @import("error.zig").fromStatusCode;
const types = @import("types.zig");
const operations = @import("operations.zig");
const transactions = @import("transactions.zig");

/// Couchbase client
pub const Client = struct {
    instance: *c.lcb_INSTANCE,
    allocator: std.mem.Allocator,
    prepared_statements: std.StringHashMap(types.PreparedStatement),
    cache_config: types.PreparedStatementCache,

    /// Connection string options
    pub const ConnectOptions = struct {
        connection_string: []const u8,
        username: ?[]const u8 = null,
        password: ?[]const u8 = null,
        bucket: ?[]const u8 = null,
        timeout_ms: u32 = 10000,
    };

    /// Create and connect to a Couchbase cluster
    pub fn connect(allocator: std.mem.Allocator, options: ConnectOptions) Error!Client {
        var create_opts: ?*c.lcb_CREATEOPTS = null;
        _ = c.lcb_createopts_create(&create_opts, c.LCB_TYPE_BUCKET);
        defer _ = c.lcb_createopts_destroy(create_opts);

        // Build connection string with bucket if provided
        // NOTE: libcouchbase holds references to these strings, so we must keep them alive
        // until after lcb_create() is called
        const conn_str_z = if (options.bucket) |bucket|
            try std.fmt.allocPrintZ(allocator, "{s}/{s}", .{ options.connection_string, bucket })
        else
            try allocator.dupeZ(u8, options.connection_string);
        defer allocator.free(conn_str_z);
        
        _ = c.lcb_createopts_connstr(create_opts, conn_str_z.ptr, conn_str_z.len);

        // Set credentials if provided
        // NOTE: These strings must also stay alive until after lcb_create()
        const username_z = if (options.username) |username|
            try allocator.dupeZ(u8, username)
        else
            null;
        defer if (username_z) |uz| allocator.free(uz);
        
        const password_z = if (options.password) |password|
            try allocator.dupeZ(u8, password)
        else
            null;
        defer if (password_z) |pz| allocator.free(pz);
        
        if (username_z) |uz| {
            const pz = password_z orelse "";
            _ = c.lcb_createopts_credentials(create_opts, uz.ptr, uz.len, pz.ptr, pz.len);
        }

        // Create instance - now all strings are still alive
        var instance: ?*c.lcb_INSTANCE = null;
        var rc = c.lcb_create(&instance, create_opts);
        try fromStatusCode(rc);
        // After this point, libcouchbase has copied the strings, so we can free them

        const inst = instance orelse return error.ConnectionFailed;

        // Set timeout
        var timeout_ms = options.timeout_ms;
        _ = c.lcb_cntl(inst, c.LCB_CNTL_SET, c.LCB_CNTL_CONFIGURATION_TIMEOUT, &timeout_ms);

        // Connect
        rc = c.lcb_connect(inst);
        try fromStatusCode(rc);

        // Wait for connection
        rc = c.lcb_wait(inst, 0);
        try fromStatusCode(rc);

        // Get bootstrap status
        rc = c.lcb_get_bootstrap_status(inst);
        try fromStatusCode(rc);

        return Client{
            .instance = inst,
            .allocator = allocator,
            .prepared_statements = std.StringHashMap(types.PreparedStatement).init(allocator),
            .cache_config = .{},
        };
    }

    /// Disconnect and cleanup
    pub fn disconnect(self: *Client) void {
        // Clean up prepared statements
        self.clearPreparedStatements();
        self.prepared_statements.deinit();
        
        c.lcb_destroy(self.instance);
    }

    /// Get a document by key
    pub fn get(self: *Client, key: []const u8) Error!operations.GetResult {
        return operations.get(self, key);
    }

    /// Get and lock a document
    pub fn getAndLock(self: *Client, key: []const u8, options: types.GetAndLockOptions) Error!operations.GetAndLockResult {
        return operations.getAndLock(self, key, options);
    }

    /// Unlock a document with options
    pub fn unlockWithOptions(self: *Client, key: []const u8, cas: u64, options: types.UnlockOptions) Error!operations.UnlockResult {
        return operations.unlockWithOptions(self, key, cas, options);
    }

    /// Get a document with collection
    pub fn getWithCollection(self: *Client, key: []const u8, collection: types.Collection) Error!operations.GetResult {
        return operations.getWithCollection(self, key, collection);
    }

    /// Upsert a document with collection
    pub fn upsertWithCollection(self: *Client, key: []const u8, value: []const u8, collection: types.Collection, options: operations.StoreOptions) Error!operations.MutationResult {
        return operations.upsertWithCollection(self, key, value, collection, options);
    }

    /// Insert a document with collection
    pub fn insertWithCollection(self: *Client, key: []const u8, value: []const u8, collection: types.Collection, options: operations.StoreOptions) Error!operations.MutationResult {
        return operations.insertWithCollection(self, key, value, collection, options);
    }

    /// Replace a document with collection
    pub fn replaceWithCollection(self: *Client, key: []const u8, value: []const u8, collection: types.Collection, options: operations.StoreOptions) Error!operations.MutationResult {
        return operations.replaceWithCollection(self, key, value, collection, options);
    }

    /// Remove a document with collection
    pub fn removeWithCollection(self: *Client, key: []const u8, collection: types.Collection, options: operations.RemoveOptions) Error!operations.MutationResult {
        return operations.removeWithCollection(self, key, collection, options);
    }

    /// Touch a document with collection
    pub fn touchWithCollection(self: *Client, key: []const u8, collection: types.Collection, expiry: u32) Error!operations.MutationResult {
        return operations.touchWithCollection(self, key, collection, expiry);
    }

    /// Counter operation with collection
    pub fn counterWithCollection(self: *Client, key: []const u8, collection: types.Collection, delta: i64, options: operations.CounterOptions) Error!operations.CounterResult {
        return operations.counterWithCollection(self, key, collection, delta, options);
    }

    /// Check if document exists with collection
    pub fn existsWithCollection(self: *Client, key: []const u8, collection: types.Collection) Error!bool {
        return operations.existsWithCollection(self, key, collection);
    }

    /// Get and lock a document with collection
    pub fn getAndLockWithCollection(self: *Client, key: []const u8, collection: types.Collection, options: types.GetAndLockOptions) Error!operations.GetAndLockResult {
        return operations.getAndLockWithCollection(self, key, collection, options);
    }

    /// Unlock a document with collection
    pub fn unlockWithCollection(self: *Client, key: []const u8, cas: u64, collection: types.Collection) Error!void {
        return operations.unlockWithCollection(self, key, cas, collection);
    }

    /// Get from replica with collection
    pub fn getReplicaWithCollection(self: *Client, key: []const u8, collection: types.Collection, mode: types.ReplicaMode) Error!operations.GetResult {
        return operations.getReplicaWithCollection(self, key, collection, mode);
    }

    /// Subdocument lookup with collection
    pub fn lookupInWithCollection(self: *Client, allocator: std.mem.Allocator, key: []const u8, collection: types.Collection, specs: []const operations.SubdocSpec) Error!operations.SubdocResult {
        return operations.lookupInWithCollection(self, allocator, key, collection, specs);
    }

    /// Subdocument mutation with collection
    pub fn mutateInWithCollection(self: *Client, allocator: std.mem.Allocator, key: []const u8, collection: types.Collection, specs: []const operations.SubdocSpec, options: operations.SubdocOptions) Error!operations.SubdocResult {
        return operations.mutateInWithCollection(self, allocator, key, collection, specs, options);
    }

    /// Get collection manifest
    pub fn getCollectionManifest(self: *Client, allocator: std.mem.Allocator) Error!types.CollectionManifest {
        return operations.getCollectionManifest(self, allocator);
    }

    /// Execute batch operations
    pub fn executeBatch(self: *Client, allocator: std.mem.Allocator, batch_operations: []const types.BatchOperation) Error!types.BatchOperationResult {
        return operations.executeBatch(self, allocator, batch_operations);
    }

    /// Get a document from replica
    pub fn getFromReplica(self: *Client, key: []const u8, mode: types.ReplicaMode) Error!operations.GetResult {
        return operations.getFromReplica(self, key, mode);
    }

    /// Upsert a document
    pub fn upsert(self: *Client, key: []const u8, value: []const u8, options: operations.StoreOptions) Error!operations.MutationResult {
        return operations.store(self, key, value, .upsert, options);
    }

    /// Insert a document (fails if exists)
    pub fn insert(self: *Client, key: []const u8, value: []const u8, options: operations.StoreOptions) Error!operations.MutationResult {
        return operations.store(self, key, value, .insert, options);
    }

    /// Replace a document (fails if doesn't exist)
    pub fn replace(self: *Client, key: []const u8, value: []const u8, options: operations.StoreOptions) Error!operations.MutationResult {
        return operations.store(self, key, value, .replace, options);
    }

    /// Remove a document
    pub fn remove(self: *Client, key: []const u8, options: operations.RemoveOptions) Error!operations.MutationResult {
        return operations.remove(self, key, options);
    }

    /// Append data to an existing document
    pub fn append(self: *Client, key: []const u8, value: []const u8, options: operations.StoreOptions) Error!operations.MutationResult {
        return operations.store(self, key, value, .append, options);
    }

    /// Prepend data to an existing document
    pub fn prepend(self: *Client, key: []const u8, value: []const u8, options: operations.StoreOptions) Error!operations.MutationResult {
        return operations.store(self, key, value, .prepend, options);
    }

    /// Check if a document exists
    pub fn exists(self: *Client, key: []const u8) Error!bool {
        return operations.exists(self, key);
    }

    /// Increment a counter
    pub fn increment(self: *Client, key: []const u8, delta: i64, options: operations.CounterOptions) Error!operations.CounterResult {
        return operations.counter(self, key, delta, options);
    }

    /// Decrement a counter
    pub fn decrement(self: *Client, key: []const u8, delta: i64, options: operations.CounterOptions) Error!operations.CounterResult {
        return operations.counter(self, key, -delta, options);
    }

    /// Touch a document (update expiration)
    pub fn touch(self: *Client, key: []const u8, expiry: u32) Error!operations.MutationResult {
        return operations.touch(self, key, expiry);
    }

    /// Unlock a locked document
    pub fn unlock(self: *Client, key: []const u8, cas: u64) Error!void {
        return operations.unlock(self, key, cas);
    }

    /// Execute a N1QL query
    pub fn query(self: *Client, allocator: std.mem.Allocator, statement: []const u8, options: operations.QueryOptions) Error!operations.QueryResult {
        return operations.query(self, allocator, statement, options);
    }

    /// Execute subdocument lookup
    pub fn lookupIn(self: *Client, allocator: std.mem.Allocator, key: []const u8, specs: []const operations.SubdocSpec) Error!operations.SubdocResult {
        return operations.lookupIn(self, allocator, key, specs);
    }

    /// Execute subdocument mutation
    pub fn mutateIn(self: *Client, allocator: std.mem.Allocator, key: []const u8, specs: []const operations.SubdocSpec, options: operations.SubdocOptions) Error!operations.SubdocResult {
        return operations.mutateIn(self, allocator, key, specs, options);
    }

    /// Ping all services
    pub fn ping(self: *Client, allocator: std.mem.Allocator) Error!operations.PingResult {
        return operations.ping(self, allocator);
    }

    /// Get diagnostics
    pub fn diagnostics(self: *Client, allocator: std.mem.Allocator) Error!operations.DiagnosticsResult {
        return operations.diagnostics(self, allocator);
    }

    /// Execute a view query
    pub fn viewQuery(
        self: *Client,
        allocator: std.mem.Allocator,
        design_doc: []const u8,
        view_name: []const u8,
        options: @import("views.zig").ViewOptions,
    ) Error!@import("views.zig").ViewResult {
        const views = @import("views.zig");
        return views.viewQuery(self, allocator, design_doc, view_name, options);
    }

    /// Execute a spatial view query (deprecated - use FTS instead)
    /// Note: Spatial views are deprecated in Couchbase Server 6.0+
    /// This method provides backward compatibility but may not work with newer servers
    pub fn spatialViewQuery(
        self: *Client,
        allocator: std.mem.Allocator,
        design_doc: []const u8,
        view_name: []const u8,
        options: @import("views.zig").SpatialViewOptions,
    ) Error!@import("views.zig").ViewResult {
        const views = @import("views.zig");
        return views.spatialViewQuery(self, allocator, design_doc, view_name, options);
    }

    /// Store operation with full durability and mutation token support
    pub fn storeWithDurability(
        self: *Client,
        key: []const u8,
        value: []const u8,
        operation: @import("types.zig").StoreOperation,
        options: @import("operations.zig").StoreOptions,
        allocator: std.mem.Allocator,
    ) Error!@import("operations.zig").MutationResult {
        return operations.storeWithDurability(self, key, value, operation, options, allocator);
    }

    /// Observe operation for durability checking
    pub fn observe(
        self: *Client,
        key: []const u8,
        cas: u64,
        options: @import("types.zig").ObserveOptions,
        allocator: std.mem.Allocator,
    ) Error!@import("types.zig").ObserveResult {
        return operations.observe(self, key, cas, options, allocator);
    }

    /// Observe multiple keys for durability checking
    pub fn observeMulti(
        self: *Client,
        keys: []const []const u8,
        cas_values: []const u64,
        options: @import("types.zig").ObserveOptions,
        allocator: std.mem.Allocator,
    ) Error![]@import("types.zig").ObserveResult {
        return operations.observeMulti(self, keys, cas_values, options, allocator);
    }

    /// Wait for durability using observe
    pub fn waitForDurability(
        self: *Client,
        key: []const u8,
        cas: u64,
        durability: @import("types.zig").ObserveDurability,
        allocator: std.mem.Allocator,
    ) Error!void {
        return operations.waitForDurability(self, key, cas, durability, allocator);
    }

    /// Wait for durability using mutation token
    pub fn waitForDurabilityWithToken(
        self: *Client,
        token: @import("types.zig").MutationToken,
        durability: @import("types.zig").ObserveDurability,
        allocator: std.mem.Allocator,
    ) Error!void {
        return operations.waitForDurabilityWithToken(self, token, durability, allocator);
    }

    /// Execute an analytics query
    pub fn analyticsQuery(
        self: *Client,
        allocator: std.mem.Allocator,
        statement: []const u8,
        options: types.AnalyticsOptions,
    ) Error!operations.AnalyticsResult {
        return operations.analyticsQuery(self, allocator, statement, options);
    }

    /// Execute a search query (Full-Text Search)
    pub fn searchQuery(
        self: *Client,
        allocator: std.mem.Allocator,
        index_name: []const u8,
        search_query: []const u8,
        options: types.SearchOptions,
    ) Error!operations.SearchResult {
        return operations.searchQuery(self, allocator, index_name, search_query, options);
    }

    /// Prepare a statement for reuse
    pub fn prepareStatement(self: *Client, statement: []const u8) Error!void {
        return operations.prepareStatement(self, statement);
    }

    /// Execute a prepared statement
    pub fn executePrepared(
        self: *Client,
        allocator: std.mem.Allocator,
        statement: []const u8,
        options: operations.QueryOptions,
    ) Error!operations.QueryResult {
        return operations.executePrepared(self, allocator, statement, options);
    }

    /// Clear prepared statement cache
    pub fn clearPreparedStatements(self: *Client) void {
        var iterator = self.prepared_statements.iterator();
        while (iterator.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.prepared_statements.clearRetainingCapacity();
    }

    /// Get prepared statement cache statistics
    pub fn getPreparedStatementStats(self: *const Client) struct { count: usize, max_size: usize } {
        return .{
            .count = self.prepared_statements.count(),
            .max_size = self.cache_config.max_size,
        };
    }

    /// Cleanup expired prepared statements
    pub fn cleanupExpiredPreparedStatements(self: *Client) void {
        if (!self.cache_config.enabled) return;
        
        var to_remove = std.ArrayList([]const u8).init(self.allocator);
        defer to_remove.deinit();
        
        var iterator = self.prepared_statements.iterator();
        while (iterator.next()) |entry| {
            if (entry.value_ptr.isExpired(self.cache_config.max_age_ms)) {
                to_remove.append(entry.key_ptr.*) catch continue;
            }
        }
        
        for (to_remove.items) |key| {
            if (self.prepared_statements.getPtr(key)) |prepared| {
                prepared.deinit();
            }
            _ = self.prepared_statements.remove(key);
        }
    }

    /// Cancel a running query
    pub fn cancelQuery(self: *Client, result: *operations.QueryResult) void {
        _ = self; // Client not used in current implementation
        result.cancel();
    }

    /// Check if a query has been cancelled
    pub fn isQueryCancelled(self: *const Client, result: *const operations.QueryResult) bool {
        _ = self; // Client not used in current implementation
        return result.isCancelled();
    }

    // Transaction methods
    pub fn beginTransaction(self: *Client, allocator: std.mem.Allocator) Error!types.TransactionContext {
        return transactions.beginTransaction(self, allocator);
    }

    pub fn addGetOperation(self: *Client, ctx: *types.TransactionContext, key: []const u8, options: ?types.TransactionOperationOptions) Error!void {
        _ = self;
        return transactions.addGetOperation(ctx, key, options);
    }

    pub fn addInsertOperation(self: *Client, ctx: *types.TransactionContext, key: []const u8, value: []const u8, options: ?types.TransactionOperationOptions) Error!void {
        _ = self;
        return transactions.addInsertOperation(ctx, key, value, options);
    }

    pub fn addUpsertOperation(self: *Client, ctx: *types.TransactionContext, key: []const u8, value: []const u8, options: ?types.TransactionOperationOptions) Error!void {
        _ = self;
        return transactions.addUpsertOperation(ctx, key, value, options);
    }

    pub fn addReplaceOperation(self: *Client, ctx: *types.TransactionContext, key: []const u8, value: []const u8, options: ?types.TransactionOperationOptions) Error!void {
        _ = self;
        return transactions.addReplaceOperation(ctx, key, value, options);
    }

    pub fn addRemoveOperation(self: *Client, ctx: *types.TransactionContext, key: []const u8, options: ?types.TransactionOperationOptions) Error!void {
        _ = self;
        return transactions.addRemoveOperation(ctx, key, options);
    }

    pub fn addIncrementOperation(self: *Client, ctx: *types.TransactionContext, key: []const u8, delta: i64, options: ?types.TransactionOperationOptions) Error!void {
        _ = self;
        return transactions.addIncrementOperation(ctx, key, delta, options);
    }

    pub fn addDecrementOperation(self: *Client, ctx: *types.TransactionContext, key: []const u8, delta: i64, options: ?types.TransactionOperationOptions) Error!void {
        _ = self;
        return transactions.addDecrementOperation(ctx, key, delta, options);
    }

    pub fn addTouchOperation(self: *Client, ctx: *types.TransactionContext, key: []const u8, expiry: u32, options: ?types.TransactionOperationOptions) Error!void {
        _ = self;
        return transactions.addTouchOperation(ctx, key, expiry, options);
    }

    pub fn addUnlockOperation(self: *Client, ctx: *types.TransactionContext, key: []const u8, cas: u64, options: ?types.TransactionOperationOptions) Error!void {
        _ = self;
        return transactions.addUnlockOperation(ctx, key, cas, options);
    }

    pub fn addQueryOperation(self: *Client, ctx: *types.TransactionContext, statement: []const u8, options: ?types.TransactionOperationOptions) Error!void {
        _ = self;
        return transactions.addQueryOperation(ctx, statement, options);
    }

    pub fn commitTransaction(self: *Client, ctx: *types.TransactionContext, config: types.TransactionConfig) Error!types.TransactionResult {
        _ = self;
        return transactions.commitTransaction(ctx, config);
    }

    pub fn rollbackTransaction(self: *Client, ctx: *types.TransactionContext) Error!types.TransactionResult {
        _ = self;
        return transactions.rollbackTransaction(ctx);
    }
};
