const std = @import("std");
const zglfw = @import("zglfw");

pub const LogType = enum(u8) {
    all = 0,
    all_non_tick = 1,
    c2s = 2,
    c2s_non_tick = 3,
    s2c = 4,
    s2c_non_tick = 5,
    off = 255,
};

pub const Button = union(enum) {
    key: zglfw.Key,
    mouse: zglfw.MouseButton,

    pub fn getKey(self: Button) zglfw.Key {
        switch (self) {
            .key => |key| return key,
            .mouse => |_| return zglfw.Key.unknown,
        }
    }

    pub fn getMouse(self: Button) zglfw.MouseButton {
        switch (self) {
            .key => |_| return zglfw.MouseButton.eight,
            .mouse => |mouse| return mouse,
        }
    }
};

pub const build_version = "0.5";
pub const app_engine_url = "http://127.0.0.1:8080/";
pub const log_packets = LogType.off;
pub const print_atlas = false;
pub const rotate_speed = 0.002;

pub var move_left: Button = .{ .key = zglfw.Key.a };
pub var move_right: Button = .{ .key = zglfw.Key.d };
pub var move_up: Button = .{ .key = zglfw.Key.w };
pub var move_down: Button = .{ .key = zglfw.Key.s };
pub var rotate_left: Button = .{ .key = zglfw.Key.q };
pub var rotate_right: Button = .{ .key = zglfw.Key.e };
pub var interact: Button = .{ .key = zglfw.Key.r };
pub var options: Button = .{ .key = zglfw.Key.escape };
pub var escape: Button = .{ .key = zglfw.Key.tab };
pub var chat_up: Button = .{ .key = zglfw.Key.page_up };
pub var chat_down: Button = .{ .key = zglfw.Key.page_down };
pub var walk: Button = .{ .key = zglfw.Key.left_shift };
pub var reset_camera: Button = .{ .key = zglfw.Key.z };
pub var toggle_stats: Button = .{ .key = zglfw.Key.F3 };
pub var chat: Button = .{ .key = zglfw.Key.enter };
pub var chat_cmd: Button = .{ .key = zglfw.Key.slash };
pub var respond: Button = .{ .key = zglfw.Key.F2 };
pub var shoot: Button = .{ .mouse = zglfw.MouseButton.left };

pub fn init() void {}

pub fn save() void {}

pub fn resetToDefault() void {}
