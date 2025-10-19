const std = @import("std");
const couchbase = @import("couchbase");

test "ping result creation and cleanup" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Test PingResult creation and cleanup
    const id = try allocator.dupe(u8, "test-ping");
    const services = try allocator.alloc(couchbase.ServiceHealth, 2);
    
    services[0] = couchbase.ServiceHealth{
        .id = try allocator.dupe(u8, "kv"),
        .latency_us = 1000,
        .state = .ok,
    };
    
    services[1] = couchbase.ServiceHealth{
        .id = try allocator.dupe(u8, "query"),
        .latency_us = 2000,
        .state = .timeout,
    };
    
    var ping_result = couchbase.PingResult{
        .id = id,
        .services = services,
        .allocator = allocator,
    };
    
    // Test that we can access the data
    try std.testing.expectEqualStrings("test-ping", ping_result.id);
    try std.testing.expectEqual(@as(usize, 2), ping_result.services.len);
    try std.testing.expectEqualStrings("kv", ping_result.services[0].id);
    try std.testing.expectEqual(@as(u64, 1000), ping_result.services[0].latency_us);
    try std.testing.expectEqual(couchbase.ServiceState.ok, ping_result.services[0].state);
    try std.testing.expectEqualStrings("query", ping_result.services[1].id);
    try std.testing.expectEqual(@as(u64, 2000), ping_result.services[1].latency_us);
    try std.testing.expectEqual(couchbase.ServiceState.timeout, ping_result.services[1].state);
    
    // Test cleanup
    ping_result.deinit();
}

test "diagnostics result creation and cleanup" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Test DiagnosticsResult creation and cleanup
    const id = try allocator.dupe(u8, "test-diagnostics");
    const services = try allocator.alloc(couchbase.ServiceDiagnostics, 1);
    
    services[0] = couchbase.ServiceDiagnostics{
        .id = try allocator.dupe(u8, "kv"),
        .last_activity_us = 5000,
        .state = .ok,
    };
    
    var diag_result = couchbase.DiagnosticsResult{
        .id = id,
        .services = services,
        .allocator = allocator,
    };
    
    // Test that we can access the data
    try std.testing.expectEqualStrings("test-diagnostics", diag_result.id);
    try std.testing.expectEqual(@as(usize, 1), diag_result.services.len);
    try std.testing.expectEqualStrings("kv", diag_result.services[0].id);
    try std.testing.expectEqual(@as(u64, 5000), diag_result.services[0].last_activity_us);
    try std.testing.expectEqual(couchbase.ServiceState.ok, diag_result.services[0].state);
    
    // Test cleanup
    diag_result.deinit();
}

test "cluster config result creation and cleanup" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Test ClusterConfigResult creation and cleanup
    const config = try allocator.dupe(u8, "{\"version\":\"1.0\",\"services\":{}}");
    
    var cluster_config = couchbase.ClusterConfigResult{
        .config = config,
        .allocator = allocator,
    };
    
    // Test that we can access the data
    try std.testing.expectEqualStrings("{\"version\":\"1.0\",\"services\":{}}", cluster_config.config);
    
    // Test cleanup
    cluster_config.deinit();
}

test "SDK metrics result creation and cleanup" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Test SdkMetricsResult creation and cleanup
    var metrics = std.StringHashMap(couchbase.MetricValue).init(allocator);
    
    const counter_key = try allocator.dupe(u8, "connection_count");
    try metrics.put(counter_key, .{ .counter = 5 });
    
    const gauge_key = try allocator.dupe(u8, "operation_timeout_ms");
    try metrics.put(gauge_key, .{ .gauge = 75000.0 });
    
    var metrics_result = couchbase.SdkMetricsResult{
        .metrics = metrics,
        .allocator = allocator,
    };
    
    // Test that we can access the data
    try std.testing.expectEqual(@as(usize, 2), metrics_result.metrics.count());
    
    const counter_entry = metrics_result.metrics.get("connection_count").?;
    try std.testing.expectEqual(couchbase.MetricValue{ .counter = 5 }, counter_entry);
    
    const gauge_entry = metrics_result.metrics.get("operation_timeout_ms").?;
    try std.testing.expectEqual(couchbase.MetricValue{ .gauge = 75000.0 }, gauge_entry);
    
    // Test cleanup
    metrics_result.deinit();
}

test "SDK metrics memory cleanup with text and histogram values" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Test SdkMetricsResult with text and histogram values that need cleanup
    var metrics = std.StringHashMap(couchbase.MetricValue).init(allocator);
    
    // Add a text metric
    const text_key = try allocator.dupe(u8, "server_version");
    const text_value = try allocator.dupe(u8, "7.0.0");
    try metrics.put(text_key, .{ .text = text_value });
    
    // Add a histogram metric
    const histogram_key = try allocator.dupe(u8, "operation_latency");
    const percentiles = try allocator.alloc(couchbase.PercentileData, 3);
    percentiles[0] = couchbase.PercentileData{ .percentile = 50.0, .value = 100.0 };
    percentiles[1] = couchbase.PercentileData{ .percentile = 95.0, .value = 200.0 };
    percentiles[2] = couchbase.PercentileData{ .percentile = 99.0, .value = 500.0 };
    
    const histogram_data = couchbase.HistogramData{
        .count = 1000,
        .min = 50.0,
        .max = 1000.0,
        .mean = 150.0,
        .std_dev = 75.0,
        .percentiles = percentiles,
        .allocator = allocator,
    };
    
    try metrics.put(histogram_key, .{ .histogram = histogram_data });
    
    var metrics_result = couchbase.SdkMetricsResult{
        .metrics = metrics,
        .allocator = allocator,
    };
    
    // Test that we can access the data
    try std.testing.expectEqual(@as(usize, 2), metrics_result.metrics.count());
    
    const text_entry = metrics_result.metrics.get("server_version").?;
    try std.testing.expectEqualStrings("7.0.0", text_entry.text);
    
    const histogram_entry = metrics_result.metrics.get("operation_latency").?;
    try std.testing.expectEqual(@as(u64, 1000), histogram_entry.histogram.count);
    try std.testing.expectEqual(@as(f64, 150.0), histogram_entry.histogram.mean);
    try std.testing.expectEqual(@as(usize, 3), histogram_entry.histogram.percentiles.len);
    
    // Test cleanup - this should free all nested allocations
    metrics_result.deinit();
}

test "HTTP tracing result creation and cleanup" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Test HttpTracingResult creation and cleanup
    const traces = try allocator.alloc(couchbase.HttpTrace, 1);
    
    traces[0] = couchbase.HttpTrace{
        .url = try allocator.dupe(u8, "http://localhost:8093/query/service"),
        .method = try allocator.dupe(u8, "POST"),
        .status_code = 200,
        .duration_ms = 150,
    };
    
    var tracing_result = couchbase.HttpTracingResult{
        .traces = traces,
        .allocator = allocator,
    };
    
    // Test that we can access the data
    try std.testing.expectEqual(@as(usize, 1), tracing_result.traces.len);
    try std.testing.expectEqualStrings("http://localhost:8093/query/service", tracing_result.traces[0].url);
    try std.testing.expectEqualStrings("POST", tracing_result.traces[0].method);
    try std.testing.expectEqual(@as(u16, 200), tracing_result.traces[0].status_code);
    try std.testing.expectEqual(@as(u64, 150), tracing_result.traces[0].duration_ms);
    
    // Test cleanup
    tracing_result.deinit();
}
