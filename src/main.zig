const std = @import("std");
const gk = @import("gamekit");
const assets = @import("assets.zig");
const settings = @import("settings.zig");
const requests = @import("requests.zig");
const networking = @import("networking.zig");

pub fn main() !void {
    std.log.debug("Hello, world!", .{});

    assets.init() catch |err| {
        std.log.err("Failed to initialize assets", .{});
        return err;
    };

    settings.init() catch |err| {
        std.log.err("Failed to initialize settings", .{});
        return err;
    };

    const allocator = std.heap.page_allocator;
    requests.init(allocator) catch |err| {
        std.log.err("Failed to initialize requests", .{});
        return err;
    };

    networking.init() catch |err| {
        std.log.err("Failed to initialize networking", .{});
        return err;
    };

    try gk.run(.{ .init = init, .update = update, .render = render, .shutdown = shutdown, .window = .{ .disable_vsync = true } });
}

fn init() !void {
}

fn deinit() !void {
    requests.deinit();
}

fn update() !void {
}

fn render() !void {
}

fn shutdown() !void {
}
