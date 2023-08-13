const std = @import("std");
const libxml2 = @import("libs/libxml/libxml2.zig");
const zglfw = @import("libs/zglfw/build.zig");
const zgpu = @import("libs/zgpu/build.zig");
const zpool = @import("libs/zpool/build.zig");
const zgui = @import("libs/zgui/build.zig");
const zstbi = @import("libs/zstbi/build.zig");
const zstbrp = @import("libs/zstbrp/build.zig");
const ztracy = @import("libs/ztracy/build.zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{ .name = "Client", .root_source_file = .{ .path = "src/main.zig" }, .target = target, .optimize = optimize });
    exe.want_lto = false; // remove later

    const libxml = try libxml2.create(b, target, optimize, .{
        .iconv = false,
        .lzma = false,
        .zlib = false,
    });
    libxml.link(exe);

    const zstbi_pkg = zstbi.package(b, target, optimize, .{});
    zstbi_pkg.link(exe);

    const zstbrp_pkg = zstbrp.package(b, target, optimize, .{});
    zstbrp_pkg.link(exe);

    const zgui_pkg = zgui.package(b, target, optimize, .{
        .options = .{ .backend = .glfw_wgpu },
    });
    zgui_pkg.link(exe);

    const ztracy_pkg = ztracy.package(b, target, optimize, .{
        .options = .{ .enable_ztracy = true },
    });
    ztracy_pkg.link(exe);

    const zglfw_pkg = zglfw.package(b, target, optimize, .{});
    const zpool_pkg = zpool.package(b, target, optimize, .{});
    const zgpu_pkg = zgpu.package(b, target, optimize, .{
        .deps = .{ .zpool = zpool_pkg.zpool, .zglfw = zglfw_pkg.zglfw },
    });

    zglfw_pkg.link(exe);
    zgpu_pkg.link(exe);

    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const exe_options = b.addOptions();
    exe.addOptions("build_options", exe_options);
    exe_options.addOption([]const u8, "asset_dir", "./assets/");

    const install_assets_step = b.addInstallDirectory(.{ .source_dir = .{ .path = "src/assets" }, .install_dir = .{ .custom = "" }, .install_subdir = "bin/assets" });
    exe.step.dependOn(&install_assets_step.step);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
