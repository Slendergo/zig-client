const std = @import("std");
const gamekit_build = @import("libs/zig-gamekit/build.zig");
const libxml2 = @import("libs/libxml/libxml2.zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "Client",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize
    });

    const libxml = try libxml2.create(b, target, optimize, .{
        .iconv = false,
        .lzma = false,
        .zlib = false,
    });
    libxml.link(exe);

    gamekit_build.addGameKitToArtifact(b, exe, target, "libs/zig-gamekit/");

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
