const std = @import("std");
const couchbase = @import("couchbase");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("Attempting connection...\n", .{});

    var client = couchbase.Client.connect(allocator, .{
        .connection_string = "couchbase://127.0.0.1",
        .username = "tester",
        .password = "csfb2010",
        .bucket = "default",
    }) catch |err| {
        std.debug.print("Connection failed: {}\n", .{err});
        return err;
    };
    defer client.disconnect();

    std.debug.print("Connected successfully!\n", .{});
}
