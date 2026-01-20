const std = @import("std");
const zbench = @import("zbench");
const Client = @import("client.zig").Client;
const operations = @import("operations.zig");

/// Benchmark configuration using zBench
pub const BenchmarkConfig = struct {
    max_iterations: u16 = 16384,
    time_budget_ns: u64 = 2_000_000_000, // 2 seconds
    track_allocations: bool = false,
    use_shuffling_allocator: bool = false,
};

/// Wrapper for running benchmarks with zBench
pub const BenchmarkRunner = struct {
    bench: zbench.Benchmark,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, config: BenchmarkConfig) !BenchmarkRunner {
        return BenchmarkRunner{
            .bench = zbench.Benchmark.init(allocator, .{
                .max_iterations = config.max_iterations,
                .time_budget_ns = config.time_budget_ns,
                .track_allocations = config.track_allocations,
                .use_shuffling_allocator = config.use_shuffling_allocator,
            }),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *BenchmarkRunner) void {
        self.bench.deinit();
    }

    /// Add a benchmark function
    pub fn add(self: *BenchmarkRunner, name: []const u8, func: *const fn (std.mem.Allocator) void, options: zbench.BenchmarkOptions) !void {
        try self.bench.add(name, func, options);
    }

    /// Run all benchmarks and write results
    pub fn run(self: *BenchmarkRunner, writer: anytype) !void {
        try self.bench.run(writer);
    }
};


/// Compare benchmark results (for comparing against libcouchbase baseline)
pub fn compareResults(zig_result_name: []const u8, baseline_result_name: []const u8, writer: anytype) !void {
    _ = zig_result_name;
    _ = baseline_result_name;
    _ = writer;
    // This would parse zBench output and compare
    // Implementation depends on how you want to store/compare results
}
