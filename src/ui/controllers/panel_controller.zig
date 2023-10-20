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

const BasicPanel = @import("../panels/basic_panel.zig").BasicPanel;

const NineSlice = ui.NineSliceImageData;

pub const PanelController = struct {
    x: f32 = 0,
    y: f32 = 0,
    width: f32 = 0,
    height: f32 = 0,
    inited: bool = false,
    _allocator: std.mem.Allocator = undefined,
    basic_panel: *BasicPanel = undefined,

    pub fn init(allocator: std.mem.Allocator, data: PanelController) !*PanelController {
        var controller = try allocator.create(PanelController);
        controller.* = .{ ._allocator = allocator };
        controller.* = data;

        controller.basic_panel = try BasicPanel.init(allocator, .{
            .x = controller.x - controller.width,
            .y = controller.y - (controller.height / 2) - 5,
            .width = controller.width,
            .height = controller.height,
            .visible = false,
        });

        controller.inited = true;
        return controller;
    }

    pub fn deinit(self: *PanelController) void {
        while (!ui.ui_lock.tryLock()) {}
        defer ui.ui_lock.unlock();

        self.basic_panel.deinit();

        self._allocator.destroy(self);
    }

    pub fn hidePanels(self: *PanelController) void {
        self.basic_panel.setVisible(false);
    }

    pub fn showBasicPanel(self: *PanelController, text: []u8, size: f32) void {
        self.basic_panel.title_text.text_data.text = text;
        self.basic_panel.title_text.text_data.size = size;
        self.basic_panel.setVisible(true);
    }

    pub fn basicPanelCallback() void {
        var sc = ui.current_screen.game.screen_controller;
        var self = ui.current_screen.game.panel_controller;

        sc.showScreen(ui.current_screen.game.interact_class);
        self.hidePanels();
    }

    pub fn resize(self: *PanelController, w: f32, h: f32) void {
        self.basic_panel.resize(w, h, self.width, self.height);
    }
};
