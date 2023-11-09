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
const PanelController = @import("../controllers/panel_controller.zig").PanelController;
const sc = @import("../controllers/screen_controller.zig");
const NineSlice = ui.NineSliceImageData;

pub const BasicPanel = struct {
    x: f32 = 0,
    y: f32 = 0,
    width: f32 = 0,
    height: f32 = 0,
    visible: bool = false,
    _allocator: std.mem.Allocator = undefined,
    inited: bool = false,
    cont: *ui.DisplayContainer = undefined,
    title_text: *ui.UiText = undefined,

    pub fn init(allocator: std.mem.Allocator, data: BasicPanel) !*BasicPanel {
        var panel = try allocator.create(BasicPanel);
        panel.* = .{ ._allocator = allocator };
        panel.* = data;

        const basic_panel_data = assets.getUiData("basicPanel", 0);

        panel.cont = try ui.DisplayContainer.create(allocator, .{
            .x = panel.x - basic_panel_data.texWRaw(),
            .y = panel.y,
            .visible = panel.visible,
        });

        _ = try panel.cont.createElement(ui.Image, .{
            .x = 0,
            .y = 0,
            .image_data = .{ .normal = .{ .atlas_data = basic_panel_data } },
        });

        panel.title_text = try panel.cont.createElement(ui.UiText, .{ .x = 10, .y = 10, .text_data = .{
            .text = "",
            .size = 22,
            .text_type = .bold,
            .backing_buffer = try allocator.alloc(u8, 8),
        } });

        const button_data_base = assets.getUiData("buttonBase", 0);
        const button_data_hover = assets.getUiData("buttonHover", 0);
        const button_data_press = assets.getUiData("buttonPress", 0);

        const button_width: f32 = basic_panel_data.texWRaw() - 20;
        const button_height: f32 = 25;

        _ = try panel.cont.createElement(ui.Button, .{
            .x = 10,
            .y = basic_panel_data.texHRaw() - button_height - 15,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, button_width, button_height, 6, 6, 7, 7, 1.0) },
            },
            .text_data = .{
                .text = @constCast("Open"),
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .press_callback = PanelController.basicPanelCallback,
        });

        panel.inited = true;
        return panel;
    }

    pub fn setVisible(self: *BasicPanel, val: bool) void {
        self.cont.visible = val;
    }

    pub fn deinit(self: *BasicPanel) void {
        self.cont.destroy();
    }

    pub fn resize(self: *BasicPanel, screen_w: f32, screen_h: f32, w: f32, h: f32) void {
        self.cont.x = screen_w - w - w;
        self.cont.y = screen_h - (h / 2) - 10;
    }
};
