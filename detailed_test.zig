const std = @import("std");
const testing = std.testing;
const c = @cImport({
    @cInclude("libcouchbase/couchbase.h");
});

fn fromStatusCode(rc: c.lcb_STATUS) !void {
    if (rc == c.LCB_SUCCESS) return;
    return error.Unknown;
}

test "detailed connection" {
    std.debug.print("\n=== Starting detailed connection test ===\n", .{});
    
    const allocator = testing.allocator;
    const conn_str_z = try allocator.dupeZ(u8, "couchbase://127.0.0.1");
    defer allocator.free(conn_str_z);
    
    std.debug.print("1. Allocated conn string\n", .{});
    
    var create_opts: ?*c.lcb_CREATEOPTS = null;
    _ = c.lcb_createopts_create(&create_opts, c.LCB_TYPE_BUCKET);
    defer _ = c.lcb_createopts_destroy(create_opts);
    
    std.debug.print("2. Created opts\n", .{});
    
    _ = c.lcb_createopts_connstr(create_opts, conn_str_z.ptr, conn_str_z.len);
    
    std.debug.print("3. Set connection string\n", .{});
    
    const username_z = try allocator.dupeZ(u8, "tester");
    defer allocator.free(username_z);
    const password_z = try allocator.dupeZ(u8, "csfb2010");
    defer allocator.free(password_z);
    
    _ = c.lcb_createopts_credentials(create_opts, username_z.ptr, username_z.len, password_z.ptr, password_z.len);
    
    std.debug.print("4. Set credentials\n", .{});
    
    const bucket_z = try allocator.dupeZ(u8, "default");
    defer allocator.free(bucket_z);
    _ = c.lcb_createopts_bucket(create_opts, bucket_z.ptr, bucket_z.len);
    
    std.debug.print("5. Set bucket\n", .{});
    
    var instance: ?*c.lcb_INSTANCE = null;
    var rc = c.lcb_create(&instance, create_opts);
    try fromStatusCode(rc);
    
    std.debug.print("6. Created instance\n", .{});
    
    const inst = instance orelse return error.ConnectionFailed;
    
    var timeout_ms: u32 = 10000;
    _ = c.lcb_cntl(inst, c.LCB_CNTL_SET, c.LCB_CNTL_CONFIGURATION_TIMEOUT, &timeout_ms);
    
    std.debug.print("7. Set timeout\n", .{});
    
    rc = c.lcb_connect(inst);
    try fromStatusCode(rc);
    
    std.debug.print("8. Called connect\n", .{});
    
    rc = c.lcb_wait(inst, 0);
    try fromStatusCode(rc);
    
    std.debug.print("9. Waited\n", .{});
    
    rc = c.lcb_get_bootstrap_status(inst);
    try fromStatusCode(rc);
    
    std.debug.print("10. Got bootstrap status\n", .{});
    
    c.lcb_destroy(inst);
    
    std.debug.print("11. Destroyed instance\n", .{});
    std.debug.print("=== Test completed ===\n", .{});
}
