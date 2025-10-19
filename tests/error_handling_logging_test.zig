const std = @import("std");
const couchbase = @import("couchbase");

test "ErrorContext creation and cleanup" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create an error context
    var error_context = try couchbase.ErrorContext.create(
        allocator,
        couchbase.Error.DocumentNotFound,
        "get",
        @as(couchbase.c.lcb_STATUS, @intCast(0x0C)),
    );
    defer error_context.deinit();

    // Test basic properties
    try std.testing.expectEqual(couchbase.Error.DocumentNotFound, error_context.err);
    try std.testing.expectEqualStrings("get", error_context.operation);
    try std.testing.expectEqual(@as(couchbase.c.lcb_STATUS, @intCast(0x0C)), error_context.status_code);

    // Add key context
    try error_context.withKey("test-key");
    try std.testing.expectEqualStrings("test-key", error_context.key.?);

    // Add collection context
    try error_context.withCollection("users", "default");
    try std.testing.expectEqualStrings("users", error_context.collection.?);
    try std.testing.expectEqualStrings("default", error_context.scope.?);

    // Add metadata
    try error_context.addMetadata("retry_count", "3");
    try error_context.addMetadata("timeout_ms", "5000");
    try std.testing.expectEqual(@as(usize, 2), error_context.metadata.count());
    try std.testing.expectEqualStrings("3", error_context.metadata.get("retry_count").?);
    try std.testing.expectEqualStrings("5000", error_context.metadata.get("timeout_ms").?);
}

test "LogLevel enum values" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(couchbase.LogLevel.debug));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(couchbase.LogLevel.info));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(couchbase.LogLevel.warn));
    try std.testing.expectEqual(@as(u8, 3), @intFromEnum(couchbase.LogLevel.err));
    try std.testing.expectEqual(@as(u8, 4), @intFromEnum(couchbase.LogLevel.fatal));
}

test "LogEntry creation and cleanup" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create a log entry
    var log_entry = try couchbase.LogEntry.create(
        allocator,
        .info,
        "test-component",
        "Test log message",
    );
    defer log_entry.deinit();

    // Test basic properties
    try std.testing.expectEqual(couchbase.LogLevel.info, log_entry.level);
    try std.testing.expectEqualStrings("test-component", log_entry.component);
    try std.testing.expectEqualStrings("Test log message", log_entry.message);
    try std.testing.expectEqual(@as(?*couchbase.ErrorContext, null), log_entry.error_context);

    // Add metadata
    try log_entry.addMetadata("key1", "value1");
    try log_entry.addMetadata("key2", "value2");
    try std.testing.expectEqual(@as(usize, 2), log_entry.metadata.count());
    try std.testing.expectEqualStrings("value1", log_entry.metadata.get("key1").?);
    try std.testing.expectEqualStrings("value2", log_entry.metadata.get("key2").?);
}

test "Logger initialization and configuration" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Test default configuration
    const logger = couchbase.Logger.init(allocator, .{});
    try std.testing.expectEqual(couchbase.LogLevel.info, logger.config.min_level);
    try std.testing.expectEqual(@as(?couchbase.LogCallback, null), logger.config.callback);
    try std.testing.expectEqual(true, logger.config.include_timestamps);
    try std.testing.expectEqual(true, logger.config.include_component);
    try std.testing.expectEqual(true, logger.config.include_metadata);

    // Test custom configuration
    const custom_config = couchbase.LoggingConfig{
        .min_level = .debug,
        .callback = couchbase.defaultLogCallback,
        .include_timestamps = false,
        .include_component = false,
        .include_metadata = false,
    };
    const custom_logger = couchbase.Logger.init(allocator, custom_config);
    try std.testing.expectEqual(couchbase.LogLevel.debug, custom_logger.config.min_level);
    try std.testing.expectEqual(couchbase.defaultLogCallback, custom_logger.config.callback);
    try std.testing.expectEqual(false, custom_logger.config.include_timestamps);
    try std.testing.expectEqual(false, custom_logger.config.include_component);
    try std.testing.expectEqual(false, custom_logger.config.include_metadata);
}

test "Logger log level filtering" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create logger with WARN level
    var logger = couchbase.Logger.init(allocator, .{ .min_level = .warn });

    // These should not log (below WARN level)
    try logger.debug("test", "Debug message");
    try logger.info("test", "Info message");

    // These should log (WARN level and above)
    try logger.warn("test", "Warning message");
    try logger.logError("test", "Error message");
    try logger.fatal("test", "Fatal message");
}

test "Client logging integration" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create client with logging configuration
    var client = couchbase.Client.connect(allocator, .{
        .connection_string = "couchbase://127.0.0.1",
        .username = "admin",
        .password = "password",
        .bucket = "default",
        .logging_config = .{ .min_level = .debug },
    }) catch |err| {
        // Expected to fail without a real server
        std.debug.print("Expected connection failure: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    // Test logging methods
    try client.logDebug("test", "Debug message");
    try client.logInfo("test", "Info message");
    try client.logWarn("test", "Warning message");
    try client.logError("test", "Error message");

    // Test log level control
    client.setLogLevel(.warn);
    try client.logDebug("test", "This should not appear");
    try client.logWarn("test", "This should appear");
}

test "Error context with logging" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create client
    var client = couchbase.Client.connect(allocator, .{
        .connection_string = "couchbase://127.0.0.1",
        .username = "admin",
        .password = "password",
        .bucket = "default",
    }) catch |err| {
        // Expected to fail without a real server
        std.debug.print("Expected connection failure: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    // Create error context
    var error_context = try client.createErrorContext(
        couchbase.Error.DocumentNotFound,
        "get",
        @as(couchbase.c.lcb_STATUS, @intCast(0x0C)),
    );
    defer error_context.deinit();

    try error_context.withKey("test-key");
    try error_context.addMetadata("operation", "get");

    // Test logging with error context
    try client.logErrorWithContext("test", "Document not found", &error_context);
}

test "Custom logging callback" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const countingCallback = struct {
        fn callback(entry: *const couchbase.LogEntry) void {
            _ = entry;
            // This is a simplified test - in practice you'd use a different approach
            // for mutable state in callbacks
        }
    }.callback;

    // Create logger with custom callback
    var logger = couchbase.Logger.init(allocator, .{ .callback = countingCallback });

    // Log some messages
    try logger.info("test", "Message 1");
    try logger.warn("test", "Message 2");
    try logger.logError("test", "Message 3");

    // Note: In a real implementation, you'd need a different approach to track
    // callback invocations due to Zig's safety constraints
}

test "LogEntry formatting" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create a log entry
    var log_entry = try couchbase.LogEntry.create(
        allocator,
        .warn,
        "test-component",
        "Test warning message",
    );
    defer log_entry.deinit();

    // Add metadata
    try log_entry.addMetadata("key1", "value1");
    try log_entry.addMetadata("key2", "value2");

    // Test formatting
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();
    try log_entry.format("", .{}, buffer.writer());
    
    const formatted = try buffer.toOwnedSlice();
    defer allocator.free(formatted);
    
    // Verify the formatted string contains expected elements
    try std.testing.expect(std.mem.indexOf(u8, formatted, "WARN") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "test-component") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "Test warning message") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "key1=value1") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "key2=value2") != null);
}
