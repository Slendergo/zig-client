const std = @import("std");
const gk = @import("gamekit");
const assets = @import("assets.zig");
const settings = @import("settings.zig");
const requests = @import("requests.zig");
const networking = @import("networking.zig");
const builtin = @import("builtin");

pub fn main() !void {
    const is_debug = builtin.mode == .Debug;
    var gpa = if (is_debug) std.heap.GeneralPurposeAllocator(.{}){} else {};
    defer _ = if (is_debug) gpa.deinit();

    const allocator = switch (builtin.mode) {
        .Debug => gpa.allocator(),
        .ReleaseSafe => std.heap.c_allocator,
        .ReleaseFast, .ReleaseSmall => std.heap.raw_c_allocator,
    };

    assets.init() catch |err| {
        std.log.err("Failed to initialize assets: {any}", .{err});
    };

    settings.init() catch |err| {
        std.log.err("Failed to initialize settings: {any}", .{err});
    };

    requests.init(allocator) catch |err| {
        std.log.err("Failed to initialize requests: {any}", .{err});
    };

    networking.init() catch |err| {
        std.log.err("Failed to initialize networking: {any}", .{err});
    };

    try gk.run(.{ .init = init, .update = update, .render = render, .shutdown = shutdown, .window = .{ .disable_vsync = true } });
}

fn init() !void {}

fn update() !void {}

fn render() !void {}

fn shutdown() !void {
    requests.deinit();
}
