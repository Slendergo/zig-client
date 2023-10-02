const std = @import("std");
const ui = @import("ui.zig");
const assets = @import("../assets.zig");
const camera = @import("../camera.zig");
const requests = @import("../requests.zig");
const xml = @import("../xml.zig");
const main = @import("../main.zig");
const utils = @import("../utils.zig");

pub const CharCreateScreen = struct {
    _allocator: std.mem.Allocator = undefined,

    pub fn init(allocator: std.mem.Allocator) !CharCreateScreen {
        var screen = CharCreateScreen{
            ._allocator = allocator,
        };

        return screen;
    }

    pub fn deinit(self: *CharCreateScreen) void {
        _ = self;
    }

    pub fn toggle(self: *CharCreateScreen, state: bool) void {
        _ = self;
        if (state) {
            main.char_create_type = 0x030e;
            main.char_create_skin_type = 0;
            main.selected_char_id = main.next_char_id;
            main.next_char_id += 1;
            if (main.server_list) |server_list| {
                main.selected_server = server_list[0];
                ui.switchScreen(.in_game);
            } else {
                std.log.err("Server list was empty", .{});
            }
        }
    }

    pub fn resize(self: *CharCreateScreen, w: f32, h: f32) void {
        _ = h;
        _ = w;
        _ = self;
    }

    pub fn update(self: *CharCreateScreen, ms_time: i64, ms_dt: f32) !void {
        _ = self;
        _ = ms_dt;
        _ = ms_time;
    }
};
