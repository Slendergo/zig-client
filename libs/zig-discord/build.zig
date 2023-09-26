const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const rpc = b.addModule("rpc", .{ .source_file = .{ .path = "src/rpc.zig" } });

    const exe = b.addExecutable(.{
        .name = "zig-discord",
        .target = target,
        .optimize = optimize,
    });
    exe.addModule("rpc", rpc);
    exe.linkLibC();

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
