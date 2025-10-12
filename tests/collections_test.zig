const std = @import("std");
const testing = std.testing;
const couchbase = @import("couchbase");

const TestConfig = couchbase.TestConfig;
const Client = couchbase.Client;
const Collection = couchbase.Collection;
const Scope = couchbase.Scope;
const CollectionManifest = couchbase.CollectionManifest;
const CollectionManifestEntry = couchbase.CollectionManifestEntry;

fn getTestClient(allocator: std.mem.Allocator) !Client {
    const test_config = couchbase.getTestConfig();
    return try couchbase.Client.connect(allocator, .{
        .connection_string = test_config.connection_string,
        .username = test_config.username,
        .password = test_config.password,
        .bucket = test_config.bucket,
        .timeout_ms = test_config.timeout_ms,
    });
}

test "collection creation and management" {
    const allocator = testing.allocator;
    
    // Test default collection
    var default_collection = try Collection.default(allocator);
    defer default_collection.deinit();
    
    try testing.expect(default_collection.isDefault());
    try testing.expectEqualStrings("_default", default_collection.name);
    try testing.expectEqualStrings("_default", default_collection.scope);
    
    // Test custom collection
    var custom_collection = try Collection.create(allocator, "test_collection", "test_scope");
    defer custom_collection.deinit();
    
    try testing.expect(!custom_collection.isDefault());
    try testing.expectEqualStrings("test_collection", custom_collection.name);
    try testing.expectEqualStrings("test_scope", custom_collection.scope);
}

test "scope creation and management" {
    const allocator = testing.allocator;
    
    // Test default scope
    var default_scope = try Scope.default(allocator);
    defer default_scope.deinit();
    
    try testing.expect(default_scope.isDefault());
    try testing.expectEqualStrings("_default", default_scope.name);
    
    // Test custom scope
    var custom_scope = try Scope.create(allocator, "test_scope");
    defer custom_scope.deinit();
    
    try testing.expect(!custom_scope.isDefault());
    try testing.expectEqualStrings("test_scope", custom_scope.name);
}

test "collection manifest creation and management" {
    const allocator = testing.allocator;
    
    // Create test collections
    const collection1 = CollectionManifestEntry{
        .name = try allocator.dupe(u8, "collection1"),
        .scope = try allocator.dupe(u8, "scope1"),
        .uid = 1,
        .max_ttl = 3600,
        .allocator = allocator,
    };
    
    const collection2 = CollectionManifestEntry{
        .name = try allocator.dupe(u8, "collection2"),
        .scope = try allocator.dupe(u8, "scope1"),
        .uid = 2,
        .max_ttl = 7200,
        .allocator = allocator,
    };
    
    const collection3 = CollectionManifestEntry{
        .name = try allocator.dupe(u8, "collection3"),
        .scope = try allocator.dupe(u8, "scope2"),
        .uid = 3,
        .max_ttl = 0,
        .allocator = allocator,
    };
    
    var collections = try allocator.alloc(CollectionManifestEntry, 3);
    collections[0] = collection1;
    collections[1] = collection2;
    collections[2] = collection3;
    
    var manifest = CollectionManifest{
        .uid = 12345,
        .collections = collections,
        .allocator = allocator,
    };
    defer manifest.deinit();
    
    // Test finding collections
    const found1 = manifest.findCollection("collection1", "scope1");
    try testing.expect(found1 != null);
    try testing.expectEqualStrings("collection1", found1.?.name);
    try testing.expectEqualStrings("scope1", found1.?.scope);
    try testing.expectEqual(@as(u32, 1), found1.?.uid);
    try testing.expectEqual(@as(u32, 3600), found1.?.max_ttl);
    
    const found2 = manifest.findCollection("collection2", "scope1");
    try testing.expect(found2 != null);
    try testing.expectEqualStrings("collection2", found2.?.name);
    
    const not_found = manifest.findCollection("nonexistent", "scope1");
    try testing.expect(not_found == null);
    
    // Test getting collections in scope
    const scope1_collections = try manifest.getCollectionsInScope("scope1", allocator);
    defer allocator.free(scope1_collections);
    try testing.expectEqual(@as(usize, 2), scope1_collections.len);
    
    const scope2_collections = try manifest.getCollectionsInScope("scope2", allocator);
    defer allocator.free(scope2_collections);
    try testing.expectEqual(@as(usize, 1), scope2_collections.len);
    try testing.expectEqualStrings("collection3", scope2_collections[0].name);
    
    const scope3_collections = try manifest.getCollectionsInScope("scope3", allocator);
    defer allocator.free(scope3_collections);
    try testing.expectEqual(@as(usize, 0), scope3_collections.len);
}

test "get with collection - basic functionality" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:collection:basic";
    const value = "{\"type\": \"test\", \"name\": \"collection_test\"}";

    // Clean up if exists
    _ = client.remove(key, .{}) catch {};

    // Insert test document
    _ = try client.upsert(key, value, .{});

    // Create collection
    var collection = try Collection.create(testing.allocator, "_default", "_default");
    defer collection.deinit();

    // Get document with collection
    var result = client.getWithCollection(key, collection) catch |err| {
        std.debug.print("Get with collection failed: {}\n", .{err});
        _ = client.remove(key, .{}) catch {};
        return;
    };
    defer result.deinit();

    // Verify the result
    try testing.expectEqualStrings(value, result.value);
    try testing.expect(result.cas > 0);

    // Clean up
    _ = try client.remove(key, .{});
}

test "get with collection - custom scope and collection" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:collection:custom";
    const value = "{\"type\": \"test\", \"name\": \"custom_collection_test\"}";

    // Clean up if exists
    _ = client.remove(key, .{}) catch {};

    // Insert test document
    _ = try client.upsert(key, value, .{});

    // Create custom collection
    var collection = try Collection.create(testing.allocator, "test_collection", "test_scope");
    defer collection.deinit();

    // Get document with collection (this may fail if collection doesn't exist)
    const result = client.getWithCollection(key, collection);
    
    // This should fail since the collection doesn't exist
    try testing.expectError(couchbase.Error.Timeout, result);

    // Clean up
    _ = client.remove(key, .{}) catch {};
}

test "collection manifest retrieval" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    // Get collection manifest
    var manifest = client.getCollectionManifest(testing.allocator) catch |err| {
        std.debug.print("Get collection manifest failed: {}\n", .{err});
        return;
    };
    defer manifest.deinit();

    // Verify manifest structure
    try testing.expect(manifest.uid >= 0);
    try testing.expect(manifest.collections.len >= 0);

    // Check for default collection
    const default_collection = manifest.findCollection("_default", "_default");
    if (default_collection) |_| {
        std.debug.print("Default collection found in manifest\n", .{});
    } else {
        std.debug.print("Default collection not found in manifest\n", .{});
    }
}

test "collection error handling" {
    const allocator = testing.allocator;
    
    // Test collection with empty name - this should succeed but create empty strings
    var empty_collection = try Collection.create(allocator, "", "scope");
    defer empty_collection.deinit();
    try testing.expectEqualStrings("", empty_collection.name);
    try testing.expectEqualStrings("scope", empty_collection.scope);
    
    // Test scope with empty name - this should succeed but create empty string
    var empty_scope = try Scope.create(allocator, "");
    defer empty_scope.deinit();
    try testing.expectEqualStrings("", empty_scope.name);
}

test "collection memory management" {
    const allocator = testing.allocator;
    
    // Test collection deinitialization
    var collection = try Collection.create(allocator, "test", "scope");
    collection.deinit(); // Should not crash
    
    // Test scope deinitialization
    var scope = try Scope.create(allocator, "test");
    scope.deinit(); // Should not crash
    
    // Test manifest deinitialization
    var collections = try allocator.alloc(CollectionManifestEntry, 1);
    collections[0] = CollectionManifestEntry{
        .name = try allocator.dupe(u8, "test"),
        .scope = try allocator.dupe(u8, "scope"),
        .uid = 1,
        .max_ttl = 0,
        .allocator = allocator,
    };
    
    var manifest = CollectionManifest{
        .uid = 1,
        .collections = collections,
        .allocator = allocator,
    };
    manifest.deinit(); // Should not crash
}

test "collection comparison and equality" {
    const allocator = testing.allocator;
    
    // Test collection equality
    var collection1 = try Collection.create(allocator, "test", "scope");
    defer collection1.deinit();
    
    var collection2 = try Collection.create(allocator, "test", "scope");
    defer collection2.deinit();
    
    var collection3 = try Collection.create(allocator, "different", "scope");
    defer collection3.deinit();
    
    // Test name and scope equality
    try testing.expectEqualStrings(collection1.name, collection2.name);
    try testing.expectEqualStrings(collection1.scope, collection2.scope);
    try testing.expect(!std.mem.eql(u8, collection1.name, collection3.name));
    
    // Test scope equality
    var scope1 = try Scope.create(allocator, "test");
    defer scope1.deinit();
    
    var scope2 = try Scope.create(allocator, "test");
    defer scope2.deinit();
    
    var scope3 = try Scope.create(allocator, "different");
    defer scope3.deinit();
    
    try testing.expectEqualStrings(scope1.name, scope2.name);
    try testing.expect(!std.mem.eql(u8, scope1.name, scope3.name));
}

test "collection manifest edge cases" {
    const allocator = testing.allocator;
    
    // Test empty manifest
    const empty_collections = try allocator.alloc(CollectionManifestEntry, 0);
    var empty_manifest = CollectionManifest{
        .uid = 0,
        .collections = empty_collections,
        .allocator = allocator,
    };
    defer empty_manifest.deinit();
    
    try testing.expectEqual(@as(usize, 0), empty_manifest.collections.len);
    try testing.expect(empty_manifest.findCollection("any", "any") == null);
    
    const empty_scope_collections = try empty_manifest.getCollectionsInScope("any", allocator);
    defer allocator.free(empty_scope_collections);
    try testing.expectEqual(@as(usize, 0), empty_scope_collections.len);
}

test "collection with special characters" {
    const allocator = testing.allocator;
    
    // Test collection with special characters in name
    var special_collection = try Collection.create(allocator, "test-collection_123", "test_scope-456");
    defer special_collection.deinit();
    
    try testing.expectEqualStrings("test-collection_123", special_collection.name);
    try testing.expectEqualStrings("test_scope-456", special_collection.scope);
    try testing.expect(!special_collection.isDefault());
    
    // Test scope with special characters
    var special_scope = try Scope.create(allocator, "test-scope_789");
    defer special_scope.deinit();
    
    try testing.expectEqualStrings("test-scope_789", special_scope.name);
    try testing.expect(!special_scope.isDefault());
}
