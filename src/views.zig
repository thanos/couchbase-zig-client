const std = @import("std");
const c = @import("c.zig");
const Error = @import("error.zig").Error;
const fromStatusCode = @import("error.zig").fromStatusCode;
const Client = @import("client.zig").Client;

/// View query result
pub const ViewResult = struct {
    rows: [][]const u8,
    meta: ?[]const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *ViewResult) void {
        for (self.rows) |row| {
            self.allocator.free(row);
        }
        self.allocator.free(self.rows);
        if (self.meta) |meta| {
            self.allocator.free(meta);
        }
    }
};

/// View query options
pub const ViewOptions = struct {
    start_key: ?[]const u8 = null,
    end_key: ?[]const u8 = null,
    start_key_doc_id: ?[]const u8 = null,
    end_key_doc_id: ?[]const u8 = null,
    limit: ?u32 = null,
    skip: ?u32 = null,
    descending: bool = false,
    include_docs: bool = false,
    reduce: bool = true,
    group: bool = false,
    group_level: ?u32 = null,
    stale: ViewStale = .update_after,
};

/// Spatial view query options (deprecated - use FTS instead)
pub const SpatialViewOptions = struct {
    bbox: ?BoundingBox = null,
    range: ?SpatialRange = null,
    limit: ?u32 = null,
    skip: ?u32 = null,
    include_docs: bool = false,
    stale: ViewStale = .update_after,
};

/// Bounding box for spatial queries
pub const BoundingBox = struct {
    min_lon: f64,
    min_lat: f64,
    max_lon: f64,
    max_lat: f64,
};

/// Spatial range for spatial queries
pub const SpatialRange = struct {
    start_lon: f64,
    start_lat: f64,
    end_lon: f64,
    end_lat: f64,
};

/// View staleness/consistency options
pub const ViewStale = enum(c_uint) {
    update_before = 0, // false in query
    ok = 1,            // ok in query  
    update_after = 2,  // update_after in query
};

const ViewContext = struct {
    rows: std.ArrayList([]const u8),
    meta: ?[]const u8 = null,
    err: ?Error = null,
    done: bool = false,
    allocator: std.mem.Allocator,
};

/// Execute a view query
pub fn viewQuery(
    client: *Client,
    allocator: std.mem.Allocator,
    design_doc: []const u8,
    view_name: []const u8,
    options: ViewOptions,
) Error!ViewResult {
    var ctx = ViewContext{
        .rows = std.ArrayList([]const u8).init(allocator),
        .allocator = allocator,
    };

    var cmd: ?*c.lcb_CMDVIEW = null;
    _ = c.lcb_cmdview_create(&cmd);
    defer _ = c.lcb_cmdview_destroy(cmd);

    _ = c.lcb_cmdview_design_document(cmd, design_doc.ptr, design_doc.len);
    _ = c.lcb_cmdview_view_name(cmd, view_name.ptr, view_name.len);

    // Build query options string
    var options_list = std.ArrayList(u8).init(allocator);
    defer options_list.deinit();

    var first = true;

    if (options.limit) |limit| {
        if (!first) try options_list.appendSlice("&");
        try options_list.writer().print("limit={d}", .{limit});
        first = false;
    }

    if (options.skip) |skip| {
        if (!first) try options_list.appendSlice("&");
        try options_list.writer().print("skip={d}", .{skip});
        first = false;
    }

    if (options.descending) {
        if (!first) try options_list.appendSlice("&");
        try options_list.appendSlice("descending=true");
        first = false;
    }

    if (options.include_docs) {
        if (!first) try options_list.appendSlice("&");
        try options_list.appendSlice("include_docs=true");
        first = false;
    }

    if (!options.reduce) {
        if (!first) try options_list.appendSlice("&");
        try options_list.appendSlice("reduce=false");
        first = false;
    }

    if (options.group) {
        if (!first) try options_list.appendSlice("&");
        try options_list.appendSlice("group=true");
        first = false;
    }

    if (options.group_level) |level| {
        if (!first) try options_list.appendSlice("&");
        try options_list.writer().print("group_level={d}", .{level});
        first = false;
    }

    if (options.start_key) |start_key| {
        if (!first) try options_list.appendSlice("&");
        try options_list.appendSlice("startkey=");
        try options_list.appendSlice(start_key);
        first = false;
    }

    if (options.end_key) |end_key| {
        if (!first) try options_list.appendSlice("&");
        try options_list.appendSlice("endkey=");
        try options_list.appendSlice(end_key);
        first = false;
    }

    // Set options if any were specified
    if (options_list.items.len > 0) {
        _ = c.lcb_cmdview_option_string(cmd, options_list.items.ptr, options_list.items.len);
    }

    const callback = struct {
        fn cb(instance: ?*c.lcb_INSTANCE, cbtype: c.lcb_CALLBACK_TYPE, resp: ?*const c.lcb_RESPVIEW) callconv(.C) void {
            _ = instance;
            _ = cbtype;

            var cookie: ?*anyopaque = null;
            _ = c.lcb_respview_cookie(resp, &cookie);
            var context: *ViewContext = @ptrCast(@alignCast(cookie));

            const rc = c.lcb_respview_status(resp);
            
            // Get row data
            var row_ptr: [*c]const u8 = undefined;
            var row_len: usize = undefined;
            _ = c.lcb_respview_row(resp, &row_ptr, &row_len);

            if (row_len > 0) {
                const row_copy = context.allocator.dupe(u8, row_ptr[0..row_len]) catch {
                    context.err = error.OutOfMemory;
                    context.done = true;
                    return;
                };
                context.rows.append(row_copy) catch {
                    context.allocator.free(row_copy);
                    context.err = error.OutOfMemory;
                    context.done = true;
                    return;
                };
            }

            if (c.lcb_respview_is_final(resp) != 0) {
                if (rc != c.LCB_SUCCESS) {
                    fromStatusCode(rc) catch |err| { context.err = err; };
                }
                context.done = true;
            }
        }
    }.cb;

    _ = c.lcb_install_callback(client.instance, c.LCB_CALLBACK_VIEWQUERY, @ptrCast(&callback));

    var rc = c.lcb_view(client.instance, &ctx, cmd);
    try fromStatusCode(rc);

    rc = c.lcb_wait(client.instance, 0);
    try fromStatusCode(rc);

    if (ctx.err) |err| {
        for (ctx.rows.items) |row| {
            allocator.free(row);
        }
        ctx.rows.deinit();
        return err;
    }

    return ViewResult{
        .rows = try ctx.rows.toOwnedSlice(),
        .meta = ctx.meta,
        .allocator = allocator,
    };
}

/// Execute a spatial view query (deprecated - use FTS instead)
/// Note: Spatial views are deprecated in Couchbase Server 6.0+
/// This function provides backward compatibility but may not work with newer servers
pub fn spatialViewQuery(
    client: *Client,
    allocator: std.mem.Allocator,
    design_doc: []const u8,
    view_name: []const u8,
    options: SpatialViewOptions,
) Error!ViewResult {
    // Print deprecation warning
    std.debug.print("Warning: Spatial views are deprecated in Couchbase Server 6.0+. Consider using Full-Text Search (FTS) for geospatial queries.\n", .{});
    
    var ctx = ViewContext{
        .rows = std.ArrayList([]const u8).init(allocator),
        .allocator = allocator,
    };

    var cmd: ?*c.lcb_CMDVIEW = null;
    _ = c.lcb_cmdview_create(&cmd);
    defer _ = c.lcb_cmdview_destroy(cmd);

    _ = c.lcb_cmdview_design_document(cmd, design_doc.ptr, design_doc.len);
    _ = c.lcb_cmdview_view_name(cmd, view_name.ptr, view_name.len);

    // Build spatial query options string
    var options_list = std.ArrayList(u8).init(allocator);
    defer options_list.deinit();

    var first = true;

    // Add spatial parameters
    if (options.bbox) |bbox| {
        if (!first) try options_list.appendSlice("&");
        try options_list.writer().print("bbox={d},{d},{d},{d}", .{ bbox.min_lon, bbox.min_lat, bbox.max_lon, bbox.max_lat });
        first = false;
    }

    if (options.range) |range| {
        if (!first) try options_list.appendSlice("&");
        try options_list.writer().print("range={d},{d},{d},{d}", .{ range.start_lon, range.start_lat, range.end_lon, range.end_lat });
        first = false;
    }

    // Add standard parameters
    if (options.limit) |limit| {
        if (!first) try options_list.appendSlice("&");
        try options_list.writer().print("limit={d}", .{limit});
        first = false;
    }

    if (options.skip) |skip| {
        if (!first) try options_list.appendSlice("&");
        try options_list.writer().print("skip={d}", .{skip});
        first = false;
    }

    if (options.include_docs) {
        if (!first) try options_list.appendSlice("&");
        try options_list.appendSlice("include_docs=true");
        first = false;
    }

    // Add stale parameter
    const stale_str = switch (options.stale) {
        .update_before => "false",
        .ok => "ok",
        .update_after => "update_after",
    };
    if (!first) try options_list.appendSlice("&");
    try options_list.appendSlice("stale=");
    try options_list.appendSlice(stale_str);

    // Set options if any were specified
    if (options_list.items.len > 0) {
        _ = c.lcb_cmdview_option_string(cmd, options_list.items.ptr, options_list.items.len);
    }

    const callback = struct {
        fn cb(instance: ?*c.lcb_INSTANCE, cbtype: c.lcb_CALLBACK_TYPE, resp: ?*const c.lcb_RESPVIEW) callconv(.C) void {
            _ = instance;
            _ = cbtype;

            var cookie: ?*anyopaque = null;
            _ = c.lcb_respview_cookie(resp, &cookie);
            var context: *ViewContext = @ptrCast(@alignCast(cookie));

            const rc = c.lcb_respview_status(resp);
            
            // Get row data
            var row_ptr: [*c]const u8 = undefined;
            var row_len: usize = undefined;
            _ = c.lcb_respview_row(resp, &row_ptr, &row_len);

            if (row_len > 0) {
                const row_copy = context.allocator.dupe(u8, row_ptr[0..row_len]) catch {
                    context.err = error.OutOfMemory;
                    context.done = true;
                    return;
                };
                context.rows.append(row_copy) catch {
                    context.allocator.free(row_copy);
                    context.err = error.OutOfMemory;
                    context.done = true;
                    return;
                };
            }

            if (c.lcb_respview_is_final(resp) != 0) {
                if (rc != c.LCB_SUCCESS) {
                    fromStatusCode(rc) catch |err| { context.err = err; };
                }
                context.done = true;
            }
        }
    }.cb;

    _ = c.lcb_install_callback(client.instance, c.LCB_CALLBACK_VIEWQUERY, @ptrCast(&callback));

    var rc = c.lcb_view(client.instance, &ctx, cmd);
    try fromStatusCode(rc);

    rc = c.lcb_wait(client.instance, 0);
    try fromStatusCode(rc);

    if (ctx.err) |err| {
        for (ctx.rows.items) |row| {
            allocator.free(row);
        }
        ctx.rows.deinit();
        return err;
    }

    return ViewResult{
        .rows = try ctx.rows.toOwnedSlice(),
        .meta = ctx.meta,
        .allocator = allocator,
    };
}
