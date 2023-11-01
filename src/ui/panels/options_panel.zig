const std = @import("std");
const ui = @import("../ui.zig");
const assets = @import("../../assets.zig");
const camera = @import("../../camera.zig");
const main = @import("../../main.zig");
const settings = @import("../../settings.zig");

const PanelController = @import("../controllers/panel_controller.zig").PanelController;
const NineSlice = ui.NineSliceImageData;
const sc = @import("../controllers/screen_controller.zig");

pub const TabType = enum {
    general,
    hotkeys,
    graphics,
    misc,
};

pub const OptionsPanel = struct {
    visible: bool = false,
    inited: bool = false,
    selected_tab_type: TabType = .general,
    main: *ui.DisplayContainer = undefined,
    buttons: *ui.DisplayContainer = undefined,
    tabs: *ui.DisplayContainer = undefined,
    general_tab: *ui.DisplayContainer = undefined,
    keys_tab: *ui.DisplayContainer = undefined,
    graphics_tab: *ui.DisplayContainer = undefined,
    misc_tab: *ui.DisplayContainer = undefined,
    _allocator: std.mem.Allocator = undefined,
    settings_arr: []u8 = undefined,

    pub fn init(allocator: std.mem.Allocator) !*OptionsPanel {
        var screen = try allocator.create(OptionsPanel);
        screen.* = .{ ._allocator = allocator };

        screen.settings_arr = try allocator.alloc(u8, 1024);

        const button_width = 150;
        const button_height = 50;
        const button_half_width = button_width / 2;
        const button_half_height = button_height / 2;
        const width = camera.screen_width;
        const height = camera.screen_height;
        const buttons_x = width / 2;
        const buttons_y = height - button_height - 50;

        screen.main = try ui.DisplayContainer.create(allocator, .{
            .x = 0,
            .y = 0,
            .visible = screen.visible,
        });

        screen.buttons = try ui.DisplayContainer.create(allocator, .{
            .x = 0,
            .y = buttons_y,
            .visible = screen.visible,
        });

        screen.tabs = try ui.DisplayContainer.create(allocator, .{
            .x = 0,
            .y = 25,
            .visible = screen.visible,
        });

        screen.general_tab = try ui.DisplayContainer.create(allocator, .{
            .x = 100,
            .y = 150,
            .visible = screen.visible and screen.selected_tab_type == .general,
        });

        screen.keys_tab = try ui.DisplayContainer.create(allocator, .{
            .x = 100,
            .y = 150,
            .visible = screen.visible and screen.selected_tab_type == .hotkeys,
        });

        screen.graphics_tab = try ui.DisplayContainer.create(allocator, .{
            .x = 100,
            .y = 150,
            .visible = screen.visible and screen.selected_tab_type == .graphics,
        });

        screen.misc_tab = try ui.DisplayContainer.create(allocator, .{
            .x = 100,
            .y = 150,
            .visible = screen.visible and screen.selected_tab_type == .misc,
        });

        const options_background = assets.getUiData("optionsBackground", 0);
        _ = try screen.main.createElement(ui.Image, .{ .x = 0, .y = 0, .image_data = .{
            .nine_slice = NineSlice.fromAtlasData(options_background, width, height, 0, 0, 8, 8, 1.0),
        } });

        _ = try screen.main.createElement(ui.UiText, .{ .x = buttons_x - 76, .y = 25, .text_data = .{
            .text = @constCast("Options"),
            .size = 32,
            .text_type = .bold,
            .backing_buffer = try allocator.alloc(u8, 8),
        } });

        const button_data_base = assets.getUiData("buttonBase", 0);
        const button_data_hover = assets.getUiData("buttonHover", 0);
        const button_data_press = assets.getUiData("buttonPress", 0);
        _ = try screen.buttons.createElement(ui.Button, .{
            .x = buttons_x - button_half_width,
            .y = button_half_height - 20,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, button_width, button_height, 6, 6, 7, 7, 1.0) },
            },
            .text_data = .{
                .text = @constCast("Continue"),
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .press_callback = closeCallback,
        });

        _ = try screen.buttons.createElement(ui.Button, .{
            .x = width - button_width - 50,
            .y = button_half_height - 20,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, button_width, button_height, 6, 6, 7, 7, 1.0) },
            },
            .text_data = .{
                .text = @constCast("Disconnect"),
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .press_callback = disconnectCallback,
        });

        _ = try screen.buttons.createElement(ui.Button, .{
            .x = 50,
            .y = button_half_height - 20,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, button_width, button_height, 6, 6, 7, 7, 1.0) },
            },
            .text_data = .{
                .text = @constCast("Defaults"),
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .press_callback = resetToDefaultsCallback,
        });

        var tab_x_offset: f32 = 50;
        const tab_y: f32 = 50;

        _ = try screen.tabs.createElement(ui.Button, .{
            .x = tab_x_offset,
            .y = tab_y,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, button_width, button_height, 6, 6, 7, 7, 1.0) },
            },
            .text_data = .{
                .text = @constCast("General"),
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .press_callback = generalTabCallback,
        });

        tab_x_offset += button_width + 10;

        _ = try screen.tabs.createElement(ui.Button, .{
            .x = tab_x_offset,
            .y = tab_y,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, button_width, button_height, 6, 6, 7, 7, 1.0) },
            },
            .text_data = .{
                .text = @constCast("Hotkeys"),
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .press_callback = hotkeysTabCallback,
        });

        tab_x_offset += button_width + 10;

        _ = try screen.tabs.createElement(ui.Button, .{
            .x = tab_x_offset,
            .y = tab_y,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, button_width, button_height, 6, 6, 7, 7, 1.0) },
            },
            .text_data = .{
                .text = @constCast("Graphics"),
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .press_callback = graphicsTabCallback,
        });

        tab_x_offset += button_width + 10;

        _ = try screen.tabs.createElement(ui.Button, .{
            .x = tab_x_offset,
            .y = tab_y,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, button_width, button_height, 6, 6, 7, 7, 1.0) },
            },
            .text_data = .{
                .text = @constCast("Misc"),
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .press_callback = miscTabCallback,
        });

        try addKeyMap(screen.general_tab, &settings.move_up, "Move Up", "");
        try addKeyMap(screen.general_tab, &settings.move_down, "Move Down", "");
        try addKeyMap(screen.general_tab, &settings.move_right, "Move Right", "");
        try addKeyMap(screen.general_tab, &settings.move_left, "Move Left", "");
        try addKeyMap(screen.general_tab, &settings.rotate_left, "Rotate Left", "");
        try addKeyMap(screen.general_tab, &settings.rotate_right, "Rotate Right", "");
        try addKeyMap(screen.general_tab, &settings.escape, "Return to Nexus", "");
        try addKeyMap(screen.general_tab, &settings.interact, "Interact", "");
        try addKeyMap(screen.general_tab, &settings.shoot, "Shoot", "");
        try addKeyMap(screen.general_tab, &settings.ability, "Use Ability", "");
        try addKeyMap(screen.general_tab, &settings.toggle_centering, "Toggle Centering", "This toggles whether to center the camera on player or ahead of it");
        try addKeyMap(screen.general_tab, &settings.reset_camera, "Reset Camera", "This resets the camera's angle to the default of 0");
        try addKeyMap(screen.general_tab, &settings.toggle_stats, "Toggle Stats", "This toggles whether to show misc. stats like the FPS counter");

        try addKeyMap(screen.keys_tab, &settings.inv_0, "Use Inventory 1", "This will either consume or equip the item at the given slot. Backpack slots can be accessed by pressing this key in combination with CTRL");
        try addKeyMap(screen.keys_tab, &settings.inv_1, "Use Inventory 2", "This will either consume or equip the item at the given slot. Backpack slots can be accessed by pressing this key in combination with CTRL");
        try addKeyMap(screen.keys_tab, &settings.inv_2, "Use Inventory 3", "This will either consume or equip the item at the given slot. Backpack slots can be accessed by pressing this key in combination with CTRL");
        try addKeyMap(screen.keys_tab, &settings.inv_3, "Use Inventory 4", "This will either consume or equip the item at the given slot. Backpack slots can be accessed by pressing this key in combination with CTRL");
        try addKeyMap(screen.keys_tab, &settings.inv_4, "Use Inventory 5", "This will either consume or equip the item at the given slot. Backpack slots can be accessed by pressing this key in combination with CTRL");
        try addKeyMap(screen.keys_tab, &settings.inv_5, "Use Inventory 6", "This will either consume or equip the item at the given slot. Backpack slots can be accessed by pressing this key in combination with CTRL");
        try addKeyMap(screen.keys_tab, &settings.inv_6, "Use Inventory 7", "This will either consume or equip the item at the given slot. Backpack slots can be accessed by pressing this key in combination with CTRL");
        try addKeyMap(screen.keys_tab, &settings.inv_7, "Use Inventory 8", "This will either consume or equip the item at the given slot. Backpack slots can be accessed by pressing this key in combination with CTRL");

        try addToggle(screen.graphics_tab, &settings.enable_vsync, "V-Sync", "Toggles vertical syncing, which can reduce screen tearing");
        try addToggle(screen.graphics_tab, &settings.enable_lights, "Lights", "Toggles lights, which can reduce frame rates");
        try addToggle(screen.graphics_tab, &settings.enable_glow, "Sprite Glow", "Toggles the glow effect on sprites, which can reduce frame rates");

        try addToggle(screen.misc_tab, &settings.always_show_xp_gain, "Show EXP Gain", "Toggles to always show the EXP gained or just below 20");

        switch (screen.selected_tab_type) {
            .general => positionElements(screen.general_tab),
            .hotkeys => positionElements(screen.keys_tab),
            .graphics => positionElements(screen.graphics_tab),
            .misc => positionElements(screen.misc_tab),
        }

        screen.inited = true;
        return screen;
    }

    pub fn deinit(self: *OptionsPanel) void {
        while (!sc.ui_lock.tryLock()) {}
        defer sc.ui_lock.unlock();

        self.main.destroy();
        self.buttons.destroy();
        self.tabs.destroy();
        self.general_tab.destroy();
        self.keys_tab.destroy();
        self.graphics_tab.destroy();

        self._allocator.destroy(self);
    }

    fn addKeyMap(target_tab: *ui.DisplayContainer, button: *settings.Button, title: []const u8, desc: []const u8) !void {
        _ = desc;

        const button_data_base = assets.getUiData("buttonBase", 0);
        const button_data_hover = assets.getUiData("buttonHover", 0);
        const button_data_press = assets.getUiData("buttonPress", 0);

        const w = 50;
        const h = 50;

        _ = try target_tab.createElement(ui.KeyMapper, .{
            .x = 0,
            .y = 0,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, w, h, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, w, h, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, w, h, 6, 6, 7, 7, 1.0) },
            },
            .title_text_data = .{
                .text = @constCast(title),
                .size = 18,
                .text_type = .bold,
                .backing_buffer = &[0]u8{},
            },
            .key = button.getKey(),
            .mouse = button.getMouse(),
            .settings_button = button,
            .set_key_callback = keyCallback,
        });
    }

    fn addToggle(target_tab: *ui.DisplayContainer, value: *bool, title: []const u8, desc: []const u8) !void {
        _ = desc;

        const toggle_data_base_off = assets.getUiData("toggleSliderBaseOff", 0);
        const toggle_data_hover_off = assets.getUiData("toggleSliderHoverOff", 0);
        const toggle_data_press_off = assets.getUiData("toggleSliderPressOff", 0);
        const toggle_data_base_on = assets.getUiData("toggleSliderBaseOn", 0);
        const toggle_data_hover_on = assets.getUiData("toggleSliderHoverOn", 0);
        const toggle_data_press_on = assets.getUiData("toggleSliderPressOn", 0);

        _ = try target_tab.createElement(ui.Toggle, .{
            .x = 0,
            .y = 0,
            .off_image_data = .{
                .base = .{ .normal = .{ .atlas_data = toggle_data_base_off } },
                .hover = .{ .normal = .{ .atlas_data = toggle_data_hover_off } },
                .press = .{ .normal = .{ .atlas_data = toggle_data_press_off } },
            },
            .on_image_data = .{
                .base = .{ .normal = .{ .atlas_data = toggle_data_base_on } },
                .hover = .{ .normal = .{ .atlas_data = toggle_data_hover_on } },
                .press = .{ .normal = .{ .atlas_data = toggle_data_press_on } },
            },
            .text_data = .{
                .text = @constCast(title),
                .size = 16,
                .text_type = .bold,
                .backing_buffer = &[0]u8{},
            },
            .toggled = value,
        });
    }

    fn positionElements(container: *ui.DisplayContainer) void {
        for (container._elements.items(), 0..) |elem, i| {
            switch (elem) {
                .balloon, .status => {},
                inline else => |inner| {
                    inner.x = @floatFromInt(@divFloor(i, 6) * 300);
                    inner.y = @floatFromInt(@mod(i, 6) * 75);
                },
            }
        }
    }

    fn keyCallback(self: *ui.KeyMapper) void {
        // Should rethink whether we want to keep this from flash. Binding things to ESC is legitimate
        if (self.key == .escape) {
            self.settings_button.* = .{ .key = .unknown };
        } else if (self.key != .unknown) {
            self.settings_button.* = .{ .key = self.key };
        } else {
            self.settings_button.* = .{ .mouse = self.mouse };
        }

        if (self.settings_button == &settings.interact)
            settings.interact_key_tex = settings.getKeyTexture(settings.interact);

        trySave();
    }

    fn closeCallback() void {
        sc.current_screen.game.panel_controller.setOptionsVisible(false);

        trySave();
    }

    fn resetToDefaultsCallback() void {
        settings.resetToDefault();
    }

    fn generalTabCallback() void {
        switchTab(.general);
    }

    fn hotkeysTabCallback() void {
        switchTab(.hotkeys);
    }

    fn graphicsTabCallback() void {
        switchTab(.graphics);
    }

    fn miscTabCallback() void {
        switchTab(.misc);
    }

    fn disconnectCallback() void {
        closeCallback();
        main.disconnect();
    }

    fn trySave() void {
        var self = sc.current_screen.game.panel_controller.options;
        settings.save(self.settings_arr) catch |err| {
            std.debug.print("Caught error. {any}", .{err});
            return;
        };
    }

    pub fn switchTab(tab: TabType) void {
        var self = sc.current_screen.game.panel_controller.options;

        self.selected_tab_type = tab;
        self.general_tab.visible = tab == .general;
        self.keys_tab.visible = tab == .hotkeys;
        self.graphics_tab.visible = tab == .graphics;
        self.misc_tab.visible = tab == .misc;

        switch (tab) {
            .general => positionElements(self.general_tab),
            .hotkeys => positionElements(self.keys_tab),
            .graphics => positionElements(self.graphics_tab),
            .misc => positionElements(self.misc_tab),
        }
    }

    pub fn setVisible(self: *OptionsPanel, val: bool) void {
        self.main.visible = val;
        self.buttons.visible = val;
        self.tabs.visible = val;

        if (val) {
            switchTab(.general);
        } else {
            self.general_tab.visible = false;
            self.keys_tab.visible = false;
            self.graphics_tab.visible = false;
            self.misc_tab.visible = false;
        }
    }

    pub fn resize(_: *OptionsPanel, _: f32, _: f32) void {}
};
