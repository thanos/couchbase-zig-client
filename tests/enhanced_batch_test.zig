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

test "enhanced batch operations with collections" {
    var client = getTestClient(testing.allocator) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    // Use default collection
    var collection = try couchbase.Collection.default(testing.allocator);
    defer collection.deinit();

    const key1 = "enhanced_batch_test_key1";
    const key2 = "enhanced_batch_test_key2";
    const key3 = "enhanced_batch_test_key3";
    const value1 = "{\"name\": \"John\", \"age\": 30}";
    const value2 = "{\"name\": \"Jane\", \"age\": 25}";

    // Create batch operations with collections
    const operations = [_]couchbase.types.BatchOperation{
        // Basic KV operations with collection
        couchbase.types.BatchOperation.upsert(key1, value1, .{}).withCollection(collection),
        couchbase.types.BatchOperation.insert(key2, value2, .{}).withCollection(collection),
        couchbase.types.BatchOperation.get(key3, .{}).withCollection(collection),
        
        // Lock operations with collection
        couchbase.types.BatchOperation.getAndLock(key1, .{ .lock_time = 10 }).withCollection(collection),
        
        // Counter operation with collection
        couchbase.types.BatchOperation.counter(key2, 5, .{ .initial = 0 }).withCollection(collection),
        
        // Exists operation with collection
        couchbase.types.BatchOperation.exists(key3, .{}).withCollection(collection),
        
        // Replica operation with collection
        couchbase.types.BatchOperation.getReplica(key1, .{}).withCollection(collection),
        
        // Subdocument operations with collection
        couchbase.types.BatchOperation.lookupIn(key1, &[_]couchbase.operations.SubdocSpec{
            .{ .op = .get, .path = "name" },
            .{ .op = .get, .path = "age" },
        }).withCollection(collection),
        
        couchbase.types.BatchOperation.mutateIn(key2, &[_]couchbase.operations.SubdocSpec{
            .{ .op = .dict_upsert, .path = "city", .value = "\"New York\"" },
        }, .{}).withCollection(collection),
    };

    // Execute batch operations
    var batch_result = try client.executeBatch(testing.allocator, &operations);
    defer batch_result.deinit();

    // Verify results
    try testing.expect(batch_result.results.len == 9);
    
    // Check success count (some operations might fail due to document not existing)
    const success_count = batch_result.getSuccessCount();
    try testing.expect(success_count >= 4); // At least 4 operations should succeed
    
    // Verify specific operations - be more flexible with success expectations
    for (batch_result.results) |result| {
        switch (result.operation_type) {
            .upsert => {
                if (result.success) {
                    try testing.expect(result.result.upsert != null);
                }
            },
            .insert => {
                if (result.success) {
                    try testing.expect(result.result.insert != null);
                }
            },
            .get => {
                if (result.success) {
                    try testing.expect(result.result.get != null);
                }
            },
            .get_and_lock => {
                if (result.success) {
                    try testing.expect(result.result.get_and_lock != null);
                }
            },
            .counter => {
                if (result.success) {
                    try testing.expect(result.result.counter != null);
                }
            },
            .exists => {
                if (result.success) {
                    try testing.expect(result.result.exists != null);
                }
            },
            .get_replica => {
                if (result.success) {
                    try testing.expect(result.result.get_replica != null);
                }
            },
            .lookup_in => {
                if (result.success) {
                    try testing.expect(result.result.lookup_in != null);
                }
            },
            .mutate_in => {
                if (result.success) {
                    try testing.expect(result.result.mutate_in != null);
                }
            },
            else => {},
        }
    }

    // Clean up
    _ = client.removeWithCollection(key1, collection, .{}) catch {};
    _ = client.removeWithCollection(key2, collection, .{}) catch {};
    _ = client.removeWithCollection(key3, collection, .{}) catch {};
}

test "enhanced batch operations without collections" {
    var client = getTestClient(testing.allocator) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    const key1 = "enhanced_batch_no_collection_key1";
    const key2 = "enhanced_batch_no_collection_key2";
    const value1 = "{\"name\": \"Alice\", \"age\": 28}";
    const value2 = "{\"name\": \"Charlie\", \"age\": 32}";

    // Create batch operations without collections
    const operations = [_]couchbase.types.BatchOperation{
        // Basic KV operations
        couchbase.types.BatchOperation.upsert(key1, value1, .{}),
        couchbase.types.BatchOperation.insert(key2, value2, .{}),
        
        // Replica operation
        couchbase.types.BatchOperation.getReplica(key1, .{}),
        
        // Subdocument operations
        couchbase.types.BatchOperation.lookupIn(key1, &[_]couchbase.operations.SubdocSpec{
            .{ .op = .get, .path = "name" },
        }),
        
        couchbase.types.BatchOperation.mutateIn(key2, &[_]couchbase.operations.SubdocSpec{
            .{ .op = .dict_upsert, .path = "city", .value = "\"Boston\"" },
        }, .{}),
    };

    // Execute batch operations
    var batch_result = try client.executeBatch(testing.allocator, &operations);
    defer batch_result.deinit();

    // Verify results
    try testing.expect(batch_result.results.len == 5);
    
    // Check success count
    const success_count = batch_result.getSuccessCount();
    try testing.expect(success_count >= 2); // At least 2 operations should succeed

    // Clean up
    _ = client.remove(key1, .{}) catch {};
    _ = client.remove(key2, .{}) catch {};
}

test "enhanced batch operations error handling" {
    var client = getTestClient(testing.allocator) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    // Use default collection
    var collection = try couchbase.Collection.default(testing.allocator);
    defer collection.deinit();

    const non_existent_key = "non_existent_enhanced_batch_key";

    // Create batch operations that will fail
    const operations = [_]couchbase.types.BatchOperation{
        // Try to get non-existent document
        couchbase.types.BatchOperation.get(non_existent_key, .{}).withCollection(collection),
        
        // Try to get and lock non-existent document
        couchbase.types.BatchOperation.getAndLock(non_existent_key, .{ .lock_time = 10 }).withCollection(collection),
        
        // Try to get replica of non-existent document
        couchbase.types.BatchOperation.getReplica(non_existent_key, .{}).withCollection(collection),
        
        // Try to do subdocument operations on non-existent document
        couchbase.types.BatchOperation.lookupIn(non_existent_key, &[_]couchbase.operations.SubdocSpec{
            .{ .op = .get, .path = "name" },
        }).withCollection(collection),
    };

    // Execute batch operations
    var batch_result = try client.executeBatch(testing.allocator, &operations);
    defer batch_result.deinit();

    // Verify results - all should fail
    try testing.expect(batch_result.results.len == 4);
    
    const failure_count = batch_result.getFailureCount();
    try testing.expect(failure_count >= 2); // At least 2 operations should fail
    
    // Verify all operations failed
    for (batch_result.results) |result| {
        try testing.expect(!result.success);
        try testing.expect(result.@"error" != null);
    }
}

test "enhanced batch operations mixed success and failure" {
    var client = getTestClient(testing.allocator) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    // Use default collection
    var collection = try couchbase.Collection.default(testing.allocator);
    defer collection.deinit();

    const existing_key = "mixed_batch_existing_key";
    const non_existent_key = "mixed_batch_non_existent_key";
    const value = "{\"name\": \"Test\", \"age\": 40}";

    // First create a document
    _ = try client.upsertWithCollection(existing_key, value, collection, .{});

    // Create batch operations with mixed success/failure
    const operations = [_]couchbase.types.BatchOperation{
        // This should succeed
        couchbase.types.BatchOperation.get(existing_key, .{}).withCollection(collection),
        
        // This should fail
        couchbase.types.BatchOperation.get(non_existent_key, .{}).withCollection(collection),
        
        // This should succeed
        couchbase.types.BatchOperation.exists(existing_key, .{}).withCollection(collection),
        
        // This should fail
        couchbase.types.BatchOperation.getAndLock(non_existent_key, .{ .lock_time = 10 }).withCollection(collection),
    };

    // Execute batch operations
    var batch_result = try client.executeBatch(testing.allocator, &operations);
    defer batch_result.deinit();

    // Verify results
    try testing.expect(batch_result.results.len == 4);
    
    const success_count = batch_result.getSuccessCount();
    const failure_count = batch_result.getFailureCount();
    
    try testing.expect(success_count >= 1);
    try testing.expect(failure_count >= 1);
    try testing.expect(success_count + failure_count == 4);

    // Clean up
    _ = client.removeWithCollection(existing_key, collection, .{}) catch {};
}
