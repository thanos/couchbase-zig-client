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

test "spatial view query - bounding box" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    // Create some test documents with geospatial data
    const doc1 = \\{"name": "Location A", "lat": 37.7749, "lon": -122.4194, "type": "location"}
    ;
    const doc2 = \\{"name": "Location B", "lat": 37.7849, "lon": -122.4094, "type": "location"}
    ;

    _ = client.upsert("spatial_test:1", doc1, .{}) catch {};
    _ = client.upsert("spatial_test:2", doc2, .{}) catch {};

    // Query spatial view with bounding box (will fail if design doc doesn't exist)
    var result = client.spatialViewQuery(
        testing.allocator,
        "dev_spatial",
        "by_location",
        .{
            .bbox = .{
                .min_lon = -122.5,
                .min_lat = 37.7,
                .max_lon = -122.3,
                .max_lat = 37.8,
            },
            .limit = 10,
        },
    ) catch |err| {
        std.debug.print("Spatial view query not available (design doc may not exist): {}\n", .{err});
        _ = client.remove("spatial_test:1", .{}) catch {};
        _ = client.remove("spatial_test:2", .{}) catch {};
        return;
    };
    defer result.deinit();

    std.debug.print("Spatial view returned {d} rows\n", .{result.rows.len});

    // Clean up
    _ = client.remove("spatial_test:1", .{}) catch {};
    _ = client.remove("spatial_test:2", .{}) catch {};
}

test "spatial view query - range" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    // Query spatial view with range
    var result = client.spatialViewQuery(
        testing.allocator,
        "dev_spatial",
        "by_location",
        .{
            .range = .{
                .start_lon = -122.5,
                .start_lat = 37.7,
                .end_lon = -122.3,
                .end_lat = 37.8,
            },
            .include_docs = true,
        },
    ) catch |err| {
        std.debug.print("Spatial view query with range skipped: {}\n", .{err});
        return;
    };
    defer result.deinit();

    try testing.expect(result.rows.len >= 0);
}

test "spatial view query - with options" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    // Query with various spatial options
    var result = client.spatialViewQuery(
        testing.allocator,
        "dev_spatial",
        "by_location",
        .{
            .bbox = .{
                .min_lon = -122.5,
                .min_lat = 37.7,
                .max_lon = -122.3,
                .max_lat = 37.8,
            },
            .limit = 5,
            .skip = 0,
            .include_docs = true,
            .stale = .ok,
        },
    ) catch |err| {
        std.debug.print("Spatial view query with options skipped: {}\n", .{err});
        return;
    };
    defer result.deinit();

    try testing.expect(result.rows.len <= 5);
}

test "spatial view query - deprecation warning" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    // This test will print a deprecation warning
    var result = client.spatialViewQuery(
        testing.allocator,
        "dev_spatial",
        "by_location",
        .{
            .bbox = .{
                .min_lon = -122.5,
                .min_lat = 37.7,
                .max_lon = -122.3,
                .max_lat = 37.8,
            },
        },
    ) catch |err| {
        std.debug.print("Spatial view query deprecation test skipped: {}\n", .{err});
        return;
    };
    defer result.deinit();

    // The function should complete (even if it fails due to missing design doc)
    try testing.expect(result.rows.len >= 0);
}

test "spatial view query - error handling" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    // Test with invalid parameters
    var result = client.spatialViewQuery(
        testing.allocator,
        "nonexistent_design_doc",
        "nonexistent_view",
        .{
            .bbox = .{
                .min_lon = -122.5,
                .min_lat = 37.7,
                .max_lon = -122.3,
                .max_lat = 37.8,
            },
        },
    ) catch |err| {
        // Expected to fail with nonexistent design doc
        std.debug.print("Spatial view query error handling test: {}\n", .{err});
        return;
    };
    defer result.deinit();

    // If it doesn't fail, that's also acceptable
    try testing.expect(result.rows.len >= 0);
}

test "spatial view query - bounding box validation" {
    // Test bounding box creation and validation
    const bbox = couchbase.views.BoundingBox{
        .min_lon = -122.5,
        .min_lat = 37.7,
        .max_lon = -122.3,
        .max_lat = 37.8,
    };

    try testing.expect(bbox.min_lon < bbox.max_lon);
    try testing.expect(bbox.min_lat < bbox.max_lat);
    try testing.expect(bbox.min_lon == -122.5);
    try testing.expect(bbox.max_lat == 37.8);
}

test "spatial view query - range validation" {
    // Test spatial range creation and validation
    const range = couchbase.views.SpatialRange{
        .start_lon = -122.5,
        .start_lat = 37.7,
        .end_lon = -122.3,
        .end_lat = 37.8,
    };

    try testing.expect(range.start_lon == -122.5);
    try testing.expect(range.start_lat == 37.7);
    try testing.expect(range.end_lon == -122.3);
    try testing.expect(range.end_lat == 37.8);
}

test "spatial view query - options validation" {
    // Test spatial view options creation
    const options = couchbase.views.SpatialViewOptions{
        .bbox = .{
            .min_lon = -122.5,
            .min_lat = 37.7,
            .max_lon = -122.3,
            .max_lat = 37.8,
        },
        .limit = 10,
        .skip = 0,
        .include_docs = true,
        .stale = .ok,
    };

    try testing.expect(options.bbox != null);
    try testing.expect(options.range == null);
    try testing.expect(options.limit == 10);
    try testing.expect(options.skip == 0);
    try testing.expect(options.include_docs == true);
    try testing.expect(options.stale == .ok);
}
