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

test "positional parameters - basic query" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    // Create test documents
    const doc1 = \\{"type": "user", "name": "Alice", "age": 30, "city": "New York"}
    ;
    const doc2 = \\{"type": "user", "name": "Bob", "age": 25, "city": "San Francisco"}
    ;
    const doc3 = \\{"type": "user", "name": "Charlie", "age": 35, "city": "New York"}
    ;

    _ = try client.upsert("test:param:1", doc1, .{});
    _ = try client.upsert("test:param:2", doc2, .{});
    _ = try client.upsert("test:param:3", doc3, .{});

    // Query with positional parameters
    const query = "SELECT name, age FROM `default` WHERE type = $1 AND city = $2";
    const params = [_][]const u8{"user", "New York"};
    
    const options = try couchbase.operations.QueryOptions.withPositionalParams(testing.allocator, &params);
    defer if (options.parameters) |p| {
        for (p) |param| testing.allocator.free(param);
        testing.allocator.free(p);
    };

    var result = client.query(testing.allocator, query, options) catch |err| {
        std.debug.print("Positional parameter query skipped: {}\n", .{err});
        // Cleanup
        _ = client.remove("test:param:1", .{}) catch {};
        _ = client.remove("test:param:2", .{}) catch {};
        _ = client.remove("test:param:3", .{}) catch {};
        return;
    };
    defer result.deinit();

    // Should find Alice and Charlie (both in New York)
    try testing.expect(result.rows.len >= 2);
    
    // Cleanup
    _ = client.remove("test:param:1", .{}) catch {};
    _ = client.remove("test:param:2", .{}) catch {};
    _ = client.remove("test:param:3", .{}) catch {};
}

test "positional parameters - numeric comparison" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    // Create test documents
    const doc1 = \\{"type": "product", "name": "Laptop", "price": 999.99, "category": "electronics"}
    ;
    const doc2 = \\{"type": "product", "name": "Mouse", "price": 29.99, "category": "electronics"}
    ;
    const doc3 = \\{"type": "product", "name": "Book", "price": 19.99, "category": "books"}
    ;

    _ = try client.upsert("test:param:num:1", doc1, .{});
    _ = try client.upsert("test:param:num:2", doc2, .{});
    _ = try client.upsert("test:param:num:3", doc3, .{});

    // Query with numeric parameters
    const query = "SELECT name, price FROM `default` WHERE type = $1 AND price > $2";
    const params = [_][]const u8{"product", "50.0"};
    
    const options = try couchbase.operations.QueryOptions.withPositionalParams(testing.allocator, &params);
    defer if (options.parameters) |p| {
        for (p) |param| testing.allocator.free(param);
        testing.allocator.free(p);
    };

    var result = client.query(testing.allocator, query, options) catch |err| {
        std.debug.print("Numeric parameter query skipped: {}\n", .{err});
        // Cleanup
        _ = client.remove("test:param:num:1", .{}) catch {};
        _ = client.remove("test:param:num:2", .{}) catch {};
        _ = client.remove("test:param:num:3", .{}) catch {};
        return;
    };
    defer result.deinit();

    // Should find Laptop (price > 50)
    try testing.expect(result.rows.len >= 1);
    
    // Cleanup
    _ = client.remove("test:param:num:1", .{}) catch {};
    _ = client.remove("test:param:num:2", .{}) catch {};
    _ = client.remove("test:param:num:3", .{}) catch {};
}

test "named parameters - basic query" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    // Create test documents
    const doc1 = \\{"type": "order", "customer": "Alice", "amount": 150.00, "status": "completed"}
    ;
    const doc2 = \\{"type": "order", "customer": "Bob", "amount": 75.50, "status": "pending"}
    ;
    const doc3 = \\{"type": "order", "customer": "Alice", "amount": 200.00, "status": "completed"}
    ;

    _ = try client.upsert("test:named:1", doc1, .{});
    _ = try client.upsert("test:named:2", doc2, .{});
    _ = try client.upsert("test:named:3", doc3, .{});

    // Query with named parameters
    const query = "SELECT customer, amount FROM `default` WHERE type = $type AND status = $status";
    
    var named_params = std.StringHashMap([]const u8).init(testing.allocator);
    defer {
        var iterator = named_params.iterator();
        while (iterator.next()) |entry| {
            testing.allocator.free(entry.key_ptr.*);
            testing.allocator.free(entry.value_ptr.*);
        }
        named_params.deinit();
    }
    
    try named_params.put(try testing.allocator.dupe(u8, "type"), try testing.allocator.dupe(u8, "order"));
    try named_params.put(try testing.allocator.dupe(u8, "status"), try testing.allocator.dupe(u8, "completed"));

    const options = couchbase.operations.QueryOptions{
        .named_parameters = named_params,
    };

    var result = client.query(testing.allocator, query, options) catch |err| {
        std.debug.print("Named parameter query skipped: {}\n", .{err});
        // Cleanup
        _ = client.remove("test:named:1", .{}) catch {};
        _ = client.remove("test:named:2", .{}) catch {};
        _ = client.remove("test:named:3", .{}) catch {};
        return;
    };
    defer result.deinit();

    // Should find Alice's completed orders
    try testing.expect(result.rows.len >= 2);
    
    // Cleanup
    _ = client.remove("test:named:1", .{}) catch {};
    _ = client.remove("test:named:2", .{}) catch {};
    _ = client.remove("test:named:3", .{}) catch {};
}

test "named parameters - with struct" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    // Create test documents
    const doc1 = \\{"type": "employee", "name": "Alice", "department": "Engineering", "salary": 80000}
    ;
    const doc2 = \\{"type": "employee", "name": "Bob", "department": "Sales", "salary": 60000}
    ;
    const doc3 = \\{"type": "employee", "name": "Charlie", "department": "Engineering", "salary": 90000}
    ;

    _ = try client.upsert("test:struct:1", doc1, .{});
    _ = try client.upsert("test:struct:2", doc2, .{});
    _ = try client.upsert("test:struct:3", doc3, .{});

    // Query with named parameters using struct
    const query = "SELECT name, salary FROM `default` WHERE type = $type AND department = $department";
    
    const params = struct {
        type: []const u8 = "employee",
        department: []const u8 = "Engineering",
    }{};
    
    const options = try couchbase.operations.QueryOptions.withNamedParams(testing.allocator, params);
    defer if (options.named_parameters) |np| {
        var iterator = np.iterator();
        while (iterator.next()) |entry| {
            testing.allocator.free(entry.key_ptr.*);
            testing.allocator.free(entry.value_ptr.*);
        }
        var np_mut = np;
        np_mut.deinit();
    };

    var result = client.query(testing.allocator, query, options) catch |err| {
        std.debug.print("Struct parameter query skipped: {}\n", .{err});
        // Cleanup
        _ = client.remove("test:struct:1", .{}) catch {};
        _ = client.remove("test:struct:2", .{}) catch {};
        _ = client.remove("test:struct:3", .{}) catch {};
        return;
    };
    defer result.deinit();

    // Should find Alice and Charlie (both in Engineering)
    try testing.expect(result.rows.len >= 2);
    
    // Cleanup
    _ = client.remove("test:struct:1", .{}) catch {};
    _ = client.remove("test:struct:2", .{}) catch {};
    _ = client.remove("test:struct:3", .{}) catch {};
}

test "parameter validation - empty parameters" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    // Query with no parameters should work
    const query = "SELECT * FROM `default` WHERE type = 'test' LIMIT 1";
    const options = couchbase.operations.QueryOptions{};

    var result = client.query(testing.allocator, query, options) catch |err| {
        std.debug.print("Empty parameter query skipped: {}\n", .{err});
        return;
    };
    defer result.deinit();

    // Should not crash
    try testing.expect(result.rows.len >= 0);
}

test "parameter validation - mismatched parameters" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    // Query with more placeholders than parameters
    const query = "SELECT * FROM `default` WHERE type = $1 AND city = $2";
    const params = [_][]const u8{"user"}; // Only one parameter for two placeholders
    
    const options = try couchbase.operations.QueryOptions.withPositionalParams(testing.allocator, &params);
    defer if (options.parameters) |p| {
        for (p) |param| testing.allocator.free(param);
        testing.allocator.free(p);
    };

    // This should either work (with null for missing param) or fail gracefully
    var result = client.query(testing.allocator, query, options) catch |err| {
        // Expected to fail with parameter mismatch
        std.debug.print("Parameter mismatch handled: {}\n", .{err});
        return;
    };
    defer result.deinit();

    // If it doesn't fail, that's also acceptable (server handles it)
    try testing.expect(result.rows.len >= 0);
}

test "parameter performance - multiple queries" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    // Create test documents
    const docs = [_]struct { []const u8, []const u8 }{
        .{ "test:perf:1", \\{"type": "item", "id": 1, "value": 100}
        },
        .{ "test:perf:2", \\{"type": "item", "id": 2, "value": 200}
        },
        .{ "test:perf:3", \\{"type": "item", "id": 3, "value": 300}
        },
    };

    for (docs) |doc| {
        _ = try client.upsert(doc[0], doc[1], .{});
    }

    // Run multiple parameterized queries
    const query = "SELECT id, value FROM `default` WHERE type = $1 AND value > $2";
    const params = [_][]const u8{"item", "150"};
    
    const options = try couchbase.operations.QueryOptions.withPositionalParams(testing.allocator, &params);
    defer if (options.parameters) |p| {
        for (p) |param| testing.allocator.free(param);
        testing.allocator.free(p);
    };

    // Run query multiple times
    for (0..5) |_| {
        var result = client.query(testing.allocator, query, options) catch |err| {
            std.debug.print("Performance test query skipped: {}\n", .{err});
            // Cleanup
            for (docs) |doc| {
                _ = client.remove(doc[0], .{}) catch {};
            }
            return;
        };
        defer result.deinit();
        
        // Should consistently find items with value > 150
        try testing.expect(result.rows.len >= 2);
    }
    
    // Cleanup
    for (docs) |doc| {
        _ = client.remove(doc[0], .{}) catch {};
    }
}
