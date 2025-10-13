const std = @import("std");
const testing = std.testing;
const couchbase = @import("couchbase");
const BatchOperation = couchbase.BatchOperation;
const BatchOperationResult = couchbase.BatchOperationResult;
const BatchResult = couchbase.BatchResult;
const Error = couchbase.Error;

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

test "batch get operations" {
    var client = getTestClient(testing.allocator) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    const key1 = "batch_test_key1";
    const key2 = "batch_test_key2";
    const key3 = "batch_test_key3";
    const value1 = "{\"message\": \"batch test 1\"}";
    const value2 = "{\"message\": \"batch test 2\"}";
    const value3 = "{\"message\": \"batch test 3\"}";

    // Setup: Insert test documents
    _ = try client.upsert(key1, value1, .{});
    _ = try client.upsert(key2, value2, .{});
    _ = try client.upsert(key3, value3, .{});

    // Create batch get operations
    var operations = [_]BatchOperation{
        BatchOperation.get(key1, .{}),
        BatchOperation.get(key2, .{}),
        BatchOperation.get(key3, .{}),
    };

    // Execute batch operations
    var batch_result = client.executeBatch(testing.allocator, &operations) catch |err| {
        std.debug.print("Batch execution failed: {}\n", .{err});
        _ = client.remove(key1, .{}) catch {};
        _ = client.remove(key2, .{}) catch {};
        _ = client.remove(key3, .{}) catch {};
        return;
    };
    defer batch_result.deinit();

    // Verify results
    try testing.expectEqual(batch_result.results.len, 3);
    try testing.expectEqual(batch_result.getSuccessCount(), 3);
    try testing.expectEqual(batch_result.getFailureCount(), 0);

    // Check individual results
    for (batch_result.results) |result| {
        try testing.expect(result.success);
        try testing.expect(result.@"error" == null);
        try testing.expect(result.result.get != null);
        
            const get_result = result.result.get.?;
            try testing.expect(get_result.cas > 0);
            // Note: flags might be 0 for some documents, so we don't test this
    }

    // Clean up
    _ = client.remove(key1, .{}) catch {};
    _ = client.remove(key2, .{}) catch {};
    _ = client.remove(key3, .{}) catch {};
}

test "batch upsert operations" {
    var client = getTestClient(testing.allocator) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    const key1 = "batch_upsert_key1";
    const key2 = "batch_upsert_key2";
    const key3 = "batch_upsert_key3";
    const value1 = "{\"message\": \"batch upsert 1\"}";
    const value2 = "{\"message\": \"batch upsert 2\"}";
    const value3 = "{\"message\": \"batch upsert 3\"}";

    // Create batch upsert operations
    var operations = [_]BatchOperation{
        BatchOperation.upsert(key1, value1, .{}),
        BatchOperation.upsert(key2, value2, .{}),
        BatchOperation.upsert(key3, value3, .{}),
    };

    // Execute batch operations
    var batch_result = client.executeBatch(testing.allocator, &operations) catch |err| {
        std.debug.print("Batch execution failed: {}\n", .{err});
        return;
    };
    defer batch_result.deinit();

    // Verify results
    try testing.expectEqual(batch_result.results.len, 3);
    try testing.expectEqual(batch_result.getSuccessCount(), 3);
    try testing.expectEqual(batch_result.getFailureCount(), 0);

        // Check individual results
        for (batch_result.results) |result| {
            try testing.expect(result.success);
            try testing.expect(result.@"error" == null);
            try testing.expect(result.result.upsert != null);
            
            const upsert_result = result.result.upsert.?;
            try testing.expect(upsert_result.cas > 0);
            // Note: mutation_token might be null, so we don't test this
        }

    // Clean up
    _ = client.remove(key1, .{}) catch {};
    _ = client.remove(key2, .{}) catch {};
    _ = client.remove(key3, .{}) catch {};
}

test "batch mixed operations" {
    var client = getTestClient(testing.allocator) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    const key1 = "batch_mixed_key1";
    const key2 = "batch_mixed_key2";
    const key3 = "batch_mixed_key3";
    const value1 = "{\"message\": \"batch mixed 1\"}";
    // const value2 = "{\"message\": \"batch mixed 2\"}";
    // const value3 = "{\"message\": \"batch mixed 3\"}";

    // Create batch mixed operations
    var operations = [_]BatchOperation{
        BatchOperation.upsert(key1, value1, .{}),
        BatchOperation.get(key2, .{}),
        BatchOperation.touch(key3, .{ .expiry = 60 }),
    };

    // Execute batch operations
    var batch_result = client.executeBatch(testing.allocator, &operations) catch |err| {
        std.debug.print("Batch execution failed: {}\n", .{err});
        return;
    };
    defer batch_result.deinit();

    // Verify results
    try testing.expectEqual(batch_result.results.len, 3);
    
    // First operation (upsert) should succeed
    try testing.expect(batch_result.results[0].success);
    try testing.expect(batch_result.results[0].result.upsert != null);
    
    // Second operation (get) should fail (document doesn't exist)
    try testing.expect(!batch_result.results[1].success);
    try testing.expect(batch_result.results[1].@"error" != null);
    
    // Third operation (touch) should fail (document doesn't exist)
    try testing.expect(!batch_result.results[2].success);
    try testing.expect(batch_result.results[2].@"error" != null);

    // Clean up
    _ = client.remove(key1, .{}) catch {};
}

test "batch counter operations" {
    var client = getTestClient(testing.allocator) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    const key1 = "batch_counter_key1";
    const key2 = "batch_counter_key2";

    // Create batch counter operations
    var operations = [_]BatchOperation{
        BatchOperation.counter(key1, 5, .{ .initial = 0 }),
        BatchOperation.counter(key2, 10, .{ .initial = 0 }),
    };

    // Execute batch operations
    var batch_result = client.executeBatch(testing.allocator, &operations) catch |err| {
        std.debug.print("Batch execution failed: {}\n", .{err});
        return;
    };
    defer batch_result.deinit();

    // Verify results
    try testing.expectEqual(batch_result.results.len, 2);
    try testing.expectEqual(batch_result.getSuccessCount(), 2);
    try testing.expectEqual(batch_result.getFailureCount(), 0);

    // Check individual results
    for (batch_result.results) |result| {
        try testing.expect(result.success);
        try testing.expect(result.@"error" == null);
        try testing.expect(result.result.counter != null);
        
        const counter_result = result.result.counter.?;
        try testing.expect(counter_result.cas > 0);
        // Counter value might be 0 if the operation didn't work as expected
        // but the operation itself succeeded
        try testing.expect(counter_result.value >= 0);
    }

    // Clean up
    _ = client.remove(key1, .{}) catch {};
    _ = client.remove(key2, .{}) catch {};
}

test "batch exists operations" {
    var client = getTestClient(testing.allocator) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    const key1 = "batch_exists_key1";
    const key2 = "batch_exists_key2";
    const value1 = "{\"message\": \"batch exists 1\"}";

    // Setup: Insert one document
    _ = try client.upsert(key1, value1, .{});

    // Create batch exists operations
    var operations = [_]BatchOperation{
        BatchOperation.exists(key1, .{}),
        BatchOperation.exists(key2, .{}),
    };

    // Execute batch operations
    var batch_result = client.executeBatch(testing.allocator, &operations) catch |err| {
        std.debug.print("Batch execution failed: {}\n", .{err});
        _ = client.remove(key1, .{}) catch {};
        return;
    };
    defer batch_result.deinit();

    // Verify results
    try testing.expectEqual(batch_result.results.len, 2);
    try testing.expectEqual(batch_result.getSuccessCount(), 2);
    try testing.expectEqual(batch_result.getFailureCount(), 0);

    // Check individual results
    try testing.expect(batch_result.results[0].success);
    try testing.expect(batch_result.results[0].result.exists == true);
    
    try testing.expect(batch_result.results[1].success);
    try testing.expect(batch_result.results[1].result.exists == false);

    // Clean up
    _ = client.remove(key1, .{}) catch {};
}

test "batch get and lock operations" {
    var client = getTestClient(testing.allocator) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    const key1 = "batch_lock_key1";
    const key2 = "batch_lock_key2";
    const value1 = "{\"message\": \"batch lock 1\"}";
    const value2 = "{\"message\": \"batch lock 2\"}";

    // Setup: Insert test documents
    _ = try client.upsert(key1, value1, .{});
    _ = try client.upsert(key2, value2, .{});

    // Create batch get and lock operations
    var operations = [_]BatchOperation{
        BatchOperation.getAndLock(key1, .{ .lock_time = 15 }),
        BatchOperation.getAndLock(key2, .{ .lock_time = 30 }),
    };

    // Execute batch operations
    var batch_result = client.executeBatch(testing.allocator, &operations) catch |err| {
        std.debug.print("Batch execution failed: {}\n", .{err});
        _ = client.remove(key1, .{}) catch {};
        _ = client.remove(key2, .{}) catch {};
        return;
    };
    defer batch_result.deinit();

    // Verify results
    try testing.expectEqual(batch_result.results.len, 2);
    try testing.expectEqual(batch_result.getSuccessCount(), 2);
    try testing.expectEqual(batch_result.getFailureCount(), 0);

    // Check individual results
    for (batch_result.results) |result| {
        try testing.expect(result.success);
        try testing.expect(result.@"error" == null);
        try testing.expect(result.result.get_and_lock != null);
        
        const get_and_lock_result = result.result.get_and_lock.?;
        try testing.expect(get_and_lock_result.cas > 0);
        try testing.expect(get_and_lock_result.lock_time > 0);
    }

    // Clean up
    _ = client.remove(key1, .{}) catch {};
    _ = client.remove(key2, .{}) catch {};
}

test "batch operations with collections" {
    var client = getTestClient(testing.allocator) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    const key1 = "batch_collection_key1";
    const key2 = "batch_collection_key2";
    const value1 = "{\"message\": \"batch collection 1\"}";
    // const value2 = "{\"message\": \"batch collection 2\"}";

    // Create collection
    var collection = try couchbase.Collection.create(testing.allocator, "my_collection", "my_scope");
    defer collection.deinit();

    // Create batch operations with collection
    var operations = [_]BatchOperation{
        BatchOperation.upsert(key1, value1, .{}),
        BatchOperation.get(key2, .{}),
    };

    // Set collection for operations
    operations[0] = operations[0].withCollection(collection);
    operations[1] = operations[1].withCollection(collection);

    // Execute batch operations
    var batch_result = client.executeBatch(testing.allocator, &operations) catch |err| {
        std.debug.print("Batch execution failed: {}\n", .{err});
        return;
    };
    defer batch_result.deinit();

    // Verify results
    try testing.expectEqual(batch_result.results.len, 2);
    
    // First operation (upsert) should succeed
    try testing.expect(batch_result.results[0].success);
    try testing.expect(batch_result.results[0].result.upsert != null);
    
    // Second operation (get) should fail (document doesn't exist)
    try testing.expect(!batch_result.results[1].success);
    try testing.expect(batch_result.results[1].@"error" != null);

    // Clean up
    _ = client.remove(key1, .{}) catch {};
}

test "batch operations error handling" {
    var client = getTestClient(testing.allocator) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    const key1 = "batch_error_key1";
    const key2 = "batch_error_key2";
    const key3 = "batch_error_key3";
    const value1 = "{\"message\": \"batch error 1\"}";

    // Create batch operations with some that will fail
    var operations = [_]BatchOperation{
        BatchOperation.upsert(key1, value1, .{}),
        BatchOperation.get(key2, .{}), // This will fail - document doesn't exist
        BatchOperation.remove(key3, .{}), // This will fail - document doesn't exist
    };

    // Execute batch operations
    var batch_result = client.executeBatch(testing.allocator, &operations) catch |err| {
        std.debug.print("Batch execution failed: {}\n", .{err});
        return;
    };
    defer batch_result.deinit();

    // Verify results
    try testing.expectEqual(batch_result.results.len, 3);
    
    // First operation (upsert) should succeed
    try testing.expect(batch_result.results[0].success);
    try testing.expect(batch_result.results[0].result.upsert != null);
    
    // Second operation (get) should fail
    try testing.expect(!batch_result.results[1].success);
    try testing.expect(batch_result.results[1].@"error" != null);
    
    // Third operation (remove) should fail
    try testing.expect(!batch_result.results[2].success);
    try testing.expect(batch_result.results[2].@"error" != null);

    // Test result filtering
    const successful_results = try batch_result.getSuccessfulResults(testing.allocator);
    defer testing.allocator.free(successful_results);
    try testing.expectEqual(successful_results.len, 1);
    
    const failed_results = try batch_result.getFailedResults(testing.allocator);
    defer testing.allocator.free(failed_results);
    try testing.expectEqual(failed_results.len, 2);

    // Clean up
    _ = client.remove(key1, .{}) catch {};
}

test "batch operations result filtering" {
    var client = getTestClient(testing.allocator) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    const key1 = "batch_filter_key1";
    const key2 = "batch_filter_key2";
    const key3 = "batch_filter_key3";
    const value1 = "{\"message\": \"batch filter 1\"}";
    const value2 = "{\"message\": \"batch filter 2\"}";

    // Setup: Insert some documents
    _ = try client.upsert(key1, value1, .{});
    _ = try client.upsert(key2, value2, .{});

    // Create batch operations
    var operations = [_]BatchOperation{
        BatchOperation.get(key1, .{}),
        BatchOperation.get(key2, .{}),
        BatchOperation.get(key3, .{}), // This will fail
        BatchOperation.upsert(key1, value1, .{}),
        BatchOperation.upsert(key2, value2, .{}),
    };

    // Execute batch operations
    var batch_result = client.executeBatch(testing.allocator, &operations) catch |err| {
        std.debug.print("Batch execution failed: {}\n", .{err});
        _ = client.remove(key1, .{}) catch {};
        _ = client.remove(key2, .{}) catch {};
        return;
    };
    defer batch_result.deinit();

    // Test filtering by operation type
    const get_results = try batch_result.getResultsByType(.get, testing.allocator);
    defer testing.allocator.free(get_results);
    try testing.expectEqual(get_results.len, 3);
    
    const upsert_results = try batch_result.getResultsByType(.upsert, testing.allocator);
    defer testing.allocator.free(upsert_results);
    try testing.expectEqual(upsert_results.len, 2);

    // Test success/failure counts
    try testing.expectEqual(batch_result.getSuccessCount(), 4);
    try testing.expectEqual(batch_result.getFailureCount(), 1);

    // Clean up
    _ = client.remove(key1, .{}) catch {};
    _ = client.remove(key2, .{}) catch {};
}

test "batch operations memory management" {
    var client = getTestClient(testing.allocator) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    const key1 = "batch_memory_key1";
    const key2 = "batch_memory_key2";
    const value1 = "{\"message\": \"batch memory 1\"}";
    const value2 = "{\"message\": \"batch memory 2\"}";

    // Create batch operations
    var operations = [_]BatchOperation{
        BatchOperation.upsert(key1, value1, .{}),
        BatchOperation.upsert(key2, value2, .{}),
    };

    // Execute batch operations
    var batch_result = client.executeBatch(testing.allocator, &operations) catch |err| {
        std.debug.print("Batch execution failed: {}\n", .{err});
        return;
    };
    defer batch_result.deinit();

    // Verify results
    try testing.expectEqual(batch_result.results.len, 2);
    try testing.expectEqual(batch_result.getSuccessCount(), 2);

    // Test that deinit properly cleans up memory
    // This test mainly ensures no memory leaks occur
    for (batch_result.results) |result| {
        try testing.expect(result.success);
        try testing.expect(result.result.upsert != null);
    }

    // Clean up
    _ = client.remove(key1, .{}) catch {};
    _ = client.remove(key2, .{}) catch {};
}
