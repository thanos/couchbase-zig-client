const std = @import("std");
const couchbase = @import("couchbase");

const TestConfig = couchbase.TestConfig;

test "ping operation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = TestConfig{
        .connection_string = std.process.getEnvVarOwned(allocator, "COUCHBASE_HOST") catch "couchbase://127.0.0.1",
        .username = std.process.getEnvVarOwned(allocator, "COUCHBASE_USER") catch "tester",
        .password = std.process.getEnvVarOwned(allocator, "COUCHBASE_PASSWORD") catch "csfb2010",
        .bucket = std.process.getEnvVarOwned(allocator, "COUCHBASE_BUCKET") catch "default",
        .timeout_ms = 30000,
    };
    defer allocator.free(config.connection_string);
    defer allocator.free(config.username);
    defer allocator.free(config.password);
    defer allocator.free(config.bucket);

    var client = couchbase.Client.connect(allocator, .{
        .connection_string = config.connection_string,
        .username = config.username,
        .password = config.password,
        .bucket = config.bucket,
        .timeout_ms = config.timeout_ms,
    }) catch |err| {
        std.debug.print("Failed to connect: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    var ping_result = client.ping(allocator) catch |err| {
        std.debug.print("Ping failed: {}\n", .{err});
        return;
    };
    defer ping_result.deinit();

    std.debug.print("Ping ID: {s}\n", .{ping_result.id});
    std.debug.print("Services checked: {}\n", .{ping_result.services.len});
    
    for (ping_result.services, 0..) |service, i| {
        std.debug.print("Service {}: {s} - {}us - {}\n", .{ i, service.id, service.latency_us, service.state });
    }
}

test "diagnostics operation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = TestConfig{
        .connection_string = std.process.getEnvVarOwned(allocator, "COUCHBASE_HOST") catch "couchbase://127.0.0.1",
        .username = std.process.getEnvVarOwned(allocator, "COUCHBASE_USER") catch "tester",
        .password = std.process.getEnvVarOwned(allocator, "COUCHBASE_PASSWORD") catch "csfb2010",
        .bucket = std.process.getEnvVarOwned(allocator, "COUCHBASE_BUCKET") catch "default",
        .timeout_ms = 30000,
    };
    defer allocator.free(config.connection_string);
    defer allocator.free(config.username);
    defer allocator.free(config.password);
    defer allocator.free(config.bucket);

    var client = couchbase.Client.connect(allocator, .{
        .connection_string = config.connection_string,
        .username = config.username,
        .password = config.password,
        .bucket = config.bucket,
        .timeout_ms = config.timeout_ms,
    }) catch |err| {
        std.debug.print("Failed to connect: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    var diag_result = client.diagnostics(allocator) catch |err| {
        std.debug.print("Diagnostics failed: {}\n", .{err});
        return;
    };
    defer diag_result.deinit();

    std.debug.print("Diagnostics ID: {s}\n", .{diag_result.id});
    std.debug.print("Services diagnosed: {}\n", .{diag_result.services.len});
    
    for (diag_result.services, 0..) |service, i| {
        std.debug.print("Service {}: {s} - {}us - {}\n", .{ i, service.id, service.last_activity_us, service.state });
    }
}

test "cluster configuration" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = TestConfig{
        .connection_string = std.process.getEnvVarOwned(allocator, "COUCHBASE_HOST") catch "couchbase://127.0.0.1",
        .username = std.process.getEnvVarOwned(allocator, "COUCHBASE_USER") catch "tester",
        .password = std.process.getEnvVarOwned(allocator, "COUCHBASE_PASSWORD") catch "csfb2010",
        .bucket = std.process.getEnvVarOwned(allocator, "COUCHBASE_BUCKET") catch "default",
        .timeout_ms = 30000,
    };
    defer allocator.free(config.connection_string);
    defer allocator.free(config.username);
    defer allocator.free(config.password);
    defer allocator.free(config.bucket);

    var client = couchbase.Client.connect(allocator, .{
        .connection_string = config.connection_string,
        .username = config.username,
        .password = config.password,
        .bucket = config.bucket,
        .timeout_ms = config.timeout_ms,
    }) catch |err| {
        std.debug.print("Failed to connect: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    var cluster_config = client.getClusterConfig(allocator) catch |err| {
        std.debug.print("Cluster config failed: {}\n", .{err});
        return;
    };
    defer cluster_config.deinit();

    std.debug.print("Cluster config length: {}\n", .{cluster_config.config.len});
    if (cluster_config.config.len > 0) {
        std.debug.print("Config preview: {s}\n", .{cluster_config.config[0..@min(200, cluster_config.config.len)]});
    }
}

test "SDK metrics" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = TestConfig{
        .connection_string = std.process.getEnvVarOwned(allocator, "COUCHBASE_HOST") catch "couchbase://127.0.0.1",
        .username = std.process.getEnvVarOwned(allocator, "COUCHBASE_USER") catch "tester",
        .password = std.process.getEnvVarOwned(allocator, "COUCHBASE_PASSWORD") catch "csfb2010",
        .bucket = std.process.getEnvVarOwned(allocator, "COUCHBASE_BUCKET") catch "default",
        .timeout_ms = 30000,
    };
    defer allocator.free(config.connection_string);
    defer allocator.free(config.username);
    defer allocator.free(config.password);
    defer allocator.free(config.bucket);

    var client = couchbase.Client.connect(allocator, .{
        .connection_string = config.connection_string,
        .username = config.username,
        .password = config.password,
        .bucket = config.bucket,
        .timeout_ms = config.timeout_ms,
    }) catch |err| {
        std.debug.print("Failed to connect: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    var metrics = client.getSdkMetrics(allocator) catch |err| {
        std.debug.print("SDK metrics failed: {}\n", .{err});
        return;
    };
    defer metrics.deinit();

    std.debug.print("Metrics collected: {}\n", .{metrics.metrics.count()});
    
    var iterator = metrics.metrics.iterator();
    while (iterator.next()) |entry| {
        std.debug.print("Metric: {s} = ", .{entry.key_ptr.*});
        switch (entry.value_ptr.*) {
            .counter => |val| std.debug.print("{}\n", .{val}),
            .gauge => |val| std.debug.print("{}\n", .{val}),
            .text => |val| std.debug.print("{s}\n", .{val}),
            .histogram => |val| std.debug.print("histogram (count: {})\n", .{val.count}),
        }
    }
}

test "HTTP tracing" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = TestConfig{
        .connection_string = std.process.getEnvVarOwned(allocator, "COUCHBASE_HOST") catch "couchbase://127.0.0.1",
        .username = std.process.getEnvVarOwned(allocator, "COUCHBASE_USER") catch "tester",
        .password = std.process.getEnvVarOwned(allocator, "COUCHBASE_PASSWORD") catch "csfb2010",
        .bucket = std.process.getEnvVarOwned(allocator, "COUCHBASE_BUCKET") catch "default",
        .timeout_ms = 30000,
    };
    defer allocator.free(config.connection_string);
    defer allocator.free(config.username);
    defer allocator.free(config.password);
    defer allocator.free(config.bucket);

    var client = couchbase.Client.connect(allocator, .{
        .connection_string = config.connection_string,
        .username = config.username,
        .password = config.password,
        .bucket = config.bucket,
        .timeout_ms = config.timeout_ms,
    }) catch |err| {
        std.debug.print("Failed to connect: {}\n", .{err});
        return;
    };
    defer client.disconnect();

    // Enable HTTP tracing
    client.enableHttpTracing(allocator) catch |err| {
        std.debug.print("Enable HTTP tracing failed: {}\n", .{err});
        return;
    };

    // Get HTTP traces
    var traces = client.getHttpTraces(allocator) catch |err| {
        std.debug.print("Get HTTP traces failed: {}\n", .{err});
        return;
    };
    defer traces.deinit();

    std.debug.print("HTTP traces collected: {}\n", .{traces.traces.len});
    
    for (traces.traces, 0..) |trace, i| {
        std.debug.print("Trace {}: {s} {s} - {}ms - {}\n", .{ i, trace.method, trace.url, trace.duration_ms, trace.status_code });
    }
}
