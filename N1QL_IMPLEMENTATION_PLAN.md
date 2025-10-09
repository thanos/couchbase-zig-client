# N1QL Query Implementation Plan

## Executive Summary

The current N1QL implementation covers only ~20% of libcouchbase's query capabilities. This plan outlines a phased approach to achieve 90% coverage, making the client production-ready for enterprise applications.

## Current State Analysis

###  Working Features
- Basic N1QL query execution
- Simple scan consistency (not_bounded, request_plus)
- Adhoc queries
- Basic error handling
- Result streaming

###  Critical Missing Features
1. **Query Parameters** - No support for parameterized queries
2. **Advanced Consistency** - Limited scan consistency options
3. **Performance Tuning** - No scan caps, timeouts, or optimization
4. **Query Profiling** - No debugging or performance analysis
5. **Prepared Statements** - No statement caching or optimization
6. **Enhanced Metadata** - Limited query result information

## Implementation Phases

### Phase 1: Query Parameters (v0.4.0) - 40 hours

#### 1.1 Positional Parameters
```zig
// Current
const query = "SELECT * FROM users WHERE age > 30";

// Target
const query = "SELECT * FROM users WHERE age > $1";
const params = [_][]const u8{"30"};
```

#### 1.2 Named Parameters
```zig
// Target
const query = "SELECT * FROM users WHERE name = $name AND age > $age";
const params = std.StringHashMap([]const u8).init(allocator);
try params.put("name", "\"Alice\"");
try params.put("age", "30");
```

#### Implementation Details
- Add `positional_params` and `named_params` to `QueryOptions`
- Implement `lcb_cmdquery_positional_param` and `lcb_cmdquery_named_param`
- Add parameter validation and type checking
- Create comprehensive tests for parameterized queries

### Phase 2: Advanced Scan Consistency (v0.4.0) - 20 hours

#### 2.1 Consistency Modes
```zig
pub const QueryConsistency = enum(c_uint) {
    not_bounded = 0,
    request_plus = 1,
    statement_plus = 2,
    at_plus = 3,
};
```

#### 2.2 Consistency Tokens
```zig
pub const QueryOptions = struct {
    consistency_token: ?[]const u8 = null,
    consistency_keyspace: ?[]const u8 = null,
};
```

#### Implementation Details
- Implement `lcb_cmdquery_consistency`
- Add consistency token support
- Update existing consistency handling
- Add tests for all consistency modes

### Phase 3: Performance Options (v0.4.0) - 30 hours

#### 3.1 Scan Configuration
```zig
pub const QueryOptions = struct {
    scan_cap: ?u32 = null,           // Maximum concurrent scans
    scan_wait_ms: ?u32 = null,       // Scan wait timeout
    flex_index: bool = false,        // Use flex index
    readonly: bool = false,          // Read-only query
};
```

#### Implementation Details
- Implement `lcb_cmdquery_scan_cap`, `lcb_cmdquery_scan_wait`
- Add `lcb_cmdquery_flex_index`, `lcb_cmdquery_readonly`
- Create performance optimization examples
- Add performance tests

### Phase 4: Query Profiling (v0.5.0) - 25 hours

#### 4.1 Profile Modes
```zig
pub const QueryProfile = enum(c_uint) {
    off = 0,
    phases = 1,
    timings = 2,
};

pub const QueryOptions = struct {
    profile: QueryProfile = .off,
    client_context_id: ?[]const u8 = null,
};
```

#### Implementation Details
- Implement `lcb_cmdquery_profile`
- Add `lcb_cmdquery_client_context_id`
- Parse and return profile information
- Create profiling examples and tests

### Phase 5: Prepared Statements (v0.6.0) - 50 hours

#### 5.1 Statement Management
```zig
pub const PreparedStatement = struct {
    name: []const u8,
    statement: []const u8,
    allocator: std.mem.Allocator,
    
    pub fn deinit(self: *PreparedStatement) void {
        self.allocator.free(self.name);
        self.allocator.free(self.statement);
    }
};

pub const QueryClient = struct {
    prepared_statements: std.StringHashMap(PreparedStatement),
    // ... other fields
};
```

#### Implementation Details
- Implement statement preparation and caching
- Add prepared statement lifecycle management
- Create performance benchmarks
- Add enterprise-level examples

### Phase 6: Enhanced Metadata (v0.5.0) - 35 hours

#### 6.1 Query Metadata
```zig
pub const QueryMetadata = struct {
    request_id: ?[]const u8,
    client_context_id: ?[]const u8,
    status: []const u8,
    metrics: ?QueryMetrics,
    profile: ?QueryProfile,
    allocator: std.mem.Allocator,
};

pub const QueryMetrics = struct {
    elapsed_time: []const u8,
    execution_time: []const u8,
    result_count: u64,
    result_size: u64,
    mutation_count: u64,
    sort_count: u64,
    error_count: u64,
    warning_count: u64,
};
```

#### Implementation Details
- Parse query metadata from responses
- Extract execution metrics
- Add observability features
- Create monitoring examples

## Testing Strategy

### Unit Tests
- Parameter validation
- Consistency mode testing
- Performance option validation
- Error handling

### Integration Tests
- Parameterized query execution
- Consistency token handling
- Performance optimization
- Profiling data collection

### Performance Tests
- Query execution benchmarks
- Prepared statement performance
- Memory usage optimization
- Concurrent query handling

## Documentation Updates

### API Documentation
- Complete N1QL API reference
- Parameter usage examples
- Performance tuning guide
- Troubleshooting guide

### Examples
- Basic query examples
- Parameterized query examples
- Performance optimization examples
- Enterprise usage patterns

## Migration Guide

### From v0.3.0 to v0.4.0
- No breaking changes
- New optional parameters available
- Enhanced consistency options

### From v0.4.0 to v0.5.0
- Optional profiling features
- Enhanced metadata access
- Backward compatible

### From v0.5.0 to v0.6.0
- Optional prepared statements
- Performance optimizations
- Backward compatible

## Success Metrics

### Coverage Targets
- **v0.4.0**: 60% N1QL coverage (parameters, consistency, performance)
- **v0.5.0**: 80% N1QL coverage (profiling, metadata)
- **v0.6.0**: 90% N1QL coverage (prepared statements, advanced features)

### Performance Targets
- Parameterized queries: <5ms overhead
- Prepared statements: 50% faster execution
- Memory usage: <10% increase
- Test coverage: >95%

## Resource Requirements

### Development Time
- **Phase 1-3 (v0.4.0)**: 90 hours
- **Phase 4-6 (v0.5.0-0.6.0)**: 110 hours
- **Total**: 200 hours

### Testing Time
- Unit tests: 20 hours
- Integration tests: 30 hours
- Performance tests: 20 hours
- **Total**: 70 hours

### Documentation Time
- API documentation: 15 hours
- Examples: 10 hours
- Migration guide: 5 hours
- **Total**: 30 hours

## Risk Assessment

### High Risk
- **Parameter validation complexity**: Mitigate with comprehensive testing
- **Memory management**: Use existing patterns and thorough testing

### Medium Risk
- **Performance impact**: Benchmark and optimize continuously
- **API compatibility**: Maintain backward compatibility

### Low Risk
- **Feature completeness**: Well-defined libcouchbase API
- **Testing coverage**: Existing test infrastructure

## Conclusion

This implementation plan will transform the N1QL support from basic (20%) to enterprise-ready (90%), making the Couchbase Zig Client suitable for production applications requiring advanced query capabilities.

The phased approach ensures incremental value delivery while maintaining backward compatibility and code quality.
