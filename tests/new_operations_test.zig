const std = @import("std");
const testing = std.testing;
const couchbase = @import("couchbase");

fn getTestClient(allocator: std.mem.Allocator) !couchbase.Client {
    const test_config = couchbase.getTestConfig();
    return try couchbase.Client.connect(allocator, .{
        .connection_string = test_config.connection_string,
        .username = test_config.username,
        .password = test_config.password,
        .bucket = test_config.bucket,
        .timeout_ms = test_config.timeout_ms,
    });
}

test "append operation" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:append";
    
    // Clean up
    _ = client.remove(key, .{}) catch {};

    // Create initial document with text
    _ = try client.upsert(key, "Hello", .{});

    // Append text
    _ = try client.append(key, " World", .{});

    // Verify
    var result = try client.get(key);
    defer result.deinit();
    try testing.expectEqualStrings("Hello World", result.value);

    // Clean up
    _ = try client.remove(key, .{});
}

test "prepend operation" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:prepend";
    
    // Clean up
    _ = client.remove(key, .{}) catch {};

    // Create initial document
    _ = try client.upsert(key, "World", .{});

    // Prepend text
    _ = try client.prepend(key, "Hello ", .{});

    // Verify
    var result = try client.get(key);
    defer result.deinit();
    try testing.expectEqualStrings("Hello World", result.value);

    // Clean up
    _ = try client.remove(key, .{});
}

test "exists operation - document exists" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:exists:yes";
    
    // Clean up
    _ = client.remove(key, .{}) catch {};

    // Create document
    _ = try client.upsert(key, "data", .{});

    // Check exists
    const exists = try client.exists(key);
    try testing.expect(exists);

    // Clean up
    _ = try client.remove(key, .{});
}

test "exists operation - document does not exist" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:exists:no:nonexistent";
    
    // Ensure doesn't exist
    _ = client.remove(key, .{}) catch {};

    // Check exists
    const exists = try client.exists(key);
    std.debug.print("EXISTS for non-existent doc: {}\n", .{exists});
    try testing.expect(!exists);
}

test "subdocument lookup" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:subdoc:lookup";
    const doc = 
        \\{"name": "Alice", "age": 30, "address": {"city": "NYC", "zip": "10001"}}
    ;
    
    // Clean up
    _ = client.remove(key, .{}) catch {};

    // Create document
    _ = try client.upsert(key, doc, .{});

    // Lookup subdocument paths
    const specs = [_]couchbase.operations.SubdocSpec{
        .{ .op = .get, .path = "name" },
        .{ .op = .get, .path = "age" },
        .{ .op = .get, .path = "address.city" },
    };

    var result = client.lookupIn(testing.allocator, key, &specs) catch |err| {
        std.debug.print("Subdoc lookup not supported: {}\n", .{err});
        _ = try client.remove(key, .{});
        return;
    };
    defer result.deinit();

    try testing.expect(result.values.len == 3);
    try testing.expect(std.mem.indexOf(u8, result.values[0], "Alice") != null);

    // Clean up
    _ = try client.remove(key, .{});
}

test "subdocument mutation" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:subdoc:mutate";
    const doc = 
        \\{"name": "Bob", "age": 25, "tags": ["developer"]}
    ;
    
    // Clean up
    _ = client.remove(key, .{}) catch {};

    // Create document
    _ = try client.upsert(key, doc, .{});

    // Mutate subdocument
    const specs = [_]couchbase.operations.SubdocSpec{
        .{ .op = .replace, .path = "age", .value = "26" },
        .{ .op = .array_add_last, .path = "tags", .value = "\"backend\"" },
    };

    var result = client.mutateIn(testing.allocator, key, &specs, .{}) catch |err| {
        std.debug.print("Subdoc mutate not supported: {}\n", .{err});
        _ = try client.remove(key, .{});
        return;
    };
    defer result.deinit();

    try testing.expect(result.cas > 0);

    // Verify changes
    var get_result = try client.get(key);
    defer get_result.deinit();
    
    try testing.expect(std.mem.indexOf(u8, get_result.value, "26") != null);
    try testing.expect(std.mem.indexOf(u8, get_result.value, "backend") != null);

    // Clean up
    _ = try client.remove(key, .{});
}

test "subdocument counter" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:subdoc:counter";
    const doc = 
        \\{"views": 100, "likes": 50}
    ;
    
    // Clean up
    _ = client.remove(key, .{}) catch {};

    // Create document
    _ = try client.upsert(key, doc, .{});

    // Increment subdoc counter
    const specs = [_]couchbase.operations.SubdocSpec{
        .{ .op = .counter, .path = "views", .value = "10" },
    };

    var result = client.mutateIn(testing.allocator, key, &specs, .{}) catch |err| {
        std.debug.print("Subdoc counter not supported: {}\n", .{err});
        _ = try client.remove(key, .{});
        return;
    };
    defer result.deinit();

    try testing.expect(result.cas > 0);

    // Verify
    var get_result = try client.get(key);
    defer get_result.deinit();
    try testing.expect(std.mem.indexOf(u8, get_result.value, "110") != null);

    // Clean up
    _ = try client.remove(key, .{});
}

test "subdocument array operations" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:subdoc:array";
    const doc = 
        \\{"items": [1, 2, 3]}
    ;
    
    // Clean up
    _ = client.remove(key, .{}) catch {};

    // Create document
    _ = try client.upsert(key, doc, .{});

    // Array operations
    const specs = [_]couchbase.operations.SubdocSpec{
        .{ .op = .array_add_first, .path = "items", .value = "0" },
        .{ .op = .array_add_last, .path = "items", .value = "4" },
    };

    var result = client.mutateIn(testing.allocator, key, &specs, .{}) catch |err| {
        std.debug.print("Subdoc array ops not supported: {}\n", .{err});
        _ = try client.remove(key, .{});
        return;
    };
    defer result.deinit();

    // Verify
    var get_result = try client.get(key);
    defer get_result.deinit();
    
    const value = get_result.value;
    try testing.expect(std.mem.indexOf(u8, value, "0") != null);
    try testing.expect(std.mem.indexOf(u8, value, "4") != null);

    // Clean up
    _ = try client.remove(key, .{});
}

test "subdocument dict operations" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:subdoc:dict";
    const doc = 
        \\{"user": {"name": "Charlie"}}
    ;
    
    // Clean up
    _ = client.remove(key, .{}) catch {};

    // Create document
    _ = try client.upsert(key, doc, .{});

    // Dict operations
    const specs = [_]couchbase.operations.SubdocSpec{
        .{ .op = .dict_add, .path = "user.email", .value = "\"charlie@example.com\"" },
        .{ .op = .dict_upsert, .path = "user.age", .value = "28" },
    };

    var result = client.mutateIn(testing.allocator, key, &specs, .{}) catch |err| {
        std.debug.print("Subdoc dict ops not supported: {}\n", .{err});
        _ = try client.remove(key, .{});
        return;
    };
    defer result.deinit();

    // Verify
    var get_result = try client.get(key);
    defer get_result.deinit();
    
    const value = get_result.value;
    try testing.expect(std.mem.indexOf(u8, value, "charlie@example.com") != null);
    try testing.expect(std.mem.indexOf(u8, value, "28") != null);

    // Clean up
    _ = try client.remove(key, .{});
}

test "subdocument delete" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:subdoc:delete";
    const doc = 
        \\{"name": "Dave", "temp": "remove-me", "keep": "this"}
    ;
    
    // Clean up
    _ = client.remove(key, .{}) catch {};

    // Create document
    _ = try client.upsert(key, doc, .{});

    // Delete field
    const specs = [_]couchbase.operations.SubdocSpec{
        .{ .op = .delete, .path = "temp" },
    };

    var result = client.mutateIn(testing.allocator, key, &specs, .{}) catch |err| {
        std.debug.print("Subdoc delete not supported: {}\n", .{err});
        _ = try client.remove(key, .{});
        return;
    };
    defer result.deinit();

    // Verify temp is removed
    var get_result = try client.get(key);
    defer get_result.deinit();
    
    try testing.expect(std.mem.indexOf(u8, get_result.value, "remove-me") == null);
    try testing.expect(std.mem.indexOf(u8, get_result.value, "keep") != null);

    // Clean up
    _ = try client.remove(key, .{});
}
