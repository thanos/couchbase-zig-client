# Running Tests

## Run All Tests

To run **all tests** (unit + integration + all other test suites):

```bash
zig build test-all
```

Or manually run each test suite:

```bash
# Unit tests only
zig build test-unit

# Integration tests (requires Couchbase running)
zig build test-integration

# Coverage tests
zig build test-coverage

# All other test suites
zig build test-new-ops
zig build test-views
zig build test-demo
zig build test-param-query
zig build test-advanced-query
zig build test-prepared-statement
zig build test-query-cancellation
zig build test-enhanced-metadata
zig build test-get-and-lock
zig build test-collections
zig build test-collections-phase1
zig build test-collections-phase2
zig build test-collections-phase3
zig build test-batch
zig build test-enhanced-batch
zig build test-spatial-view
zig build test-connection-features
```

## Environment Variables

For integration tests that require a Couchbase connection, set:

```bash
export COUCHBASE_USER=test
export COUCHBASE_PASSWORD=password
export COUCHBASE_BUCKET=test
export COUCHBASE_HOST=127.0.0.1
```

Or run with inline env vars:

```bash
COUCHBASE_USER=test COUCHBASE_PASSWORD=password COUCHBASE_BUCKET=test COUCHBASE_HOST=127.0.0.1 zig build test-integration
```

## Note

The `zig build test` command currently only runs unit tests. Use `zig build test-all` for comprehensive testing.
