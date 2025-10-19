const std = @import("std");
const couchbase = @import("couchbase");

/// Custom logging callback that writes to a file
fn customLogCallback(entry: *const couchbase.LogEntry) void {
    const file = std.fs.cwd().openFile("couchbase.log", .{ .mode = .write_only }) catch return;
    defer file.close();
    
    file.writer().print("{}\n", .{entry}) catch {};
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Couchbase Error Handling & Logging Demo ===\n\n", .{});

    // Configure logging
    const logging_config = couchbase.LoggingConfig{
        .min_level = .debug,
        .callback = customLogCallback,
        .include_timestamps = true,
        .include_component = true,
        .include_metadata = true,
    };

    // Connect with logging configuration
    var client = couchbase.Client.connect(allocator, .{
        .connection_string = "couchbase://127.0.0.1",
        .username = "admin",
        .password = "password",
        .bucket = "default",
        .logging_config = logging_config,
    }) catch |err| {
        std.debug.print("Failed to connect: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    // Demonstrate logging at different levels
    std.debug.print("1. Demonstrating different log levels...\n", .{});
    try client.logDebug("demo", "This is a debug message");
    try client.logInfo("demo", "This is an info message");
    try client.logWarn("demo", "This is a warning message");
    try client.logError("demo", "This is an error message");

    // Demonstrate error context creation
    std.debug.print("\n2. Demonstrating error context...\n", .{});
    
    // Create an error context for a failed operation
    var error_context = try client.createErrorContext(
        couchbase.Error.DocumentNotFound,
        "get",
        @as(couchbase.c.lcb_STATUS, @intCast(0x0C)),
    );
    defer error_context.deinit();

    // Add additional context
    try error_context.withKey("user:123");
    try error_context.withCollection("users", "default");
    try error_context.addMetadata("retry_count", "3");
    try error_context.addMetadata("timeout_ms", "5000");

    // Log the error with context
    try client.logErrorWithContext("demo", "Failed to retrieve document", &error_context);

    // Demonstrate log level control
    std.debug.print("\n3. Demonstrating log level control...\n", .{});
    
    // Set log level to WARN (should suppress DEBUG and INFO)
    client.setLogLevel(.warn);
    try client.logDebug("demo", "This debug message should not appear");
    try client.logInfo("demo", "This info message should not appear");
    try client.logWarn("demo", "This warning message should appear");
    try client.logError("demo", "This error message should appear");

    // Demonstrate custom logging callback
    std.debug.print("\n4. Demonstrating custom logging callback...\n", .{});
    
    // Set a custom callback that prints to stdout with custom format
    const customCallback = struct {
        fn callback(entry: *const couchbase.LogEntry) void {
            const level_str = switch (entry.level) {
                .debug => "🐛",
                .info => "ℹ️",
                .warn => "⚠️",
                .err => "❌",
                .fatal => "💀",
            };
            std.debug.print("{s} [{}] {s}: {s}\n", .{ 
                level_str, 
                entry.timestamp, 
                entry.component, 
                entry.message 
            });
        }
    }.callback;

    client.setLogCallback(customCallback);
    try client.logInfo("demo", "This message uses the custom callback");
    try client.logWarn("demo", "This warning uses the custom callback");

    // Demonstrate error context formatting
    std.debug.print("\n5. Demonstrating error context formatting...\n", .{});
    std.debug.print("Error Context: {}\n", .{error_context});

    // Demonstrate operations with logging
    std.debug.print("\n6. Demonstrating operations with logging...\n", .{});
    
    // Try to get a document that doesn't exist (this will log an error)
    const result = client.get("nonexistent-key") catch |err| {
        // Create error context for this specific operation
        var op_error_context = try client.createErrorContext(
            err,
            "get",
            @as(couchbase.c.lcb_STATUS, @intCast(0x0C)),
        );
        defer op_error_context.deinit();
        
        try op_error_context.withKey("nonexistent-key");
        try op_error_context.addMetadata("operation", "get");
        try op_error_context.addMetadata("bucket", "default");
        
        // Log the error with context
        try client.logErrorWithContext("operations", "Document not found", &op_error_context);
        return;
    };
    defer result.deinit();

    std.debug.print("\n=== Error Handling & Logging Demo Complete ===\n", .{});
}
