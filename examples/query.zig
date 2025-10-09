const std = @import("std");
const couchbase = @import("couchbase");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Couchbase N1QL Query Example ===\n\n", .{});

    // Connect
    var client = try couchbase.Client.connect(allocator, .{
        .connection_string = "couchbase://localhost",
        .username = "Administrator",
        .password = "password",
        .bucket = "default",
    });
    defer client.disconnect();

    std.debug.print("Connected to Couchbase\n\n", .{});

    // Create some sample documents
    std.debug.print("1. Creating sample user documents...\n", .{});
    
    const users = [_]struct { id: []const u8, data: []const u8 }{
        .{ .id = "user:alice", .data = 
            \\{"type": "user", "name": "Alice Smith", "age": 28, "city": "New York"}
        },
        .{ .id = "user:bob", .data = 
            \\{"type": "user", "name": "Bob Johnson", "age": 35, "city": "San Francisco"}
        },
        .{ .id = "user:charlie", .data = 
            \\{"type": "user", "name": "Charlie Brown", "age": 42, "city": "New York"}
        },
    };

    for (users) |user| {
        _ = try client.upsert(user.id, user.data, .{});
        std.debug.print("   Created: {s}\n", .{user.id});
    }
    std.debug.print("\n", .{});

    // Query 1: Select all users (basic query)
    std.debug.print("2. Basic Query: Select all users\n", .{});
    const query1 = "SELECT * FROM `default` WHERE type = 'user'";
    
    var result1 = client.query(allocator, query1, .{}) catch |err| {
        std.debug.print("   Query failed: {}\n", .{err});
        std.debug.print("   Note: Make sure the bucket has a primary index.\n", .{});
        std.debug.print("   Run: CREATE PRIMARY INDEX ON `default`\n\n", .{});
        
        // Cleanup
        for (users) |user| {
            _ = try client.remove(user.id, .{});
        }
        return;
    };
    defer result1.deinit();

    std.debug.print("   Found {d} rows:\n", .{result1.rows.len});
    for (result1.rows, 0..) |row, i| {
        std.debug.print("   Row {d}: {s}\n", .{ i + 1, row });
    }
    std.debug.print("\n", .{});

    // Query 2: Parameterized query with positional parameters
    std.debug.print("3. Parameterized Query: Users by city (positional parameters)\n", .{});
    const query2 = "SELECT name, age FROM `default` WHERE type = $1 AND city = $2";
    const params = [_][]const u8{"user", "New York"};
    
    var options2 = try couchbase.operations.QueryOptions.withPositionalParams(allocator, &params);
    defer if (options2.parameters) |p| {
        for (p) |param| allocator.free(param);
        allocator.free(p);
    };
    
    var result2 = client.query(allocator, query2, options2) catch |err| {
        std.debug.print("   Parameterized query failed: {}\n", .{err});
        std.debug.print("   Note: This requires N1QL parameter support.\n\n", .{});
    } else {
        defer result2.deinit();
        std.debug.print("   Found {d} users in New York:\n", .{result2.rows.len});
        for (result2.rows, 0..) |row, i| {
            std.debug.print("   Row {d}: {s}\n", .{ i, row });
        }
    }
    std.debug.print("\n", .{});

    // Query 3: Parameterized query with named parameters
    std.debug.print("4. Parameterized Query: Users by age range (named parameters)\n", .{});
    const query3 = "SELECT name, age, city FROM `default` WHERE type = $type AND age > $min_age";
    
    var named_params = std.StringHashMap([]const u8).init(allocator);
    defer {
        var iterator = named_params.iterator();
        while (iterator.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            allocator.free(entry.value_ptr.*);
        }
        named_params.deinit();
    }
    
    try named_params.put(try allocator.dupe(u8, "type"), try allocator.dupe(u8, "user"));
    try named_params.put(try allocator.dupe(u8, "min_age"), try allocator.dupe(u8, "25"));

    var options3 = couchbase.operations.QueryOptions{
        .named_parameters = named_params,
    };
    
    var result3 = client.query(allocator, query3, options3) catch |err| {
        std.debug.print("   Named parameter query failed: {}\n", .{err});
        std.debug.print("   Note: This requires N1QL parameter support.\n\n", .{});
    } else {
        defer result3.deinit();
        std.debug.print("   Found {d} users over 25:\n", .{result3.rows.len});
        for (result3.rows, 0..) |row, i| {
            std.debug.print("   Row {d}: {s}\n", .{ i, row });
        }
    }
    std.debug.print("\n", .{});

    // Query 4: Aggregate - Count users by city
    std.debug.print("5. Query: Count users by city\n", .{});
    const query4 = "SELECT city, COUNT(*) as count FROM `default` WHERE type = 'user' GROUP BY city";
    
    var result4 = try client.query(allocator, query4, .{});
    defer result4.deinit();

    std.debug.print("   Found {d} rows:\n", .{result4.rows.len});
    for (result4.rows, 0..) |row, i| {
        std.debug.print("   Row {d}: {s}\n", .{ i + 1, row });
    }
    std.debug.print("\n", .{});

    // Query 4: Parameterized query
    std.debug.print("5. Query with consistency: SELECT with request_plus\n", .{});
    const query4 = "SELECT name FROM `default` WHERE type = 'user' AND age > 30 ORDER BY age";
    
    var result4 = try client.query(allocator, query4, .{
        .consistency = .request_plus,
        .adhoc = true,
    });
    defer result4.deinit();

    std.debug.print("   Found {d} rows:\n", .{result4.rows.len});
    for (result4.rows, 0..) |row, i| {
        std.debug.print("   Row {d}: {s}\n", .{ i + 1, row });
    }
    std.debug.print("\n", .{});

    // Cleanup
    std.debug.print("6. Cleaning up...\n", .{});
    for (users) |user| {
        _ = try client.remove(user.id, .{});
        std.debug.print("   Removed: {s}\n", .{user.id});
    }

    std.debug.print("\n=== Example completed successfully! ===\n", .{});
    std.debug.print("\nNote: For production use, consider:\n", .{});
    std.debug.print("  - Creating appropriate indexes for your queries\n", .{});
    std.debug.print("  - Using prepared statements for frequently-run queries\n", .{});
    std.debug.print("  - Implementing proper error handling and retries\n", .{});
}
