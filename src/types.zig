const std = @import("std");
const c = @import("c.zig");

/// Document representation
pub const Document = struct {
    id: []const u8,
    content: []const u8,
    cas: u64 = 0,
    flags: u32 = 0,
};

/// Durability level for operations
pub const DurabilityLevel = enum(c_uint) {
    none = c.LCB_DURABILITYLEVEL_NONE,
    majority = c.LCB_DURABILITYLEVEL_MAJORITY,
    majority_and_persist_to_active = c.LCB_DURABILITYLEVEL_MAJORITY_AND_PERSIST_TO_ACTIVE,
    persist_to_majority = c.LCB_DURABILITYLEVEL_PERSIST_TO_MAJORITY,
};

/// Durability settings
pub const Durability = struct {
    level: DurabilityLevel = .none,
    timeout_ms: u32 = 0,
};

/// Store operation type
pub const StoreOperation = enum(c_uint) {
    upsert = c.LCB_STORE_UPSERT,
    insert = c.LCB_STORE_INSERT,
    replace = c.LCB_STORE_REPLACE,
    append = c.LCB_STORE_APPEND,
    prepend = c.LCB_STORE_PREPEND,
};

/// Replica mode for get operations
pub const ReplicaMode = enum {
    any,
    all,
    index,
};

/// Subdocument operation type
pub const SubdocOp = enum(c_uint) {
    get = 0,
    exists = 1,
    replace = 2,
    dict_add = 3,
    dict_upsert = 4,
    array_add_first = 5,
    array_add_last = 6,
    array_add_unique = 7,
    array_insert = 8,
    delete = 9,
    counter = 10,
    get_count = 11,
};

/// Scan consistency for queries
pub const ScanConsistency = enum(c_uint) {
    not_bounded = 0,
    request_plus = 1,
};

/// Query profile mode
pub const QueryProfile = enum(c_uint) {
    off = 0,
    phases = 1,
    timings = 2,
};

/// Query consistency mode
pub const QueryConsistency = enum(c_uint) {
    not_bounded = 0,
    request_plus = 1,
    statement_plus = 2,
};

/// Analytics query options
pub const AnalyticsOptions = struct {
    timeout_ms: u32 = 300000,
    priority: bool = false,
    client_context_id: ?[]const u8 = null,
    read_only: bool = false,
    max_parallelism: ?u32 = null,
    pipeline_batch: ?u32 = null,
    pipeline_cap: ?u32 = null,
    scan_cap: ?u32 = null,
    scan_wait: ?u32 = null,
    scan_consistency: ?[]const u8 = null,
    query_context: ?[]const u8 = null,
    pretty: bool = false,
    metrics: bool = true,
    raw: ?[]const u8 = null,
    positional_parameters: ?[]const []const u8 = null,
    named_parameters: ?std.StringHashMap([]const u8) = null,
};

/// Search query options
pub const SearchOptions = struct {
    timeout_ms: u32 = 75000,
    limit: ?u32 = null,
    skip: ?u32 = null,
    explain: bool = false,
    highlight_style: ?[]const u8 = null,
    highlight_fields: ?[]const []const u8 = null,
    sort: ?[]const []const u8 = null,
    facets: ?[]const []const u8 = null,
    fields: ?[]const []const u8 = null,
    disable_scoring: bool = false,
    include_locations: bool = false,
    consistent_with: ?[]const u8 = null,
    client_context_id: ?[]const u8 = null,
    raw: ?[]const u8 = null,
};

/// View query options
pub const ViewQueryOptions = struct {
    start_key: ?[]const u8 = null,
    end_key: ?[]const u8 = null,
    limit: ?u32 = null,
    skip: ?u32 = null,
    descending: bool = false,
    include_docs: bool = false,
};
