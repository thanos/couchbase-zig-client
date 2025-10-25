const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Module for the library
    const couchbase_module = b.addModule("couchbase", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Link libcouchbase
    couchbase_module.linkSystemLibrary("couchbase", .{});

    // Static library
    const lib = b.addStaticLibrary(.{
        .name = "couchbase-zig-client",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib.linkSystemLibrary("couchbase");
    lib.linkLibC();
    b.installArtifact(lib);

    // Examples
    const examples = [_]struct { name: []const u8, path: []const u8 }{
        .{ .name = "basic", .path = "examples/basic.zig" },
        .{ .name = "kv_operations", .path = "examples/kv_operations.zig" },
        .{ .name = "query", .path = "examples/query.zig" },
        .{ .name = "diagnostics", .path = "examples/diagnostics.zig" },
        .{ .name = "error_handling_logging", .path = "examples/error_handling_logging.zig" },
        .{ .name = "binary_protocol", .path = "examples/binary_protocol.zig" },
        .{ .name = "connection_features", .path = "examples/connection_features.zig" },
    };

    const example_step = b.step("examples", "Build all examples");
    
    inline for (examples) |example| {
        const exe = b.addExecutable(.{
            .name = example.name,
            .root_source_file = b.path(example.path),
            .target = target,
            .optimize = optimize,
        });
        exe.root_module.addImport("couchbase", couchbase_module);
        exe.linkSystemLibrary("couchbase");
        exe.linkLibC();
        
        const install_exe = b.addInstallArtifact(exe, .{});
        example_step.dependOn(&install_exe.step);
        
        // Individual run step for each example
        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(&install_exe.step);
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }
        const run_step = b.step(b.fmt("run-{s}", .{example.name}), b.fmt("Run the {s} example", .{example.name}));
        run_step.dependOn(&run_cmd.step);
    }

    // Tests
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib_unit_tests.linkSystemLibrary("couchbase");
    lib_unit_tests.linkLibC();

    const unit_tests = b.addTest(.{
        .root_source_file = b.path("tests/unit_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    unit_tests.root_module.addImport("couchbase", couchbase_module);
    unit_tests.linkSystemLibrary("couchbase");
    unit_tests.linkLibC();

    const integration_tests = b.addTest(.{
        .root_source_file = b.path("tests/integration_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    integration_tests.root_module.addImport("couchbase", couchbase_module);
    integration_tests.linkSystemLibrary("couchbase");
    integration_tests.linkLibC();

    const coverage_tests = b.addTest(.{
        .root_source_file = b.path("tests/coverage_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    coverage_tests.root_module.addImport("couchbase", couchbase_module);
    coverage_tests.linkSystemLibrary("couchbase");
    coverage_tests.linkLibC();

    const new_ops_tests = b.addTest(.{
        .root_source_file = b.path("tests/new_operations_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    new_ops_tests.root_module.addImport("couchbase", couchbase_module);
    new_ops_tests.linkSystemLibrary("couchbase");
    new_ops_tests.linkLibC();

    const view_tests = b.addTest(.{
        .root_source_file = b.path("tests/view_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    view_tests.root_module.addImport("couchbase", couchbase_module);
    view_tests.linkSystemLibrary("couchbase");
    view_tests.linkLibC();

    const demo_tests = b.addTest(.{
        .root_source_file = b.path("demo_integration_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    demo_tests.root_module.addImport("couchbase", couchbase_module);
    demo_tests.linkSystemLibrary("couchbase");
    demo_tests.linkLibC();

    const param_query_tests = b.addTest(.{
        .root_source_file = b.path("tests/parameterized_query_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    param_query_tests.root_module.addImport("couchbase", couchbase_module);
    param_query_tests.linkSystemLibrary("couchbase");
    param_query_tests.linkLibC();

    const advanced_query_tests = b.addTest(.{
        .root_source_file = b.path("tests/simple_advanced_query_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    advanced_query_tests.root_module.addImport("couchbase", couchbase_module);
    advanced_query_tests.linkSystemLibrary("couchbase");
    advanced_query_tests.linkLibC();

    const connection_features_tests = b.addTest(.{
        .root_source_file = b.path("tests/connection_features_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    connection_features_tests.root_module.addImport("couchbase", couchbase_module);
    connection_features_tests.linkSystemLibrary("couchbase");
    connection_features_tests.linkLibC();

    const prepared_statement_tests = b.addTest(.{
        .root_source_file = b.path("tests/prepared_statement_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    prepared_statement_tests.root_module.addImport("couchbase", couchbase_module);
    prepared_statement_tests.linkSystemLibrary("couchbase");
    prepared_statement_tests.linkLibC();

    const query_cancellation_tests = b.addTest(.{
        .root_source_file = b.path("tests/query_cancellation_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    query_cancellation_tests.root_module.addImport("couchbase", couchbase_module);
    query_cancellation_tests.linkSystemLibrary("couchbase");
    query_cancellation_tests.linkLibC();

    const enhanced_metadata_tests = b.addTest(.{
        .root_source_file = b.path("tests/enhanced_metadata_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    enhanced_metadata_tests.root_module.addImport("couchbase", couchbase_module);
    enhanced_metadata_tests.linkSystemLibrary("couchbase");
    enhanced_metadata_tests.linkLibC();

    const get_and_lock_tests = b.addTest(.{
        .root_source_file = b.path("tests/get_and_lock_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    get_and_lock_tests.root_module.addImport("couchbase", couchbase_module);
    get_and_lock_tests.linkSystemLibrary("couchbase");
    get_and_lock_tests.linkLibC();

    const collections_tests = b.addTest(.{
        .root_source_file = b.path("tests/collections_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    collections_tests.root_module.addImport("couchbase", couchbase_module);
    collections_tests.linkSystemLibrary("couchbase");
    collections_tests.linkLibC();

    const collections_phase1_tests = b.addTest(.{
        .root_source_file = b.path("tests/collections_phase1_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    collections_phase1_tests.root_module.addImport("couchbase", couchbase_module);
    collections_phase1_tests.linkSystemLibrary("couchbase");
    collections_phase1_tests.linkLibC();

    const collections_phase2_tests = b.addTest(.{
        .root_source_file = b.path("tests/collections_phase2_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    collections_phase2_tests.root_module.addImport("couchbase", couchbase_module);
    collections_phase2_tests.linkSystemLibrary("couchbase");
    collections_phase2_tests.linkLibC();

    const collections_phase3_tests = b.addTest(.{
        .root_source_file = b.path("tests/collections_phase3_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    collections_phase3_tests.root_module.addImport("couchbase", couchbase_module);
    collections_phase3_tests.linkSystemLibrary("couchbase");
    collections_phase3_tests.linkLibC();

    const batch_tests = b.addTest(.{
        .root_source_file = b.path("tests/batch_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    batch_tests.root_module.addImport("couchbase", couchbase_module);
    batch_tests.linkSystemLibrary("couchbase");
    batch_tests.linkLibC();

    const enhanced_batch_tests = b.addTest(.{
        .root_source_file = b.path("tests/enhanced_batch_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    enhanced_batch_tests.root_module.addImport("couchbase", couchbase_module);
    enhanced_batch_tests.linkSystemLibrary("couchbase");
    enhanced_batch_tests.linkLibC();

    const spatial_view_tests = b.addTest(.{
        .root_source_file = b.path("tests/spatial_view_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    spatial_view_tests.root_module.addImport("couchbase", couchbase_module);
    spatial_view_tests.linkSystemLibrary("couchbase");
    spatial_view_tests.linkLibC();

    const durability_tests = b.addTest(.{
        .root_source_file = b.path("tests/durability_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    durability_tests.root_module.addImport("couchbase", couchbase_module);
    durability_tests.linkSystemLibrary("couchbase");
    durability_tests.linkLibC();

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const run_unit_tests = b.addRunArtifact(unit_tests);
    const run_integration_tests = b.addRunArtifact(integration_tests);
    const run_coverage_tests = b.addRunArtifact(coverage_tests);
    const run_new_ops_tests = b.addRunArtifact(new_ops_tests);
    const run_view_tests = b.addRunArtifact(view_tests);
    const run_demo_tests = b.addRunArtifact(demo_tests);
    const run_param_query_tests = b.addRunArtifact(param_query_tests);
    const run_advanced_query_tests = b.addRunArtifact(advanced_query_tests);
    const run_prepared_statement_tests = b.addRunArtifact(prepared_statement_tests);
    const run_query_cancellation_tests = b.addRunArtifact(query_cancellation_tests);
    const run_enhanced_metadata_tests = b.addRunArtifact(enhanced_metadata_tests);
    const run_get_and_lock_tests = b.addRunArtifact(get_and_lock_tests);
    const run_collections_tests = b.addRunArtifact(collections_tests);
    const run_collections_phase1_tests = b.addRunArtifact(collections_phase1_tests);
    const run_collections_phase2_tests = b.addRunArtifact(collections_phase2_tests);
    const run_collections_phase3_tests = b.addRunArtifact(collections_phase3_tests);
    const run_batch_tests = b.addRunArtifact(batch_tests);
    const run_enhanced_batch_tests = b.addRunArtifact(enhanced_batch_tests);
    const run_spatial_view_tests = b.addRunArtifact(spatial_view_tests);
    const run_durability_tests = b.addRunArtifact(durability_tests);

    const transaction_tests = b.addTest(.{
        .root_source_file = b.path("tests/transaction_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    transaction_tests.root_module.addImport("couchbase", couchbase_module);
    transaction_tests.linkSystemLibrary("couchbase");
    transaction_tests.linkLibC();

    const run_transaction_tests = b.addRunArtifact(transaction_tests);

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_unit_tests.step);

    const unit_test_step = b.step("test-unit", "Run unit tests only");
    unit_test_step.dependOn(&run_lib_unit_tests.step);
    unit_test_step.dependOn(&run_unit_tests.step);

    const integration_test_step = b.step("test-integration", "Run integration tests");
    integration_test_step.dependOn(&run_integration_tests.step);

    const coverage_test_step = b.step("test-coverage", "Run coverage tests");
    coverage_test_step.dependOn(&run_coverage_tests.step);

    const new_ops_test_step = b.step("test-new-ops", "Run new operations tests");
    new_ops_test_step.dependOn(&run_new_ops_tests.step);

    const view_test_step = b.step("test-views", "Run view query tests");
    view_test_step.dependOn(&run_view_tests.step);

    const demo_test_step = b.step("test-demo", "Run comprehensive demo test");
    demo_test_step.dependOn(&run_demo_tests.step);

    const param_query_test_step = b.step("test-param-query", "Run parameterized query tests");
    param_query_test_step.dependOn(&run_param_query_tests.step);

    const advanced_query_test_step = b.step("test-advanced-query", "Run advanced query tests");
    advanced_query_test_step.dependOn(&run_advanced_query_tests.step);

    const prepared_statement_test_step = b.step("test-prepared-statement", "Run prepared statement tests");
    prepared_statement_test_step.dependOn(&run_prepared_statement_tests.step);

    const query_cancellation_test_step = b.step("test-query-cancellation", "Run query cancellation tests");
    query_cancellation_test_step.dependOn(&run_query_cancellation_tests.step);

    const enhanced_metadata_test_step = b.step("test-enhanced-metadata", "Run enhanced metadata tests");
    enhanced_metadata_test_step.dependOn(&run_enhanced_metadata_tests.step);

    const get_and_lock_test_step = b.step("test-get-and-lock", "Run get and lock tests");
    get_and_lock_test_step.dependOn(&run_get_and_lock_tests.step);

    const collections_test_step = b.step("test-collections", "Run collections and scopes tests");
    collections_test_step.dependOn(&run_collections_tests.step);

    const collections_phase1_test_step = b.step("test-collections-phase1", "Run collections phase 1 tests");
    collections_phase1_test_step.dependOn(&run_collections_phase1_tests.step);

    const collections_phase2_test_step = b.step("test-collections-phase2", "Run collections phase 2 tests");
    collections_phase2_test_step.dependOn(&run_collections_phase2_tests.step);

    const collections_phase3_test_step = b.step("test-collections-phase3", "Run collections phase 3 tests");
    collections_phase3_test_step.dependOn(&run_collections_phase3_tests.step);

    const batch_test_step = b.step("test-batch", "Run batch operation tests");
    batch_test_step.dependOn(&run_batch_tests.step);

    const enhanced_batch_test_step = b.step("test-enhanced-batch", "Run enhanced batch operation tests");
    enhanced_batch_test_step.dependOn(&run_enhanced_batch_tests.step);

    const spatial_view_test_step = b.step("test-spatial-view", "Run spatial view tests");
    spatial_view_test_step.dependOn(&run_spatial_view_tests.step);

    const durability_test_step = b.step("test-durability", "Run durability and consistency tests");
    durability_test_step.dependOn(&run_durability_tests.step);

    const transaction_test_step = b.step("test-transaction", "Run transaction tests");
    transaction_test_step.dependOn(&run_transaction_tests.step);

    // Advanced N1QL tests
    const advanced_n1ql_tests = b.addTest(.{
        .root_source_file = b.path("tests/advanced_n1ql_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    advanced_n1ql_tests.root_module.addImport("couchbase", couchbase_module);
    advanced_n1ql_tests.linkSystemLibrary("couchbase");
    advanced_n1ql_tests.linkLibC();

    const run_advanced_n1ql_tests = b.addRunArtifact(advanced_n1ql_tests);
    const advanced_n1ql_test_step = b.step("test-advanced-n1ql", "Run advanced N1QL query tests");
    advanced_n1ql_test_step.dependOn(&run_advanced_n1ql_tests.step);

    // Query options memory management tests
    const query_options_memory_tests = b.addTest(.{
        .root_source_file = b.path("tests/query_options_memory_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    query_options_memory_tests.root_module.addImport("couchbase", couchbase_module);
    query_options_memory_tests.linkSystemLibrary("couchbase");
    query_options_memory_tests.linkLibC();

    const run_query_options_memory_tests = b.addRunArtifact(query_options_memory_tests);
    const query_options_memory_test_step = b.step("test-query-options-memory", "Run query options memory management tests");
    query_options_memory_test_step.dependOn(&run_query_options_memory_tests.step);

    // Diagnostics tests
    const diagnostics_tests = b.addTest(.{
        .root_source_file = b.path("tests/diagnostics_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    diagnostics_tests.root_module.addImport("couchbase", couchbase_module);
    diagnostics_tests.linkSystemLibrary("couchbase");
    diagnostics_tests.linkLibC();

    const run_diagnostics_tests = b.addRunArtifact(diagnostics_tests);
    const diagnostics_test_step = b.step("test-diagnostics", "Run diagnostics and monitoring tests");
    diagnostics_test_step.dependOn(&run_diagnostics_tests.step);

    // Diagnostics unit tests
    const diagnostics_unit_tests = b.addTest(.{
        .root_source_file = b.path("tests/diagnostics_unit_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    diagnostics_unit_tests.root_module.addImport("couchbase", couchbase_module);
    diagnostics_unit_tests.linkSystemLibrary("couchbase");
    diagnostics_unit_tests.linkLibC();

    const run_diagnostics_unit_tests = b.addRunArtifact(diagnostics_unit_tests);
    const diagnostics_unit_test_step = b.step("test-diagnostics-unit", "Run diagnostics unit tests");
    diagnostics_unit_test_step.dependOn(&run_diagnostics_unit_tests.step);

    // Error handling and logging tests
    const error_handling_logging_tests = b.addTest(.{
        .root_source_file = b.path("tests/error_handling_logging_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    error_handling_logging_tests.root_module.addImport("couchbase", couchbase_module);
    error_handling_logging_tests.linkSystemLibrary("couchbase");
    error_handling_logging_tests.linkLibC();

    const run_error_handling_logging_tests = b.addRunArtifact(error_handling_logging_tests);
    const error_handling_logging_test_step = b.step("test-error-handling-logging", "Run error handling and logging tests");
    error_handling_logging_test_step.dependOn(&run_error_handling_logging_tests.step);

    // Binary protocol tests
    const binary_protocol_tests = b.addTest(.{
        .root_source_file = b.path("tests/binary_protocol_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    binary_protocol_tests.root_module.addImport("couchbase", couchbase_module);
    binary_protocol_tests.linkSystemLibrary("couchbase");
    binary_protocol_tests.linkLibC();

    const run_binary_protocol_tests = b.addRunArtifact(binary_protocol_tests);
    const binary_protocol_test_step = b.step("test-binary-protocol", "Run binary protocol tests");
    binary_protocol_test_step.dependOn(&run_binary_protocol_tests.step);

    // Connection features tests
    const run_connection_features_tests = b.addRunArtifact(connection_features_tests);
    const connection_features_test_step = b.step("test-connection-features", "Run connection features tests");
    connection_features_test_step.dependOn(&run_connection_features_tests.step);

    const all_tests_step = b.step("test-all", "Run all test suites");
    all_tests_step.dependOn(&run_lib_unit_tests.step);
    all_tests_step.dependOn(&run_unit_tests.step);
    all_tests_step.dependOn(&run_integration_tests.step);
    all_tests_step.dependOn(&run_coverage_tests.step);
    all_tests_step.dependOn(&run_new_ops_tests.step);
    all_tests_step.dependOn(&run_view_tests.step);
    all_tests_step.dependOn(&run_param_query_tests.step);
    all_tests_step.dependOn(&run_advanced_query_tests.step);
    all_tests_step.dependOn(&run_prepared_statement_tests.step);
    all_tests_step.dependOn(&run_query_cancellation_tests.step);
    all_tests_step.dependOn(&run_enhanced_metadata_tests.step);
    all_tests_step.dependOn(&run_get_and_lock_tests.step);
    all_tests_step.dependOn(&run_collections_tests.step);
    all_tests_step.dependOn(&run_collections_phase1_tests.step);
    all_tests_step.dependOn(&run_collections_phase2_tests.step);
    all_tests_step.dependOn(&run_collections_phase3_tests.step);
    all_tests_step.dependOn(&run_batch_tests.step);
    all_tests_step.dependOn(&run_enhanced_batch_tests.step);
    all_tests_step.dependOn(&run_spatial_view_tests.step);
    all_tests_step.dependOn(&run_durability_tests.step);
    all_tests_step.dependOn(&run_transaction_tests.step);
    all_tests_step.dependOn(&run_advanced_n1ql_tests.step);
    all_tests_step.dependOn(&run_query_options_memory_tests.step);
    all_tests_step.dependOn(&run_diagnostics_tests.step);
    all_tests_step.dependOn(&run_diagnostics_unit_tests.step);
    all_tests_step.dependOn(&run_error_handling_logging_tests.step);
    all_tests_step.dependOn(&run_binary_protocol_tests.step);
    all_tests_step.dependOn(&run_connection_features_tests.step);
}
