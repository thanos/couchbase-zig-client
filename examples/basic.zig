const std = @import("std");
const couchbase = @import("couchbase");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("Connecting to Couchbase...\n", .{});

    // Connect to Couchbase cluster
    var client = try couchbase.Client.connect(allocator, .{
        .connection_string = "couchbase://localhost",
        .username = "Administrator",
        .password = "password",
        .bucket = "default",
    });
    defer client.disconnect();

    std.debug.print("Connected successfully!\n", .{});

    // Upsert a document
    const doc_id = "user:123";
    const doc_content = 
        \\{"name": "John Doe", "age": 30, "email": "john@example.com"}
    ;

    std.debug.print("Upserting document '{s}'...\n", .{doc_id});
    const upsert_result = try client.upsert(doc_id, doc_content, .{});
    std.debug.print("Upserted with CAS: {d}\n", .{upsert_result.cas});

    // Get the document back
    std.debug.print("Getting document '{s}'...\n", .{doc_id});
    var get_result = try client.get(doc_id);
    defer get_result.deinit();

    std.debug.print("Retrieved document:\n", .{});
    std.debug.print("  CAS: {d}\n", .{get_result.cas});
    std.debug.print("  Value: {s}\n", .{get_result.value});

    // Update the document
    const updated_content = 
        \\{"name": "John Doe", "age": 31, "email": "john@example.com"}
    ;
    std.debug.print("Updating document...\n", .{});
    const replace_result = try client.replace(doc_id, updated_content, .{
        .cas = get_result.cas,
    });
    std.debug.print("Updated with new CAS: {d}\n", .{replace_result.cas});

    // Remove the document
    std.debug.print("Removing document...\n", .{});
    const remove_result = try client.remove(doc_id, .{});
    std.debug.print("Removed with CAS: {d}\n", .{remove_result.cas});

    std.debug.print("Example completed successfully!\n", .{});
}
