const std = @import("std");
const couchbase = @import("couchbase");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Couchbase Key-Value Operations Example ===\n\n", .{});

    // Connect
    var client = try couchbase.Client.connect(allocator, .{
        .connection_string = "couchbase://localhost",
        .username = "Administrator",
        .password = "password",
        .bucket = "default",
    });
    defer client.disconnect();

    std.debug.print("Connected to Couchbase\n\n", .{});

    // ===== Insert Operation =====
    std.debug.print("1. INSERT operation (creates new document, fails if exists):\n", .{});
    const new_doc_id = "product:laptop-001";
    const new_doc_content = 
        \\{"name": "ThinkPad X1", "price": 1299.99, "stock": 15}
    ;

    const insert_result = client.insert(new_doc_id, new_doc_content, .{}) catch |err| {
        if (err == error.DocumentExists) {
            std.debug.print("   Document already exists, removing first...\n", .{});
            _ = try client.remove(new_doc_id, .{});
            try client.insert(new_doc_id, new_doc_content, .{});
        } else {
            return err;
        }
    };
    std.debug.print("   Inserted with CAS: {d}\n\n", .{insert_result.cas});

    // ===== Counter Operations =====
    std.debug.print("2. COUNTER operations (increment/decrement):\n", .{});
    const counter_id = "counter:page-views";

    std.debug.print("   Incrementing counter by 10...\n", .{});
    const inc_result = try client.increment(counter_id, 10, .{ .initial = 0 });
    std.debug.print("   Counter value: {d}\n", .{inc_result.value});

    std.debug.print("   Incrementing counter by 5...\n", .{});
    const inc_result2 = try client.increment(counter_id, 5, .{});
    std.debug.print("   Counter value: {d}\n", .{inc_result2.value});

    std.debug.print("   Decrementing counter by 3...\n", .{});
    const dec_result = try client.decrement(counter_id, 3, .{});
    std.debug.print("   Counter value: {d}\n\n", .{dec_result.value});

    // ===== Touch Operation (Update Expiry) =====
    std.debug.print("3. TOUCH operation (update expiration):\n", .{});
    std.debug.print("   Setting expiration to 60 seconds...\n", .{});
    const touch_result = try client.touch(new_doc_id, 60);
    std.debug.print("   Touched with CAS: {d}\n\n", .{touch_result.cas});

    // ===== Get from Replica =====
    std.debug.print("4. GET FROM REPLICA:\n", .{});
    std.debug.print("   Attempting to get from any replica...\n", .{});
    var replica_result = client.getFromReplica(new_doc_id, .any) catch |err| {
        std.debug.print("   Replica not available: {}\n", .{err});
        var result = try client.get(new_doc_id);
        defer result.deinit();
        std.debug.print("   Got from master instead: {s}\n\n", .{result.value});
        result.deinit();
        result = try client.get(new_doc_id);
        result
    };
    defer replica_result.deinit();

    // ===== CAS (Compare and Swap) =====
    std.debug.print("5. CAS (Optimistic Locking):\n", .{});
    var get_result = try client.get(new_doc_id);
    defer get_result.deinit();

    std.debug.print("   Current CAS: {d}\n", .{get_result.cas});
    std.debug.print("   Attempting replace with correct CAS...\n", .{});
    
    const updated_content = 
        \\{"name": "ThinkPad X1", "price": 1199.99, "stock": 14}
    ;
    const cas_result = try client.replace(new_doc_id, updated_content, .{
        .cas = get_result.cas,
    });
    std.debug.print("   Success! New CAS: {d}\n", .{cas_result.cas});

    std.debug.print("   Attempting replace with old CAS (should fail)...\n", .{});
    _ = client.replace(new_doc_id, updated_content, .{
        .cas = get_result.cas,
    }) catch |err| {
        std.debug.print("   Failed as expected: {}\n\n", .{err});
    };

    // ===== Durability =====
    std.debug.print("6. DURABILITY (ensuring data is replicated):\n", .{});
    const durable_doc_id = "important:transaction-001";
    const durable_content = 
        \\{"amount": 1000.00, "from": "account-A", "to": "account-B"}
    ;

    std.debug.print("   Upserting with majority durability...\n", .{});
    const durable_result = client.upsert(durable_doc_id, durable_content, .{
        .durability = .{
            .level = .majority,
        },
    }) catch |err| {
        std.debug.print("   Durability not available in this setup: {}\n", .{err});
        const result = try client.upsert(durable_doc_id, durable_content, .{});
        result
    };
    std.debug.print("   Upserted with durability, CAS: {d}\n\n", .{durable_result.cas});

    // Cleanup
    std.debug.print("7. CLEANUP:\n", .{});
    _ = try client.remove(new_doc_id, .{});
    _ = try client.remove(counter_id, .{});
    _ = try client.remove(durable_doc_id, .{});
    std.debug.print("   All test documents removed\n\n", .{});

    std.debug.print("=== Example completed successfully! ===\n", .{});
}
