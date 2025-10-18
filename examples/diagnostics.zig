const std = @import("std");
const couchbase = @import("couchbase");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Connect to Couchbase
    var client = couchbase.Client.connect(allocator, .{
        .connection_string = "couchbase://127.0.0.1",
        .username = "tester",
        .password = "csfb2010",
        .bucket = "default",
        .timeout_ms = 10000,
    }) catch |err| {
        std.debug.print("Failed to connect: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    std.debug.print("=== Couchbase Diagnostics & Monitoring Demo ===\n\n");

    // 1. Ping all services
    std.debug.print("1. Pinging all services...\n");
    const ping_result = client.ping(allocator) catch |err| {
        std.debug.print("Ping failed: {}\n", .{err});
        return;
    };
    defer ping_result.deinit();

    std.debug.print("Ping ID: {s}\n", .{ping_result.id});
    std.debug.print("Services checked: {}\n", .{ping_result.services.len});
    
    for (ping_result.services, 0..) |service, i| {
        const state_str = switch (service.state) {
            .ok => "OK",
            .timeout => "TIMEOUT",
            .error_other => "ERROR",
        };
        std.debug.print("  Service {}: {s} - {}us - {s}\n", .{ i, service.id, service.latency_us, state_str });
    }

    // 2. Get diagnostics
    std.debug.print("\n2. Getting diagnostics...\n");
    const diag_result = client.diagnostics(allocator) catch |err| {
        std.debug.print("Diagnostics failed: {}\n", .{err});
        return;
    };
    defer diag_result.deinit();

    std.debug.print("Diagnostics ID: {s}\n", .{diag_result.id});
    std.debug.print("Services diagnosed: {}\n", .{diag_result.services.len});
    
    for (diag_result.services, 0..) |service, i| {
        const state_str = switch (service.state) {
            .ok => "OK",
            .timeout => "TIMEOUT",
            .error_other => "ERROR",
        };
        std.debug.print("  Service {}: {s} - {}us - {s}\n", .{ i, service.id, service.last_activity_us, state_str });
    }

    // 3. Get cluster configuration
    std.debug.print("\n3. Getting cluster configuration...\n");
    const cluster_config = client.getClusterConfig(allocator) catch |err| {
        std.debug.print("Cluster config failed: {}\n", .{err});
        return;
    };
    defer cluster_config.deinit();

    std.debug.print("Cluster config length: {} bytes\n", .{cluster_config.config.len});
    if (cluster_config.config.len > 0) {
        const preview_len = @min(300, cluster_config.config.len);
        std.debug.print("Config preview: {s}\n", .{cluster_config.config[0..preview_len]});
        if (cluster_config.config.len > 300) {
            std.debug.print("... (truncated)\n");
        }
    }

    // 4. Get SDK metrics
    std.debug.print("\n4. Getting SDK metrics...\n");
    const metrics = client.getSdkMetrics(allocator) catch |err| {
        std.debug.print("SDK metrics failed: {}\n", .{err});
        return;
    };
    defer metrics.deinit();

    std.debug.print("Metrics collected: {}\n", .{metrics.metrics.count()});
    
    var iterator = metrics.metrics.iterator();
    while (iterator.next()) |entry| {
        std.debug.print("  {s}: ", .{entry.key_ptr.*});
        switch (entry.value_ptr.*) {
            .counter => |val| std.debug.print("{}\n", .{val}),
            .gauge => |val| std.debug.print("{}\n", .{val}),
            .text => |val| std.debug.print("{s}\n", .{val}),
            .histogram => |val| std.debug.print("histogram (count: {}, mean: {})\n", .{ val.count, val.mean }),
        }
    }

    // 5. Enable HTTP tracing
    std.debug.print("\n5. Enabling HTTP tracing...\n");
    client.enableHttpTracing(allocator) catch |err| {
        std.debug.print("Enable HTTP tracing failed: {}\n", .{err});
        return;
    };
    std.debug.print("HTTP tracing enabled\n");

    // 6. Get HTTP traces
    std.debug.print("\n6. Getting HTTP traces...\n");
    const traces = client.getHttpTraces(allocator) catch |err| {
        std.debug.print("Get HTTP traces failed: {}\n", .{err});
        return;
    };
    defer traces.deinit();

    std.debug.print("HTTP traces collected: {}\n", .{traces.traces.len});
    
    for (traces.traces, 0..) |trace, i| {
        std.debug.print("  Trace {}: {} {} - {}ms - {}\n", .{ i, trace.method, trace.url, trace.duration_ms, trace.status_code });
    }

    std.debug.print("\n=== Diagnostics Demo Complete ===\n");
}
