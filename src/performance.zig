const std = @import("std");
const Client = @import("client.zig").Client;
const operations = @import("operations.zig");

/// Performance benchmark results
pub const BenchmarkResult = struct {
    operation_name: []const u8,
    iterations: u64,
    total_time_ns: u64,
    min_time_ns: u64,
    max_time_ns: u64,
    avg_time_ns: u64,
    p50_time_ns: u64,
    p95_time_ns: u64,
    p99_time_ns: u64,
    throughput_ops_per_sec: f64,
    memory_allocations: u64,
    memory_bytes_allocated: u64,
    errors: u64,

    pub fn format(self: BenchmarkResult, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print(
            \\Benchmark: {s}
            \\  Iterations: {}
            \\  Total Time: {d:.2}ms
            \\  Min: {d:.2}μs
            \\  Max: {d:.2}μs
            \\  Avg: {d:.2}μs
            \\  P50: {d:.2}μs
            \\  P95: {d:.2}μs
            \\  P99: {d:.2}μs
            \\  Throughput: {d:.2} ops/sec
            \\  Memory Allocations: {}
            \\  Memory Allocated: {} bytes
            \\  Errors: {}
            \\
        , .{
            self.operation_name,
            self.iterations,
            @as(f64, @floatFromInt(self.total_time_ns)) / 1_000_000.0,
            @as(f64, @floatFromInt(self.min_time_ns)) / 1000.0,
            @as(f64, @floatFromInt(self.max_time_ns)) / 1000.0,
            @as(f64, @floatFromInt(self.avg_time_ns)) / 1000.0,
            @as(f64, @floatFromInt(self.p50_time_ns)) / 1000.0,
            @as(f64, @floatFromInt(self.p95_time_ns)) / 1000.0,
            @as(f64, @floatFromInt(self.p99_time_ns)) / 1000.0,
            self.throughput_ops_per_sec,
            self.memory_allocations,
            self.memory_bytes_allocated,
            self.errors,
        });
    }
};

/// Benchmark configuration
pub const BenchmarkConfig = struct {
    iterations: u64 = 1000,
    warmup_iterations: u64 = 100,
    enable_memory_tracking: bool = true,
    print_progress: bool = false,
};

/// Memory tracking allocator wrapper
const TrackingAllocator = struct {
    parent: std.mem.Allocator,
    allocations: *u64,
    bytes_allocated: *u64,

    fn allocator(self: *TrackingAllocator) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .free = free,
            },
        };
    }

    fn alloc(ctx: *anyopaque, len: usize, log2_align: u8, return_address: usize) ?[*]u8 {
        const self: *TrackingAllocator = @ptrCast(@alignCast(ctx));
        self.allocations.* += 1;
        self.bytes_allocated.* += len;
        return self.parent.alloc(len, log2_align, return_address);
    }

    fn resize(ctx: *anyopaque, buf: []u8, log2_align: u8, new_len: usize, return_address: usize) bool {
        const self: *TrackingAllocator = @ptrCast(@alignCast(ctx));
        if (new_len > buf.len) {
            self.bytes_allocated.* += new_len - buf.len;
        }
        return self.parent.resize(buf, log2_align, new_len, return_address);
    }

    fn free(ctx: *anyopaque, buf: []u8, log2_align: u8, return_address: usize) void {
        _ = ctx;
        _ = log2_align;
        _ = return_address;
        _ = buf;
        // Don't decrement on free - we track peak usage
    }
};

/// Benchmark GET operations
pub fn benchmarkGet(client: *Client, allocator: std.mem.Allocator, config: BenchmarkConfig, key: []const u8) !BenchmarkResult {
    const allocations: u64 = 0;
    const bytes_allocated: u64 = 0;
    // Note: Memory tracking disabled for now as it interferes with normal operations
    // The allocator passed to operations is the client's allocator, not the tracking one
    _ = config.enable_memory_tracking;

    // Warmup
    for (0..config.warmup_iterations) |_| {
        if (operations.get(client, key)) |result| {
            result.deinit();
        } else |_| {}
    }

    var timings = std.ArrayList(u64).init(allocator);
    defer timings.deinit();
    try timings.ensureTotalCapacity(config.iterations);

    var errors: u64 = 0;
    const start_time = std.time.nanoTimestamp();

    for (0..config.iterations) |i| {
        if (config.print_progress and i % 100 == 0) {
            std.debug.print("Progress: {}/{} iterations\n", .{ i, config.iterations });
        }

        const iter_start = std.time.nanoTimestamp();
        if (operations.get(client, key)) |result| {
            const iter_end = std.time.nanoTimestamp();
            const duration = @as(u64, @intCast(iter_end - iter_start));
            try timings.append(duration);
            result.deinit();
        } else |_| {
            errors += 1;
        }
    }

    const end_time = std.time.nanoTimestamp();
    const total_time = @as(u64, @intCast(end_time - start_time));

    return calculateStats("GET", timings.items, total_time, allocations, bytes_allocated, errors, config.iterations);
}

/// Benchmark UPSERT operations
pub fn benchmarkUpsert(client: *Client, allocator: std.mem.Allocator, config: BenchmarkConfig, key: []const u8, value: []const u8) !BenchmarkResult {
    const allocations: u64 = 0;
    const bytes_allocated: u64 = 0;
    // Note: Memory tracking disabled for now as it interferes with normal operations
    _ = config.enable_memory_tracking;

    // Warmup
    for (0..config.warmup_iterations) |_| {
        _ = operations.store(client, key, value, .upsert, .{}) catch {};
    }

    var timings = std.ArrayList(u64).init(allocator);
    defer timings.deinit();
    try timings.ensureTotalCapacity(config.iterations);

    var errors: u64 = 0;
    const start_time = std.time.nanoTimestamp();

    for (0..config.iterations) |i| {
        if (config.print_progress and i % 100 == 0) {
            std.debug.print("Progress: {}/{} iterations\n", .{ i, config.iterations });
        }

        const iter_start = std.time.nanoTimestamp();
        _ = operations.store(client, key, value, .upsert, .{}) catch |err| {
            _ = err catch {};
            errors += 1;
            continue;
        };
        const iter_end = std.time.nanoTimestamp();
        const duration = @as(u64, @intCast(iter_end - iter_start));
        try timings.append(duration);
    }

    const end_time = std.time.nanoTimestamp();
    const total_time = @as(u64, @intCast(end_time - start_time));

    return calculateStats("UPSERT", timings.items, total_time, allocations, bytes_allocated, errors, config.iterations);
}

/// Benchmark QUERY operations
pub fn benchmarkQuery(client: *Client, allocator: std.mem.Allocator, config: BenchmarkConfig, query: []const u8) !BenchmarkResult {
    const allocations: u64 = 0;
    const bytes_allocated: u64 = 0;
    // Note: Memory tracking disabled for now as it interferes with normal operations
    _ = config.enable_memory_tracking;

    // Warmup
    for (0..config.warmup_iterations) |_| {
        if (operations.query(client, allocator, query, .{})) |result| {
            result.deinit();
        } else |_| {}
    }

    var timings = std.ArrayList(u64).init(allocator);
    defer timings.deinit();
    try timings.ensureTotalCapacity(config.iterations);

    var errors: u64 = 0;
    const start_time = std.time.nanoTimestamp();

    for (0..config.iterations) |i| {
        if (config.print_progress and i % 100 == 0) {
            std.debug.print("Progress: {}/{} iterations\n", .{ i, config.iterations });
        }

        const iter_start = std.time.nanoTimestamp();
        if (operations.query(client, allocator, query, .{})) |result| {
            const iter_end = std.time.nanoTimestamp();
            const duration = @as(u64, @intCast(iter_end - iter_start));
            try timings.append(duration);
            result.deinit();
        } else |_| {
            errors += 1;
        }
    }

    const end_time = std.time.nanoTimestamp();
    const total_time = @as(u64, @intCast(end_time - start_time));

    return calculateStats("QUERY", timings.items, total_time, allocations, bytes_allocated, errors, config.iterations);
}

/// Calculate statistics from timing data
fn calculateStats(
    operation_name: []const u8,
    timings: []u64,
    total_time_ns: u64,
    allocations: u64,
    bytes_allocated: u64,
    errors: u64,
    iterations: u64,
) BenchmarkResult {
    const allocator = std.heap.page_allocator;
    if (timings.len == 0) {
        return BenchmarkResult{
            .operation_name = operation_name,
            .iterations = iterations,
            .total_time_ns = total_time_ns,
            .min_time_ns = 0,
            .max_time_ns = 0,
            .avg_time_ns = 0,
            .p50_time_ns = 0,
            .p95_time_ns = 0,
            .p99_time_ns = 0,
            .throughput_ops_per_sec = 0.0,
            .memory_allocations = allocations,
            .memory_bytes_allocated = bytes_allocated,
            .errors = errors,
        };
    }

    // Sort timings for percentile calculation (create mutable copy)
    const sorted_timings = allocator.dupe(u64, timings) catch return BenchmarkResult{
        .operation_name = operation_name,
        .iterations = iterations,
        .total_time_ns = total_time_ns,
        .min_time_ns = 0,
        .max_time_ns = 0,
        .avg_time_ns = 0,
        .p50_time_ns = 0,
        .p95_time_ns = 0,
        .p99_time_ns = 0,
        .throughput_ops_per_sec = 0.0,
        .memory_allocations = allocations,
        .memory_bytes_allocated = bytes_allocated,
        .errors = errors,
    };
    defer allocator.free(sorted_timings);
    // Sort in place - std.mem.sort mutates the slice but Zig can't track it
    std.mem.sort(u64, @constCast(sorted_timings), {}, comptime std.sort.asc(u64));

    const min = sorted_timings[0];
    const max = sorted_timings[sorted_timings.len - 1];
    const sum = blk: {
        var s: u64 = 0;
        for (sorted_timings) |t| {
            s += t;
        }
        break :blk s;
    };
    const avg = sum / @as(u64, @intCast(sorted_timings.len));

    const p50_idx = sorted_timings.len * 50 / 100;
    const p95_idx = sorted_timings.len * 95 / 100;
    const p99_idx = sorted_timings.len * 99 / 100;

    const p50 = sorted_timings[@min(p50_idx, sorted_timings.len - 1)];
    const p95 = sorted_timings[@min(p95_idx, sorted_timings.len - 1)];
    const p99 = sorted_timings[@min(p99_idx, sorted_timings.len - 1)];

    const successful_ops = @as(f64, @floatFromInt(sorted_timings.len));
    const total_time_sec = @as(f64, @floatFromInt(total_time_ns)) / 1_000_000_000.0;
    const throughput = if (total_time_sec > 0.0) successful_ops / total_time_sec else 0.0;

    return BenchmarkResult{
        .operation_name = operation_name,
        .iterations = iterations,
        .total_time_ns = total_time_ns,
        .min_time_ns = min,
        .max_time_ns = max,
        .avg_time_ns = avg,
        .p50_time_ns = p50,
        .p95_time_ns = p95,
        .p99_time_ns = p99,
        .throughput_ops_per_sec = throughput,
        .memory_allocations = allocations,
        .memory_bytes_allocated = bytes_allocated,
        .errors = errors,
    };
}

/// Compare two benchmark results
pub fn compareResults(zig_result: BenchmarkResult, baseline_result: BenchmarkResult, writer: anytype) !void {
    const avg_diff = if (baseline_result.avg_time_ns > 0)
        (@as(f64, @floatFromInt(zig_result.avg_time_ns)) - @as(f64, @floatFromInt(baseline_result.avg_time_ns))) / @as(f64, @floatFromInt(baseline_result.avg_time_ns)) * 100.0
    else
        0.0;

    const throughput_diff = if (baseline_result.throughput_ops_per_sec > 0)
        (zig_result.throughput_ops_per_sec - baseline_result.throughput_ops_per_sec) / baseline_result.throughput_ops_per_sec * 100.0
    else
        0.0;

    try writer.print(
        \\Comparison: {s}
        \\  Average Latency: {s:+.2f}% ({d:.2}μs vs {d:.2}μs)
        \\  Throughput: {s:+.2f}% ({d:.2} vs {d:.2} ops/sec)
        \\  Memory Allocations: {} vs {}
        \\  Memory Allocated: {} vs {} bytes
        \\
    , .{
        zig_result.operation_name,
        if (avg_diff >= 0) "+" else "",
        avg_diff,
        @as(f64, @floatFromInt(zig_result.avg_time_ns)) / 1000.0,
        @as(f64, @floatFromInt(baseline_result.avg_time_ns)) / 1000.0,
        if (throughput_diff >= 0) "+" else "",
        throughput_diff,
        zig_result.throughput_ops_per_sec,
        baseline_result.throughput_ops_per_sec,
        zig_result.memory_allocations,
        baseline_result.memory_allocations,
        zig_result.memory_bytes_allocated,
        baseline_result.memory_bytes_allocated,
    });
}
