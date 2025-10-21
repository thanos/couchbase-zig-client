const std = @import("std");
const couchbase = @import("couchbase");

test "FeatureFlags initialization and properties" {
    var features = couchbase.FeatureFlags{};
    
    // Test default values
    try std.testing.expectEqual(false, features.collections);
    try std.testing.expectEqual(false, features.dcp);
    try std.testing.expectEqual(false, features.durability);
    try std.testing.expectEqual(false, features.tracing);
    try std.testing.expectEqual(false, features.binary_data);
    try std.testing.expectEqual(false, features.compression);
    
    // Test setting values
    features.collections = true;
    features.dcp = true;
    features.durability = true;
    
    try std.testing.expectEqual(true, features.collections);
    try std.testing.expectEqual(true, features.dcp);
    try std.testing.expectEqual(true, features.durability);
}

test "ProtocolVersion creation and formatting" {
    const version = couchbase.ProtocolVersion{
        .major = 3,
        .minor = 2,
        .patch = 1,
    };
    
    try std.testing.expectEqual(@as(u8, 3), version.major);
    try std.testing.expectEqual(@as(u8, 2), version.minor);
    try std.testing.expectEqual(@as(u8, 1), version.patch);
    
    // Test formatting
    var buffer = std.ArrayList(u8).init(std.testing.allocator);
    defer buffer.deinit();
    try version.format("", .{}, buffer.writer());
    
    const formatted = try buffer.toOwnedSlice();
    defer std.testing.allocator.free(formatted);
    
    try std.testing.expectEqualStrings("3.2.1", formatted);
}

test "BinaryDocument creation and cleanup" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const data = "test binary data";
    const content_type = try allocator.dupe(u8, "application/octet-stream");
    
    var doc = couchbase.BinaryDocument{
        .data = data,
        .content_type = content_type,
        .flags = 0x12345678,
    };
    
    try std.testing.expectEqualStrings("test binary data", doc.data);
    try std.testing.expectEqualStrings("application/octet-stream", doc.content_type.?);
    try std.testing.expectEqual(@as(u32, 0x12345678), doc.flags);
    
    // Test cleanup
    doc.deinit(allocator);
}

test "BinaryOperationContext collection management" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var context = couchbase.BinaryOperationContext{};
    defer context.deinit(allocator);
    
    // Test initial state
    try std.testing.expectEqual(@as(?[]const u8, null), context.collection);
    try std.testing.expectEqual(@as(?[]const u8, null), context.scope);
    
    // Test setting collection
    try context.withCollection(allocator, "users", "default");
    try std.testing.expectEqualStrings("users", context.collection.?);
    try std.testing.expectEqualStrings("default", context.scope.?);
    
    // Test changing collection
    try context.withCollection(allocator, "products", "inventory");
    try std.testing.expectEqualStrings("products", context.collection.?);
    try std.testing.expectEqualStrings("inventory", context.scope.?);
}

test "DcpEvent creation and cleanup" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const key = try allocator.dupe(u8, "test-key");
    const value = try allocator.dupe(u8, "test-value");
    
    var event = couchbase.DcpEvent{
        .event_type = .mutation,
        .key = key,
        .value = value,
        .cas = 12345,
        .flags = 0x87654321,
        .expiry = 3600,
        .sequence = 67890,
        .vbucket = 5,
        .allocator = allocator,
    };
    
    try std.testing.expectEqual(couchbase.DcpEventType.mutation, event.event_type);
    try std.testing.expectEqualStrings("test-key", event.key);
    try std.testing.expectEqualStrings("test-value", event.value.?);
    try std.testing.expectEqual(@as(u64, 12345), event.cas);
    try std.testing.expectEqual(@as(u32, 0x87654321), event.flags);
    try std.testing.expectEqual(@as(u32, 3600), event.expiry);
    try std.testing.expectEqual(@as(u64, 67890), event.sequence);
    try std.testing.expectEqual(@as(u16, 5), event.vbucket);
    
    // Test cleanup
    event.deinit();
}

test "DcpEventType enum values" {
    try std.testing.expectEqual(@as(u32, 0), @intFromEnum(couchbase.DcpEventType.mutation));
    try std.testing.expectEqual(@as(u32, 1), @intFromEnum(couchbase.DcpEventType.deletion));
    try std.testing.expectEqual(@as(u32, 2), @intFromEnum(couchbase.DcpEventType.expiration));
    try std.testing.expectEqual(@as(u32, 3), @intFromEnum(couchbase.DcpEventType.stream_end));
    try std.testing.expectEqual(@as(u32, 4), @intFromEnum(couchbase.DcpEventType.snapshot_marker));
}

test "BinaryProtocol initialization" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const protocol = couchbase.BinaryProtocol.init(allocator);
    
    // Test initial state
    try std.testing.expectEqual(false, protocol.feature_flags.collections);
    try std.testing.expectEqual(false, protocol.feature_flags.dcp);
    try std.testing.expectEqual(@as(?couchbase.ProtocolVersion, null), protocol.protocol_version);
}

test "Client binary protocol integration" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Test client creation with binary protocol
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
    
    // Test binary protocol methods
    try client.negotiateBinaryFeatures();
    
    const features = client.getBinaryFeatureFlags();
    try std.testing.expectEqual(false, features.collections);
    try std.testing.expectEqual(false, features.dcp);
    
    const version = client.getProtocolVersion();
    try std.testing.expectEqual(@as(?couchbase.ProtocolVersion, null), version);
}

test "Binary document operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
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
    
    // Test binary document operations
    var binary_doc = couchbase.BinaryDocument{
        .data = "test data",
        .content_type = try allocator.dupe(u8, "text/plain"),
        .flags = 0x12345678,
    };
    defer binary_doc.deinit(allocator);
    
    var context = couchbase.BinaryOperationContext{};
    defer context.deinit(allocator);
    try context.withCollection(allocator, "test", "default");
    
    // These operations will fail without a real server, but we can test the API
    client.storeBinary("test-key", binary_doc, &context) catch |err| {
        std.debug.print("Expected store failure: {}\n", .{err});
    };
    
    _ = client.getBinary("test-key", &context) catch |err| {
        std.debug.print("Expected get failure: {}\n", .{err});
        return;
    };
}

test "DCP operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
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
    
    // Test DCP operations
    client.startDcpStream("default", 0) catch |err| {
        std.debug.print("Expected DCP start failure: {}\n", .{err});
    };
    
    const event = client.getNextDcpEvent() catch |err| {
        std.debug.print("Expected DCP event failure: {}\n", .{err});
        return;
    };
    
    try std.testing.expectEqual(@as(?couchbase.DcpEvent, null), event);
}
