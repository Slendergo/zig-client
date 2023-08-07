const std = @import("std");

pub const LogType = enum(u8) {
    all = 0,
    all_non_tick = 1,
    c2s = 2,
    c2s_non_tick = 3,
    s2c = 4,
    s2c_non_tick = 5,
    off = 255,
};

pub const build_version = "0.5";
pub const app_engine_url = "http://127.0.0.1:8080";
pub const log_packets = LogType.off;

pub fn init() void {}

pub fn save() void {}

pub fn resetToDefault() void {}
