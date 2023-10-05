const std = @import("std");
const ui = @import("ui.zig");
const assets = @import("../assets.zig");
const camera = @import("../camera.zig");
const requests = @import("../requests.zig");
const xml = @import("../xml.zig");
const main = @import("../main.zig");
const utils = @import("../utils.zig");

pub const CharCreateScreen = struct {
    inited: bool = false,
    _allocator: std.mem.Allocator = undefined,

    pub fn init(allocator: std.mem.Allocator) !*CharCreateScreen {
        var screen = try allocator.create(CharCreateScreen);
        screen.* = CharCreateScreen{
            ._allocator = allocator,
        };

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

        screen.inited = true;
        return screen;
    }

    pub fn deinit(self: *CharCreateScreen) void {
        self._allocator.destroy(self);
    }

    pub fn resize(_: *CharCreateScreen, _: f32, _: f32) void {}

    pub fn update(_: *CharCreateScreen, _: i64, _: f32) !void {}
};
