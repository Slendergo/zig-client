const std = @import("std");
const ui = @import("../ui.zig");
const assets = @import("../../assets.zig");
const camera = @import("../../camera.zig");
const network = @import("../../network.zig");
const xml = @import("../../xml.zig");
const main = @import("../../main.zig");
const utils = @import("../../utils.zig");
const game_data = @import("../../game_data.zig");
const map = @import("../../map.zig");
const input = @import("../../input.zig");

const screen_controller = @import("../controllers/screen_controller.zig");
const PanelController = @import("../controllers/panel_controller.zig").PanelController;
const NineSlice = ui.NineSliceImageData;

pub const WikiPanel = struct {
    inited: bool = false,
    _allocator: std.mem.Allocator = undefined,
    visible: bool = false,
    cont: *ui.DisplayContainer = undefined,
    pub fn init(allocator: std.mem.Allocator, data: WikiPanel) !*WikiPanel {
        var screen = try allocator.create(WikiPanel);
        screen.* = .{ ._allocator = allocator };
        screen.* = data;

        const width: f32 = camera.screen_width;
        const height: f32 = camera.screen_height;
        const half_width: f32 = width / 2;
        const half_height: f32 = height / 2;

        const container_data = assets.getUiData("containerView", 0);
        screen.cont = try ui.DisplayContainer.create(allocator, .{
            .x = 0,
            .y = 0,
            .visible = screen.visible,
        });

        _ = try screen.cont.createElement(ui.Image, .{
            .x = 0,
            .y = 0,
            .image_data = .{ .normal = .{ .atlas_data = container_data } },
        });

        const button_data_base = assets.getUiData("buttonBase", 0);
        const button_data_hover = assets.getUiData("buttonHover", 0);
        const button_data_press = assets.getUiData("buttonPress", 0);

        const actual_width = container_data.texWRaw() - 10;
        const actual_height = container_data.texHRaw() - 10;

        _ = try screen.cont.createElement(ui.Button, .{
            .x = half_width,
            .y = half_height,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, actual_width, actual_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, actual_width, actual_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, actual_width, actual_height, 6, 6, 7, 7, 1.0) },
            },
            .text_data = .{
                .text = @constCast("Close"),
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .press_callback = closeCallback,
        });

        screen.inited = true;
        return screen;
    }

    pub fn setVisible(self: *WikiPanel, val: bool) void {
        self.cont.visible = val;
    }

    pub fn deinit(self: *WikiPanel) void {
        self.cont.destroy();
    }

    fn closeCallback() void {
        screen_controller.current_screen.game.panel_controller.hidePanels();
    }

    pub fn resize(_: *WikiPanel, _: f32, _: f32) void {}
};
