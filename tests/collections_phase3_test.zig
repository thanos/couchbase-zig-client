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

test "collection-aware get replica operation" {
    var client = getTestClient(testing.allocator) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    // Use default collection
    var collection = try couchbase.Collection.default(testing.allocator);
    defer collection.deinit();

    const key = "collection_replica_test_key";
    const value = "{\"message\": \"collection replica test\"}";

    // First upsert a document
    const upsert_result = try client.upsertWithCollection(key, value, collection, .{});
    try testing.expect(upsert_result.cas > 0);

    // Get from replica (any mode)
    var replica_result = client.getReplicaWithCollection(key, collection, .any) catch |err| {
        // Replica might not be available in single-node setup
        if (err == couchbase.Error.DocumentNotFound or err == couchbase.Error.Unknown) {
            // This is expected in single-node setup
            return;
        }
        return err;
    };
    defer replica_result.deinit();

    try testing.expectEqualStrings(value, replica_result.value);
    try testing.expect(replica_result.cas > 0);

    // Clean up
    _ = client.removeWithCollection(key, collection, .{}) catch {};
}

test "collection-aware subdocument lookup operation" {
    var client = getTestClient(testing.allocator) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    // Use default collection
    var collection = try couchbase.Collection.default(testing.allocator);
    defer collection.deinit();

    const key = "collection_subdoc_lookup_test_key";
    const value = "{\"name\": \"John\", \"age\": 30, \"city\": \"New York\"}";

    // First upsert a document
    const upsert_result = try client.upsertWithCollection(key, value, collection, .{});
    try testing.expect(upsert_result.cas > 0);

    // Create subdocument specs
    const specs = [_]couchbase.operations.SubdocSpec{
        .{ .op = .get, .path = "name" },
        .{ .op = .get, .path = "age" },
        .{ .op = .exists, .path = "city" },
    };

    // Perform subdocument lookup
    var subdoc_result = try client.lookupInWithCollection(testing.allocator, key, collection, &specs);
    defer subdoc_result.deinit();

    try testing.expect(subdoc_result.values.len == 3);
    try testing.expectEqualStrings("\"John\"", subdoc_result.values[0]);
    try testing.expectEqualStrings("30", subdoc_result.values[1]);
    // exists operation returns the value if it exists, not empty string
    try testing.expectEqualStrings("\"New York\"", subdoc_result.values[2]);

    // Clean up
    _ = client.removeWithCollection(key, collection, .{}) catch {};
}

test "collection-aware subdocument mutation operation" {
    var client = getTestClient(testing.allocator) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    // Use default collection
    var collection = try couchbase.Collection.default(testing.allocator);
    defer collection.deinit();

    const key = "collection_subdoc_mutation_test_key";
    const value = "{\"name\": \"John\", \"age\": 30}";

    // First upsert a document
    const upsert_result = try client.upsertWithCollection(key, value, collection, .{});
    try testing.expect(upsert_result.cas > 0);

    // Create subdocument mutation specs
    const specs = [_]couchbase.operations.SubdocSpec{
        .{ .op = .dict_upsert, .path = "city", .value = "\"New York\"" },
        .{ .op = .replace, .path = "age", .value = "31" },
    };

    // Perform subdocument mutation
    var subdoc_result = try client.mutateInWithCollection(testing.allocator, key, collection, &specs, .{});
    defer subdoc_result.deinit();

    try testing.expect(subdoc_result.cas > upsert_result.cas);

    // Verify the changes by getting the document
    var get_result = try client.getWithCollection(key, collection);
    defer get_result.deinit();

    // Parse the result to verify changes
    const updated_value = get_result.value;
    try testing.expect(std.mem.indexOf(u8, updated_value, "city") != null);
    try testing.expect(std.mem.indexOf(u8, updated_value, "31") != null);

    // Clean up
    _ = client.removeWithCollection(key, collection, .{}) catch {};
}

test "collection-aware subdocument array operations" {
    var client = getTestClient(testing.allocator) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    // Use default collection
    var collection = try couchbase.Collection.default(testing.allocator);
    defer collection.deinit();

    const key = "collection_subdoc_array_test_key";
    const value = "{\"items\": [\"apple\", \"banana\"]}";

    // First upsert a document
    const upsert_result = try client.upsertWithCollection(key, value, collection, .{});
    try testing.expect(upsert_result.cas > 0);

    // Create subdocument array mutation specs
    const specs = [_]couchbase.operations.SubdocSpec{
        .{ .op = .array_add_last, .path = "items", .value = "\"orange\"" },
        .{ .op = .array_add_first, .path = "items", .value = "\"grape\"" },
    };

    // Perform subdocument mutation
    var subdoc_result = try client.mutateInWithCollection(testing.allocator, key, collection, &specs, .{});
    defer subdoc_result.deinit();

    try testing.expect(subdoc_result.cas > upsert_result.cas);

    // Verify the changes by getting the document
    var get_result = try client.getWithCollection(key, collection);
    defer get_result.deinit();

    // Parse the result to verify changes
    const updated_value = get_result.value;
    try testing.expect(std.mem.indexOf(u8, updated_value, "\"grape\"") != null);
    try testing.expect(std.mem.indexOf(u8, updated_value, "\"orange\"") != null);

    // Clean up
    _ = client.removeWithCollection(key, collection, .{}) catch {};
}

test "collection-aware subdocument counter operation" {
    var client = getTestClient(testing.allocator) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    // Use default collection
    var collection = try couchbase.Collection.default(testing.allocator);
    defer collection.deinit();

    const key = "collection_subdoc_counter_test_key";
    const value = "{\"count\": 10}";

    // First upsert a document
    const upsert_result = try client.upsertWithCollection(key, value, collection, .{});
    try testing.expect(upsert_result.cas > 0);

    // Create subdocument counter spec
    const specs = [_]couchbase.operations.SubdocSpec{
        .{ .op = .counter, .path = "count", .value = "5" }, // Add 5 to count
    };

    // Perform subdocument mutation
    var subdoc_result = try client.mutateInWithCollection(testing.allocator, key, collection, &specs, .{});
    defer subdoc_result.deinit();

    try testing.expect(subdoc_result.cas > upsert_result.cas);

    // Verify the changes by getting the document
    var get_result = try client.getWithCollection(key, collection);
    defer get_result.deinit();

    // Parse the result to verify changes
    const updated_value = get_result.value;
    try testing.expect(std.mem.indexOf(u8, updated_value, "15") != null);

    // Clean up
    _ = client.removeWithCollection(key, collection, .{}) catch {};
}

test "collection-aware subdocument error handling" {
    var client = getTestClient(testing.allocator) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    // Use default collection
    var collection = try couchbase.Collection.default(testing.allocator);
    defer collection.deinit();

    const key = "nonexistent_subdoc_key";

    // Create subdocument specs for non-existent document
    const specs = [_]couchbase.operations.SubdocSpec{
        .{ .op = .get, .path = "name" },
    };

    // Try to perform subdocument lookup on non-existent document
    try testing.expectError(couchbase.Error.DocumentNotFound, client.lookupInWithCollection(testing.allocator, key, collection, &specs));
}

test "collection-aware subdocument with options" {
    var client = getTestClient(testing.allocator) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    // Use default collection
    var collection = try couchbase.Collection.default(testing.allocator);
    defer collection.deinit();

    const key = "collection_subdoc_options_test_key";
    const value = "{\"name\": \"John\"}";

    // First upsert a document
    const upsert_result = try client.upsertWithCollection(key, value, collection, .{});
    try testing.expect(upsert_result.cas > 0);

    // Create subdocument mutation specs
    const specs = [_]couchbase.operations.SubdocSpec{
        .{ .op = .dict_upsert, .path = "age", .value = "30" },
    };

    // Perform subdocument mutation with options
    const options = couchbase.operations.SubdocOptions{
        .cas = upsert_result.cas,
        .expiry = 60,
        .durability = .{ .level = .none },
    };

    var subdoc_result = try client.mutateInWithCollection(testing.allocator, key, collection, &specs, options);
    defer subdoc_result.deinit();

    try testing.expect(subdoc_result.cas > upsert_result.cas);

    // Clean up
    _ = client.removeWithCollection(key, collection, .{}) catch {};
}
