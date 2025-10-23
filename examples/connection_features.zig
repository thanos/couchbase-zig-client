const std = @import("std");
const couchbase = @import("couchbase");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("Couchbase Zig Client - Advanced Connection Features Demo\n", .{});
    std.debug.print("========================================================\n\n", .{});

    // Configure connection pool
    const pool_config = couchbase.ConnectionPoolConfig{
        .max_connections = 5,
        .min_connections = 2,
        .idle_timeout_ms = 300000, // 5 minutes
        .acquisition_timeout_ms = 30000, // 30 seconds
        .validate_on_borrow = true,
        .eviction_enabled = true,
    };

    // Configure retry policy
    var retry_policy = try couchbase.RetryPolicy.create(allocator);
    defer retry_policy.deinit();

    // Configure failover
    const failover_config = couchbase.FailoverConfig{
        .enabled = true,
        .max_attempts = 3,
        .timeout_ms = 30000,
        .backoff_multiplier = 2.0,
        .initial_delay_ms = 1000,
        .circuit_breaker_enabled = true,
    };

    // Configure DNS SRV
    var dns_config = couchbase.DnsSrvConfig.create(allocator);
    defer dns_config.deinit();

    // Connect with advanced connection features
    var client = try couchbase.Client.connect(allocator, .{
        .connection_string = "couchbase://localhost",
        .username = "Administrator",
        .password = "password",
        .bucket = "default",
        .connection_pool_config = pool_config,
        .retry_policy = retry_policy,
        .failover_config = failover_config,
        .dns_srv_config = dns_config,
    });
    defer client.disconnect();

    std.debug.print("Connected to Couchbase with advanced connection features\n\n", .{});

    // Demonstrate connection pool usage
    std.debug.print("Connection Pool Features:\n", .{});
    std.debug.print("- Max connections: {}\n", .{pool_config.max_connections});
    std.debug.print("- Min connections: {}\n", .{pool_config.min_connections});
    std.debug.print("- Idle timeout: {}ms\n", .{pool_config.idle_timeout_ms});
    std.debug.print("- Validation on borrow: {}\n", .{pool_config.validate_on_borrow});
    std.debug.print("- Eviction enabled: {}\n\n", .{pool_config.eviction_enabled});

    // Demonstrate retry logic
    std.debug.print("Retry Policy Features:\n", .{});
    std.debug.print("- Max attempts: {}\n", .{retry_policy.max_attempts});
    std.debug.print("- Initial delay: {}ms\n", .{retry_policy.initial_delay_ms});
    std.debug.print("- Max delay: {}ms\n", .{retry_policy.max_delay_ms});
    std.debug.print("- Backoff multiplier: {}\n", .{retry_policy.backoff_multiplier});
    std.debug.print("- Exponential backoff: {}\n\n", .{retry_policy.exponential_backoff});

    // Demonstrate failover configuration
    std.debug.print("Failover Configuration:\n", .{});
    std.debug.print("- Enabled: {}\n", .{failover_config.enabled});
    std.debug.print("- Max attempts: {}\n", .{failover_config.max_attempts});
    std.debug.print("- Timeout: {}ms\n", .{failover_config.timeout_ms});
    std.debug.print("- Circuit breaker: {}\n", .{failover_config.circuit_breaker_enabled});
    std.debug.print("- Health checks: {}\n\n", .{failover_config.health_check_enabled});

    // Demonstrate DNS SRV configuration
    std.debug.print("DNS SRV Configuration:\n", .{});
    std.debug.print("- Query timeout: {}ms\n", .{dns_config.query_timeout_ms});
    std.debug.print("- Max retries: {}\n", .{dns_config.max_retries});
    std.debug.print("- Cache TTL: {}s\n", .{dns_config.cache_ttl_seconds});
    std.debug.print("- Cache enabled: {}\n\n", .{dns_config.enable_cache});

    // Demonstrate operations with retry logic
    std.debug.print("Performing operations with retry logic...\n", .{});

    // Store a document (simplified for demo)
    const result = try client.upsert("connection_demo:1", "{\"feature\":\"connection_pooling\",\"timestamp\":1234567890}", .{});
    std.debug.print("Document stored with CAS: {}\n", .{result.cas});

    // Retrieve the document
    const get_result = try client.get("connection_demo:1");
    std.debug.print("Retrieved document: {s}\n", .{get_result.value});

    // Demonstrate failover handling
    std.debug.print("\nFailover Management:\n", .{});
    if (client.failover_manager) |*failover_manager| {
        const current_endpoint = failover_manager.getCurrentEndpoint();
        std.debug.print("Current endpoint: {s}\n", .{current_endpoint});
        
        // Simulate a connection failure (this would normally be triggered by an actual failure)
        std.debug.print("Simulating connection failure handling...\n", .{});
        // Note: In a real scenario, this would be called automatically when a connection fails
        // try failover_manager.handleFailure();
    }

    // Demonstrate connection pool statistics
    std.debug.print("\nConnection Pool Statistics:\n", .{});
    if (client.connection_pool) |*pool| {
        std.debug.print("Total connections: {}\n", .{pool.connections.items.len});
        std.debug.print("Available connections: {}\n", .{pool.available_connections.items.len});
        std.debug.print("Pool utilization: {d:.1}%\n", .{@as(f64, @floatFromInt(pool.available_connections.items.len)) / @as(f64, @floatFromInt(pool.connections.items.len)) * 100.0});
    }

    // Demonstrate certificate authentication (if configured)
    std.debug.print("\nCertificate Authentication:\n", .{});
    std.debug.print("Certificate authentication can be configured by providing:\n", .{});
    std.debug.print("- client_cert_path: Path to client certificate\n", .{});
    std.debug.print("- client_key_path: Path to client private key\n", .{});
    std.debug.print("- ca_cert_path: Path to CA certificate (optional)\n", .{});
    std.debug.print("- verify_certificates: Enable certificate verification\n", .{});
    std.debug.print("- verify_hostname: Enable hostname verification\n", .{});

    std.debug.print("\nAdvanced Connection Features Demo Complete!\n", .{});
}
