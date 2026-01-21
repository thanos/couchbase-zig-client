const std = @import("std");
const couchbase = @import("couchbase");
const zbench = @import("zbench");

// Global state for benchmarks (zBench requires function pointers)
var g_client: ?*couchbase.Client = null;
var g_key: []const u8 = "";
var g_value: []const u8 = "";
var g_query: []const u8 = "";

fn benchmarkGet(allocator: std.mem.Allocator) void {
    _ = allocator;
    if (g_client) |client| {
        if (couchbase.operations.get(client, g_key)) |result| {
            result.deinit();
        } else |_| {}
    }
}

fn benchmarkUpsert(allocator: std.mem.Allocator) void {
    _ = allocator;
    if (g_client) |client| {
        _ = couchbase.operations.store(client, g_key, g_value, .upsert, .{}) catch {};
    }
}

fn benchmarkQuery(allocator: std.mem.Allocator) void {
    if (g_client) |client| {
        if (couchbase.operations.query(client, allocator, g_query, .{})) |result| {
            result.deinit();
        } else |_| {}
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("Couchbase Zig Client - Performance Benchmark (using zBench)\n", .{});
    std.debug.print("===========================================================\n\n", .{});

    // Connect to Couchbase
    // Accept either a full connection string (e.g. couchbase://127.0.0.1)
    // or a plain host (e.g. 127.0.0.1) via COUCHBASE_HOST.
    const host_raw = std.process.getEnvVarOwned(allocator, "COUCHBASE_HOST") catch try allocator.dupe(u8, "couchbase://localhost");
    defer allocator.free(host_raw);
    const host = if (std.mem.indexOf(u8, host_raw, "://") != null)
        host_raw
    else
        try std.fmt.allocPrint(allocator, "couchbase://{s}", .{host_raw});
    defer if (host.ptr != host_raw.ptr) allocator.free(host);
    const user = std.process.getEnvVarOwned(allocator, "COUCHBASE_USER") catch try allocator.dupe(u8, "Administrator");
    defer allocator.free(user);
    const password = std.process.getEnvVarOwned(allocator, "COUCHBASE_PASSWORD") catch try allocator.dupe(u8, "password");
    defer allocator.free(password);
    const bucket = std.process.getEnvVarOwned(allocator, "COUCHBASE_BUCKET") catch try allocator.dupe(u8, "default");
    defer allocator.free(bucket);
    
    var client = couchbase.Client.connect(allocator, .{
        .connection_string = host,
        .username = user,
        .password = password,
        .bucket = bucket,
    }) catch |err| {
        std.debug.print("Failed to connect: {any}\n", .{err});
        std.debug.print("Set COUCHBASE_HOST, COUCHBASE_USER, COUCHBASE_PASSWORD, COUCHBASE_BUCKET and rerun.\n", .{});
        return;
    };
    defer client.disconnect();

    std.debug.print("Connected to Couchbase\n\n", .{});

    // Prepare test data
    const test_key = "benchmark:test:key";
    const test_value = "{\"test\":\"data\",\"timestamp\":1234567890,\"value\":\"benchmark\"}";
    const test_query = "SELECT * FROM `default` WHERE test = 'data' LIMIT 10";

    // Store test document (warmup) - tolerate transient issues
    _ = client.upsert(test_key, test_value, .{ .timeout_ms = 120_000 }) catch |err| {
        std.debug.print("Warmup upsert failed: {any}\n", .{err});
        std.debug.print("Continuing benchmarks anyway (they may fail if KV is not ready).\n", .{});
    };

    // Set global state for benchmarks
    g_client = &client;
    g_key = test_key;
    g_value = test_value;
    g_query = test_query;

    // Initialize zBench with proper I/O setup for Zig 0.15.2
    const stdout_file = std.fs.File.stdout();
    var buf: [4096]u8 = undefined;
    var writer_instance = stdout_file.writer(&buf);
    const writer = &writer_instance.interface;

    var bench = zbench.Benchmark.init(allocator, .{
        .max_iterations = 16384,
        .time_budget_ns = 2_000_000_000, // 2 seconds
        .track_allocations = false,
    });
    defer bench.deinit();

    // Add benchmarks
    try bench.add("GET", benchmarkGet, .{});
    try bench.add("UPSERT", benchmarkUpsert, .{});
    try bench.add("QUERY", benchmarkQuery, .{});

    // Run all benchmarks
    std.debug.print("Running benchmarks...\n\n", .{});
    try bench.run(writer);

    std.debug.print("\nBenchmark complete!\n", .{});
}
