const std = @import("std");

pub const Package = struct {
    zstbrp: *std.Build.Module,
    zstbrp_c_cpp: *std.Build.CompileStep,

    pub fn link(pkg: Package, exe: *std.Build.CompileStep) void {
        exe.linkLibrary(pkg.zstbrp_c_cpp);
        exe.addModule("zstbrp", pkg.zstbrp);
    }
};

pub fn package(
    b: *std.Build,
    target: std.zig.CrossTarget,
    optimize: std.builtin.Mode,
    _: struct {},
) Package {
    const zstbrp = b.createModule(.{
        .source_file = .{ .path = thisDir() ++ "/src/zstbrp.zig" },
    });

    const zstbrp_c_cpp = b.addStaticLibrary(.{
        .name = "zstbrp",
        .target = target,
        .optimize = optimize,
    });
    if (optimize == .Debug) {
        // TODO: Workaround for Zig bug.
        zstbrp_c_cpp.addCSourceFile(.{
            .file = .{ .path = thisDir() ++ "/libs/stbrp/stb_rect_pack.c" },
            .flags = &.{
                "-std=c99",
                "-fno-sanitize=undefined",
                "-g",
                "-O0",
            },
        });
    } else {
        zstbrp_c_cpp.addCSourceFile(.{
            .file = .{ .path = thisDir() ++ "/libs/stbrp/stb_rect_pack.c" },
            .flags = &.{
                "-std=c99",
                "-fno-sanitize=undefined",
            },
        });
    }
    zstbrp_c_cpp.linkLibC();

    return .{
        .zstbrp = zstbrp,
        .zstbrp_c_cpp = zstbrp_c_cpp,
    };
}

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const test_step = b.step("test", "Run zstbrp tests");
    test_step.dependOn(runTests(b, optimize, target));
}

pub fn runTests(
    b: *std.Build,
    optimize: std.builtin.Mode,
    target: std.zig.CrossTarget,
) *std.Build.Step {
    const tests = b.addTest(.{
        .name = "zstbrp-tests",
        .root_source_file = .{ .path = thisDir() ++ "/src/zstbrp.zig" },
        .target = target,
        .optimize = optimize,
    });

    const zstbrp_pkg = package(b, target, optimize, .{});
    zstbrp_pkg.link(tests);

    return &b.addRunArtifact(tests).step;
}

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}
