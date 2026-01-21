// C bindings for libcouchbase
// This file is a simple @cImport that other modules can use
// Import this file as: const c = @import("c.zig");
// Then access symbols as: c.lcb_create, c.lcb_STATUS, etc.
pub const lcb = @cImport({
    @cInclude("libcouchbase/couchbase.h");
});
