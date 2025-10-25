const std = @import("std");

pub const c = @import("c.zig");
pub const Client = @import("client.zig").Client;
pub const Error = @import("error_context.zig").Error;
pub const StatusCode = @import("error.zig").StatusCode;
pub const types = @import("types.zig");
pub const operations = @import("operations.zig");
pub const views = @import("views.zig");
pub const transactions = @import("transactions.zig");

// Error Handling & Logging
pub const ErrorContext = @import("error_context.zig").ErrorContext;
pub const LogLevel = @import("error_context.zig").LogLevel;
pub const Logger = @import("logging.zig").Logger;
pub const LoggingConfig = @import("logging.zig").LoggingConfig;
pub const LogEntry = @import("logging.zig").LogEntry;
pub const LogCallback = @import("logging.zig").LogCallback;
pub const defaultLogCallback = @import("logging.zig").defaultLogCallback;

// Binary Protocol Features
pub const BinaryProtocol = @import("binary_protocol.zig").BinaryProtocol;
pub const FeatureFlags = @import("binary_protocol.zig").FeatureFlags;
pub const ProtocolVersion = @import("binary_protocol.zig").ProtocolVersion;
pub const BinaryDocument = @import("binary_protocol.zig").BinaryDocument;
pub const BinaryOperationContext = @import("binary_protocol.zig").BinaryOperationContext;
pub const DcpEvent = @import("binary_protocol.zig").DcpEvent;
pub const DcpEventType = @import("binary_protocol.zig").DcpEventType;

// Advanced Connection Features
pub const connection_features = @import("connection_features.zig");
pub const ConnectionPoolConfig = connection_features.ConnectionPoolConfig;
pub const CertificateAuthConfig = connection_features.CertificateAuthConfig;
pub const DnsSrvConfig = connection_features.DnsSrvConfig;
pub const FailoverConfig = connection_features.FailoverConfig;
pub const RetryPolicy = connection_features.RetryPolicy;
pub const ConnectionPool = connection_features.ConnectionPool;
pub const FailoverManager = connection_features.FailoverManager;
pub const RetryManager = connection_features.RetryManager;

// Re-export common types
pub const Document = types.Document;
pub const GetResult = operations.GetResult;
pub const MutationResult = operations.MutationResult;
pub const QueryResult = operations.QueryResult;
pub const QueryOptions = operations.QueryOptions;
pub const ViewResult = views.ViewResult;
pub const ViewOptions = views.ViewOptions;
pub const ViewStale = views.ViewStale;
pub const Durability = types.Durability;
pub const DurabilityLevel = types.DurabilityLevel;
pub const ObserveDurability = types.ObserveDurability;
pub const MutationToken = types.MutationToken;
pub const ObserveResult = types.ObserveResult;
pub const ObserveOptions = types.ObserveOptions;

// Diagnostics & Monitoring types
pub const PingResult = operations.PingResult;
pub const ServiceHealth = operations.ServiceHealth;
pub const ServiceState = operations.ServiceState;
pub const DiagnosticsResult = operations.DiagnosticsResult;
pub const ServiceDiagnostics = operations.ServiceDiagnostics;
pub const ClusterConfigResult = operations.ClusterConfigResult;
pub const HttpTracingResult = operations.HttpTracingResult;
pub const HttpTrace = operations.HttpTrace;
pub const SdkMetricsResult = operations.SdkMetricsResult;
pub const MetricValue = operations.MetricValue;
pub const HistogramData = operations.HistogramData;
pub const PercentileData = operations.PercentileData;

// Transaction types
pub const TransactionContext = types.TransactionContext;
pub const TransactionResult = types.TransactionResult;
pub const TransactionConfig = types.TransactionConfig;
pub const TransactionOperation = types.TransactionOperation;
pub const TransactionOperationType = types.TransactionOperationType;
pub const TransactionOperationOptions = types.TransactionOperationOptions;
pub const TransactionState = types.TransactionState;

    // Advanced query types
    pub const QueryProfile = types.QueryProfile;
    pub const QueryConsistency = types.QueryConsistency;
    pub const AnalyticsOptions = types.AnalyticsOptions;
    pub const SearchOptions = types.SearchOptions;
    pub const AnalyticsResult = operations.AnalyticsResult;
    pub const SearchResult = operations.SearchResult;
    
    // Prepared statement types
    pub const PreparedStatement = types.PreparedStatement;
    pub const PreparedStatementCache = types.PreparedStatementCache;
    
    // Query cancellation types
    pub const QueryHandle = types.QueryHandle;
    pub const QueryCancellationOptions = types.QueryCancellationOptions;
    
    // Enhanced query metadata types
    pub const QueryMetadata = types.QueryMetadata;
    pub const QueryMetrics = types.QueryMetrics;
    pub const ConsistencyToken = types.ConsistencyToken;
    
    // Lock operation types
    pub const GetAndLockOptions = types.GetAndLockOptions;
    pub const UnlockOptions = types.UnlockOptions;
    pub const GetAndLockResult = operations.GetAndLockResult;
    pub const UnlockResult = operations.UnlockResult;
    
// Collections & Scopes types
pub const Collection = types.Collection;
pub const Scope = types.Scope;
pub const CollectionManifest = types.CollectionManifest;
pub const CollectionManifestEntry = types.CollectionManifestEntry;

// Batch operation types
pub const BatchOperationType = types.BatchOperationType;
pub const BatchOperation = types.BatchOperation;
pub const BatchResult = types.BatchResult;
pub const BatchOperationResult = types.BatchOperationResult;

// Test configuration from environment variables
pub fn getTestConfig() TestConfig {
    return TestConfig{
        .connection_string = std.process.getEnvVarOwned(std.heap.page_allocator, "COUCHBASE_HOST") catch "couchbase://127.0.0.1",
        .username = std.process.getEnvVarOwned(std.heap.page_allocator, "COUCHBASE_USER") catch "tester",
        .password = std.process.getEnvVarOwned(std.heap.page_allocator, "COUCHBASE_PASSWORD") catch "csfb2010",
        .bucket = std.process.getEnvVarOwned(std.heap.page_allocator, "COUCHBASE_BUCKET") catch "default",
        .timeout_ms = 30000,
    };
}

pub const TestConfig = struct {
    connection_string: []const u8,
    username: []const u8,
    password: []const u8,
    bucket: []const u8,
    timeout_ms: u32,
};

test {
    std.testing.refAllDecls(@This());
}
