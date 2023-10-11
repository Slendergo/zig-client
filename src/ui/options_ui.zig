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

pub const Tabs = enum {
    general,
    hotkeys,
    graphics,
    performance,
};

pub const OptionsUi = struct {
    visible: bool = true,
    _allocator: std.mem.Allocator = undefined,
    inited: bool = false,
    selected_tab: Tabs = Tabs.general, //which tab do we start visible on
    main_cont: *ui.DisplayContainer = undefined,
    buttons_cont: *ui.DisplayContainer = undefined,
    tabs_cont: *ui.DisplayContainer = undefined,
    gen_cont: *ui.DisplayContainer = undefined,
    keys_cont: *ui.DisplayContainer = undefined,
    graphics_cont: *ui.DisplayContainer = undefined,
    perf_cont: *ui.DisplayContainer = undefined,

    pub fn init(allocator: std.mem.Allocator) !*OptionsUi {
        var screen = try allocator.create(OptionsUi);
        screen.* = .{ ._allocator = allocator };

        const button_data_base = assets.getUiData("buttonBase", 0);
        const button_data_hover = assets.getUiData("buttonHover", 0);
        const button_data_press = assets.getUiData("buttonPress", 0);
        const text_input_press = assets.getUiData("textInputPress", 0);
        const options_background = assets.getUiData("optionsBackground", 0);
        const button_width = 150;
        const button_height = 50;
        const button_half_width = (button_width / 2);
        const button_half_height = (button_height / 2);

        var width: f32 = camera.screen_width;
        var height: f32 = camera.screen_height;

        var buttons_x: f32 = width / 2;
        var buttons_y: f32 = height - button_height - 50;
        //var half_height: f32 = height / 2;

        screen.main_cont = try ui.DisplayContainer.create(allocator, .{
            .x = 0,
            .y = 0,
        });
        screen.buttons_cont = try ui.DisplayContainer.create(allocator, .{
            .x = 0,
            .y = buttons_y,
        });
        screen.tabs_cont = try ui.DisplayContainer.create(allocator, .{
            .x = 0,
            .y = 50,
        });
        screen.gen_cont = try ui.DisplayContainer.create(allocator, .{
            .x = 0,
            .y = 100,
            .visible = screen.selected_tab == Tabs.general,
        });
        screen.keys_cont = try ui.DisplayContainer.create(allocator, .{
            .x = 0,
            .y = 100,
            .visible = screen.selected_tab == Tabs.hotkeys,
        });
        screen.graphics_cont = try ui.DisplayContainer.create(allocator, .{
            .x = 0,
            .y = 100,
            .visible = screen.selected_tab == Tabs.graphics,
        });
        screen.perf_cont = try ui.DisplayContainer.create(allocator, .{
            .x = 0,
            .y = 100,
            .visible = screen.selected_tab == Tabs.performance,
        });

        const bg_image = try screen.main_cont.createElement(ui.Image, .{ .x = 0, .y = 0, .image_data = .{
            .nine_slice = NineSlice.fromAtlasData(options_background, width, height, 0, 0, 8, 8, 1.0),
        } });
        _ = bg_image;

        const buttons_bg_image = try screen.buttons_cont.createElement(ui.Image, .{ .x = 0, .y = -20, .image_data = .{
            .nine_slice = NineSlice.fromAtlasData(text_input_press, width, button_height + 40, 8, 8, 32, 32, 1.0),
        } });
        buttons_bg_image.x = 0;

        const cls_but = try screen.buttons_cont.createElement(ui.Button, .{
            .x = buttons_x - button_half_width,
            .y = buttons_bg_image.y + button_half_height,
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
        cls_but.x = buttons_x - button_half_width;

        const disc_but = try screen.buttons_cont.createElement(ui.Button, .{
            .x = width - button_width - 50,
            .y = buttons_bg_image.y + button_half_height,
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
        disc_but.x = width - button_width - 50;

        const reset_but = try screen.buttons_cont.createElement(ui.Button, .{
            .x = 50,
            .y = buttons_bg_image.y + button_half_height,
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
        reset_but.x = 50;

        const title_text = try screen.main_cont.createElement(ui.UiText, .{ .x = buttons_x - 76, .y = 50, .text_data = .{
            .text = @constCast("Options"),
            .size = 24,
            .text_type = .bold,
            .backing_buffer = try allocator.alloc(u8, 8),
        } });
        title_text.x = buttons_x - 76;

        var tab_x_offset: f32 = 50;
        const tab_y: f32 = 100;

        const gen_tab = try screen.tabs_cont.createElement(ui.Button, .{
            .x = tab_x_offset,
            .y = tab_y,
            .visible = screen.visible,
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
        gen_tab.x = tab_x_offset;

        tab_x_offset += 100 + button_width;

        const keys_tab = try screen.tabs_cont.createElement(ui.Button, .{
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
        keys_tab.x = tab_x_offset;

        tab_x_offset += 100 + button_width;

        const graphics_tab = try screen.tabs_cont.createElement(ui.Button, .{
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
        graphics_tab.x = tab_x_offset;

        tab_x_offset += 100 + button_width;

        const perf_tab = try screen.tabs_cont.createElement(ui.Button, .{
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
        perf_tab.x = tab_x_offset;

        const key_width: f32 = 50;
        const key_y_spacer: f32 = 20 + button_height;
        const key_title_size: f32 = 18;
        var key_y: f32 = key_y_spacer;
        const magic: f32 = key_title_size * 9;

        const move_up_map = try screen.gen_cont.createElement(ui.KeyMapper, .{
            .x = key_width + magic,
            .y = key_y,
            .visible = screen.selected_tab == Tabs.general,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, key_width, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, key_width, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, key_width, button_height, 6, 6, 7, 7, 1.0) },
            },
            .text_data = .{
                .text = @constCast(@tagName(settings.move_up.getKey())),
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .title_text_data = .{
                .text = @constCast("Move up"),
                .size = key_title_size,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .key = settings.move_up.getKey(),
            .settings_button = &settings.move_up,
            .set_key_callback = keyCallback,
        });
        move_up_map.y = key_y;

        key_y += key_y_spacer;

        const move_down_map = try screen.gen_cont.createElement(ui.KeyMapper, .{
            .x = key_width + magic,
            .y = key_y,
            .visible = screen.selected_tab == Tabs.general,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, key_width, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, key_width, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, key_width, button_height, 6, 6, 7, 7, 1.0) },
            },
            .text_data = .{
                .text = @constCast(@tagName(settings.move_down.getKey())),
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .title_text_data = .{
                .text = @constCast("Move down"),
                .size = key_title_size,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .key = settings.move_down.getKey(),
            .settings_button = &settings.move_down,
            .set_key_callback = keyCallback,
        });
        move_down_map.y = key_y;

        key_y += key_y_spacer;

        const move_right_map = try screen.gen_cont.createElement(ui.KeyMapper, .{
            .x = key_width + magic,
            .y = key_y,
            .visible = screen.selected_tab == Tabs.general,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, key_width, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, key_width, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, key_width, button_height, 6, 6, 7, 7, 1.0) },
            },
            .text_data = .{
                .text = @constCast(@tagName(settings.move_right.getKey())),
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .title_text_data = .{
                .text = @constCast("Move right"),
                .size = key_title_size,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .key = settings.move_right.getKey(),
            .settings_button = &settings.move_right,
            .set_key_callback = keyCallback,
        });
        move_right_map.y = key_y;

        key_y += key_y_spacer;

        const move_left_map = try screen.gen_cont.createElement(ui.KeyMapper, .{
            .x = key_width + magic,
            .y = key_y,
            .visible = screen.selected_tab == Tabs.general,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, key_width, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, key_width, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, key_width, button_height, 6, 6, 7, 7, 1.0) },
            },
            .text_data = .{
                .text = @constCast(@tagName(settings.move_left.getKey())),
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .title_text_data = .{
                .text = @constCast("Move left"),
                .size = key_title_size,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .key = settings.move_left.getKey(),
            .settings_button = &settings.move_left,
            .set_key_callback = keyCallback,
        });
        move_left_map.y = key_y;

        const toggle_data_base_off = assets.getUiData("toggleSliderBaseOff", 0);
        const toggle_data_hover_off = assets.getUiData("toggleSliderHoverOff", 0);
        const toggle_data_press_off = assets.getUiData("toggleSliderPressOff", 0);
        const toggle_data_base_on = assets.getUiData("toggleSliderBaseOn", 0);
        const toggle_data_hover_on = assets.getUiData("toggleSliderHoverOn", 0);
        const toggle_data_press_on = assets.getUiData("toggleSliderPressOn", 0);

        const toggle_width: f32 = 100;
        const toggle_height: f32 = 50;
        const toggle_x_offset: f32 = 25;
        const toggle_y_offset: f32 = 75;
        var toggle_y: f32 = toggle_y_offset;

        _ = try screen.graphics_cont.createElement(ui.Toggle, .{
            .x = toggle_x_offset + magic,
            .y = toggle_y,
            .visible = screen.selected_tab == Tabs.graphics,
            .off_image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(toggle_data_base_off, toggle_width, toggle_height, 0, 0, 84, 48, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(toggle_data_hover_off, toggle_width, toggle_height, 0, 0, 84, 48, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(toggle_data_press_off, toggle_width, toggle_height, 0, 0, 84, 48, 1.0) },
            },
            .on_image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(toggle_data_base_on, toggle_width, toggle_height, 0, 0, 84, 48, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(toggle_data_hover_on, toggle_width, toggle_height, 0, 0, 84, 48, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(toggle_data_press_on, toggle_width, toggle_height, 0, 0, 84, 48, 1.0) },
            },
            .text_data = .{ .text = @constCast("V-Sync"), .size = 16, .text_type = .bold, .backing_buffer = try allocator.alloc(u8, 8) },
            .toggled = settings.enable_vsync,
            .state_change = onVSyncToggle,
        });

        toggle_y += toggle_y_offset;

        _ = try screen.graphics_cont.createElement(ui.Toggle, .{
            .x = toggle_x_offset + magic,
            .y = toggle_y,
            .visible = screen.selected_tab == Tabs.graphics,
            .off_image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(toggle_data_base_off, toggle_width, toggle_height, 0, 0, 84, 48, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(toggle_data_hover_off, toggle_width, toggle_height, 0, 0, 84, 48, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(toggle_data_press_off, toggle_width, toggle_height, 0, 0, 84, 48, 1.0) },
            },
            .on_image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(toggle_data_base_on, toggle_width, toggle_height, 0, 0, 84, 48, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(toggle_data_hover_on, toggle_width, toggle_height, 0, 0, 84, 48, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(toggle_data_press_on, toggle_width, toggle_height, 0, 0, 84, 48, 1.0) },
            },
            .text_data = .{
                .text = @constCast("Lights"),
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .toggled = settings.enable_lights,
            .state_change = onLightsToggle,
        });

        toggle_y += toggle_y_offset;

        _ = try screen.graphics_cont.createElement(ui.Toggle, .{
            .x = toggle_x_offset + magic,
            .y = toggle_y,
            .visible = screen.selected_tab == Tabs.graphics,
            .off_image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(toggle_data_base_off, toggle_width, toggle_height, 0, 0, 84, 48, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(toggle_data_hover_off, toggle_width, toggle_height, 0, 0, 84, 48, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(toggle_data_press_off, toggle_width, toggle_height, 0, 0, 84, 48, 1.0) },
            },
            .on_image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(toggle_data_base_on, toggle_width, toggle_height, 0, 0, 84, 48, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(toggle_data_hover_on, toggle_width, toggle_height, 0, 0, 84, 48, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(toggle_data_press_on, toggle_width, toggle_height, 0, 0, 84, 48, 1.0) },
            },
            .text_data = .{ .text = @constCast("Glow"), .size = 16, .text_type = .bold, .backing_buffer = try allocator.alloc(u8, 8) },
            .toggled = settings.enable_glow,
            .state_change = onGlowToggle,
        });

        screen.inited = true;
        return screen;
    }

    pub fn deinit(self: *OptionsUi) void {
        while (!ui.ui_lock.tryLock()) {}
        defer ui.ui_lock.unlock();

        self.gen_cont.destroy();
        self.buttons_cont.destroy();
        self.tabs_cont.destroy();
        self.keys_cont.destroy();
        self.perf_cont.destroy();
        self.graphics_cont.destroy();
        self.main_cont.destroy();

        self._allocator.destroy(self);
    }

    fn onVSyncToggle(self: *ui.Toggle) void {
        settings.enable_vsync = self.toggled;
    }

    fn onLightsToggle(self: *ui.Toggle) void {
        settings.enable_lights = self.toggled;
    }

    fn onGlowToggle(self: *ui.Toggle) void {
        settings.enable_glow = self.toggled;
    }

    fn keyCallback(self: *ui.KeyMapper) void {
        self.settings_button.key = self.key;
    }

    fn closeCallback() void {
        ui.hideOptions();
    }

    fn resetToDefaultsCallback() void {
        settings.resetToDefault();
    }

    fn generalTabCallback() void {
        switchTab(.general);
    }

    fn graphicsTabCallback() void {
        switchTab(.graphics);
    }

    fn hotkeysTabCallback() void {
        switchTab(.hotkeys);
    }

    fn performanceTabCallback() void {
        switchTab(.performance);
    }

    fn disconnectCallback() void {
        closeCallback();
        main.disconnect();
    }

    pub fn switchTab(tab: Tabs) void {
        ui.options.selected_tab = tab;
        ui.options.gen_cont.visible = tab == .general;
        ui.options.keys_cont.visible = tab == .hotkeys;
        ui.options.graphics_cont.visible = tab == .graphics;
        ui.options.perf_cont.visible = tab == .performance;
    }
};
