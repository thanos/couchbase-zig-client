const std = @import("std");
const c = @import("c.zig");

/// Log levels for the Couchbase client
pub const LogLevel = enum(u8) {
    debug,
    info,
    warn,
    err,
    fatal,
};

/// Error context information providing detailed error details
pub const ErrorContext = struct {
    /// The primary error that occurred
    err: Error,
    /// Additional context about where the error occurred
    operation: []const u8,
    /// Key or document identifier involved in the operation
    key: ?[]const u8,
    /// Collection/scope context
    collection: ?[]const u8,
    scope: ?[]const u8,
    /// Additional metadata about the error
    metadata: std.StringHashMap([]const u8),
    /// Timestamp when the error occurred
    timestamp: u64,
    /// libcouchbase status code
    status_code: c.lcb_STATUS,
    /// Error description from libcouchbase
    description: []const u8,
    /// Allocator for memory management
    allocator: std.mem.Allocator,

    pub fn deinit(self: *ErrorContext) void {
        if (self.key) |key| self.allocator.free(key);
        if (self.collection) |collection| self.allocator.free(collection);
        if (self.scope) |scope| self.allocator.free(scope);
        self.allocator.free(self.operation);
        self.allocator.free(self.description);
        
        var iterator = self.metadata.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.metadata.deinit();
    }

    /// Create a new error context
    pub fn create(
        allocator: std.mem.Allocator,
        err: Error,
        operation: []const u8,
        status_code: c.lcb_STATUS,
    ) !ErrorContext {
        const operation_owned = try allocator.dupe(u8, operation);
        const description = try getErrorDescription(allocator, status_code);
        const timestamp = @as(u64, @intCast(std.time.timestamp()));

        return ErrorContext{
            .err = err,
            .operation = operation_owned,
            .key = null,
            .collection = null,
            .scope = null,
            .metadata = std.StringHashMap([]const u8).init(allocator),
            .timestamp = timestamp,
            .status_code = status_code,
            .description = description,
            .allocator = allocator,
        };
    }

    /// Add a key to the error context
    pub fn withKey(self: *ErrorContext, key: []const u8) !void {
        if (self.key) |existing| self.allocator.free(existing);
        self.key = try self.allocator.dupe(u8, key);
    }

    /// Add collection/scope context
    pub fn withCollection(self: *ErrorContext, collection: []const u8, scope: []const u8) !void {
        if (self.collection) |existing| self.allocator.free(existing);
        if (self.scope) |existing| self.allocator.free(existing);
        self.collection = try self.allocator.dupe(u8, collection);
        self.scope = try self.allocator.dupe(u8, scope);
    }

    /// Add metadata to the error context
    pub fn addMetadata(self: *ErrorContext, key: []const u8, value: []const u8) !void {
        const key_owned = try self.allocator.dupe(u8, key);
        const value_owned = try self.allocator.dupe(u8, value);
        try self.metadata.put(key_owned, value_owned);
    }

    /// Format the error context as a string
    pub fn format(self: *const ErrorContext, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        
        try writer.print("ErrorContext{{\n", .{});
        try writer.print("  error: {s}\n", .{@errorName(self.err)});
        try writer.print("  operation: {s}\n", .{self.operation});
        if (self.key) |key| {
            try writer.print("  key: {s}\n", .{key});
        }
        if (self.collection) |collection| {
            try writer.print("  collection: {s}\n", .{collection});
        }
        if (self.scope) |scope| {
            try writer.print("  scope: {s}\n", .{scope});
        }
        try writer.print("  status_code: {}\n", .{self.status_code});
        try writer.print("  description: {s}\n", .{self.description});
        try writer.print("  timestamp: {}\n", .{self.timestamp});
        
        if (self.metadata.count() > 0) {
            try writer.print("  metadata: {{\n", .{});
            var iterator = self.metadata.iterator();
            while (iterator.next()) |entry| {
                try writer.print("    {s}: {s}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
            }
            try writer.print("  }}\n", .{});
        }
        try writer.print("}}", .{});
    }
};

/// Error types with enhanced context support
pub const Error = error{
    /// Generic error
    GenericError,
    /// Connection errors
    ConnectionFailed,
    ConnectionTimeout,
    NetworkError,
    CannotConnect,
    /// Authentication errors
    AuthenticationFailed,
    InvalidCredentials,
    /// Document errors
    DocumentNotFound,
    DocumentExists,
    DocumentLocked,
    /// Timeout errors
    Timeout,
    DurabilityTimeout,
    /// Server errors
    ServerError,
    TemporaryFailure,
    OutOfMemory,
    NotSupported,
    InternalError,
    /// Bucket/Scope/Collection errors
    BucketNotFound,
    ScopeNotFound,
    CollectionNotFound,
    /// Query errors
    QueryError,
    PlanningFailure,
    IndexNotFound,
    PreparedStatementFailure,
    PreparedStatementNotFound,
    QueryCancelled,
    /// Durability errors
    DurabilityImpossible,
    DurabilityAmbiguous,
    DurabilitySyncWriteInProgress,
    /// Subdocument errors
    SubdocPathNotFound,
    SubdocPathExists,
    SubdocPathMismatch,
    SubdocPathInvalid,
    SubdocValueTooDeep,
    /// Encoding errors
    EncodingError,
    DecodingError,
    InvalidArgument,
    /// Transaction errors
    TransactionNotActive,
    TransactionFailed,
    TransactionTimeout,
    TransactionConflict,
    TransactionRollbackFailed,
    /// Logging errors
    LoggingError,
    /// Other
    Unknown,
};

/// Get error description from libcouchbase status code
fn getErrorDescription(allocator: std.mem.Allocator, status_code: c.lcb_STATUS) ![]const u8 {
    const desc = c.lcb_strerror_short(status_code);
    return allocator.dupe(u8, std.mem.span(desc));
}

/// Convert libcouchbase status code to Zig error
pub fn fromStatusCode(rc: c.lcb_STATUS) Error!void {
    if (rc == c.LCB_SUCCESS) return;

    const rc_int: c_int = @intCast(rc);
    
    // Map known error codes (values from libcouchbase)
    if (rc == c.LCB_ERR_AUTHENTICATION_FAILURE) return error.AuthenticationFailed;
    if (rc == c.LCB_ERR_BUSY) return error.TemporaryFailure;
    if (rc == c.LCB_ERR_INVALID_ARGUMENT) return error.InvalidArgument;
    if (rc == c.LCB_ERR_NO_MEMORY) return error.OutOfMemory;
    if (rc == c.LCB_ERR_GENERIC) return error.GenericError;
    if (rc == c.LCB_ERR_TEMPORARY_FAILURE) return error.TemporaryFailure;
    if (rc == c.LCB_ERR_DOCUMENT_EXISTS) return error.DocumentExists;
    if (rc == c.LCB_ERR_DOCUMENT_NOT_FOUND) return error.DocumentNotFound;
    if (rc == c.LCB_ERR_ENCODING_FAILURE) return error.EncodingError;
    if (rc == c.LCB_ERR_TIMEOUT) return error.Timeout;
    if (rc == c.LCB_ERR_DOCUMENT_LOCKED) return error.DocumentLocked;
    if (rc == c.LCB_ERR_BUCKET_NOT_FOUND) return error.BucketNotFound;
    
    // Durability errors (if defined)
    if (rc_int == 0xD0) return error.DurabilityAmbiguous;
    if (rc_int == 0xD1) return error.DurabilityImpossible;
    if (rc_int == 0xD2) return error.DurabilitySyncWriteInProgress;
    
    // Subdoc errors (if defined)
    if (rc_int >= 0xC0 and rc_int <= 0xCF) return error.SubdocPathNotFound;
    
    // Collection errors (if defined)
    if (rc_int == 0x88) return error.CollectionNotFound;
    if (rc_int == 0x8C) return error.ScopeNotFound;
    
    return error.Unknown;
}
