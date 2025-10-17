const std = @import("std");
const couchbase = @import("couchbase");

test "query options memory management" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Test withRaw (allocates memory)
    var options = try couchbase.operations.QueryOptions.withRaw(allocator, "{\"timeout\":\"30s\"}");
    defer options.deinit(); // This will free the allocated memory
    
    // Test withRawOwned (no allocation)
    _ = couchbase.operations.QueryOptions.withRawOwned("{\"timeout\":\"30s\"}");
    // No deinit needed - caller owns the memory
    
    // Test withContextIdOwned (allocates memory)
    var options_ctx = try couchbase.operations.QueryOptions.withContextIdOwned(allocator, "my-context");
    defer options_ctx.deinit(); // This will free the allocated memory
    
    // Test withQueryContextOwned (allocates memory)
    var options_query_ctx = try couchbase.operations.QueryOptions.withQueryContextOwned(allocator, "default:default");
    defer options_query_ctx.deinit(); // This will free the allocated memory
    
    // Test chaining with memory management
    var chained = couchbase.operations.QueryOptions.readonly()
        .chain(try couchbase.operations.QueryOptions.withRaw(allocator, "{\"readonly\":true}"));
    defer chained.deinit(); // This will free the allocated memory from withRaw
    
    std.debug.print("Query options memory management test passed\n", .{});
}
