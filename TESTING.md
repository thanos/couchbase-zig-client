# Testing Documentation

## Test Suites

The library includes three test suites:

1. **Unit Tests** - Test data structures and type safety (no server required)
2. **Integration Tests** - Test operations against a live Couchbase server
3. **Coverage Tests** - Comprehensive coverage of all operations and options

## Configuration

Test configuration is in `src/test_config.zig`:

```zig
pub const TestConfig = struct {
    connection_string: []const u8 = "couchbase://127.0.0.1",
    username: []const u8 = "tester",
    password: []const u8 = "csfb2010",
    bucket: []const u8 = "default",
    timeout_ms: u32 = 10000,
};
```

## Requirements

Integration and coverage tests require:
- Couchbase Server running at 127.0.0.1:8091
- Username: `tester`
- Password: `csfb2010`
- Bucket: `default`

## Running Tests

```bash
# Unit tests only (no server required)
zig build test-unit

# Integration tests (requires server)
zig build test-integration

# Coverage tests (requires server)
zig build test-coverage

# All tests
zig build test-all
```

## Test Coverage

### Unit Tests (tests/unit_test.zig)

Tests without server dependency:
- Error type mappings
- Durability level enum values
- Default values for all option structs
- Document structure
- Result structures (MutationResult, CounterResult, GetResult, QueryResult)
- Memory management (deinit)
- Enum values (ReplicaMode, StoreOperation, SubdocOp, ScanConsistency)

### Integration Tests (tests/integration_test.zig)

Tests against live server (26 tests):

1. **Connection**
   - Basic connection establishment
   - Disconnect

2. **Basic Operations**
   - Get/Upsert/Remove cycle
   - Document verification after operations

3. **Insert Operation**
   - Insert new document
   - Insert existing document (failure)
   - Error handling

4. **Replace Operation**
   - Replace non-existent (failure)
   - Replace existing document
   - Value verification

5. **CAS (Compare-and-Swap)**
   - Replace with correct CAS
   - Replace with old CAS (failure)
   - CAS value changes

6. **Counter Operations**
   - Increment with initial value
   - Multiple increments
   - Decrement operations
   - Delta values

7. **Touch Operation**
   - Update expiration
   - CAS changes
   - Document preservation

8. **Expiry**
   - Document with TTL
   - Expiry verification
   - Post-expiry retrieval failure

9. **Get from Replica**
   - Any replica mode
   - Fallback handling

10. **Queries (N1QL)**
    - CREATE and SELECT
    - Query result streaming
    - Consistency options
    - Cleanup

11. **Multiple Operations**
    - Sequential operations on multiple documents
    - Batch insert
    - Batch read
    - Batch update
    - Batch remove

12. **Large Documents**
    - Store 1MB+ documents
    - Retrieve large documents

13. **Stress Test**
    - 50 rapid operations
    - Sequential create/read/delete

14. **Error Handling**
    - DocumentNotFound
    - DocumentExists
    - Invalid operations

15. **Durability**
    - Majority durability level
    - Operation verification

16. **Flags Support**
    - Custom flags storage
    - Flags retrieval

### Coverage Tests (tests/coverage_test.zig)

Comprehensive coverage of all APIs (18 tests):

1. **All Client Methods**
   - Every method callable
   - Basic parameter variations

2. **Store Options Coverage**
   - CAS option
   - Expiry option
   - Flags option
   - Combined options

3. **Remove Options Coverage**
   - CAS option
   - Default options

4. **Counter Options Coverage**
   - Initial value option
   - Expiry option
   - Combined options

5. **Query Options Coverage**
   - Default options
   - Consistency option
   - Timeout option
   - Adhoc option

6. **Replica Modes Coverage**
   - Any replica
   - All replicas
   - Index replica

7. **Error Types Coverage**
   - DocumentNotFound
   - DocumentExists
   - CAS mismatch

8. **Durability Levels Coverage**
   - None (default)
   - Majority
   - Persist to majority
   - Majority and persist to active

9. **Unlock Operation**
   - Unlock call
   - CAS parameter

10. **Result Types Coverage**
    - GetResult
    - MutationResult
    - CounterResult
    - QueryResult
    - Deinit methods

11. **Connection Options**
    - Minimal options
    - Full options

12. **Batch Operations**
    - 100 document batch
    - Batch upsert
    - Batch get
    - Batch remove

13. **Edge Cases**
    - Empty key (failure)
    - Very long key
    - Empty value
    - Zero expiry
    - Zero CAS

14. **Concurrent Access Patterns**
    - Optimistic locking simulation
    - CAS conflicts
    - Update patterns

## Test Statistics

- **Total test cases**: 60+
- **Unit tests**: 16
- **Integration tests**: 26
- **Coverage tests**: 18

## Test Matrix

| Feature | Unit | Integration | Coverage |
|---------|------|-------------|----------|
| Connection | - |  |  |
| Get |  |  |  |
| Insert |  |  |  |
| Upsert |  |  |  |
| Replace |  |  |  |
| Remove |  |  |  |
| Increment |  |  |  |
| Decrement |  |  |  |
| Touch |  |  |  |
| Unlock |  | - |  |
| CAS |  |  |  |
| Expiry |  |  |  |
| Flags |  |  |  |
| Durability |  |  |  |
| Replicas |  |  |  |
| Query |  |  |  |
| Error Handling |  |  |  |
| Options |  | - |  |
| Batch Ops | - |  |  |
| Edge Cases | - | - |  |

## CI Integration

Tests can be run in CI/CD pipelines:

```yaml
# Example GitHub Actions
- name: Start Couchbase
  run: |
    docker run -d --name couchbase \
      -p 8091-8096:8091-8096 \
      -p 11210-11211:11210-11211 \
      couchbase:community
    
- name: Wait for Couchbase
  run: sleep 30

- name: Run tests
  run: zig build test-all
```

## Writing New Tests

### Unit Test Template

```zig
test "feature name" {
    // Test type/struct behavior without server
    const Feature = couchbase.Feature;
    const instance = Feature{};
    try testing.expectEqual(expected, instance.field);
}
```

### Integration Test Template

```zig
test "operation name" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    const key = "test:operation";
    
    // Clean up
    _ = client.remove(key, .{}) catch {};
    
    // Test operation
    _ = try client.operation(key, ...);
    
    // Verify
    var result = try client.get(key);
    result.deinit();
    
    // Clean up
    _ = try client.remove(key, .{});
}
```

### Coverage Test Template

```zig
test "coverage: feature with options" {
    var client = try getTestClient(testing.allocator);
    defer client.disconnect();

    // Test all option combinations
    _ = try client.operation(key, .{});
    _ = try client.operation(key, .{ .option1 = value });
    _ = try client.operation(key, .{ .option2 = value });
    _ = try client.operation(key, .{ .option1 = value, .option2 = value });
}
```

## Known Limitations

1. **Subdocument Operations**: Stub implementations only
2. **Transactions**: Not yet implemented
3. **Analytics**: Not yet implemented
4. **Full-text Search**: Not yet implemented
5. **Views**: Not yet implemented

## Troubleshooting

### Tests Fail to Connect

Check that Couchbase is running:
```bash
curl http://127.0.0.1:8091
```

### Authentication Errors

Verify credentials match test_config.zig:
- Username: tester
- Password: csfb2010

### Query Tests Fail

Create a primary index:
```sql
CREATE PRIMARY INDEX ON `default`;
```

### Durability Tests Fail

Durability requires properly configured cluster with replicas.
