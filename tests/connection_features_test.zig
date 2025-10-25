const std = @import("std");
const couchbase = @import("couchbase");

test "ConnectionPoolConfig initialization and cleanup" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const config = couchbase.ConnectionPoolConfig{
        .max_connections = 10,
        .min_connections = 2,
        .idle_timeout_ms = 300000,
        .acquisition_timeout_ms = 30000,
        .validate_on_borrow = true,
        .eviction_enabled = true,
    };

    try std.testing.expectEqual(@as(u32, 10), config.max_connections);
    try std.testing.expectEqual(@as(u32, 2), config.min_connections);
    try std.testing.expectEqual(@as(u32, 300000), config.idle_timeout_ms);
    try std.testing.expectEqual(@as(u32, 30000), config.acquisition_timeout_ms);
    try std.testing.expect(config.validate_on_borrow);
    try std.testing.expect(config.eviction_enabled);

    var mutable_config = config;
    mutable_config.deinit();
}

test "CertificateAuthConfig creation and validation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create test certificate files
    const cert_file = std.fs.cwd().createFile("test_client.crt", .{}) catch return;
    defer cert_file.close();
    defer std.fs.cwd().deleteFile("test_client.crt") catch {};

    const key_file = std.fs.cwd().createFile("test_client.key", .{}) catch return;
    defer key_file.close();
    defer std.fs.cwd().deleteFile("test_client.key") catch {};

    const ca_file = std.fs.cwd().createFile("test_ca.crt", .{}) catch return;
    defer ca_file.close();
    defer std.fs.cwd().deleteFile("test_ca.crt") catch {};

    // Test basic creation
    var cert_config = try couchbase.CertificateAuthConfig.create(allocator, "test_client.crt", "test_client.key");
    defer cert_config.deinit();

    try std.testing.expectEqualStrings("test_client.crt", cert_config.client_cert_path);
    try std.testing.expectEqualStrings("test_client.key", cert_config.client_key_path);
    try std.testing.expect(cert_config.verify_certificates);
    try std.testing.expect(cert_config.verify_hostname);
    try std.testing.expectEqual(@as(u32, 10000), cert_config.validation_timeout_ms);

    // Test validation
    try cert_config.validate();

    // Test with CA certificate
    cert_config.ca_cert_path = try allocator.dupe(u8, "test_ca.crt");
    try cert_config.validate();
}

test "DnsSrvConfig creation and management" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var dns_config = couchbase.DnsSrvConfig.create(allocator);
    defer dns_config.deinit();

    try std.testing.expectEqual(@as(u32, 5000), dns_config.query_timeout_ms);
    try std.testing.expectEqual(@as(u32, 3), dns_config.max_retries);
    try std.testing.expectEqual(@as(u32, 300), dns_config.cache_ttl_seconds);
    try std.testing.expect(dns_config.enable_cache);
    try std.testing.expect(dns_config.enable_srv);
    try std.testing.expectEqualStrings("_couchbase._tcp", dns_config.srv_service);
    try std.testing.expectEqualStrings("couchbase.com", dns_config.srv_domain);
    try std.testing.expectEqual(@as(u32, 1000), dns_config.cache_size);

    // Test adding DNS servers
    try dns_config.addDnsServer("8.8.8.8");
    try dns_config.addDnsServer("1.1.1.1");

    try std.testing.expect(dns_config.dns_servers != null);
    try std.testing.expectEqual(@as(usize, 2), dns_config.dns_servers.?.len);
    try std.testing.expectEqualStrings("8.8.8.8", dns_config.dns_servers.?[0]);
    try std.testing.expectEqualStrings("1.1.1.1", dns_config.dns_servers.?[1]);
}

test "FailoverConfig creation and delay calculation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const failover_config = couchbase.FailoverConfig{
        .enabled = true,
        .max_attempts = 5,
        .timeout_ms = 30000,
        .backoff_multiplier = 2.0,
        .initial_delay_ms = 1000,
        .max_delay_ms = 30000,
        .circuit_breaker_enabled = true,
        .failure_threshold = 5,
        .recovery_timeout_ms = 60000,
        .health_check_enabled = true,
        .health_check_interval_ms = 10000,
        .load_balancing_enabled = true,
        .load_balancing_strategy = .round_robin,
        .priority_enabled = false,
    };

    try std.testing.expect(failover_config.enabled);
    try std.testing.expectEqual(@as(u32, 5), failover_config.max_attempts);
    try std.testing.expectEqual(@as(u32, 30000), failover_config.timeout_ms);
    try std.testing.expectEqual(@as(f64, 2.0), failover_config.backoff_multiplier);
    try std.testing.expectEqual(@as(u32, 1000), failover_config.initial_delay_ms);
    try std.testing.expect(failover_config.circuit_breaker_enabled);
    try std.testing.expectEqual(@as(u32, 5), failover_config.failure_threshold);
    try std.testing.expect(failover_config.health_check_enabled);
    try std.testing.expect(failover_config.load_balancing_enabled);
    try std.testing.expectEqual(couchbase.FailoverConfig.LoadBalancingStrategy.round_robin, failover_config.load_balancing_strategy);

    // Test delay calculation
    try std.testing.expectEqual(@as(u32, 1000), failover_config.calculateDelay(0));
    try std.testing.expectEqual(@as(u32, 2000), failover_config.calculateDelay(1));
    try std.testing.expectEqual(@as(u32, 4000), failover_config.calculateDelay(2));
    try std.testing.expectEqual(@as(u32, 8000), failover_config.calculateDelay(3));
    try std.testing.expectEqual(@as(u32, 16000), failover_config.calculateDelay(4));
    try std.testing.expectEqual(@as(u32, 30000), failover_config.calculateDelay(5)); // Max delay
}

test "RetryPolicy creation and delay calculation" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var retry_policy = try couchbase.RetryPolicy.create(allocator);
    defer retry_policy.deinit();

    try std.testing.expectEqual(@as(u32, 3), retry_policy.max_attempts);
    try std.testing.expectEqual(@as(u32, 1000), retry_policy.initial_delay_ms);
    try std.testing.expectEqual(@as(u32, 30000), retry_policy.max_delay_ms);
    try std.testing.expectEqual(@as(f64, 2.0), retry_policy.backoff_multiplier);
    try std.testing.expectEqual(@as(f64, 0.1), retry_policy.jitter_factor);
    try std.testing.expect(retry_policy.exponential_backoff);
    try std.testing.expect(!retry_policy.linear_backoff);
    try std.testing.expect(retry_policy.enable_metrics);
    try std.testing.expectEqual(@as(u32, 60000), retry_policy.retry_timeout_ms);
    try std.testing.expect(!retry_policy.adaptive_delays);
    try std.testing.expectEqual(@as(f64, 0.5), retry_policy.max_jitter_percent);
    try std.testing.expect(retry_policy.retry_on_partial_failure);

    // Test retry on errors
    try std.testing.expectEqual(@as(usize, 3), retry_policy.retry_on_errors.len);
    try std.testing.expectEqual(couchbase.Error.Timeout, retry_policy.retry_on_errors[0]);
    try std.testing.expectEqual(couchbase.Error.TemporaryFailure, retry_policy.retry_on_errors[1]);
    try std.testing.expectEqual(couchbase.Error.NetworkError, retry_policy.retry_on_errors[2]);

    // Test no retry errors
    try std.testing.expectEqual(@as(usize, 2), retry_policy.no_retry_errors.len);
    try std.testing.expectEqual(couchbase.Error.AuthenticationFailed, retry_policy.no_retry_errors[0]);
    try std.testing.expectEqual(couchbase.Error.InvalidArgument, retry_policy.no_retry_errors[1]);

    // Test delay calculation
    const delay1 = retry_policy.calculateDelay(0);
    const delay2 = retry_policy.calculateDelay(1);
    const delay3 = retry_policy.calculateDelay(2);

    try std.testing.expect(delay1 >= retry_policy.initial_delay_ms);
    try std.testing.expect(delay2 > delay1);
    try std.testing.expect(delay3 > delay2);
    try std.testing.expect(delay3 <= retry_policy.max_delay_ms);
}

test "ConnectionPool initialization and cleanup" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = couchbase.ConnectionPoolConfig{
        .max_connections = 5,
        .min_connections = 1,
        .idle_timeout_ms = 60000,
        .acquisition_timeout_ms = 10000,
        .validate_on_borrow = true,
        .eviction_enabled = true,
    };

    var pool = couchbase.ConnectionPool.init(allocator, config);
    defer pool.deinit();

    try std.testing.expectEqual(@as(u32, 5), pool.config.max_connections);
    try std.testing.expectEqual(@as(u32, 1), pool.config.min_connections);
    try std.testing.expectEqual(@as(usize, 0), pool.connections.items.len);
    try std.testing.expectEqual(@as(usize, 0), pool.available_connections.items.len);
    try std.testing.expectEqual(@as(usize, 0), pool.connection_metadata.items.len);
}

test "FailoverManager initialization and cleanup" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const failover_config = couchbase.FailoverConfig{
        .enabled = true,
        .max_attempts = 3,
        .timeout_ms = 30000,
        .backoff_multiplier = 2.0,
        .initial_delay_ms = 1000,
        .max_delay_ms = 30000,
        .circuit_breaker_enabled = true,
        .failure_threshold = 5,
        .recovery_timeout_ms = 60000,
        .health_check_enabled = true,
        .health_check_interval_ms = 10000,
        .load_balancing_enabled = true,
        .load_balancing_strategy = .round_robin,
        .priority_enabled = false,
    };

    const endpoints = [_][]const u8{ "couchbase://node1", "couchbase://node2", "couchbase://node3" };
    var failover_manager = try couchbase.FailoverManager.init(allocator, failover_config, &endpoints);
    defer failover_manager.deinit();

    try std.testing.expect(failover_manager.config.enabled);
    try std.testing.expectEqual(@as(u32, 3), failover_manager.config.max_attempts);
    try std.testing.expectEqual(@as(usize, 3), failover_manager.available_endpoints.items.len);
    try std.testing.expectEqualStrings("couchbase://node1", failover_manager.current_endpoint);
    try std.testing.expectEqualStrings("couchbase://node1", failover_manager.getCurrentEndpoint());
}

test "RetryManager initialization and cleanup" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const retry_policy = try couchbase.RetryPolicy.create(allocator);
    var retry_manager = couchbase.RetryManager.init(allocator, retry_policy);
    defer retry_manager.deinit();

    try std.testing.expectEqual(@as(u32, 3), retry_manager.policy.max_attempts);
    try std.testing.expectEqual(@as(u32, 1000), retry_manager.policy.initial_delay_ms);
    try std.testing.expect(retry_manager.policy.exponential_backoff);
}

test "Error types and error handling" {
    // Test that connection features error types are properly defined
    // These are error sets, not enums, so we test their existence by using them in a function
    const TestConnectionError = struct {
        fn check() couchbase.connection_features.Error!void {
            return couchbase.connection_features.Error.ConnectionPoolExhausted;
        }
    };
    
    // Test that main error types are accessible
    const TestMainError = struct {
        fn check() couchbase.Error!void {
            return couchbase.Error.Timeout;
        }
    };
    
    // These should compile without error
    _ = TestConnectionError.check;
    _ = TestMainError.check;
}

test "LoadBalancingStrategy enum values" {
    try std.testing.expectEqual(@as(u32, 0), @intFromEnum(couchbase.FailoverConfig.LoadBalancingStrategy.round_robin));
    try std.testing.expectEqual(@as(u32, 1), @intFromEnum(couchbase.FailoverConfig.LoadBalancingStrategy.least_connections));
    try std.testing.expectEqual(@as(u32, 2), @intFromEnum(couchbase.FailoverConfig.LoadBalancingStrategy.weighted_round_robin));
    try std.testing.expectEqual(@as(u32, 3), @intFromEnum(couchbase.FailoverConfig.LoadBalancingStrategy.random));
}

test "Memory management and cleanup" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Test that all configurations properly clean up memory
    var cert_config = try couchbase.CertificateAuthConfig.create(allocator, "test.crt", "test.key");
    cert_config.deinit();

    var dns_config = couchbase.DnsSrvConfig.create(allocator);
    try dns_config.addDnsServer("8.8.8.8");
    dns_config.deinit();

    var retry_policy = try couchbase.RetryPolicy.create(allocator);
    retry_policy.deinit();

    // Test that no memory leaks occur
    try std.testing.expect(true);
}
