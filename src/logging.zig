const std = @import("std");
const c = @import("c.zig");
const ErrorContext = @import("error_context.zig").ErrorContext;
const LogLevel = @import("error_context.zig").LogLevel;

/// Log entry containing structured log information
pub const LogEntry = struct {
    /// Log level
    level: LogLevel,
    /// Log message
    message: []const u8,
    /// Timestamp
    timestamp: u64,
    /// Component that generated the log
    component: []const u8,
    /// Optional error context
    error_context: ?*ErrorContext,
    /// Additional metadata
    metadata: std.StringHashMap([]const u8),
    /// Allocator for memory management
    allocator: std.mem.Allocator,

    pub fn deinit(self: *LogEntry) void {
        self.allocator.free(self.message);
        self.allocator.free(self.component);
        
        var iterator = self.metadata.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.metadata.deinit();
    }

    /// Create a new log entry
    pub fn create(
        allocator: std.mem.Allocator,
        level: LogLevel,
        component: []const u8,
        message: []const u8,
    ) !LogEntry {
        const component_owned = try allocator.dupe(u8, component);
        const message_owned = try allocator.dupe(u8, message);
        const timestamp = @as(u64, @intCast(std.time.timestamp()));

        return LogEntry{
            .level = level,
            .message = message_owned,
            .timestamp = timestamp,
            .component = component_owned,
            .error_context = null,
            .metadata = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    /// Add metadata to the log entry
    pub fn addMetadata(self: *LogEntry, key: []const u8, value: []const u8) !void {
        const key_owned = try self.allocator.dupe(u8, key);
        const value_owned = try self.allocator.dupe(u8, value);
        try self.metadata.put(key_owned, value_owned);
    }

    /// Format the log entry as a string
    pub fn format(self: *const LogEntry, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        
        const level_str = switch (self.level) {
            .debug => "DEBUG",
            .info => "INFO",
            .warn => "WARN",
            .err => "ERROR",
            .fatal => "FATAL",
        };
        
        try writer.print("[{}] {s} {s}: {s}", .{ 
            self.timestamp, 
            level_str, 
            self.component, 
            self.message 
        });
        
        if (self.error_context) |ctx| {
            try writer.print(" (Error: {s})", .{@errorName(ctx.err)});
        }
        
        if (self.metadata.count() > 0) {
            try writer.print(" [", .{});
            var iterator = self.metadata.iterator();
            var first = true;
            while (iterator.next()) |entry| {
                if (!first) try writer.print(", ", .{});
                try writer.print("{s}={s}", .{ entry.key_ptr.*, entry.value_ptr.* });
                first = false;
            }
            try writer.print("]", .{});
        }
    }
};

/// Custom logging callback function type
pub const LogCallback = *const fn (entry: *const LogEntry) void;

/// Default logging callback that prints to stderr
pub fn defaultLogCallback(entry: *const LogEntry) void {
    std.debug.print("{}\n", .{entry});
}

/// Logging configuration
pub const LoggingConfig = struct {
    /// Minimum log level to output
    min_level: LogLevel = .info,
    /// Custom logging callback (if null, uses default)
    callback: ?LogCallback = null,
    /// Whether to include timestamps
    include_timestamps: bool = true,
    /// Whether to include component names
    include_component: bool = true,
    /// Whether to include metadata
    include_metadata: bool = true,
};

/// Logger instance for the Couchbase client
pub const Logger = struct {
    config: LoggingConfig,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, config: LoggingConfig) Logger {
        return Logger{
            .config = config,
            .allocator = allocator,
        };
    }

    /// Log a message at the specified level
    pub fn log(self: *Logger, level: LogLevel, component: []const u8, message: []const u8) !void {
        if (@intFromEnum(level) < @intFromEnum(self.config.min_level)) {
            return; // Skip logging if below minimum level
        }

        var entry = try LogEntry.create(self.allocator, level, component, message);
        defer entry.deinit();

        if (self.config.callback) |callback| {
            callback(&entry);
        } else {
            defaultLogCallback(&entry);
        }
    }

    /// Log a debug message
    pub fn debug(self: *Logger, component: []const u8, message: []const u8) !void {
        try self.log(.debug, component, message);
    }

    /// Log an info message
    pub fn info(self: *Logger, component: []const u8, message: []const u8) !void {
        try self.log(.info, component, message);
    }

    /// Log a warning message
    pub fn warn(self: *Logger, component: []const u8, message: []const u8) !void {
        try self.log(.warn, component, message);
    }

    /// Log an error message
    pub fn logError(self: *Logger, component: []const u8, message: []const u8) !void {
        try self.log(.err, component, message);
    }

    /// Log a fatal message
    pub fn fatal(self: *Logger, component: []const u8, message: []const u8) !void {
        try self.log(.fatal, component, message);
    }

    /// Log an error with context
    pub fn logErrorWithContext(self: *Logger, component: []const u8, message: []const u8, error_context: *ErrorContext) !void {
        if (@intFromEnum(LogLevel.err) < @intFromEnum(self.config.min_level)) {
            return; // Skip logging if below minimum level
        }

        var entry = try LogEntry.create(self.allocator, .err, component, message);
        entry.error_context = error_context;
        defer entry.deinit();

        if (self.config.callback) |callback| {
            callback(&entry);
        } else {
            defaultLogCallback(&entry);
        }
    }

    /// Set the minimum log level
    pub fn setMinLevel(self: *Logger, level: LogLevel) void {
        self.config.min_level = level;
    }

    /// Set a custom logging callback
    pub fn setCallback(self: *Logger, callback: ?LogCallback) void {
        self.config.callback = callback;
    }
};
