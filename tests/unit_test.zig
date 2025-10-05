const std = @import("std");
const testing = std.testing;
const couchbase = @import("couchbase");

test "error type mappings" {
    // Verify error type exists
    _ = couchbase.Error;
    
    // Test that errors can be returned
    const test_error: couchbase.Error!void = error.DocumentNotFound;
    try testing.expectError(error.DocumentNotFound, test_error);
}

test "durability level enum values" {
    const DurabilityLevel = couchbase.DurabilityLevel;

    try testing.expect(@intFromEnum(DurabilityLevel.none) >= 0);
    try testing.expect(@intFromEnum(DurabilityLevel.majority) > 0);
    try testing.expect(@intFromEnum(DurabilityLevel.majority_and_persist_to_active) > 0);
    try testing.expect(@intFromEnum(DurabilityLevel.persist_to_majority) > 0);
}

test "store options defaults" {
    const StoreOptions = couchbase.operations.StoreOptions;

    const opts = StoreOptions{};
    try testing.expectEqual(@as(u64, 0), opts.cas);
    try testing.expectEqual(@as(u32, 0), opts.expiry);
    try testing.expectEqual(@as(u32, 0), opts.flags);
    try testing.expectEqual(couchbase.DurabilityLevel.none, opts.durability.level);
}

test "remove options defaults" {
    const RemoveOptions = couchbase.operations.RemoveOptions;

    const opts = RemoveOptions{};
    try testing.expectEqual(@as(u64, 0), opts.cas);
    try testing.expectEqual(couchbase.DurabilityLevel.none, opts.durability.level);
}

test "counter options defaults" {
    const CounterOptions = couchbase.operations.CounterOptions;

    const opts = CounterOptions{};
    try testing.expectEqual(@as(u64, 0), opts.initial);
    try testing.expectEqual(@as(u32, 0), opts.expiry);
    try testing.expectEqual(couchbase.DurabilityLevel.none, opts.durability.level);
}

test "query options defaults" {
    const QueryOptions = couchbase.operations.QueryOptions;

    const opts = QueryOptions{};
    try testing.expectEqual(couchbase.types.ScanConsistency.not_bounded, opts.consistency);
    try testing.expectEqual(@as(?[]const []const u8, null), opts.parameters);
    try testing.expectEqual(@as(u32, 75000), opts.timeout_ms);
    try testing.expectEqual(true, opts.adhoc);
}

test "document structure" {
    const Document = couchbase.Document;

    const doc = Document{
        .id = "test-id",
        .content = "test-content",
        .cas = 123456,
        .flags = 0xABCD,
    };

    try testing.expectEqualStrings("test-id", doc.id);
    try testing.expectEqualStrings("test-content", doc.content);
    try testing.expectEqual(@as(u64, 123456), doc.cas);
    try testing.expectEqual(@as(u32, 0xABCD), doc.flags);
}

test "mutation result structure" {
    const MutationResult = couchbase.MutationResult;

    const result = MutationResult{
        .cas = 987654,
        .mutation_token = null,
    };

    try testing.expectEqual(@as(u64, 987654), result.cas);
    try testing.expectEqual(@as(?couchbase.operations.MutationToken, null), result.mutation_token);
}

test "counter result structure" {
    const CounterResult = couchbase.operations.CounterResult;

    const result = CounterResult{
        .value = 42,
        .cas = 111222,
        .mutation_token = null,
    };

    try testing.expectEqual(@as(u64, 42), result.value);
    try testing.expectEqual(@as(u64, 111222), result.cas);
}

test "connect options structure" {
    const ConnectOptions = couchbase.Client.ConnectOptions;

    const opts = ConnectOptions{
        .connection_string = "couchbase://localhost",
        .username = "admin",
        .password = "password",
        .bucket = "default",
        .timeout_ms = 5000,
    };

    try testing.expectEqualStrings("couchbase://localhost", opts.connection_string);
    try testing.expectEqualStrings("admin", opts.username.?);
    try testing.expectEqualStrings("password", opts.password.?);
    try testing.expectEqualStrings("default", opts.bucket.?);
    try testing.expectEqual(@as(u32, 5000), opts.timeout_ms);
}

test "replica mode enum" {
    const ReplicaMode = couchbase.types.ReplicaMode;

    const modes = [_]ReplicaMode{ .any, .all, .index };
    try testing.expectEqual(@as(usize, 3), modes.len);
}

test "store operation enum" {
    const StoreOperation = couchbase.types.StoreOperation;

    try testing.expect(@intFromEnum(StoreOperation.upsert) >= 0);
    try testing.expect(@intFromEnum(StoreOperation.insert) >= 0);
    try testing.expect(@intFromEnum(StoreOperation.replace) >= 0);
    try testing.expect(@intFromEnum(StoreOperation.append) >= 0);
    try testing.expect(@intFromEnum(StoreOperation.prepend) >= 0);
}

test "subdoc operation enum" {
    const SubdocOp = couchbase.types.SubdocOp;

    try testing.expect(@intFromEnum(SubdocOp.get) >= 0);
    try testing.expect(@intFromEnum(SubdocOp.exists) >= 0);
    try testing.expect(@intFromEnum(SubdocOp.replace) >= 0);
    try testing.expect(@intFromEnum(SubdocOp.dict_add) >= 0);
    try testing.expect(@intFromEnum(SubdocOp.delete) >= 0);
    try testing.expect(@intFromEnum(SubdocOp.counter) >= 0);
}

test "scan consistency enum" {
    const ScanConsistency = couchbase.types.ScanConsistency;

    try testing.expect(@intFromEnum(ScanConsistency.not_bounded) >= 0);
    try testing.expect(@intFromEnum(ScanConsistency.request_plus) > 0);
}

test "subdoc spec structure" {
    const SubdocSpec = couchbase.operations.SubdocSpec;

    const spec = SubdocSpec{
        .op = .get,
        .path = "field.subfield",
        .value = "",
        .flags = 0,
    };

    try testing.expectEqual(couchbase.types.SubdocOp.get, spec.op);
    try testing.expectEqualStrings("field.subfield", spec.path);
    try testing.expectEqualStrings("", spec.value);
    try testing.expectEqual(@as(u32, 0), spec.flags);
}

test "durability structure" {
    const Durability = couchbase.Durability;

    const dur = Durability{
        .level = .majority,
        .timeout_ms = 5000,
    };

    try testing.expectEqual(couchbase.DurabilityLevel.majority, dur.level);
    try testing.expectEqual(@as(u32, 5000), dur.timeout_ms);
}

test "durability default" {
    const Durability = couchbase.Durability;

    const dur = Durability{};
    try testing.expectEqual(couchbase.DurabilityLevel.none, dur.level);
    try testing.expectEqual(@as(u32, 0), dur.timeout_ms);
}

test "get result memory management" {
    const GetResult = couchbase.GetResult;

    // Simulate a result
    var result = GetResult{
        .value = try testing.allocator.dupe(u8, "test value"),
        .cas = 12345,
        .flags = 0,
        .allocator = testing.allocator,
    };

    try testing.expectEqualStrings("test value", result.value);
    try testing.expectEqual(@as(u64, 12345), result.cas);

    // Cleanup
    result.deinit();
}

test "query result memory management" {
    const QueryResult = couchbase.QueryResult;

    const row1 = try testing.allocator.dupe(u8, "row1");
    const row2 = try testing.allocator.dupe(u8, "row2");
    
    const rows = try testing.allocator.alloc([]const u8, 2);
    rows[0] = row1;
    rows[1] = row2;

    var result = QueryResult{
        .rows = rows,
        .meta = null,
        .allocator = testing.allocator,
    };

    try testing.expectEqual(@as(usize, 2), result.rows.len);
    try testing.expectEqualStrings("row1", result.rows[0]);
    try testing.expectEqualStrings("row2", result.rows[1]);

    // Cleanup
    result.deinit();
}
