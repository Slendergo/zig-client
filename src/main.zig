const std = @import("std");
const gk = @import("gamekit");
const assets = @import("assets.zig");
const settings = @import("settings.zig");
const requests = @import("requests.zig");
const network = @import("network.zig");
const builtin = @import("builtin");

pub var fba: std.heap.FixedBufferAllocator = undefined;
pub var stack_allocator: std.mem.Allocator = undefined;
pub var allocator: std.mem.Allocator = undefined;
pub var server: ?network.Server = undefined;

pub fn main() !void {
    const is_debug = builtin.mode == .Debug;
    var gpa = if (is_debug) std.heap.GeneralPurposeAllocator(.{}){} else {};
    defer _ = if (is_debug) gpa.deinit();

    allocator = switch (builtin.mode) {
        .Debug => gpa.allocator(),
        .ReleaseSafe => std.heap.c_allocator,
        .ReleaseFast, .ReleaseSmall => std.heap.raw_c_allocator,
    };

    var buf: [65536]u8 = undefined;
    fba = std.heap.FixedBufferAllocator.init(&buf);
    stack_allocator = fba.allocator();

    // parse char list later
    server = network.Server.init("127.0.0.1", 2050);

    try gk.run(.{ .init = init, .update = update, .render = render, .shutdown = shutdown, .window = .{ .disable_vsync = true } });
}

fn init() !void {
    assets.init() catch |err| {
        std.log.err("Failed to initialize assets: {any}", .{err});
    };

    settings.init() catch |err| {
        std.log.err("Failed to initialize settings: {any}", .{err});
    };

    requests.init(allocator) catch |err| {
        std.log.err("Failed to initialize requests: {any}", .{err});
    };
}

fn update() !void {

}

fn render() !void {}

fn shutdown() !void {
    requests.deinit();
}
