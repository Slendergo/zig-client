const std = @import("std");

const VaultPanel = @import("../panels/vault_panel.zig").VaultPanel;
const MarketPanel = @import("../panels/market_panel.zig").MarketPanel;
const WikiPanel = @import("../panels/wiki_panel.zig").WikiPanel;

const ui = @import("../ui.zig");
const input = @import("../../input.zig");
const game_data = @import("../../game_data.zig");

pub var screen_open: bool = false;

pub const ScreenController = struct {
    inited: bool = false,
    _allocator: std.mem.Allocator = undefined,

    vault: *VaultPanel = undefined,
    market: *MarketPanel = undefined,
    wiki: *WikiPanel = undefined,

    pub fn init(allocator: std.mem.Allocator) !*ScreenController {
        var controller = try allocator.create(ScreenController);
        controller.* = .{ ._allocator = allocator };

        controller.vault = try VaultPanel.init(allocator, .{ .visible = false }); //just to be explicit
        controller.market = try MarketPanel.init(allocator, .{ .visible = false });
        controller.wiki = try WikiPanel.init(allocator, .{ .visible = false });

        return controller;
    }

    pub fn deinit(self: *ScreenController) void {
        while (!ui.ui_lock.tryLock()) {}
        defer ui.ui_lock.unlock();

        self.vault.deinit();
        self.market.deinit();
        self.wiki.deinit();

        self._allocator.destroy(self);
    }

    pub fn hideScreens(self: *ScreenController) void {
        self.vault.setVisible(false);
        self.market.setVisible(false);
        self.wiki.setVisible(false);
        screen_open = false;
        input.disable_input = false;
    }

    pub fn showScreen(self: *ScreenController, class_type: game_data.ClassType) void {
        screen_open = true;
        input.disable_input = true;
        input.reset();
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
                self.hideScreens();
                std.log.err("screen_controller:: {} screen not implemented", .{class_type});
            },
        }
    }

    pub fn resize(self: *ScreenController, w: f32, h: f32) void {
        self.vault.resize(w, h);
        self.market.resize(w, h);
        self.wiki.resize(w, h);
    }
};
