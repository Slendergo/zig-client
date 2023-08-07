const std = @import("std");

pub const app_engine_url: []const u8 = "127.0.0.1:2050";

pub fn init() !void {
    std.log.debug("Settings Initialized!", .{});
}

pub fn save() !void {
    std.log.debug("Settings Saved!", .{});
}


pub fn resetToDefualt() !void {
    std.log.debug("Settings Reset!", .{});
}