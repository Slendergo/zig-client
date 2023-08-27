const std = @import("std");
const zglfw = @import("zglfw");

pub const LogType = enum(u8) {
    all = 0,
    all_non_tick = 1,
    c2s = 2,
    c2s_non_tick = 3,
    c2s_tick = 4,
    s2c = 5,
    s2c_non_tick = 6,
    s2c_tick = 7,
    off = 255,
};

pub const CursorType = enum(u8) {
    basic = 0,
    royal = 1,
    ranger = 2,
    aztec = 3,
    fiery = 4,
    target_enemy = 5,
    target_ally = 6,
};

pub const Button = union(enum) {
    key: zglfw.Key,
    mouse: zglfw.MouseButton,

    pub fn getKey(self: Button) zglfw.Key {
        switch (self) {
            .key => |key| return key,
            .mouse => |_| return .unknown,
        }
    }

    pub fn getMouse(self: Button) zglfw.MouseButton {
        switch (self) {
            .key => |_| return .eight,
            .mouse => |mouse| return mouse,
        }
    }
};

pub const build_version = "0.5";
pub const app_engine_url = "http://127.0.0.1:8080/";
pub const log_packets = LogType.off;
pub const print_atlas = false;
pub const print_ui_atlas = false;
pub const rotate_speed = 0.002;
pub const enable_tracy = false;

pub var move_left: Button = .{ .key = .a };
pub var move_right: Button = .{ .key = .d };
pub var move_up: Button = .{ .key = .w };
pub var move_down: Button = .{ .key = .s };
pub var rotate_left: Button = .{ .key = .q };
pub var rotate_right: Button = .{ .key = .e };
pub var interact: Button = .{ .key = .r };
pub var options: Button = .{ .key = .escape };
pub var escape: Button = .{ .key = .tab };
pub var chat_up: Button = .{ .key = .page_up };
pub var chat_down: Button = .{ .key = .page_down };
pub var walk: Button = .{ .key = .left_shift };
pub var reset_camera: Button = .{ .key = .z };
pub var toggle_stats: Button = .{ .key = .F3 };
pub var chat: Button = .{ .key = .enter };
pub var chat_cmd: Button = .{ .key = .slash };
pub var respond: Button = .{ .key = .F2 };
pub var toggle_centering: Button = .{ .key = .x };
pub var shoot: Button = .{ .mouse = .left };
pub var ability: Button = .{ .mouse = .right };
pub var sfx_volume: f32 = 0.33;
pub var music_volume: f32 = 0.33;
pub var enable_glow = false;
pub var enable_lights = false;
pub var enable_vsync = true;
pub var selected_cursor = CursorType.aztec;

pub fn init() void {}

pub fn save() void {}

pub fn resetToDefault() void {
    move_left = .{ .key = .a };
    move_right = .{ .key = .d };
    move_up = .{ .key = .w };
    move_down = .{ .key = .s };
    rotate_left = .{ .key = .q };
    rotate_right = .{ .key = .e };
    interact = .{ .key = .r };
    options = .{ .key = .escape };
    escape = .{ .key = .tab };
    chat_up = .{ .key = .page_up };
    chat_down = .{ .key = .page_down };
    walk = .{ .key = .left_shift };
    reset_camera = .{ .key = .z };
    toggle_stats = .{ .key = .F3 };
    chat = .{ .key = .enter };
    chat_cmd = .{ .key = .slash };
    respond = .{ .key = .F2 };
    toggle_centering = .{ .key = .x };
    shoot = .{ .mouse = .left };
    ability = .{ .mouse = .right };
    sfx_volume = 0.33;
    music_volume = 0.33;
    enable_glow = true;
    enable_lights = true;
}
