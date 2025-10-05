const std = @import("std");
const testing = std.testing;
const c = @cImport({
    @cInclude("libcouchbase/couchbase.h");
});

fn fromStatusCode(rc: c.lcb_STATUS) !void {
    if (rc == c.LCB_SUCCESS) return;
    return error.Unknown;
}

test "detailed connection with error codes" {
    std.debug.print("\n=== Starting detailed connection test ===\n", .{});
    
    const allocator = testing.allocator;
    const conn_str_z = try allocator.dupeZ(u8, "couchbase://127.0.0.1");
    defer allocator.free(conn_str_z);
    
    var create_opts: ?*c.lcb_CREATEOPTS = null;
    _ = c.lcb_createopts_create(&create_opts, c.LCB_TYPE_BUCKET);
    defer _ = c.lcb_createopts_destroy(create_opts);
    
    _ = c.lcb_createopts_connstr(create_opts, conn_str_z.ptr, conn_str_z.len);
    
    const username_z = try allocator.dupeZ(u8, "tester");
    defer allocator.free(username_z);
    const password_z = try allocator.dupeZ(u8, "csfb2010");
    defer allocator.free(password_z);
    
    _ = c.lcb_createopts_credentials(create_opts, username_z.ptr, username_z.len, password_z.ptr, password_z.len);
    
    const bucket_z = try allocator.dupeZ(u8, "default");
    defer allocator.free(bucket_z);
    _ = c.lcb_createopts_bucket(create_opts, bucket_z.ptr, bucket_z.len);
    
    var instance: ?*c.lcb_INSTANCE = null;
    var rc = c.lcb_create(&instance, create_opts);
    std.debug.print("Create: rc={d}\n", .{rc});
    try fromStatusCode(rc);
    
    const inst = instance orelse return error.ConnectionFailed;
    
    var timeout_ms: u32 = 10000;
    _ = c.lcb_cntl(inst, c.LCB_CNTL_SET, c.LCB_CNTL_CONFIGURATION_TIMEOUT, &timeout_ms);
    
    rc = c.lcb_connect(inst);
    std.debug.print("Connect: rc={d}\n", .{rc});
    try fromStatusCode(rc);
    
    rc = c.lcb_wait(inst, 0);
    std.debug.print("Wait: rc={d} (hex: 0x{x})\n", .{ rc, rc });
    const err_desc = c.lcb_strerror_short(rc);
    std.debug.print("Error: {s}\n", .{std.mem.span(err_desc)});
    
    if (rc != c.LCB_SUCCESS) {
        std.debug.print("Wait failed, trying bootstrap status anyway...\n", .{});
    }
    
    rc = c.lcb_get_bootstrap_status(inst);
    std.debug.print("Bootstrap status: rc={d}\n", .{rc});
    const err_desc2 = c.lcb_strerror_short(rc);
    std.debug.print("Bootstrap error: {s}\n", .{std.mem.span(err_desc2)});
    
    c.lcb_destroy(inst);
    std.debug.print("=== Test completed ===\n", .{});
}
