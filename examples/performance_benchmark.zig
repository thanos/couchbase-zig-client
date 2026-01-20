const std = @import("std");
const couchbase = @import("couchbase");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("Couchbase Zig Client - Performance Benchmark\n", .{});
    std.debug.print("============================================\n\n", .{});

    // Connect to Couchbase
    const host = std.process.getEnvVarOwned(allocator, "COUCHBASE_HOST") catch try allocator.dupe(u8, "couchbase://localhost");
    defer allocator.free(host);
    const user = std.process.getEnvVarOwned(allocator, "COUCHBASE_USER") catch try allocator.dupe(u8, "Administrator");
    defer allocator.free(user);
    const password = std.process.getEnvVarOwned(allocator, "COUCHBASE_PASSWORD") catch try allocator.dupe(u8, "password");
    defer allocator.free(password);
    const bucket = std.process.getEnvVarOwned(allocator, "COUCHBASE_BUCKET") catch try allocator.dupe(u8, "default");
    defer allocator.free(bucket);
    
    var client = try couchbase.Client.connect(allocator, .{
        .connection_string = host,
        .username = user,
        .password = password,
        .bucket = bucket,
    });
    defer client.disconnect();

    std.debug.print("Connected to Couchbase\n\n", .{});

    // Prepare test data
    const test_key = "benchmark:test:key";
    const test_value = "{\"test\":\"data\",\"timestamp\":1234567890,\"value\":\"benchmark\"}";

    // Store test document
    _ = try client.upsert(test_key, test_value, .{});

    // Benchmark configuration
    const config = couchbase.BenchmarkConfig{
        .iterations = 1000,
        .warmup_iterations = 100,
        .enable_memory_tracking = true,
        .print_progress = true,
    };

    std.debug.print("Running GET benchmark...\n", .{});
    const get_result = try couchbase.performance.benchmarkGet(&client, allocator, config, test_key);
    std.debug.print("{}\n", .{get_result});

    std.debug.print("\nRunning UPSERT benchmark...\n", .{});
    const upsert_result = try couchbase.performance.benchmarkUpsert(&client, allocator, config, test_key, test_value);
    std.debug.print("{}\n", .{upsert_result});

    std.debug.print("\nRunning QUERY benchmark...\n", .{});
    const query = "SELECT * FROM `default` WHERE test = 'data' LIMIT 10";
    const query_result = try couchbase.performance.benchmarkQuery(&client, allocator, config, query);
    std.debug.print("{}\n", .{query_result});

    std.debug.print("\nBenchmark Summary:\n", .{});
    std.debug.print("  GET:     {d:.2}μs avg, {d:.2} ops/sec\n", .{
        @as(f64, @floatFromInt(get_result.avg_time_ns)) / 1000.0,
        get_result.throughput_ops_per_sec,
    });
    std.debug.print("  UPSERT:  {d:.2}μs avg, {d:.2} ops/sec\n", .{
        @as(f64, @floatFromInt(upsert_result.avg_time_ns)) / 1000.0,
        upsert_result.throughput_ops_per_sec,
    });
    std.debug.print("  QUERY:   {d:.2}μs avg, {d:.2} ops/sec\n", .{
        @as(f64, @floatFromInt(query_result.avg_time_ns)) / 1000.0,
        query_result.throughput_ops_per_sec,
    });
}
