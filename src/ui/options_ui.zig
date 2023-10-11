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

    general_tab_button: *ui.Button = undefined,
    hotkeys_tab_button: *ui.Button = undefined,
    graphics_tab_button: *ui.Button = undefined,
    performance_tab_button: *ui.Button = undefined,

    selected_tab: Tabs = Tabs.general,

    general_text: *ui.UiText = undefined,
    graphics_text: *ui.UiText = undefined,
    hotkeys_text: *ui.UiText = undefined,
    performance_text: *ui.UiText = undefined,

    move_up_mapper: *ui.KeyMapper = undefined,
    move_down_mapper: *ui.KeyMapper = undefined,
    move_right_mapper: *ui.KeyMapper = undefined,
    move_left_mapper: *ui.KeyMapper = undefined,

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
            .backing_buffer = try allocator.alloc(u8, 8),
        } });

        var tab_x_offset: f32 = 50;
        const tab_y: f32 = 100;

        screen.general_tab_button = try ui.Button.create(allocator, .{
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

        //temp
        screen.general_text = try ui.UiText.create(allocator, .{ .x = buttons_x, .y = half_height, .visible = true, .text_data = .{
            .text = @constCast("General"),
            .size = 24,
            .text_type = .bold,
            .backing_buffer = try allocator.alloc(u8, 8),
        } });

        //temp
        screen.hotkeys_text = try ui.UiText.create(allocator, .{ .x = buttons_x, .y = half_height, .visible = false, .text_data = .{
            .text = @constCast("Hotkeys"),
            .size = 24,
            .text_type = .bold,
            .backing_buffer = try allocator.alloc(u8, 8),
        } });

        //temp
        screen.graphics_text = try ui.UiText.create(allocator, .{ .x = buttons_x, .y = half_height, .visible = false, .text_data = .{
            .text = @constCast("Graphics"),
            .size = 24,
            .text_type = .bold,
            .backing_buffer = try allocator.alloc(u8, 8),
        } });

        //temp
        screen.performance_text = try ui.UiText.create(allocator, .{ .x = buttons_x, .y = half_height, .visible = false, .text_data = .{
            .text = @constCast("Performance"),
            .size = 24,
            .text_type = .bold,
            .backing_buffer = try allocator.alloc(u8, 8),
        } });

        const key_width: f32 = 50;
        const key_y_spacer: f32 = 20 + button_height;
        const key_title_size: f32 = 18;
        var key_y: f32 = screen.general_tab_button.y + key_y_spacer;
        const magic: f32 = key_title_size * 9;

        screen.move_up_mapper = try ui.KeyMapper.create(allocator, .{
            .x = screen.general_tab_button.x + key_width + magic,
            .y = key_y,
            .visible = screen.selected_tab == Tabs.general,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, key_width, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, key_width, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, key_width, button_height, 6, 6, 7, 7, 1.0) },
            },
            .text_data = .{
                .text = "", //Set it to specific Settings.'key';
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .title_text_data = .{
                .text = @constCast("Move up"), //Set it to specific Settings.'key';
                .size = key_title_size,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .press_callback = keyCallback,
        });

        key_y += key_y_spacer;

        screen.move_down_mapper = try ui.KeyMapper.create(allocator, .{
            .x = screen.general_tab_button.x + key_width + magic,
            .y = key_y,
            .visible = screen.selected_tab == Tabs.general,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, key_width, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, key_width, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, key_width, button_height, 6, 6, 7, 7, 1.0) },
            },
            .text_data = .{
                .text = "", //Set it to specific Settings.'key';
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .title_text_data = .{
                .text = @constCast("Move down"), //Set it to specific Settings.'key';
                .size = key_title_size,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .press_callback = keyCallback,
        });

        key_y += key_y_spacer;

        screen.move_right_mapper = try ui.KeyMapper.create(allocator, .{
            .x = screen.general_tab_button.x + key_width + magic,
            .y = key_y,
            .visible = screen.selected_tab == Tabs.general,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, key_width, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, key_width, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, key_width, button_height, 6, 6, 7, 7, 1.0) },
            },
            .text_data = .{
                .text = "", //Set it to specific Settings.'key';
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .title_text_data = .{
                .text = @constCast("Move right"), //Set it to specific Settings.'key';
                .size = key_title_size,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .press_callback = keyCallback,
        });

        key_y += key_y_spacer;

        screen.move_left_mapper = try ui.KeyMapper.create(allocator, .{
            .x = screen.general_tab_button.x + key_width + magic,
            .y = key_y,
            .visible = screen.selected_tab == Tabs.general,
            .image_data = .{
                .base = .{ .nine_slice = NineSlice.fromAtlasData(button_data_base, key_width, button_height, 6, 6, 7, 7, 1.0) },
                .hover = .{ .nine_slice = NineSlice.fromAtlasData(button_data_hover, key_width, button_height, 6, 6, 7, 7, 1.0) },
                .press = .{ .nine_slice = NineSlice.fromAtlasData(button_data_press, key_width, button_height, 6, 6, 7, 7, 1.0) },
            },
            .text_data = .{
                .text = "", //Set it to specific Settings.'key';
                .size = 16,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .title_text_data = .{
                .text = @constCast("Move left"), //Set it to specific Settings.'key';
                .size = key_title_size,
                .text_type = .bold,
                .backing_buffer = try allocator.alloc(u8, 8),
            },
            .press_callback = keyCallback,
        });

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

        self.general_tab_button.destroy();
        self.hotkeys_tab_button.destroy();
        self.graphics_tab_button.destroy();
        self.performance_tab_button.destroy();

        self.general_text.destroy();
        self.hotkeys_text.destroy();
        self.graphics_text.destroy();
        self.performance_text.destroy();

        self.move_up_mapper.destroy();
        self.move_down_mapper.destroy();
        self.move_right_mapper.destroy();
        self.move_left_mapper.destroy();

        self._allocator.destroy(self);
    }

    fn keyCallback() void {
        settings.save();
    }

    fn closeCallback() void {
        ui.hideOptions();
    }

    fn resetToDefaultsCallback() void {
        settings.resetToDefault();
    }

    fn generalTabCallback() void {
        ui.switchOptionsTab(Tabs.general);
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

    pub fn switchTab(self: *OptionsUi, tab: Tabs) void {
        if (self.selected_tab == tab)
            return;

        self.selected_tab = tab;
        self.setGeneralVis(tab == Tabs.general);
        self.setHotkeysVis(tab == Tabs.hotkeys);
        self.setGraphicsVis(tab == Tabs.graphics);
        self.setPerformanceVis(tab == Tabs.performance);
    }

    //All components of each tab goes below
    fn setGeneralVis(self: *OptionsUi, val: bool) void {
        self.general_text.visible = val;
        self.move_up_mapper.visible = val;
        self.move_right_mapper.visible = val;
        self.move_left_mapper.visible = val;
        self.move_down_mapper.visible = val;
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
        general,
        hotkeys,
        graphics,
        performance,
    };
};
