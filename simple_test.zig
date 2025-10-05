const std = @import("std");
const testing = std.testing;
const c = @cImport({
    @cInclude("libcouchbase/couchbase.h");
});

test "simple connection" {
    std.debug.print("\n=== Starting simple connection test ===\n", .{});
    
    var create_opts: ?*c.lcb_CREATEOPTS = null;
    _ = c.lcb_createopts_create(&create_opts, c.LCB_TYPE_BUCKET);
    defer _ = c.lcb_createopts_destroy(create_opts);
    
    std.debug.print("1. Created opts\n", .{});
    
    const conn_str = "couchbase://127.0.0.1";
    _ = c.lcb_createopts_connstr(create_opts, conn_str.ptr, conn_str.len);
    
    std.debug.print("2. Set connection string\n", .{});
    
    const username = "tester";
    const password = "csfb2010";
    _ = c.lcb_createopts_credentials(create_opts, username.ptr, username.len, password.ptr, password.len);
    
    std.debug.print("3. Set credentials\n", .{});
    
    var instance: ?*c.lcb_INSTANCE = null;
    const rc = c.lcb_create(&instance, create_opts);
    
    std.debug.print("4. Create result: {d}\n", .{rc});
    
    if (instance) |inst| {
        std.debug.print("5. Destroying instance\n", .{});
        c.lcb_destroy(inst);
        std.debug.print("6. Instance destroyed\n", .{});
    }
    
    std.debug.print("=== Test completed ===\n", .{});
}
