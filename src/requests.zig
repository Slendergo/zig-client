const std = @import("std");
const settings = @import("settings.zig");

var client: std.http.Client = undefined;
var headers: std.http.Headers = undefined;
var buffer: [std.math.maxInt(u16)]u8 = undefined;

pub fn init(allocator: std.mem.Allocator) !void {
    client = std.http.Client{ .allocator = allocator };
    headers = std.http.Headers{ .allocator = allocator };

    std.log.debug("Request Handler Initialized", .{});
}

pub fn deinit() void {
    client.deinit();
    headers.deinit();
}