const std = @import("std");
const couchbase = @import("couchbase");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Couchbase Binary Protocol Features Demo ===\n\n", .{});

    // Connect to Couchbase
    var client = couchbase.Client.connect(allocator, .{
        .connection_string = "couchbase://127.0.0.1",
        .username = "admin",
        .password = "password",
        .bucket = "default",
    }) catch |err| {
        std.debug.print("Failed to connect: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    // 1. Negotiate binary protocol features
    std.debug.print("1. Negotiating binary protocol features...\n", .{});
    try client.negotiateBinaryFeatures();
    
    // Get feature flags
    const features = client.getBinaryFeatureFlags();
    std.debug.print("Feature flags: collections={}, dcp={}, durability={}, tracing={}, binary_data={}, compression={}\n", .{
        features.collections,
        features.dcp,
        features.durability,
        features.tracing,
        features.binary_data,
        features.compression,
    });

    // Get protocol version
    if (client.getProtocolVersion()) |version| {
        std.debug.print("Protocol version: {}\n", .{version});
    } else {
        std.debug.print("Protocol version: Not negotiated\n", .{});
    }

    // 2. Binary document operations
    std.debug.print("\n2. Binary document operations...\n", .{});
    
    // Create binary document
    const binary_data = "Hello, Binary World!";
    var binary_doc = couchbase.BinaryDocument{
        .data = binary_data,
        .content_type = try allocator.dupe(u8, "application/octet-stream"),
        .flags = 0x12345678,
    };
    defer binary_doc.deinit(allocator);

    // Create collection context
    var context = couchbase.BinaryOperationContext{};
    defer context.deinit(allocator);
    
    try context.withCollection(allocator, "users", "default");
    std.debug.print("Collection context: scope={s}, collection={s}\n", .{ context.scope.?, context.collection.? });

    // Store binary document
    try client.storeBinary("binary-key-1", binary_doc, &context);
    std.debug.print("Stored binary document with key: binary-key-1\n", .{});

    // Retrieve binary document
    var retrieved_doc = try client.getBinary("binary-key-1", &context);
    defer retrieved_doc.deinit(allocator);
    
    std.debug.print("Retrieved binary document: {s}\n", .{retrieved_doc.data});
    if (retrieved_doc.content_type) |ct| {
        std.debug.print("Content type: {s}\n", .{ct});
    }
    std.debug.print("Flags: 0x{x}\n", .{retrieved_doc.flags});

    // 3. DCP (Database Change Protocol) demonstration
    std.debug.print("\n3. DCP (Database Change Protocol) demonstration...\n", .{});
    
    // Start DCP stream
    try client.startDcpStream("default", 0);
    std.debug.print("Started DCP stream for bucket 'default', vbucket 0\n", .{});

    // Simulate getting DCP events
    std.debug.print("Listening for DCP events...\n", .{});
    for (0..3) |i| {
        if (try client.getNextDcpEvent()) |event| {
            var mutable_event = event;
            defer mutable_event.deinit();
            
            const event_type_str = switch (mutable_event.event_type) {
                .mutation => "MUTATION",
                .deletion => "DELETION",
                .expiration => "EXPIRATION",
                .stream_end => "STREAM_END",
                .snapshot_marker => "SNAPSHOT_MARKER",
            };
            
            std.debug.print("DCP Event {}: type={s}, key={s}, cas={}, vbucket={}\n", .{
                i + 1,
                event_type_str,
                mutable_event.key,
                mutable_event.cas,
                mutable_event.vbucket,
            });
        } else {
            std.debug.print("No DCP events available\n", .{});
            break;
        }
    }

    // 4. Feature flag demonstration
    std.debug.print("\n4. Feature flag demonstration...\n", .{});
    
    std.debug.print("Binary protocol capabilities:\n", .{});
    std.debug.print("  - Collections in Protocol: {}\n", .{features.collections});
    std.debug.print("  - DCP Support: {}\n", .{features.dcp});
    std.debug.print("  - Server-side Durability: {}\n", .{features.durability});
    std.debug.print("  - Response Time Tracing: {}\n", .{features.tracing});
    std.debug.print("  - Binary Data Handling: {}\n", .{features.binary_data});
    std.debug.print("  - Advanced Compression: {}\n", .{features.compression});

    // 5. Protocol version information
    std.debug.print("\n5. Protocol version information...\n", .{});
    
    if (client.getProtocolVersion()) |version| {
        std.debug.print("Negotiated protocol version: {}\n", .{version});
        std.debug.print("  - Major: {}\n", .{version.major});
        std.debug.print("  - Minor: {}\n", .{version.minor});
        std.debug.print("  - Patch: {}\n", .{version.patch});
    } else {
        std.debug.print("Protocol version not yet negotiated\n", .{});
    }

    std.debug.print("\n=== Binary Protocol Features Demo Complete ===\n", .{});
}
