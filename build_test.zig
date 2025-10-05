const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const couchbase_module = b.addModule("couchbase", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    couchbase_module.linkSystemLibrary("couchbase", .{});

    const exe = b.addExecutable(.{
        .name = "test_connect",
        .root_source_file = b.path("test_connect.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("couchbase", couchbase_module);
    exe.linkSystemLibrary("couchbase");
    exe.linkLibC();
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the test");
    run_step.dependOn(&run_cmd.step);
}
