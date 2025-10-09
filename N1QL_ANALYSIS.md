# N1QL Query Implementation Analysis and Plan

## Current Implementation Status

###  Implemented Features
- Basic N1QL query execution (`lcb_query`)
- Statement execution (`lcb_cmdquery_statement`)
- Adhoc queries (`lcb_cmdquery_adhoc`)
- Basic scan consistency (not_bounded, request_plus)
- Query result streaming
- Error handling
- Memory management

###  Missing Features (Critical Gaps)

#### 1. Query Parameters
- **Positional Parameters**: `lcb_cmdquery_positional_param`
- **Named Parameters**: `lcb_cmdquery_named_param`
- **Current**: Only basic string queries supported

#### 2. Advanced Scan Consistency
- **Scan Consistency Modes**: `lcb_cmdquery_consistency`
- **Consistency Tokens**: `lcb_cmdquery_consistency_token_for_keyspace`
- **Current**: Only basic not_bounded/request_plus

#### 3. Query Performance Options
- **Scan Cap**: `lcb_cmdquery_scan_cap`
- **Scan Wait**: `lcb_cmdquery_scan_wait`
- **Flex Index**: `lcb_cmdquery_flex_index`
- **Readonly**: `lcb_cmdquery_readonly`

#### 4. Query Profiling and Debugging
- **Profile Mode**: `lcb_cmdquery_profile`
- **Client Context ID**: `lcb_cmdquery_client_context_id`

#### 5. Prepared Statements
- **Prepared Statement Caching**: Not implemented
- **Statement Preparation**: Not implemented

#### 6. Query Metadata
- **Query Metadata Parsing**: Basic meta field, not parsed
- **Execution Statistics**: Not extracted
- **Query Plan**: Not available

## Implementation Plan

### Phase 1: Query Parameters (High Priority)

#### 1.1 Positional Parameters
```zig
pub const QueryOptions = struct {
    // ... existing fields
    positional_params: ?[][]const u8 = null,
    named_params: ?std.StringHashMap([]const u8) = null,
};
```

#### 1.2 Named Parameters
```zig
// Support for named parameters like $name, $age
const params = std.StringHashMap([]const u8).init(allocator);
defer params.deinit();
try params.put("name", "\"Alice\"");
try params.put("age", "30");
```

### Phase 2: Advanced Scan Consistency (High Priority)

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
    // ... existing fields
    consistency_token: ?[]const u8 = null,
    consistency_keyspace: ?[]const u8 = null,
};
```

### Phase 3: Performance Options (Medium Priority)

#### 3.1 Scan Options
```zig
pub const QueryOptions = struct {
    // ... existing fields
    scan_cap: ?u32 = null,
    scan_wait_ms: ?u32 = null,
    flex_index: bool = false,
    readonly: bool = false,
};
```

### Phase 4: Query Profiling (Medium Priority)

#### 4.1 Profile Modes
```zig
pub const QueryProfile = enum(c_uint) {
    off = 0,
    phases = 1,
    timings = 2,
};
```

#### 4.2 Client Context
```zig
pub const QueryOptions = struct {
    // ... existing fields
    client_context_id: ?[]const u8 = null,
    profile: QueryProfile = .off,
};
```

### Phase 5: Prepared Statements (Low Priority)

#### 5.1 Statement Preparation
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
```

#### 5.2 Statement Caching
```zig
pub const QueryClient = struct {
    prepared_statements: std.StringHashMap(PreparedStatement),
    // ... other fields
};
```

### Phase 6: Enhanced Metadata (Low Priority)

#### 6.1 Query Metadata Parsing
```zig
pub const QueryMetadata = struct {
    request_id: ?[]const u8,
    client_context_id: ?[]const u8,
    status: []const u8,
    metrics: ?QueryMetrics,
    profile: ?QueryProfile,
    allocator: std.mem.Allocator,
    
    pub fn deinit(self: *QueryMetadata) void {
        // ... cleanup
    }
};
```

#### 6.2 Query Metrics
```zig
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

## Implementation Priority

### High Priority (v0.4.0)
1. **Query Parameters** - Essential for production use
2. **Advanced Scan Consistency** - Required for data consistency
3. **Basic Performance Options** - scan_cap, scan_wait

### Medium Priority (v0.5.0)
4. **Query Profiling** - Debugging and optimization
5. **Enhanced Metadata** - Better observability

### Low Priority (v0.6.0)
6. **Prepared Statements** - Performance optimization
7. **Advanced Caching** - Enterprise features

## Current Coverage Assessment

| Feature | Current | Target | Priority |
|---------|---------|--------|----------|
| Basic Queries |  |  | Complete |
| Query Parameters |  |  | High |
| Scan Consistency | ï |  | High |
| Performance Options |  |  | High |
| Query Profiling |  |  | Medium |
| Prepared Statements |  |  | Low |
| Enhanced Metadata |  |  | Medium |

**Current N1QL Coverage: ~20%**  
**Target N1QL Coverage: ~90%**

## Estimated Implementation Effort

- **Phase 1 (Parameters)**: 40 hours
- **Phase 2 (Consistency)**: 20 hours  
- **Phase 3 (Performance)**: 30 hours
- **Phase 4 (Profiling)**: 25 hours
- **Phase 5 (Prepared)**: 50 hours
- **Phase 6 (Metadata)**: 35 hours

**Total: ~200 hours for complete N1QL implementation**

## Next Steps

1. **Immediate**: Implement query parameters (Phase 1)
2. **Short-term**: Add advanced scan consistency (Phase 2)
3. **Medium-term**: Performance options and profiling (Phases 3-4)
4. **Long-term**: Prepared statements and advanced metadata (Phases 5-6)

This will bring N1QL coverage from 20% to 90%, making it production-ready for enterprise applications.
