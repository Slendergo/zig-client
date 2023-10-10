const std = @import("std");
const ui = @import("ui.zig");
const assets = @import("../assets.zig");
const camera = @import("../camera.zig");
const network = @import("../network.zig");
const xml = @import("../xml.zig");
const main = @import("../main.zig");
const utils = @import("../utils.zig");
const game_data = @import("../game_data.zig");
const map = @import("../map.zig");
const input = @import("../input.zig");
const settings = @import("../settings.zig");
const NineSlice = ui.NineSliceImageData;

pub const OptionsUi = struct {
    visible: bool = false,
    _allocator: std.mem.Allocator = undefined,
    inited: bool = false,

    close_button: *ui.Button = undefined,
    disconnect_button: *ui.Button = undefined,
    reset_to_default_button: *ui.Button = undefined,
    background_image: *ui.Image = undefined,
    buttons_background_image: *ui.Image = undefined,
    title_text: *ui.UiText = undefined,

    movement_tab_button: *ui.Button = undefined,
    graphics_tab_button: *ui.Button = undefined,
    hotkeys_tab_button: *ui.Button = undefined,
    performance_tab_button: *ui.Button = undefined,
    selected_tab: Tabs = Tabs.movement,

    movement_text: *ui.UiText = undefined,
    graphics_text: *ui.UiText = undefined,
    hotkeys_text: *ui.UiText = undefined,
    performance_text: *ui.UiText = undefined,

    pub fn init(allocator: std.mem.Allocator, data: OptionsUi) !*OptionsUi {
        var screen = try allocator.create(OptionsUi);
        screen.* = .{ ._allocator = allocator };

        screen.visible = data.visible;

        const button_data_base = assets.getUiData("buttonBase", 0);
        const button_data_hover = assets.getUiData("buttonHover", 0);
        const button_data_press = assets.getUiData("buttonPress", 0);
        const text_input_press = assets.getUiData("textInputPress", 0);
        const options_background = assets.getUiData("optionsBackground", 0);
        const button_width = 150;
        const button_height = 50;
        const button_half_width = (button_width / 2);
        //const button_half_height = (button_height / 2);

        var width: f32 = camera.screen_width;
        var height: f32 = camera.screen_height;

        var buttons_x: f32 = width / 2;
        var buttons_y: f32 = height - 50;

        var half_height: f32 = height / 2;

        screen.background_image = try ui.Image.create(allocator, .{ .x = 0, .y = 0, .visible = screen.visible, .image_data = .{
            .nine_slice = NineSlice.fromAtlasData(options_background, width, height, 0, 0, 8, 8, 1.0),
        } });

        screen.buttons_background_image = try ui.Image.create(allocator, .{ .x = 0, .y = buttons_y - button_height - 20, .visible = screen.visible, .image_data = .{
            .nine_slice = NineSlice.fromAtlasData(text_input_press, width, button_height + 40, 8, 8, 32, 32, 1.0),
        } });

        screen.close_button = try ui.Button.create(allocator, .{
            .x = buttons_x - button_half_width,
            .y = buttons_y - button_height,
            .visible = screen.visible,
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

        screen.disconnect_button = try ui.Button.create(allocator, .{
            .x = width - button_width - 50,
            .y = buttons_y - button_height,
            .visible = screen.visible,
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

        screen.reset_to_default_button = try ui.Button.create(allocator, .{
            .x = 50,
            .y = buttons_y - button_height,
            .visible = screen.visible,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, button_width, button_height, 6, 6, 7, 7, 1.0) },
            },
            .text_data = .{
                .text = @constCast("Reset to default"),
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .press_callback = resetToDefaultsCallback,
        });

        screen.title_text = try ui.UiText.create(allocator, .{ .x = buttons_x - 76, .y = 50, .text_data = .{
            .text = @constCast("Options"),
            .size = 24,
            .text_type = .bold,
            .backing_buffer = try allocator.alloc(u8, 32),
        } });

        var tab_x_offset: f32 = 50;
        const tab_y: f32 = 100;

        screen.movement_tab_button = try ui.Button.create(allocator, .{
            .x = tab_x_offset,
            .y = tab_y,
            .visible = screen.visible,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, button_width, button_height, 6, 6, 7, 7, 1.0) },
            },
            .text_data = .{
                .text = @constCast("Movement"),
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .press_callback = movementTabCallback,
        });

        tab_x_offset += 100 + button_width;

        screen.hotkeys_tab_button = try ui.Button.create(allocator, .{
            .x = tab_x_offset,
            .y = tab_y,
            .visible = screen.visible,
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

        tab_x_offset += 100 + button_width;

        screen.graphics_tab_button = try ui.Button.create(allocator, .{
            .x = tab_x_offset,
            .y = tab_y,
            .visible = screen.visible,
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

        tab_x_offset += 100 + button_width;

        screen.performance_tab_button = try ui.Button.create(allocator, .{
            .x = tab_x_offset,
            .y = tab_y,
            .visible = screen.visible,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, button_width, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, button_width, button_height, 6, 6, 7, 7, 1.0) },
            },
            .text_data = .{
                .text = @constCast("Performance"),
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .press_callback = performanceTabCallback,
        });

        screen.movement_text = try ui.UiText.create(allocator, .{ .x = buttons_x, .y = half_height, .visible = true, .text_data = .{
            .text = @constCast("Movement"),
            .size = 24,
            .text_type = .bold,
            .backing_buffer = try allocator.alloc(u8, 32),
        } });

        screen.graphics_text = try ui.UiText.create(allocator, .{ .x = buttons_x, .y = half_height, .visible = false, .text_data = .{
            .text = @constCast("Graphics"),
            .size = 24,
            .text_type = .bold,
            .backing_buffer = try allocator.alloc(u8, 32),
        } });

        screen.hotkeys_text = try ui.UiText.create(allocator, .{ .x = buttons_x, .y = half_height, .visible = false, .text_data = .{
            .text = @constCast("Hotkeys"),
            .size = 24,
            .text_type = .bold,
            .backing_buffer = try allocator.alloc(u8, 32),
        } });

        screen.performance_text = try ui.UiText.create(allocator, .{ .x = buttons_x, .y = half_height, .visible = false, .text_data = .{
            .text = @constCast("Performance"),
            .size = 24,
            .text_type = .bold,
            .backing_buffer = try allocator.alloc(u8, 32),
        } });

        screen.inited = true;
        return screen;
    }

    pub fn deinit(self: *OptionsUi) void {
        while (!ui.ui_lock.tryLock()) {}
        defer ui.ui_lock.unlock();

        self.background_image.destroy();
        self.buttons_background_image.destroy();
        self.close_button.destroy();
        self.disconnect_button.destroy();
        self.reset_to_default_button.destroy();
        self.title_text.destroy();

        self.movement_tab_button.destroy();
        self.hotkeys_tab_button.destroy();
        self.graphics_tab_button.destroy();
        self.performance_tab_button.destroy();

        self.movement_text.destroy();
        self.hotkeys_text.destroy();
        self.graphics_text.destroy();
        self.performance_text.destroy();

        self._allocator.destroy(self);
    }

    fn closeCallback() void {
        ui.hideOptions();
    }

    fn resetToDefaultsCallback() void {
        settings.resetToDefault();
    }

    fn movementTabCallback() void {
        ui.switchOptionsTab(Tabs.movement);
    }

    fn graphicsTabCallback() void {
        ui.switchOptionsTab(Tabs.graphics);
    }

    fn hotkeysTabCallback() void {
        ui.switchOptionsTab(Tabs.hotkeys);
    }

    fn performanceTabCallback() void {
        ui.switchOptionsTab(Tabs.performance);
    }

    fn disconnectCallback() void {
        closeCallback();
        main.disconnect();
    }

    //I don't like this but it works :L -Evil
    pub fn switchTab(self: *OptionsUi, tab: Tabs) void {
        if (self.selected_tab == tab)
            return;

        self.selected_tab = tab;

        switch (tab) {
            .movement => {
                setMovementVis(self, true);
                setGraphicsVis(self, false);
                setPerformanceVis(self, false);
                setHotkeysVis(self, false);
            },
            .hotkeys => {
                setMovementVis(self, false);
                setGraphicsVis(self, false);
                setPerformanceVis(self, false);
                setHotkeysVis(self, true);
            },
            .graphics => {
                setMovementVis(self, false);
                setGraphicsVis(self, true);
                setPerformanceVis(self, false);
                setHotkeysVis(self, false);
            },
            .performance => {
                setMovementVis(self, false);
                setGraphicsVis(self, false);
                setPerformanceVis(self, true);
                setHotkeysVis(self, false);
            },
        }
    }

    //All components of each tab goes below
    fn setMovementVis(self: *OptionsUi, val: bool) void {
        self.movement_text.visible = val;
    }
    fn setGraphicsVis(self: *OptionsUi, val: bool) void {
        self.graphics_text.visible = val;
    }
    fn setHotkeysVis(self: *OptionsUi, val: bool) void {
        self.hotkeys_text.visible = val;
    }
    fn setPerformanceVis(self: *OptionsUi, val: bool) void {
        self.performance_text.visible = val;
    }

    pub const Tabs = enum {
        movement,
        hotkeys,
        graphics,
        performance,
    };
};
