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
const VaultPanel = @import("../panels/vault_panel.zig").VaultPanel;
const MarketPanel = @import("../panels/market_panel.zig").MarketPanel;
const WikiPanel = @import("../panels/wiki_panel.zig").WikiPanel;
const OptionsPanel = @import("../panels/options_panel.zig").OptionsPanel;
const screen_controller = @import("screen_controller.zig");

const NineSlice = ui.NineSliceImageData;

pub const PanelController = struct {
    x: f32 = 0,
    y: f32 = 0,
    width: f32 = 0,
    height: f32 = 0,
    inited: bool = false,
    _allocator: std.mem.Allocator = undefined,

    basic_panel: *BasicPanel = undefined,
    vault: *VaultPanel = undefined,
    market: *MarketPanel = undefined,
    wiki: *WikiPanel = undefined,
    options: *OptionsPanel = undefined,

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

        controller.vault = try VaultPanel.init(allocator, .{ .visible = false }); //just to be explicit
        controller.market = try MarketPanel.init(allocator, .{ .visible = false });
        controller.wiki = try WikiPanel.init(allocator, .{ .visible = false });

        //Options always last
        controller.options = try OptionsPanel.init(allocator);

        controller.inited = true;
        return controller;
    }

    pub fn deinit(self: *PanelController) void {
        while (!screen_controller.ui_lock.tryLock()) {}
        defer screen_controller.ui_lock.unlock();

        self.basic_panel.deinit();
        self.vault.deinit();
        self.market.deinit();
        self.wiki.deinit();
        self.options.deinit();

        self._allocator.destroy(self);
    }

    pub fn hidePanels(self: *PanelController) void {
        self.basic_panel.setVisible(false);
        self.vault.setVisible(false);
        self.market.setVisible(false);
        self.wiki.setVisible(false);
    }

    fn hideSmallPanels(self: *PanelController) void {
        self.basic_panel.setVisible(false);
    }

    pub fn showBasicPanel(self: *PanelController, text: []u8, size: f32) void {
        self.basic_panel.title_text.text_data.text = text;
        self.basic_panel.title_text.text_data.size = size;
        self.basic_panel.setVisible(true);
    }

    pub fn showPanel(self: *PanelController, class_type: game_data.ClassType) void {
        input.disable_input = true;
        input.reset();

        self.hideSmallPanels();
        switch (class_type) {
            .vault_chest => {
                self.vault.setVisible(true);
            },
            .market_place => {
                self.market.setVisible(true);
            },
            .wiki => {
                self.wiki.setVisible(true);
            },
            else => {
                self.hidePanels();
                std.log.err("screen_controller:: {} screen not implemented", .{class_type});
            },
        }
    }

    pub fn basicPanelCallback() void {
        var game_screen = screen_controller.current_screen.game;
        var self = game_screen.panel_controller;
        self.showPanel(game_screen.interact_class);
        self.hidePanels();
    }

    pub fn resize(self: *PanelController, w: f32, h: f32) void {
        self.basic_panel.resize(w, h, self.width, self.height);
        self.vault.resize(w, h);
        self.market.resize(w, h);
        self.wiki.resize(w, h);
        self.options.resize(w, h);
    }

    pub fn setOptionsVisible(self: *PanelController, vis: bool) void {
        self.options.setVisible(vis);
        input.disable_input = vis;
    }
};
