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

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const run_unit_tests = b.addRunArtifact(unit_tests);
    const run_integration_tests = b.addRunArtifact(integration_tests);
    const run_coverage_tests = b.addRunArtifact(coverage_tests);
    const run_new_ops_tests = b.addRunArtifact(new_ops_tests);
    const run_view_tests = b.addRunArtifact(view_tests);
    const run_demo_tests = b.addRunArtifact(demo_tests);
    const run_param_query_tests = b.addRunArtifact(param_query_tests);
    const run_advanced_query_tests = b.addRunArtifact(advanced_query_tests);

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

    const all_tests_step = b.step("test-all", "Run all test suites");
    all_tests_step.dependOn(&run_lib_unit_tests.step);
    all_tests_step.dependOn(&run_unit_tests.step);
    all_tests_step.dependOn(&run_integration_tests.step);
    all_tests_step.dependOn(&run_coverage_tests.step);
    all_tests_step.dependOn(&run_new_ops_tests.step);
    all_tests_step.dependOn(&run_view_tests.step);
    all_tests_step.dependOn(&run_param_query_tests.step);
    all_tests_step.dependOn(&run_advanced_query_tests.step);
}
